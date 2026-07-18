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
 *   - concluida → cria comissão (se configurada)
 *   - qualquer outro status → remove comissões da OS
 *     (pendente: delete; paga: apaga despesa + comissão)
 *
 * Assim OS reaberta (atribuida) ou cancelada não deixa comissão fantasma.
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
  // Só na transição para concluida (prev !== concluida).
  if (prevStatus === "concluida") return;

  const profId = String(record.get("profissional") || "");
  if (!profId) {
    console.log("[comissao] OS sem profissional; skip.");
    return;
  }

  const osId = record.id;

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
    console.log("[comissao] comissao_valor inválido; skip.");
    return;
  }

  // ── Diária: 1× por dia BRT se ≥1 OS concluída (não exige valor_pago) ─────
  if (tipo === "diaria") {
    const ymd = dataParedeDaOs(record);
    if (jaTemDiariaNoDia(app, profId, ymd)) {
      console.log(
        "[comissao] diária já existe p/ " + profId + " em " + ymd + "; skip.",
      );
      return;
    }
    const valorComissao = Math.round(base * 100) / 100;
    const valorPago = Number(record.get("valor_pago") || 0);
    const nomeCurto = String(record.get("nome_curto") || "");
    try {
      salvarComissao(app, {
        profissional: profId,
        profissional_nome: String(prof.get("name") || ""),
        os: osId,
        valor_os: valorPago,
        valor_comissao: valorComissao,
        tipo_aplicado: "diaria",
        base_valor: base,
        status: "pendente",
        data: ymd,
        descricao:
          "Diária · " +
          ymd +
          (nomeCurto ? " · " + nomeCurto : ""),
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

  const valorPago = Number(record.get("valor_pago") || 0);
  if (!(valorPago > 0)) {
    console.log("[comissao] OS sem valor_pago > 0; skip.");
    return;
  }

  // Anti-duplicata por OS (percentual/fixo)
  try {
    app.findFirstRecordByFilter(
      "prof_comissoes",
      "os = '" + osId.replace(/'/g, "\\'") + "'",
    );
    console.log("[comissao] já existe para OS " + osId + "; skip.");
    return;
  } catch (_) {
    /* not found */
  }

  let valorComissao = 0;
  if (tipo === "percentual") {
    valorComissao = Math.round(((valorPago * base) / 100) * 100) / 100;
  } else {
    valorComissao = Math.round(base * 100) / 100;
  }
  if (!(valorComissao > 0)) return;

  const nomeCurto = String(record.get("nome_curto") || "");
  const servico = String(record.get("tipo_servico_nome") || "");
  try {
    salvarComissao(app, {
      profissional: profId,
      profissional_nome: String(prof.get("name") || ""),
      os: osId,
      valor_os: valorPago,
      valor_comissao: valorComissao,
      tipo_aplicado: tipo,
      base_valor: base,
      status: "pendente",
      data: dataParedeDaOs(record),
      descricao: (servico || "OS") + (nomeCurto ? " · " + nomeCurto : ""),
    });
    console.log(
      "[comissao] OS " +
        osId +
        " → R$ " +
        valorComissao +
        " (" +
        tipo +
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
  removerComissoesDaOs,
  dataBrtAgora,
  dataParedeDaOs,
};
