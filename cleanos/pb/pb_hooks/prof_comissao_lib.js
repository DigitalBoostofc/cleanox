/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — gera comissão do profissional ao concluir OS.
 *
 * Best-effort (nunca lança). Idempotente por os_id único em prof_comissoes.
 * Só cria se o profissional tiver comissao_tipo percentual|fixo e valor > 0.
 *
 * Chamado DEPOIS de e.next() (mesmo padrão de os_financeiro_lib.js).
 */

/**
 * "Agora" no fuso BRT (UTC-3), no formato que o PB grava.
 *
 * O processo do PocketBase roda em UTC na VPS. `new Date().toISOString()` puro
 * faz uma conclusão às 21:30 BRT gravar como 00:30 do DIA SEGUINTE — e os
 * relatórios bucketizam pela parte-data 'YYYY-MM-DD'.
 *
 * Preferir [dataParedeDaOs] (data_hora da OS) ao criar comissão/despesa —
 * "agora" só como fallback (sem data_hora / OS sumida).
 */
function dataBrtAgora() {
  var BRT_OFFSET_MS = 3 * 60 * 60 * 1000;
  return (
    new Date(Date.now() - BRT_OFFSET_MS)
      .toISOString()
      .replace("T", " ")
      .slice(0, 23) + "Z"
  );
}

/**
 * Parte-data parede BRT da OS (`data_hora`), igual à receita via_os.
 * Assim a comissão e a entrada da OS caem no MESMO dia em Movimentações.
 * Fallback: dia BRT de agora.
 */
function dataParedeDaOs(osRecord) {
  try {
    return require(`${__hooks}/os_financeiro_lib.js`).dataParedeBrtDaOs(
      osRecord,
    );
  } catch (_) {
    return String(dataBrtAgora()).slice(0, 10);
  }
}

/**
 * Ponto único OS → comissão (chamar DEPOIS de e.next()):
 *   - concluida (1ª vez) → cria comissão (se configurada)
 *   - concluida (já era) → atualiza valor_os / valor_comissao se o valor mudou
 *   - qualquer outro status → remove comissões da OS
 *     (pendente: delete; paga: apaga despesa + comissão)
 *
 * Assim OS reaberta (atribuida) ou cancelada não deixa comissão fantasma.
 * E editar o valor_pago de uma OS já concluída recalcula a comissão do prof.
 */
function sincronizarComissaoOs(app, record, origStatus) {
  const status = String(record.get("status") || "");
  if (status === "concluida") {
    criarComissaoProfissional(app, record, origStatus);
    return;
  }
  removerComissoesDaOs(app, record.id);
}

/**
 * Lista comissões ligadas a uma OS (0..N; diária tem 1 por dia com os=).
 */
function listarComissoesDaOs(app, osId) {
  if (!osId) return [];
  try {
    const list = app.findRecordsByFilter(
      "prof_comissoes",
      "os = {:id}",
      "",
      50,
      0,
      { id: osId },
    );
    return list || [];
  } catch (_) {
    return [];
  }
}

/**
 * Recalcula valor_comissao a partir do tipo congelado na linha + base da OS.
 *   percentual → baseOs × base_valor% × fracao
 *   fixo | diaria → base_valor × fracao (diária em geral fracao=1)
 *
 * [baseOs] = total da OS (principal + extras cobráveis − descontos), ver
 * [valorBaseComissaoOs] — NÃO usar só valor_servico do orçamento inicial.
 * [fracao] = 1 solo; 0.5 em dupla (percentual/fixo). Diária usa 1.
 */
function calcValorComissao(tipoAplicado, baseValor, baseOs, fracao) {
  const tipo = String(tipoAplicado || "").toLowerCase();
  const base = Number(baseValor || 0);
  const osValor = Number(baseOs || 0);
  const f = fracao == null || !(Number(fracao) > 0) ? 1 : Number(fracao);
  if (!(base > 0)) return 0;
  if (tipo === "percentual") {
    if (!(osValor > 0)) return 0;
    return Math.round(((osValor * base) / 100) * f * 100) / 100;
  }
  if (tipo === "fixo" || tipo === "diaria") {
    return Math.round(base * f * 100) / 100;
  }
  return 0;
}

/** Fração da comissão %/fixo: 0.5 em dupla, 1 em solo. Diária não usa isto. */
function fracaoComissaoOs(record) {
  try {
    const osLib = require(`${__hooks}/os_logic.js`);
    return osLib.execucaoModo(record) === "dupla" ? 0.5 : 1;
  } catch (_) {
    const m = String(record.get("execucao_modo") || "").toLowerCase();
    return m === "dupla" ? 0.5 : 1;
  }
}

function profIdsParaComissao(record) {
  try {
    return require(`${__hooks}/os_logic.js`).profIdsDaOs(record);
  } catch (_) {
    const p1 = String(record.get("profissional") || "");
    const p2 = String(record.get("profissional2") || "");
    const modo = String(record.get("execucao_modo") || "").toLowerCase();
    if (modo === "dupla" && p1 && p2 && p1 !== p2) return [p1, p2];
    return p1 ? [p1] : [];
  }
}

/**
 * Adicionais cobráveis (mesmo critério do Flutter `valorTotal` e da receita
 * multi-linha em os_financeiro_lib): aprovado | nao_requer | vazio.
 *
 * Preferir getString: no JSVM, get() de JSONField devolve JSONRaw (bytes)
 * e Array.isArray falha — o total ficava só no principal (bug de extra).
 */
function _parseAdicionaisOs(record) {
  try {
    var raw = null;
    // getString devolve o JSON textual no JSVM (evita JSONRaw/bytes).
    // Só parsear se parecer JSON de array; senão cair no get().
    if (record.getString) {
      var s = String(record.getString("adicionais") || "").trim();
      // JSON real começa com "[{", "[]" ou whitespace+[. Evita String([obj])
      // do mock/JS que vira "[object Object]" e quebra o parse.
      if (
        s &&
        s !== "null" &&
        (s === "[]" || s.indexOf("[{") === 0 || s.indexOf("[\n") === 0)
      ) {
        raw = JSON.parse(s);
      }
    }
    if (raw == null) {
      raw = record.get("adicionais");
      if (raw == null || raw === "") return [];
      if (typeof raw === "string") {
        if (raw === "null" || raw === "[]") return raw === "[]" ? [] : [];
        raw = JSON.parse(raw);
      }
    }
    if (Array.isArray(raw)) return raw;
    // Array-like do goja (tem length, mas não é Array nativo)
    if (raw && typeof raw.length === "number" && raw.length >= 0) {
      var out = [];
      for (var i = 0; i < raw.length; i++) out.push(raw[i]);
      return out;
    }
    return [];
  } catch (_) {
    return [];
  }
}

function _isAdicionalCobravelOs(a) {
  if (!a) return false;
  const ap = String(a.aprovacao || "nao_requer");
  return ap === "aprovado" || ap === "nao_requer" || ap === "";
}

/**
 * Total da OS = principal (valor_servico) + extras cobráveis − descontos.
 * Espelha `OrdemServico.valorTotal` no Flutter.
 */
function calcValorTotalOs(record) {
  const principal = Number(record.get("valor_servico") || 0);
  var extras = 0;
  const ads = _parseAdicionaisOs(record);
  for (var i = 0; i < ads.length; i++) {
    const a = ads[i];
    if (!_isAdicionalCobravelOs(a)) continue;
    const v = Number(a.valor || 0) * Number(a.quantidade || 1);
    if (v > 0) extras += v;
  }
  const descontos = Number(record.get("descontos") || 0);
  const d = descontos > 0 ? descontos : 0;
  var total = principal + extras - d;
  if (total < 0) total = 0;
  return Math.round(total * 100) / 100;
}

/**
 * Base da comissão: o que realmente entrou no caixa (`valor_pago`).
 *
 * Regra do dono (2026-07): margem de negociação — tabela (principal + extras)
 * é orçamento; o profissional registra o valor cobrado na conclusão e a
 * comissão % usa ESSE valor. Se ainda não há pagamento, cai no total orçado
 * (estimativa / OS sem fechar).
 */
function valorBaseComissaoOs(record) {
  const pago = Number(record.get("valor_pago") || 0);
  if (pago > 0) return Math.round(pago * 100) / 100;
  return calcValorTotalOs(record);
}

/**
 * OS já estava concluída e foi regravada (ex.: admin editou valor_pago).
 * Atualiza todas as comissões ligadas a essa OS. Se não existir comissão
 * (config ausente na conclusão, backfill), tenta criar como na 1ª transição.
 *
 * Em dupla: mantém 1 linha por profissional da OS; remove órfãs; cria faltantes.
 * Best-effort. app.save na comissão dispara prof_comissao_pago (repasse se paga).
 */
function atualizarComissaoDaOs(app, record) {
  const osId = record.id;
  if (!osId) return;

  const baseOs = valorBaseComissaoOs(record);
  const list = listarComissoesDaOs(app, osId);
  const profIds = profIdsParaComissao(record);
  const fracao = fracaoComissaoOs(record);
  const nomeCurto = String(record.get("nome_curto") || "");
  const servico = String(record.get("tipo_servico_nome") || "");
  const emDupla = fracao < 1;

  if (!list || list.length === 0) {
    console.log(
      "[comissao] OS " +
        osId +
        " concluída regravada sem comissão; tenta criar.",
    );
    criarComissaoProfissional(app, record, "em_andamento");
    return;
  }

  // Mapa profId → comissões existentes (diária pode coexistir com %).
  const byProf = {};
  for (let i = 0; i < list.length; i++) {
    const rec = list[i];
    const pid = String(rec.get("profissional") || "");
    if (!byProf[pid]) byProf[pid] = [];
    byProf[pid].push(rec);
  }

  // Remove comissões de quem saiu da OS (troca de time / saiu da dupla).
  const wanted = {};
  for (let i = 0; i < profIds.length; i++) wanted[profIds[i]] = true;
  const pagoLib = require(`${__hooks}/prof_comissao_pago_lib.js`);
  for (let i = 0; i < list.length; i++) {
    const rec = list[i];
    const pid = String(rec.get("profissional") || "");
    if (wanted[pid]) continue;
    try {
      try {
        pagoLib.apagarLancamentoDaComissao(app, rec.id);
      } catch (err) {
        console.error("[comissao] remoção despesa órfã falhou: " + err);
      }
      app.delete(rec);
      console.log(
        "[comissao] removida órfã " + rec.id + " (prof " + pid + " saiu da OS)",
      );
    } catch (err) {
      console.error("[comissao] falha ao remover órfã " + rec.id + ": " + err);
    }
  }

  // Atualiza linhas dos profissionais atuais.
  for (let p = 0; p < profIds.length; p++) {
    const profId = profIds[p];
    const rows = byProf[profId] || [];
    if (rows.length === 0) {
      // Faltava linha (entrou na dupla depois) — cria como 1ª vez p/ este prof.
      _criarComissaoParaProf(app, record, profId, {
        force: true,
        skipDiariaDupCheck: false,
      });
      continue;
    }
    for (let i = 0; i < rows.length; i++) {
      const rec = rows[i];
      try {
        const tipo = String(rec.get("tipo_aplicado") || "").toLowerCase();
        const base = Number(rec.get("base_valor") || 0);
        // Diária: valor cheio por dia (não divide). %/fixo: fraciona na dupla.
        const fLinha = tipo === "diaria" ? 1 : fracao;
        const novoValor = calcValorComissao(tipo, base, baseOs, fLinha);
        const velhoValor = Number(rec.get("valor_comissao") || 0);
        const velhoOs = Number(rec.get("valor_os") || 0);

        let mudou = false;
        if (velhoOs !== baseOs) {
          rec.set("valor_os", baseOs);
          mudou = true;
        }
        if (velhoValor !== novoValor) {
          rec.set("valor_comissao", novoValor);
          mudou = true;
        }

        // Descrição: percentual/fixo reflete serviço; diária mantém prefixo.
        let desc;
        if (tipo === "diaria") {
          const ymd = String(rec.get("data") || dataParedeDaOs(record)).slice(
            0,
            10,
          );
          desc = "Diária · " + ymd + (nomeCurto ? " · " + nomeCurto : "");
        } else {
          desc = (servico || "OS") + (nomeCurto ? " · " + nomeCurto : "");
          if (emDupla) desc += " · Dupla";
        }
        if (desc && String(rec.get("descricao") || "") !== desc) {
          rec.set("descricao", desc);
          mudou = true;
        }

        if (!mudou) {
          console.log(
            "[comissao] OS " + osId + " regravada; comissão " + rec.id + " ok.",
          );
          continue;
        }

        app.save(rec);
        console.log(
          "[comissao] OS " +
            osId +
            " base total → R$ " +
            baseOs +
            "; comissão " +
            rec.id +
            " " +
            tipo +
            " R$ " +
            velhoValor +
            " → R$ " +
            novoValor,
        );
      } catch (err) {
        console.error(
          "[comissao] falha ao atualizar comissão da OS " + osId + ": " + err,
        );
      }
    }
  }
}

/**
 * Remove todas as comissões ligadas à OS.
 * Pendente: delete direto.
 * Paga: apaga o lançamento de despesa (via lib) e a comissão.
 */
function removerComissoesDaOs(app, osId) {
  if (!osId) return;
  let list = [];
  try {
    list = app.findRecordsByFilter(
      "prof_comissoes",
      "os = {:id}",
      "",
      50,
      0,
      { id: osId },
    );
  } catch (_) {
    list = [];
  }
  if (!list || list.length === 0) return;

  const pagoLib = require(`${__hooks}/prof_comissao_pago_lib.js`);
  for (let i = 0; i < list.length; i++) {
    const rec = list[i];
    try {
      // Sempre remove a despesa (pendente ou paga) antes da comissão.
      try {
        pagoLib.apagarLancamentoDaComissao(app, rec.id);
      } catch (err) {
        console.error(
          "[comissao] remoção despesa falhou (segue delete): " + err,
        );
      }
      app.delete(rec);
      console.log(
        "[comissao] removida " +
          rec.id +
          " (OS " +
          osId +
          " não está concluída)",
      );
    } catch (err) {
      console.error("[comissao] falha ao remover " + rec.id + ": " + err);
    }
  }
}

/**
 * Próximo dia civil a partir de YYYY-MM-DD (string data parede).
 */
function nextDayYmd(ymd) {
  const p = String(ymd || "").slice(0, 10).split("-");
  if (p.length !== 3) return "";
  const d = new Date(Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2])));
  d.setUTCDate(d.getUTCDate() + 1);
  const pad = (n) => String(n).padStart(2, "0");
  return (
    d.getUTCFullYear() +
    "-" +
    pad(d.getUTCMonth() + 1) +
    "-" +
    pad(d.getUTCDate())
  );
}

/**
 * Já existe comissão diária do profissional na data parede (YYYY-MM-DD)?
 */
function jaTemDiariaNoDia(app, profId, ymd) {
  const day = String(ymd || "").slice(0, 10);
  if (!day || !profId) return false;
  const next = nextDayYmd(day);
  if (!next) return false;
  try {
    const list = app.findRecordsByFilter(
      "prof_comissoes",
      'profissional = "' +
        String(profId).replace(/"/g, '\\"') +
        '" && tipo_aplicado = "diaria" && data >= "' +
        day +
        ' 00:00:00.000Z" && data < "' +
        next +
        ' 00:00:00.000Z"',
      "",
      1,
      0,
    );
    return !!(list && list.length);
  } catch (_) {
    return false;
  }
}

function salvarComissao(app, fields) {
  const col = app.findCollectionByNameOrId("prof_comissoes");
  const rec = new Record(col);
  const keys = Object.keys(fields);
  for (let i = 0; i < keys.length; i++) {
    rec.set(keys[i], fields[keys[i]]);
  }
  app.save(rec);
  return rec;
}

function criarComissaoProfissional(app, record, origStatus) {
  const newStatus = String(record.get("status") || "");
  if (newStatus !== "concluida") return;

  let prevStatus;
  if (arguments.length >= 3) {
    prevStatus = String(origStatus || "");
  } else {
    const orig = record.original ? record.original() : null;
    prevStatus = orig ? String(orig.get("status") || "") : "";
  }
  // Já estava concluída: não recria — atualiza valor se mudou (edit do admin).
  if (prevStatus === "concluida") {
    atualizarComissaoDaOs(app, record);
    return;
  }

  const profIds = profIdsParaComissao(record);
  if (!profIds.length) {
    console.log("[comissao] OS sem profissional; skip.");
    return;
  }

  for (let i = 0; i < profIds.length; i++) {
    _criarComissaoParaProf(app, record, profIds[i], { force: false });
  }
}

/**
 * Cria comissão de UM profissional para a OS (percentual/fixo/diária).
 * Em dupla: % e fixo usam metade (fracao 0.5). Diária permanece valor cheio/dia.
 */
function _criarComissaoParaProf(app, record, profId, opts) {
  opts = opts || {};
  const osId = record.id;
  if (!profId || !osId) return;

  let prof;
  try {
    prof = app.findRecordById("users", profId);
  } catch (e) {
    console.log("[comissao] profissional não encontrado: " + profId);
    return;
  }

  const tipo = String(prof.get("comissao_tipo") || "nenhuma").toLowerCase();
  const base = Number(prof.get("comissao_valor") || 0);
  if (!(base > 0)) {
    console.log("[comissao] comissao_valor inválido p/ " + profId + "; skip.");
    return;
  }

  const fracao = fracaoComissaoOs(record);
  const emDupla = fracao < 1;
  const baseOs = valorBaseComissaoOs(record);
  const nomeCurto = String(record.get("nome_curto") || "");
  const servico = String(record.get("tipo_servico_nome") || "");

  // ── Diária: 1× por dia BRT se ≥1 OS concluída (não exige valor_pago) ─────
  if (tipo === "diaria") {
    const ymd = dataParedeDaOs(record);
    if (!opts.skipDiariaDupCheck && jaTemDiariaNoDia(app, profId, ymd)) {
      console.log(
        "[comissao] diária já existe p/ " + profId + " em " + ymd + "; skip.",
      );
      return;
    }
    const valorComissao = Math.round(base * 100) / 100;
    try {
      salvarComissao(app, {
        profissional: profId,
        profissional_nome: String(prof.get("name") || ""),
        os: osId,
        valor_os: baseOs,
        valor_comissao: valorComissao,
        tipo_aplicado: "diaria",
        base_valor: base,
        status: "pendente",
        data: ymd,
        descricao:
          "Diária · " + ymd + (nomeCurto ? " · " + nomeCurto : ""),
      });
      console.log(
        "[comissao] diária " +
          ymd +
          " → R$ " +
          valorComissao +
          " para " +
          profId,
      );
    } catch (e) {
      console.error("[comissao] falha ao salvar diária: " + e);
    }
    return;
  }

  if (tipo !== "percentual" && tipo !== "fixo") {
    console.log("[comissao] prof " + profId + " sem comissão configurada.");
    return;
  }

  // Base = valor_pago (caixa real). Sem pagamento, total orçado.
  if (!(baseOs > 0)) {
    console.log("[comissao] OS sem valor total > 0; skip.");
    return;
  }

  // Anti-duplicata por OS + profissional (percentual/fixo)
  if (!opts.force) {
    try {
      app.findFirstRecordByFilter(
        "prof_comissoes",
        "os = {:os} && profissional = {:pid} && tipo_aplicado != 'diaria'",
        { os: osId, pid: profId },
      );
      console.log(
        "[comissao] já existe para OS " + osId + " + prof " + profId + "; skip.",
      );
      return;
    } catch (_) {
      /* not found — ok */
    }
  } else {
    // force: se já existe linha %/fixo deste prof, não cria outra.
    try {
      app.findFirstRecordByFilter(
        "prof_comissoes",
        "os = {:os} && profissional = {:pid} && tipo_aplicado != 'diaria'",
        { os: osId, pid: profId },
      );
      return;
    } catch (_) {
      /* not found */
    }
  }

  const valorComissao = calcValorComissao(tipo, base, baseOs, fracao);
  if (!(valorComissao > 0)) return;

  let desc = (servico || "OS") + (nomeCurto ? " · " + nomeCurto : "");
  if (emDupla) desc += " · Dupla";

  try {
    salvarComissao(app, {
      profissional: profId,
      profissional_nome: String(prof.get("name") || ""),
      os: osId,
      valor_os: baseOs,
      valor_comissao: valorComissao,
      tipo_aplicado: tipo,
      base_valor: base,
      status: "pendente",
      data: dataParedeDaOs(record),
      descricao: desc,
    });
    console.log(
      "[comissao] OS " +
        osId +
        " (total R$ " +
        baseOs +
        ") → R$ " +
        valorComissao +
        " (" +
        tipo +
        (emDupla ? " · dupla/2" : "") +
        ") para " +
        profId,
    );
  } catch (e) {
    console.error("[comissao] falha ao salvar: " + e);
  }
}

module.exports = {
  sincronizarComissaoOs,
  criarComissaoProfissional,
  atualizarComissaoDaOs,
  calcValorComissao,
  calcValorTotalOs,
  valorBaseComissaoOs,
  removerComissoesDaOs,
  dataBrtAgora,
  dataParedeDaOs,
  fracaoComissaoOs,
  profIdsParaComissao,
};
