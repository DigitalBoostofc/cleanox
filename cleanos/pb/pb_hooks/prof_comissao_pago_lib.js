/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — comissão ↔ despesa em fin_lancamentos (origem "via_comissao").
 *
 * Ciclo desejado (dono, 2026-07-21):
 *   OS concluída → cria **apenas** prof_comissoes (pendente)
 *                 → **NÃO** gera despesa por OS
 *   Equipe: comissões acumulam / somam por profissional
 *   Marcar paga (mãozinha ou Fechar ciclo) no dia de repasse
 *                 → **1 despesa** por profissional no dia (total a pagar)
 *                 → status pago (fin_saldo debita uma vez o total)
 *
 * Despesa de repasse: origem=via_comissao, profissional_id=<prof>,
 * data=dia do pagamento (pago_em), comissao_id vazio, valor=Σ comissões.
 *
 * ── R1 ─────────────────────────────────────────────────────────────────────
 * NUNCA grava fin_contas.saldo_atual. Só cria/atualiza/apaga o lançamento;
 * o saldo é do fin_saldo.pb.js.
 *
 * Best-effort: nunca lança.
 */

/**
 * Trava de reentrada: comissão → lançamento → comissão gerava loop eterno
 * (Fechar ciclo / mão em lote). Enquanto > 0, espelhos e efeitos colaterais
 * de re-save não disparam o outro lado de novo.
 *
 * Usa globalThis: em JSVM o require() pode recarregar o módulo e zerar um
 * `var` de arquivo — aí cada app.save(comissao) reentrava e criava fatias
 * duplicadas (ex.: 1 OS R$105 + 9 OS R$630 no mesmo segundo).
 */
function _syncKey() {
  return "__cleanos_comissao_sync_guard";
}
function _skip1x1Key() {
  return "__cleanos_comissao_skip_1x1";
}
function _beginSync() {
  try {
    var g = typeof globalThis !== "undefined" ? globalThis : null;
    if (g) g[_syncKey()] = (Number(g[_syncKey()]) || 0) + 1;
  } catch (_) {}
}
function _endSync() {
  try {
    var g = typeof globalThis !== "undefined" ? globalThis : null;
    if (g) {
      var n = Number(g[_syncKey()]) || 0;
      g[_syncKey()] = n > 0 ? n - 1 : 0;
    }
  } catch (_) {}
}
function _inSync() {
  try {
    var g = typeof globalThis !== "undefined" ? globalThis : null;
    if (g) return (Number(g[_syncKey()]) || 0) > 0;
  } catch (_) {}
  return false;
}
/** Durante pagamento em lote, nunca criar despesa 1:1 por OS. */
function _setSkip1x1(on) {
  try {
    var g = typeof globalThis !== "undefined" ? globalThis : null;
    if (g) g[_skip1x1Key()] = !!on;
  } catch (_) {}
}
function _skip1x1() {
  try {
    var g = typeof globalThis !== "undefined" ? globalThis : null;
    if (g) return !!g[_skip1x1Key()];
  } catch (_) {}
  return false;
}

/**
 * Atualiza status da comissão SEM disparar hooks (evita reentrada
 * app.save → sincronizarLancamento → 1:1 → delete → saldo infinito).
 * JSVM: cada hook pode ter VM isolada; globalThis guard não basta.
 */
function _sqlSetComissaoStatus(app, id, status, pagoEm) {
  var cid = String(id || "").trim();
  if (!cid) return false;
  var st = String(status || "");
  var pe = pagoEm == null ? "" : String(pagoEm).slice(0, 10);
  try {
    app
      .db()
      .newQuery(
        "UPDATE prof_comissoes SET status = {:st}, pago_em = {:pe} WHERE id = {:id}",
      )
      .bind({ st: st, pe: pe, id: cid })
      .execute();
    return true;
  } catch (err) {
    console.error("[comissao-pago] sqlSetComissaoStatus " + cid + ": " + err);
    return false;
  }
}

/**
 * Atualiza só metadados do lançamento SEM hooks de saldo.
 * Usado no lote: o e.next() do toggle já debitou/creditou o valor;
 * um 2º app.save reaplicava o efeito (desconto em dobro: 200→400).
 */
function _sqlUpdateLancMeta(app, id, fields) {
  var lid = String(id || "").trim();
  if (!lid || !fields) return false;
  try {
    var sets = [];
    var bind = { id: lid };
    if (fields.descricao != null) {
      sets.push("descricao = {:descricao}");
      bind.descricao = String(fields.descricao);
    }
    if (fields.observacao != null) {
      sets.push("observacao = {:observacao}");
      bind.observacao = String(fields.observacao);
    }
    if (fields.data != null) {
      // data parede YYYY-MM-DD (PB grava com hora 00:00Z)
      sets.push("data = {:data}");
      bind.data = String(fields.data).slice(0, 10);
    }
    if (fields.valor != null && isFinite(Number(fields.valor))) {
      // Só se o valor mudar: ajusta saldo manualmente (delta).
      // Preferir NÃO mudar valor no lote se o pendente já tinha o total certo.
      sets.push("valor = {:valor}");
      bind.valor = Number(fields.valor);
    }
    if (fields.status != null) {
      sets.push("status = {:status}");
      bind.status = String(fields.status);
    }
    if (!sets.length) return true;
    app
      .db()
      .newQuery(
        "UPDATE fin_lancamentos SET " + sets.join(", ") + " WHERE id = {:id}",
      )
      .bind(bind)
      .execute();
    return true;
  } catch (err) {
    console.error("[comissao-pago] sqlUpdateLancMeta " + lid + ": " + err);
    return false;
  }
}

/**
 * Resolve categoria de despesa da comissão/repasse.
 * Retorna { categoriaId, subcategoriaId }.
 *
 * Canônico (dono 2026-07-24): só a raiz **"Equipe"** (sem subcategorias
 * Comissões/Profissionais). Subs legadas, se ainda existirem, são ignoradas
 * (migração 1700000047 remove e re-aponta lançamentos).
 */
function acharCategoriaComissao(app, profNome, profId) {
  const configurada = _categoriaConfiguradaProf(app, profId);
  if (configurada) return configurada;
  // 1) Raiz Equipe
  try {
    const equipe = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && nome = 'Equipe' && (parent_id = '' || parent_id = null)",
    );
    if (equipe) {
      return _acharOuCriarSubcategoriaProf(app, equipe.id, profNome);
    }
  } catch (_) {}

  // 2) Fallback: id canônico do seed
  try {
    const e = app.findRecordById("fin_categorias", "catdequipe00001");
    if (e) return _acharOuCriarSubcategoriaProf(app, e.id, profNome);
  } catch (_) {}

  // 3) Fallback: 1ª despesa raiz
  try {
    const list = app.findRecordsByFilter(
      "fin_categorias",
      "tipo = 'despesa' && (parent_id = '' || parent_id = null)",
      "nome",
      1,
      0,
      {},
    );
    if (list && list.length > 0) {
      return _acharOuCriarSubcategoriaProf(app, list[0].id, profNome);
    }
  } catch (_) {}
  return null;
}

function _categoriaConfiguradaProf(app, profId) {
  const id = String(profId || "").trim();
  if (!id) return null;
  try {
    const user = app.findRecordById("users", id);
    const selectedId = String(user.get("categoria_comissao") || "").trim();
    if (!selectedId) return null;
    const selected = app.findRecordById("fin_categorias", selectedId);
    if (String(selected.get("tipo") || "") !== "despesa") return null;
    const parentId = String(selected.get("parent_id") || "").trim();
    if (!parentId) return { categoriaId: selected.id, subcategoriaId: null };
    return { categoriaId: parentId, subcategoriaId: selected.id };
  } catch (_) {
    return null;
  }
}

function _acharOuCriarSubcategoriaProf(app, equipeId, profNome) {
  const nome = String(profNome || "").trim();
  if (!nome) return { categoriaId: equipeId, subcategoriaId: null };
  const safeNome = nome.replace(/'/g, "\\'");
  try {
    const sub = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && parent_id = '" +
        equipeId +
        "' && nome = '" +
        safeNome +
        "'",
    );
    if (sub) return { categoriaId: equipeId, subcategoriaId: sub.id };
  } catch (_) {}
  try {
    const col = app.findCollectionByNameOrId("fin_categorias");
    const sub = new Record(col);
    sub.set("nome", nome);
    sub.set("tipo", "despesa");
    sub.set("parent_id", equipeId);
    sub.set("icone", "");
    sub.set("cor", "");
    sub.set("arquivada", false);
    app.save(sub);
    return { categoriaId: equipeId, subcategoriaId: sub.id };
  } catch (err) {
    console.log("[comissao-pago] subcategoria profissional: " + err);
    return { categoriaId: equipeId, subcategoriaId: null };
  }
}

function acharConta(app) {
  try {
    const padrao = app.findRecordsByFilter(
      "fin_contas",
      "ativo = true && padrao = true",
      "nome",
      1,
      0,
      {},
    );
    if (padrao && padrao.length > 0) return padrao[0].id;
  } catch (_) {}
  try {
    const ativas = app.findRecordsByFilter(
      "fin_contas",
      "ativo = true",
      "nome",
      1,
      0,
      {},
    );
    if (ativas && ativas.length > 0) return ativas[0].id;
  } catch (_) {}
  return null;
}

function dataBrtHojeYmd() {
  try {
    return String(
      require(`${__hooks}/prof_comissao_lib.js`).dataBrtAgora(),
    ).slice(0, 10);
  } catch (_) {
    var BRT = 3 * 60 * 60 * 1000;
    return new Date(Date.now() - BRT).toISOString().slice(0, 10);
  }
}

/** Lançamento 1:1 legado (uma despesa por comissão/OS) — ainda apagamos no estorno. */
function acharLancamentoDaComissao(app, comissaoId) {
  try {
    return app.findFirstRecordByFilter(
      "fin_lancamentos",
      "comissao_id = '" + String(comissaoId).replace(/'/g, "\\'") + "'",
    );
  } catch (_) {
    return null;
  }
}

/**
 * Próximo dia civil YYYY-MM-DD (UTC math — só para janela de data parede).
 */
function _nextDayYmd(ymd) {
  const p = String(ymd || "")
    .slice(0, 10)
    .split("-");
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
 * Lista despesas de **repasse PAGO** do prof no dia (via_comissao, sem
 * comissao_id). NÃO inclui linhas de ciclo pendente (`repasse_ciclo:…`) —
 * misturar as duas gerava "duplicata", apagava o ciclo e reabria OS (loop).
 *
 * IMPORTANTE: `data` no PB grava como `YYYY-MM-DD 00:00:00.000Z`. Filtro
 * `data = 'YYYY-MM-DD'` **não casa** — usar janela half-open [dia, dia+1).
 */
function listarLancamentosRepasse(app, profId, ymd) {
  const p = String(profId || "").replace(/"/g, '\\"');
  const d = String(ymd || "").slice(0, 10);
  if (!p || !/^\d{4}-\d{2}-\d{2}$/.test(d)) return [];
  const next = _nextDayYmd(d);
  if (!next) return [];

  function _filtrarSemCicloPendente(list) {
    var out = [];
    for (var i = 0; i < (list || []).length; i++) {
      var obs = String(list[i].get("observacao") || "");
      // Ciclo pendente é outro silo — não consolidar/apagar aqui.
      if (obs.indexOf("repasse_ciclo:") === 0) continue;
      out.push(list[i]);
    }
    return out;
  }

  // Preferência: profissional_id + janela + status pago (repasse quitado)
  try {
    const list = app.findRecordsByFilter(
      "fin_lancamentos",
      'origem = "via_comissao" && status = "pago" && profissional_id = "' +
        p +
        '" && data >= "' +
        d +
        ' 00:00:00.000Z" && data < "' +
        next +
        ' 00:00:00.000Z" && (comissao_id = "" || comissao_id = null)',
      "created",
      50,
      0,
    );
    var f = _filtrarSemCicloPendente(list);
    if (f.length) return f;
  } catch (_) {}

  // Fallback: data literal YYYY-MM-DD
  try {
    const list = app.findRecordsByFilter(
      "fin_lancamentos",
      'origem = "via_comissao" && status = "pago" && profissional_id = "' +
        p +
        '" && data = "' +
        d +
        '" && (comissao_id = "" || comissao_id = null)',
      "created",
      50,
      0,
    );
    var f2 = _filtrarSemCicloPendente(list);
    if (f2.length) return f2;
  } catch (_) {}

  // Fallback sem profissional_id: descrição de repasse
  try {
    const list = app.findRecordsByFilter(
      "fin_lancamentos",
      'origem = "via_comissao" && status = "pago" && data >= "' +
        d +
        ' 00:00:00.000Z" && data < "' +
        next +
        ' 00:00:00.000Z" && descricao ~ "Repasse" && (comissao_id = "" || comissao_id = null)',
      "created",
      50,
      0,
    );
    return _filtrarSemCicloPendente(list);
  } catch (_) {
    return [];
  }
}

/**
 * Uma despesa de repasse pago (a mais antiga). Consolida só duplicatas PAGAS
 * sem chave de ciclo — nunca apaga `repasse_ciclo:…`.
 */
function acharLancamentoRepasse(app, profId, ymd) {
  const list = listarLancamentosRepasse(app, profId, ymd);
  if (!list || list.length === 0) return null;
  const keep = list[0];
  for (var i = 1; i < list.length; i++) {
    try {
      app.delete(list[i]);
      console.log(
        "[comissao-pago] repasse pago duplicado " +
          list[i].id +
          " removido (upsert único).",
      );
    } catch (err) {
      console.error(
        "[comissao-pago] falha ao apagar repasse duplicado: " + err,
      );
    }
  }
  return keep;
}

function apagarLancamentoDaComissao(app, comissaoId) {
  const lanc = acharLancamentoDaComissao(app, comissaoId);
  if (!lanc) return false;
  app.delete(lanc);
  console.log("[comissao-pago] lançamento 1:1 " + lanc.id + " removido.");
  return true;
}

/**
 * Soma comissões pagas do profissional no dia de repasse e upsert 1 despesa.
 * Se total = 0, remove a despesa do dia.
 */
function recalcularDespesaRepasse(app, profId, ymd) {
  const p = String(profId || "").trim();
  const d = String(ymd || "").slice(0, 10);
  if (!p || !/^\d{4}-\d{2}-\d{2}$/.test(d)) return null;

  let list = [];
  try {
    list = app.findRecordsByFilter(
      "prof_comissoes",
      "profissional = {:pid} && status = 'paga' && pago_em = {:d}",
      "",
      500,
      0,
      { pid: p, d: d },
    );
  } catch (_) {
    // fallback filter string se {:} não funcionar em mock
    try {
      list = app.findRecordsByFilter(
        "prof_comissoes",
        "profissional = '" +
          p.replace(/'/g, "\\'") +
          "' && status = 'paga'",
        "",
        500,
        0,
      );
      list = (list || []).filter(function (c) {
        return String(c.get("pago_em") || "").slice(0, 10) === d;
      });
    } catch (_) {
      list = [];
    }
  }

  var cents = 0;
  var profNome = "";
  var n = 0;
  var minYmd = "";
  var maxYmd = "";
  for (var i = 0; i < (list || []).length; i++) {
    var c = list[i];
    var v = Number(c.get("valor_comissao") || 0);
    if (!(v > 0)) continue;
    cents += Math.round(v * 100);
    n++;
    if (!profNome) {
      profNome = String(c.get("profissional_nome") || "").trim();
    }
    var cd = String(c.get("data") || "")
      .trim()
      .slice(0, 10);
    if (/^\d{4}-\d{2}-\d{2}$/.test(cd)) {
      if (!minYmd || cd < minYmd) minYmd = cd;
      if (!maxYmd || cd > maxYmd) maxYmd = cd;
    }
  }
  var total = cents / 100.0;

  var existente = acharLancamentoRepasse(app, p, d);

  if (!(total > 0) || n === 0) {
    if (existente) {
      app.delete(existente);
      console.log(
        "[comissao-pago] repasse " +
          p +
          " @ " +
          d +
          " removido (sem comissões pagas).",
      );
    }
    return null;
  }

  if (!profNome) {
    try {
      var u = app.findRecordById("users", p);
      profNome = String(u.get("name") || u.get("nome") || "");
    } catch (_) {}
  }

  var cats = acharCategoriaComissao(app, profNome, p);
  if (!cats || !cats.categoriaId) {
    console.log("[comissao-pago] nenhuma categoria de despesa; skip repasse.");
    return null;
  }
  var contaId = acharConta(app);
  if (!contaId) {
    console.log("[comissao-pago] nenhuma conta ativa; skip repasse.");
    return null;
  }

  // Período das OS pagas (parede) — ex.: "20/07 a 26/07/2026"
  var periodo = "";
  if (minYmd && maxYmd) {
    periodo = _labelPeriodoBr(minYmd, maxYmd);
  }
  var descricao =
    "Repasse · " +
    (profNome || p.slice(0, 8)) +
    (periodo ? " · " + periodo : " · " + _ymdBr(d)) +
    " (" +
    n +
    " OS)";

  if (existente) {
    var mudou = false;
    if (Number(existente.get("valor") || 0) !== total) {
      existente.set("valor", total);
      mudou = true;
    }
    if (String(existente.get("status") || "") !== "pago") {
      existente.set("status", "pago");
      mudou = true;
    }
    if (String(existente.get("descricao") || "") !== descricao) {
      existente.set("descricao", descricao);
      mudou = true;
    }
    if (String(existente.get("profissional_id") || "") !== p) {
      try {
        existente.set("profissional_id", p);
        mudou = true;
      } catch (_) {}
    }
    if (mudou) app.save(existente);
    console.log(
      "[comissao-pago] repasse atualizado " +
        existente.id +
        " → R$ " +
        total +
        " (" +
        n +
        " comissões)",
    );
    return existente;
  }

  var col = app.findCollectionByNameOrId("fin_lancamentos");
  var lanc = new Record(col);
  lanc.set("tipo", "despesa");
  lanc.set("descricao", descricao);
  lanc.set("categoria_id", cats.categoriaId);
  lanc.set("subcategoria_id", cats.subcategoriaId || "");
  lanc.set("valor", total);
  lanc.set("conta_id", contaId);
  lanc.set("data", d);
  lanc.set("status", "pago");
  lanc.set("recorrencia", "unica");
  lanc.set("origem", "via_comissao");
  lanc.set("comissao_id", ""); // repasse agregado — sem 1:1
  lanc.set("os_id", "");
  try {
    lanc.set("profissional_id", p);
  } catch (_) {}
  app.save(lanc);
  console.log(
    "[comissao-pago] repasse criado " +
      lanc.id +
      " · " +
      (profNome || p) +
      " · R$ " +
      total +
      " · " +
      n +
      " comissões · " +
      d,
  );
  return lanc;
}

/**
 * Data do lançamento de comissão: mesma da entrada da OS (via_os).
 * Ordem (não usar "agora" nem data legada errada se a OS existir):
 *   1) data da receita via_os da mesma OS
 *   2) data_hora parede BRT da OS
 *   3) data já gravada na comissão
 *   4) dia BRT de agora
 */
function dataLancamentoComissao(app, comissao) {
  const comLib = require(`${__hooks}/prof_comissao_lib.js`);
  const osId = String(comissao.get("os") || "").trim();

  // 1) receita via_os — espelho da "entrada da conclusão" em Movimentações
  if (osId) {
    try {
      const rec = app.findFirstRecordByFilter(
        "fin_lancamentos",
        "os_id = {:id} && origem = 'via_os'",
        { id: osId },
      );
      const d = String(rec.get("data") || "")
        .trim()
        .slice(0, 10);
      if (/^\d{4}-\d{2}-\d{2}$/.test(d)) return d;
    } catch (_) {}
  }

  // 2) data_hora da OS
  if (osId) {
    try {
      const os = app.findRecordById("ordens_servico", osId);
      const d = comLib.dataParedeDaOs(os);
      if (d && /^\d{4}-\d{2}-\d{2}$/.test(String(d).slice(0, 10))) {
        return String(d).slice(0, 10);
      }
    } catch (_) {
      /* OS sumida */
    }
  }

  // 3) data da comissão (se legítima)
  const raw = String(comissao.get("data") || "").trim();
  if (raw) {
    const d = raw.slice(0, 10);
    if (/^\d{4}-\d{2}-\d{2}$/.test(d)) return d;
  }

  return String(comLib.dataBrtAgora()).slice(0, 10);
}

/**
 * Cria despesa via_comissao.
 * @param {string} statusLanc  "pendente" (ao concluir OS) | "pago" (ao marcar paga)
 */
function criarLancamentoDaComissao(app, comissao, statusLanc) {
  const status = statusLanc === "pago" ? "pago" : "pendente";

  if (acharLancamentoDaComissao(app, comissao.id)) {
    console.log("[comissao-pago] lançamento já existe; skip create.");
    return null;
  }

  const valor = Number(comissao.get("valor_comissao") || 0);
  if (!(valor > 0)) {
    console.log("[comissao-pago] valor_comissao <= 0; skip.");
    return null;
  }

  const profId = String(comissao.get("profissional") || "").trim();
  let profNome = String(comissao.get("profissional_nome") || "").trim();
  if (!profNome) {
    try {
      if (profId) {
        const p = app.findRecordById("users", profId);
        profNome = String(p.get("name") || "");
      }
    } catch (_) {}
  }

  const cats = acharCategoriaComissao(app, profNome, profId);
  if (!cats || !cats.categoriaId) {
    console.log("[comissao-pago] nenhuma categoria de despesa; skip.");
    return null;
  }
  const contaId = acharConta(app);
  if (!contaId) {
    console.log("[comissao-pago] nenhuma conta ativa; skip.");
    return null;
  }

  const desc = String(comissao.get("descricao") || "");
  const descricao =
    "Comissão" + (profNome ? " · " + profNome : "") + (desc ? " · " + desc : "");

  const osId = String(comissao.get("os") || "");
  const data = dataLancamentoComissao(app, comissao);

  const col = app.findCollectionByNameOrId("fin_lancamentos");
  const lanc = new Record(col);
  lanc.set("tipo", "despesa");
  lanc.set("descricao", descricao);
  lanc.set("categoria_id", cats.categoriaId);
  // Sem sub: só Equipe raiz (PB: "" se vazia, nunca null — R2)
  lanc.set("subcategoria_id", cats.subcategoriaId || "");
  lanc.set("valor", valor);
  lanc.set("conta_id", contaId);
  // Mesma data da OS / receita via_os — não "hoje" do backfill.
  lanc.set("data", data);
  lanc.set("status", status);
  lanc.set("recorrencia", "unica");
  lanc.set("origem", "via_comissao");
  lanc.set("comissao_id", comissao.id);
  if (osId) {
    lanc.set("os_id", osId);
    lanc.set("os_numero", osId.slice(-6).toUpperCase());
  }

  app.save(lanc);
  console.log(
    "[comissao-pago] comissão " +
      comissao.id +
      " → despesa " +
      status +
      " R$ " +
      valor +
      " (lanç. " +
      lanc.id +
      ")",
  );
  return lanc;
}

/** Garante despesa existente com o status pedido (cria ou atualiza). */
function garantirLancamentoStatus(app, comissao, statusLanc) {
  const status = statusLanc === "pago" ? "pago" : "pendente";
  const lanc = acharLancamentoDaComissao(app, comissao.id);
  if (!lanc) {
    return criarLancamentoDaComissao(app, comissao, status);
  }
  const atual = String(lanc.get("status") || "");
  const profId = String(comissao.get("profissional") || "").trim();
  let profNome = String(comissao.get("profissional_nome") || "").trim();
  if (!profNome) {
    try {
      if (profId) {
        const p = app.findRecordById("users", profId);
        profNome = String(p.get("name") || p.get("nome") || "");
      }
    } catch (_) {}
  }
  const cats = acharCategoriaComissao(app, profNome, profId);
  var mudou = false;
  if (atual !== status) {
    lanc.set("status", status);
    mudou = true;
  }
  // Mantém categoria Equipe (raiz) alinhada
  if (cats && cats.categoriaId) {
    if (String(lanc.get("categoria_id") || "") !== cats.categoriaId) {
      lanc.set("categoria_id", cats.categoriaId);
      mudou = true;
    }
    const wantSub = cats.subcategoriaId || "";
    if (String(lanc.get("subcategoria_id") || "") !== wantSub) {
      lanc.set("subcategoria_id", wantSub);
      mudou = true;
    }
  }
  const valor = Number(comissao.get("valor_comissao") || 0);
  if (valor > 0 && Number(lanc.get("valor") || 0) !== valor) {
    lanc.set("valor", valor);
    mudou = true;
  }
  if (!mudou) return lanc;
  app.save(lanc);
  console.log(
    "[comissao-pago] lançamento " +
      lanc.id +
      " status " +
      atual +
      " → " +
      status,
  );
  return lanc;
}

/**
 * Sincroniza despesa com o status da comissão (DEPOIS do e.next()).
 *
 * 👍 individual (Equipe, 1 OS):
 *   despesa 1:1 "Comissão - Prof - OS - Cliente" na data do 👍 (pago_em).
 *
 * Lote (Fechar ciclo / mão na linha da semana) NÃO passa por aqui para
 * cada OS — marca via linha repasse_ciclo e gera 1 despesa "… - N OS".
 */
function sincronizarLancamento(app, comissao, origStatus) {
  // Evita loop comissão → fin_lancamentos → comissão.
  if (_inSync()) return;
  _beginSync();
  try {
    const novo = String(comissao.get("status") || "");
    const profId = String(comissao.get("profissional") || "").trim();

    if (!profId) {
      if (novo === "paga") {
        garantirLancamentoStatus(app, comissao, "pago");
      } else {
        try {
          apagarLancamentoDaComissao(app, comissao.id);
        } catch (_) {}
      }
      return;
    }

    // pago_em = dia em que marcou paga (hoje BRT se vazio). NÃO fim do ciclo.
    if (novo === "paga") {
      var pe = String(comissao.get("pago_em") || "")
        .trim()
        .slice(0, 10);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(pe)) {
        pe = dataBrtHojeYmd();
        try {
          comissao.set("pago_em", pe);
        } catch (_) {}
      }
      // 1:1 SÓ se veio da Equipe (OS isolada). Lote seta _skip1x1.
      if (!_skip1x1()) {
        try {
          _upsertDespesaOsPaga(app, comissao, profId);
        } catch (err) {
          console.error("[comissao-pago] 1:1 individual: " + err);
        }
      }
    } else {
      try {
        apagarLancamentoDaComissao(app, comissao.id);
      } catch (_) {}
    }

    try {
      sincronizarCiclosDoProf(app, profId);
    } catch (err) {
      console.error("[comissao-pago] sincronizarCiclosDoProf: " + err);
    }
  } finally {
    _endSync();
  }
}

/**
 * Upsert despesa 1:1 paga por OS (caminho individual).
 * Retorna o lançamento ou null.
 */
function _upsertDespesaOsPaga(app, comissao, profId) {
  var p = String(profId || "").trim();
  var cid = String(comissao.id || "").trim();
  if (!p || !cid) return null;
  var valor = Number(comissao.get("valor_comissao") || 0);
  if (!(valor > 0)) return null;

  var pe = String(comissao.get("pago_em") || "")
    .trim()
    .slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(pe)) pe = dataBrtHojeYmd();

  var profNome = String(comissao.get("profissional_nome") || "").trim();
  if (!profNome) {
    try {
      var u = app.findRecordById("users", p);
      profNome = String(u.get("name") || u.get("nome") || "");
    } catch (_) {}
  }
  var descricao = _descricaoComissaoOsPaga(profNome || p.slice(0, 8), comissao);

  var cats = acharCategoriaComissao(app, profNome, p);
  if (!cats || !cats.categoriaId) return null;
  var contaId = acharConta(app);
  if (!contaId) return null;

  var existente = null;
  try {
    existente = acharLancamentoDaComissao(app, cid);
  } catch (_) {
    existente = null;
  }

  if (existente) {
    var mudou = false;
    if (Number(existente.get("valor") || 0) !== valor) {
      existente.set("valor", valor);
      mudou = true;
    }
    if (String(existente.get("status") || "") !== "pago") {
      existente.set("status", "pago");
      mudou = true;
    }
    if (String(existente.get("descricao") || "") !== descricao) {
      existente.set("descricao", descricao);
      mudou = true;
    }
    if (String(existente.get("data") || "").slice(0, 10) !== pe) {
      existente.set("data", pe);
      mudou = true;
    }
    if (String(existente.get("origem") || "") !== "via_comissao") {
      existente.set("origem", "via_comissao");
      mudou = true;
    }
    if (String(existente.get("categoria_id") || "") !== cats.categoriaId) {
      existente.set("categoria_id", cats.categoriaId);
      mudou = true;
    }
    try {
      if (String(existente.get("profissional_id") || "") !== p) {
        existente.set("profissional_id", p);
        mudou = true;
      }
    } catch (_) {}
    if (mudou) app.save(existente);
    return existente;
  }

  var col = app.findCollectionByNameOrId("fin_lancamentos");
  var lanc = new Record(col);
  lanc.set("tipo", "despesa");
  lanc.set("descricao", descricao);
  lanc.set("categoria_id", cats.categoriaId);
  lanc.set("subcategoria_id", cats.subcategoriaId || "");
  lanc.set("valor", valor);
  lanc.set("conta_id", contaId);
  lanc.set("data", pe);
  lanc.set("status", "pago");
  lanc.set("recorrencia", "unica");
  lanc.set("origem", "via_comissao");
  lanc.set("comissao_id", cid);
  try {
    lanc.set("profissional_id", p);
  } catch (_) {}
  app.save(lanc);
  console.log(
    "[comissao-pago] OS paga individual " +
      lanc.id +
      " · " +
      descricao +
      " · R$ " +
      valor +
      " · " +
      pe,
  );
  return lanc;
}

/**
 * Nome do cliente a partir da descrição da comissão / OS.
 * Ex.: "Cleanox Completo - Promoção · Renata Sabóia - Fiat Argo" → "Renata Sabóia"
 */
function _nomeClienteDaComissao(comissao) {
  var desc = String(comissao.get("descricao") || "").trim();
  if (!desc) return "OS";
  var rest = desc;
  var idx = desc.indexOf("·");
  if (idx >= 0) rest = desc.slice(idx + 1).trim();
  // "Cliente - Veículo" ou "Cliente = Veículo"
  var m = rest.match(/^(.+?)\s*[-–=]\s+.+$/);
  if (m && m[1] && m[1].trim().length >= 2) return m[1].trim();
  return rest || "OS";
}

function _isBonificacao(comissao) {
  return String(comissao.get("tipo_aplicado") || "").toLowerCase() === "bonificacao";
}

function _motivoBonificacao(comissao) {
  var desc = String(comissao.get("descricao") || "").trim();
  if (!desc) return "Bonificação";
  if (desc.toLowerCase().indexOf("bonificação") === 0) {
    var idx = desc.indexOf("·");
    if (idx >= 0) {
      var rest = desc.slice(idx + 1).trim();
      if (rest) return rest;
    }
    return "Bonificação";
  }
  return desc;
}

/**
 * Padrão dono: "Comissão - {prof} - OS - {cliente}"
 */
function _descricaoComissaoOsPaga(profNome, comissao) {
  var nome = String(profNome || "").trim() || "Profissional";
  if (_isBonificacao(comissao)) {
    return "Bonificação - " + nome + " - " + _motivoBonificacao(comissao);
  }
  var cliente = _nomeClienteDaComissao(comissao);
  return "Comissão - " + nome + " - OS - " + cliente;
}

/**
 * Formata YYYY-MM-DD → dd/MM/yyyy (parede, sem fuso).
 */
function _ymdBr(ymd) {
  var d = String(ymd || "").slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(d)) return d;
  return d.slice(8, 10) + "/" + d.slice(5, 7) + "/" + d.slice(0, 4);
}

/**
 * "20/07 a 26/07/2026" (mesmo ano omite ano no início).
 */
function _labelPeriodoBr(inicioYmd, fimYmd) {
  var a = String(inicioYmd || "").slice(0, 10);
  var b = String(fimYmd || "").slice(0, 10);
  if (a === b) return _ymdBr(a);
  if (a.slice(0, 4) === b.slice(0, 4)) {
    return (
      a.slice(8, 10) +
      "/" +
      a.slice(5, 7) +
      " a " +
      _ymdBr(b)
    );
  }
  return _ymdBr(a) + " a " + _ymdBr(b);
}

/**
 * Soma N dias a YYYY-MM-DD (calendário UTC, data de parede).
 */
function _addDaysYmd(ymd, n) {
  var p = String(ymd || "")
    .slice(0, 10)
    .split("-");
  if (p.length !== 3) return "";
  var d = new Date(Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2])));
  d.setUTCDate(d.getUTCDate() + n);
  var pad = function (x) {
    return String(x).padStart(2, "0");
  };
  return d.getUTCFullYear() + "-" + pad(d.getUTCMonth() + 1) + "-" + pad(d.getUTCDate());
}

/**
 * Weekday nosso (1=seg … 7=dom) da data parede YYYY-MM-DD.
 */
function _ourWeekdayYmd(ymd) {
  var p = String(ymd || "")
    .slice(0, 10)
    .split("-");
  if (p.length !== 3) return 0;
  var d = new Date(Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2])));
  // getUTCDay: 0=dom … 6=sáb → nosso: 7,1,2,3,4,5,6
  var js = d.getUTCDay();
  return js === 0 ? 7 : js;
}

/**
 * Janela do ciclo do profissional em torno de [refYmd] (YYYY-MM-DD).
 * Semanal sáb: domingo→sábado. Retorna {inicio, fim} ou null.
 */
function cicloDoProfEm(app, profId, refYmd) {
  var u;
  try {
    u = app.findRecordById("users", profId);
  } catch (_) {
    return null;
  }
  var freq = String(u.get("pagamento_frequencia") || "").toLowerCase();
  var ref = String(refYmd || "").slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(ref)) ref = dataBrtHojeYmd();
  var dia = Number(u.get("pagamento_dia") || 0);
  // Sem ciclo configurado: semana civil seg→dom (fallback seguro p/ testes e legado).
  if (!freq) {
    var w0 = _ourWeekdayYmd(ref); // 1=seg…7=dom
    var back = w0 - 1; // dias até segunda
    var inicio0 = _addDaysYmd(ref, -back);
    var fim0 = _addDaysYmd(inicio0, 6);
    return { inicio: inicio0, fim: fim0 };
  }

  if (freq === "diario") {
    return { inicio: ref, fim: ref };
  }
  if (freq === "semanal") {
    var target = dia >= 1 && dia <= 7 ? dia : 5;
    var w = _ourWeekdayYmd(ref);
    var delta = (target - w + 7) % 7;
    var fim = _addDaysYmd(ref, delta);
    var inicio = _addDaysYmd(fim, -6);
    return { inicio: inicio, fim: fim };
  }
  // mensal: 1 corte no dia configurado
  if (freq === "mensal") {
    var t = dia >= 1 && dia <= 31 ? dia : 15;
    var parts = ref.split("-");
    var y = Number(parts[0]);
    var m = Number(parts[1]);
    var day = Number(parts[2]);
    var last = new Date(Date.UTC(y, m, 0)).getUTCDate();
    var payDay = Math.min(t, last);
    var fimM;
    var iniM;
    if (day <= payDay) {
      fimM =
        y +
        "-" +
        String(m).padStart(2, "0") +
        "-" +
        String(payDay).padStart(2, "0");
      var pm = m === 1 ? 12 : m - 1;
      var py = m === 1 ? y - 1 : y;
      var plast = new Date(Date.UTC(py, pm, 0)).getUTCDate();
      var pp = Math.min(t, plast);
      iniM = _addDaysYmd(
        py +
          "-" +
          String(pm).padStart(2, "0") +
          "-" +
          String(pp).padStart(2, "0"),
        1,
      );
    } else {
      var nm = m === 12 ? 1 : m + 1;
      var ny = m === 12 ? y + 1 : y;
      var nlast = new Date(Date.UTC(ny, nm, 0)).getUTCDate();
      var np = Math.min(t, nlast);
      fimM =
        ny +
        "-" +
        String(nm).padStart(2, "0") +
        "-" +
        String(np).padStart(2, "0");
      iniM = _addDaysYmd(
        y +
          "-" +
          String(m).padStart(2, "0") +
          "-" +
          String(payDay).padStart(2, "0"),
        1,
      );
    }
    return { inicio: iniM, fim: fimM };
  }

  // quinzenal: 2 cortes — pagamento_dia + pagamento_dia_2 (0 = último do mês).
  // Espelha Flutter cicloCorrente (ex. João: 15 e fim do mês → 16–31/07).
  if (freq === "quinzenal") {
    var d1 = dia >= 1 && dia <= 31 ? dia : 15;
    var d2raw = Number(u.get("pagamento_dia_2") || 0);
    var partsQ = ref.split("-");
    var yQ = Number(partsQ[0]);
    var mQ = Number(partsQ[1]);
    var dayQ = Number(partsQ[2]);
    var pad = function (x) {
      return String(x).padStart(2, "0");
    };
    function _lastDay(yy, mm) {
      return new Date(Date.UTC(yy, mm, 0)).getUTCDate();
    }
    function _cutYmd(yy, mm, dRaw) {
      var lm = _lastDay(yy, mm);
      var dd = dRaw === 0 ? lm : Math.min(Math.max(dRaw, 1), lm);
      return yy + "-" + pad(mm) + "-" + pad(dd);
    }
    // Cortes do mês atual e vizinhos (ordenado)
    var cuts = [];
    function _pushMonthCuts(yy, mm) {
      cuts.push(_cutYmd(yy, mm, d1));
      cuts.push(_cutYmd(yy, mm, d2raw === 0 ? 0 : d2raw));
    }
    var pmQ = mQ === 1 ? 12 : mQ - 1;
    var pyQ = mQ === 1 ? yQ - 1 : yQ;
    var nmQ = mQ === 12 ? 1 : mQ + 1;
    var nyQ = mQ === 12 ? yQ + 1 : yQ;
    _pushMonthCuts(pyQ, pmQ);
    _pushMonthCuts(yQ, mQ);
    _pushMonthCuts(nyQ, nmQ);
    cuts.sort();
    // Dedup
    var uniq = [];
    for (var ci = 0; ci < cuts.length; ci++) {
      if (ci === 0 || cuts[ci] !== cuts[ci - 1]) uniq.push(cuts[ci]);
    }
    cuts = uniq;
    var fimQ = "";
    for (var fi = 0; fi < cuts.length; fi++) {
      if (cuts[fi] >= ref) {
        fimQ = cuts[fi];
        break;
      }
    }
    if (!fimQ) fimQ = cuts[cuts.length - 1];
    var iniQ = _addDaysYmd(fimQ, -14); // fallback
    for (var bi = cuts.length - 1; bi >= 0; bi--) {
      if (cuts[bi] < fimQ) {
        iniQ = _addDaysYmd(cuts[bi], 1);
        break;
      }
    }
    return { inicio: iniQ, fim: fimQ };
  }
  return null;
}

function cicloCorrenteDoProf(app, profId) {
  return cicloDoProfEm(app, profId, dataBrtHojeYmd());
}

/**
 * Sincroniza Movimentações do profissional.
 *
 * Pendente (ciclo):
 *   1 despesa agregada — data = fim do ciclo.
 *   obs: repasse_ciclo:ini:fim
 *   desc: "Comissão · {prof} · {período} (N OS)"
 *
 * Paga — dois caminhos:
 *   A) Individual (👍 numa OS): já existe 1:1 com comissao_id
 *      "Comissão - {prof} - OS - {cliente}" · data = pago_em
 *   B) Lote (Fechar ciclo / mão na linha da semana): sem 1:1
 *      1 despesa "Comissão - {prof} - N OS" · data = pago_em
 *      obs: repasse_ciclo_pago:ini:fim:pago_em
 */
function sincronizarCiclosDoProf(app, profId) {
  var p = String(profId || "").trim();
  if (!p) return null;

  var list = [];
  try {
    list = app.findRecordsByFilter(
      "prof_comissoes",
      "profissional = {:pid}",
      "",
      500,
      0,
      { pid: p },
    );
  } catch (_) {
    list = [];
  }

  var grupos = {}; // pendentes por ciclo
  var pagas = [];
  for (var i = 0; i < (list || []).length; i++) {
    var c = list[i];
    if (_isBonificacao(c)) {
      // Bonificação paga com lançamento 1:1 continua válida, mas nunca forma lote.
      if (String(c.get("status") || "") === "paga") {
        pagas.push({ c: c, win: cicloDoProfEm(app, p, String(c.get("data") || '').slice(0, 10)) });
      }
      continue;
    }
    var v = Number(c.get("valor_comissao") || 0);
    if (!(v > 0)) continue;
    var st = String(c.get("status") || "");
    var cd = String(c.get("data") || "")
      .trim()
      .slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(cd)) cd = dataBrtHojeYmd();
    var win = cicloDoProfEm(app, p, cd);
    if (!win || !win.inicio || !win.fim) continue;
    var gkey = win.inicio + "_" + win.fim;
    if (!grupos[gkey]) {
      grupos[gkey] = {
        win: win,
        pendCents: 0,
        pendN: 0,
        pendBonusN: 0,
        profNome: String(c.get("profissional_nome") || "").trim(),
      };
    }
    if (st === "paga") {
      pagas.push({ c: c, win: win });
    } else if (st === "pendente") {
      grupos[gkey].pendCents += Math.round(v * 100);
      grupos[gkey].pendN++;
      if (_isBonificacao(c)) grupos[gkey].pendBonusN++;
    }
    if (!grupos[gkey].profNome) {
      grupos[gkey].profNome = String(c.get("profissional_nome") || "").trim();
    }
  }

  var gKeys = Object.keys(grupos);
  var keysPendentes = {};
  for (var gi = 0; gi < gKeys.length; gi++) {
    var gg = grupos[gKeys[gi]];
    if (gg.pendN > 0) {
      keysPendentes[
        "repasse_ciclo:" + gg.win.inicio + ":" + gg.win.fim
      ] = true;
    }
  }

  // Classifica pagas: individual (tem 1:1) vs lote (sem 1:1)
  var idsIndividuais = {}; // comissao_id → true
  var loteGrupos = {}; // key ini_fim_pagoEm → { win, pe, cents, n, bonusN, nome, ids:[] }
  for (var pi = 0; pi < pagas.length; pi++) {
    var pc = pagas[pi].c;
    var pwin = pagas[pi].win;
    var pcid = String(pc.id || "");
    var tem1x1 = false;
    try {
      tem1x1 = !!acharLancamentoDaComissao(app, pcid);
    } catch (_) {
      tem1x1 = false;
    }
    if (tem1x1) {
      idsIndividuais[pcid] = true;
      continue;
    }
    if (_isBonificacao(pc)) continue;
    var pe =
      String(pc.get("pago_em") || "")
        .trim()
        .slice(0, 10) || dataBrtHojeYmd();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(pe)) pe = dataBrtHojeYmd();
    var lkey = pwin.inicio + "_" + pwin.fim + "_" + pe;
    if (!loteGrupos[lkey]) {
      loteGrupos[lkey] = {
        win: pwin,
        pe: pe,
        cents: 0,
        n: 0,
        bonusN: 0,
        nome: String(pc.get("profissional_nome") || "").trim(),
        ids: [],
      };
    }
    loteGrupos[lkey].cents += Math.round(
      Number(pc.get("valor_comissao") || 0) * 100,
    );
    loteGrupos[lkey].n++;
    if (_isBonificacao(pc)) loteGrupos[lkey].bonusN++;
    loteGrupos[lkey].ids.push(pcid);
    if (!loteGrupos[lkey].nome) {
      loteGrupos[lkey].nome = String(pc.get("profissional_nome") || "").trim();
    }
  }

  var keysLote = {};
  var lKeys = Object.keys(loteGrupos);
  for (var li = 0; li < lKeys.length; li++) {
    var lg = loteGrupos[lKeys[li]];
    // 1 OS em lote (edge) → ainda assim "1 OS" agregado se veio sem 1:1
    keysLote[
      "repasse_ciclo_pago:" + lg.win.inicio + ":" + lg.win.fim + ":" + lg.pe
    ] = true;
  }

  var cands = [];
  try {
    cands =
      app.findRecordsByFilter(
        "fin_lancamentos",
        'origem = "via_comissao" && profissional_id = "' +
          p.replace(/"/g, '\\"') +
          '" && observacao ~ "repasse_ciclo"',
        "-updated",
        200,
        0,
      ) || [];
  } catch (_) {
    cands = [];
  }

  // CUIDADO: apagar despesa PAGA credita o saldo (fin_saldo). Preferir
  // remapear obs / upsert em vez de delete+create em loop.
  var seenKey = {};
  var candsVivos = [];
  for (var k = 0; k < cands.length; k++) {
    var ok = String(cands[k].get("observacao") || "");
    var isPend = ok.indexOf("repasse_ciclo:") === 0;
    var isPagoAgg = ok.indexOf("repasse_ciclo_pago:") === 0;
    if (!isPend && !isPagoAgg) continue;

    var ativo = isPend ? !!keysPendentes[ok] : !!keysLote[ok];
    // Formato antigo pago sem :pago_em → remapeia p/ chave com data
    if (isPagoAgg && !ativo) {
      var mOld = ok.match(
        /^repasse_ciclo_pago:(\d{4}-\d{2}-\d{2}):(\d{4}-\d{2}-\d{2})$/,
      );
      if (mOld) {
        var dataLn = String(cands[k].get("data") || "")
          .trim()
          .slice(0, 10);
        var alt =
          "repasse_ciclo_pago:" + mOld[1] + ":" + mOld[2] + ":" + dataLn;
        if (keysLote[alt]) {
          try {
            cands[k].set("observacao", alt);
            app.save(cands[k]);
            ok = alt;
            ativo = true;
          } catch (_) {}
        }
      }
    }
    if (!ativo) {
      try {
        app.delete(cands[k]);
        console.log("[comissao-pago] ciclo órfão removido " + cands[k].id);
      } catch (_) {}
      continue;
    }
    if (seenKey[ok]) {
      try {
        app.delete(cands[k]);
        console.log(
          "[comissao-pago] ciclo duplicado removido " + cands[k].id,
        );
      } catch (_) {}
      continue;
    }
    seenKey[ok] = true;
    candsVivos.push(cands[k]);
  }
  cands = candsVivos;

  // Legados sem chave de ciclo e sem comissao_id
  try {
    var legados =
      app.findRecordsByFilter(
        "fin_lancamentos",
        'origem = "via_comissao" && profissional_id = "' +
          p.replace(/"/g, '\\"') +
          '" && (comissao_id = "" || comissao_id = null)',
        "",
        100,
        0,
      ) || [];
    for (var lj = 0; lj < legados.length; lj++) {
      var lo = String(legados[lj].get("observacao") || "");
      if (lo.indexOf("repasse_ciclo:") === 0) continue;
      if (lo.indexOf("repasse_ciclo_pago:") === 0) continue;
      try {
        app.delete(legados[lj]);
        console.log(
          "[comissao-pago] repasse legado removido " + legados[lj].id,
        );
      } catch (_) {}
    }
  } catch (_) {}

  var profNome = "";
  try {
    var u = app.findRecordById("users", p);
    profNome = String(u.get("name") || u.get("nome") || "");
  } catch (_) {}

  var cats = acharCategoriaComissao(app, profNome, p);
  if (!cats || !cats.categoriaId) return null;
  var contaId = acharConta(app);
  if (!contaId) return null;

  function _resumoItens(n, bonusN) {
    var totalN = Number(n || 0);
    var bonus = Number(bonusN || 0);
    if (bonus < 0) bonus = 0;
    if (bonus > totalN) bonus = totalN;
    var osN = totalN - bonus;
    if (bonus === 0) return totalN + " OS";
    if (osN === 0) return bonus + (bonus === 1 ? " bonificação" : " bonificações");
    return (
      osN +
      " OS + " +
      bonus +
      (bonus === 1 ? " bonificação" : " bonificações")
    );
  }

  function _upsertAgg(
    obsKey,
    status,
    total,
    n,
    bonusN,
    dataYmd,
    nome,
    isPendente,
  ) {
    if (!(total > 0) || n === 0) return null;
    var descricao;
    if (isPendente) {
      // pendente mantém período na descrição
      var parts = obsKey.split(":");
      var periodo =
        parts.length >= 3 ? _labelPeriodoBr(parts[1], parts[2]) : dataYmd;
      descricao =
        (bonusN > 0 ? "Repasse" : "Comissão") +
        " · " +
        nome +
        " · " +
        periodo +
        " (" +
        _resumoItens(n, bonusN) +
        ")";
    } else {
      // lote pago: "Comissão - Prof - N OS" ou repasse misto com bonificação.
      descricao =
        (bonusN > 0 ? "Repasse" : "Comissão") +
        " - " +
        nome +
        " - " +
        _resumoItens(n, bonusN);
    }
    var existente = null;
    for (var j = 0; j < cands.length; j++) {
      if (String(cands[j].get("observacao") || "") === obsKey) {
        existente = cands[j];
        break;
      }
    }
    if (existente) {
      var mudou = false;
      if (Number(existente.get("valor") || 0) !== total) {
        existente.set("valor", total);
        mudou = true;
      }
      if (String(existente.get("status") || "") !== status) {
        existente.set("status", status);
        mudou = true;
      }
      if (String(existente.get("descricao") || "") !== descricao) {
        existente.set("descricao", descricao);
        mudou = true;
      }
      if (String(existente.get("data") || "").slice(0, 10) !== dataYmd) {
        existente.set("data", dataYmd);
        mudou = true;
      }
      if (mudou) app.save(existente);
      return existente;
    }
    var col = app.findCollectionByNameOrId("fin_lancamentos");
    var lanc = new Record(col);
    lanc.set("tipo", "despesa");
    lanc.set("descricao", descricao);
    lanc.set("categoria_id", cats.categoriaId);
    lanc.set("subcategoria_id", cats.subcategoriaId || "");
    lanc.set("valor", total);
    lanc.set("conta_id", contaId);
    lanc.set("data", dataYmd);
    lanc.set("status", status);
    lanc.set("recorrencia", "unica");
    lanc.set("origem", "via_comissao");
    lanc.set("comissao_id", "");
    lanc.set("os_id", "");
    lanc.set("observacao", obsKey);
    try {
      lanc.set("profissional_id", p);
    } catch (_) {}
    app.save(lanc);
    cands.push(lanc);
    console.log(
      "[comissao-pago] " +
        (isPendente ? "ciclo pendente" : "lote pago") +
        " " +
        lanc.id +
        " · " +
        descricao +
        " · R$ " +
        total +
        " · " +
        dataYmd,
    );
    return lanc;
  }

  var lastSaved = null;
  var nomeBase = profNome || p.slice(0, 8);

  // Pendentes por ciclo
  for (var gii = 0; gii < gKeys.length; gii++) {
    var g = grupos[gKeys[gii]];
    var nome = g.profNome || nomeBase;
    var r1 = _upsertAgg(
      "repasse_ciclo:" + g.win.inicio + ":" + g.win.fim,
      "pendente",
      g.pendCents / 100.0,
      g.pendN,
      g.pendBonusN,
      g.win.fim,
      nome,
      true,
    );
    if (r1) lastSaved = r1;
  }

  // Individuais: re-upsert 1:1 (já existem; garante alinhamento)
  var idsPagasKeep = {};
  for (var pii = 0; pii < pagas.length; pii++) {
    var pci = String(pagas[pii].c.id || "");
    if (!idsIndividuais[pci]) continue;
    idsPagasKeep[pci] = true;
    try {
      var rI = _upsertDespesaOsPaga(app, pagas[pii].c, p);
      if (rI) lastSaved = rI;
    } catch (_) {}
  }

  // Lotes agregados
  for (var lii = 0; lii < lKeys.length; lii++) {
    var L = loteGrupos[lKeys[lii]];
    var nomeL = L.nome || nomeBase;
    var obsL =
      "repasse_ciclo_pago:" + L.win.inicio + ":" + L.win.fim + ":" + L.pe;
    var rL = _upsertAgg(
      obsL,
      "pago",
      L.cents / 100.0,
      L.n,
      L.bonusN,
      L.pe,
      nomeL,
      false,
    );
    if (rL) lastSaved = rL;
  }

  // Remove 1:1 de comissões que não estão mais pagas OU que migraram para lote
  // (só mantém idsIndividuais / idsPagasKeep)
  try {
    var ones =
      app.findRecordsByFilter(
        "fin_lancamentos",
        'origem = "via_comissao" && profissional_id = "' +
          p.replace(/"/g, '\\"') +
          '" && comissao_id != "" && comissao_id != null',
        "",
        200,
        0,
      ) || [];
    for (var oi = 0; oi < ones.length; oi++) {
      var ocid = String(ones[oi].get("comissao_id") || "").trim();
      if (ocid && idsPagasKeep[ocid]) continue;
      try {
        app.delete(ones[oi]);
        console.log(
          "[comissao-pago] 1:1 removida " + ones[oi].id + " (cid=" + ocid + ")",
        );
      } catch (_) {}
    }
  } catch (_) {}

  return lastSaved;
}

/** Alias: mantém callers antigos. */
function sincronizarRepasseCicloPendente(app, profId) {
  return sincronizarCiclosDoProf(app, profId);
}

/**
 * Ao criar comissão (OS concluída): atualiza acumulado pendente do ciclo
 * em Movimentações (status pendente — sem debitar saldo).
 * Se já nascer "paga", gera repasse pago do dia.
 */
function onComissaoCriada(app, comissao) {
  const st = String(comissao.get("status") || "");
  const profId = String(comissao.get("profissional") || "").trim();
  if (!profId) return;
  if (st === "paga") {
    var pe = String(comissao.get("pago_em") || "")
      .trim()
      .slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(pe)) pe = dataBrtHojeYmd();
    try {
      comissao.set("pago_em", pe);
      // save reentrante com guard
      if (!_inSync()) {
        _beginSync();
        try {
          app.save(comissao);
        } finally {
          _endSync();
        }
      }
    } catch (_) {}
  }
  try {
    if (!_inSync()) {
      _beginSync();
      try {
        sincronizarCiclosDoProf(app, profId);
      } finally {
        _endSync();
      }
    } else {
      sincronizarCiclosDoProf(app, profId);
    }
  } catch (err) {
    console.error("[comissao-pago] ciclo (create): " + err);
  }
}

/**
 * Bidirecional: status da despesa via_comissao → status da(s) comissão(ões).
 * pago → paga; qualquer outro → pendente.
 * Idempotente (só grava se diferir) para não loopar com sincronizarLancamento.
 *
 * - 1:1 (comissao_id preenchido): espelha aquela OS.
 * - Ciclo (repasse_ciclo:inicio:fim + profissional_id): espelha TODAS as OS
 *   daquela janela do profissional (mão na Movimentação ↔ Equipe).
 */
function sincronizarComissaoDoLancamento(app, lancamento, origStatusLanc) {
  // Evita loop fin_lancamentos → comissão → fin_lancamentos.
  if (_inSync()) return;

  const origem = String(lancamento.get("origem") || "");
  if (origem !== "via_comissao") return;

  const novoLanc = String(lancamento.get("status") || "");
  const velhoLanc = String(origStatusLanc || "");
  if (novoLanc === velhoLanc) return;

  const want = novoLanc === "pago" ? "paga" : "pendente";
  const comissaoId = String(lancamento.get("comissao_id") || "").trim();

  _beginSync();
  try {
    // ── 1:1 por OS ────────────────────────────────────────────────────────
    if (comissaoId) {
      let comissao;
      try {
        comissao = app.findRecordById("prof_comissoes", comissaoId);
      } catch (_) {
        console.log(
          "[comissao-pago] comissão " +
            comissaoId +
            " não encontrada; skip sync.",
        );
        return;
      }
      const atual = String(comissao.get("status") || "");
      if (atual === want) return;
      comissao.set("status", want);
      if (want === "paga") {
        var pe1 = String(lancamento.get("data") || "")
          .trim()
          .slice(0, 10);
        if (!/^\d{4}-\d{2}-\d{2}$/.test(pe1)) pe1 = dataBrtHojeYmd();
        comissao.set("pago_em", pe1);
      } else {
        try {
          comissao.set("pago_em", "");
        } catch (_) {}
      }
      app.save(comissao);
      console.log(
        "[comissao-pago] comissão " +
          comissaoId +
          " " +
          atual +
          " → " +
          want +
          " (via lançamento " +
          lancamento.id +
          ")",
      );
      return;
    }

    // ── Ciclo/semana (pendente ou lote pago) ────────────────────────────
    // Mão na linha em Transações OU Fechar ciclo → SEMPRE agregado.
    // Nunca gera 1:1 por cliente.
    const obs = String(lancamento.get("observacao") || "").trim();
    // repasse_ciclo:ini:fim  OU  repasse_ciclo_pago:ini:fim[:pago_em]
    var m = obs.match(
      /^repasse_ciclo(?:_pago)?:(\d{4}-\d{2}-\d{2}):(\d{4}-\d{2}-\d{2})/,
    );
    const profId = String(lancamento.get("profissional_id") || "").trim();
    if (!m || !profId) {
      return;
    }
    const ini = m[1];
    const fim = m[2];
    const isPagoSlice = obs.indexOf("repasse_ciclo_pago:") === 0;

    let list = [];
    try {
      list = app.findRecordsByFilter(
        "prof_comissoes",
        "profissional = {:pid}",
        "",
        500,
        0,
        { pid: profId },
      );
    } catch (_) {
      list = [];
    }

    // Lote: e.next() JÁ aplicou o efeito no saldo (pendente↔pago).
    // Aqui: SQL nas comissões + SQL nos metadados da MESMA linha.
    // NUNCA app.save(lancamento/comissao) — 2º save debitava de novo (200→400).
    // NUNCA criar outra despesa paga no sync.
    _setSkip1x1(true);
    try {
      var n = 0;
      var cents = 0;
      var profNome = "";
      var hoje = dataBrtHojeYmd();
      // Data do lançamento: preferir a já gravada (fim do ciclo); fallback hoje.
      var dataLanc = String(lancamento.get("data") || "")
        .trim()
        .slice(0, 10);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(dataLanc)) dataLanc = hoje;

      for (var i = 0; i < (list || []).length; i++) {
        var c = list[i];
        // Bonificação não pode ser paga/reaberta pelo ciclo de OS.
        if (_isBonificacao(c)) continue;
        var cd = String(c.get("data") || "")
          .trim()
          .slice(0, 10);
        if (!/^\d{4}-\d{2}-\d{2}$/.test(cd)) continue;
        if (cd < ini || cd > fim) continue;
        var atualC = String(c.get("status") || "");
        var cid = String(c.id || "");

        if (isPagoSlice) {
          // 👎 na linha de LOTE: reabre só as que NÃO têm 1:1 individual.
          if (want === "pendente" && atualC === "paga") {
            var tem1x1 = false;
            try {
              tem1x1 = !!acharLancamentoDaComissao(app, cid);
            } catch (_) {
              tem1x1 = false;
            }
            if (tem1x1) continue;
            if (_sqlSetComissaoStatus(app, cid, "pendente", "")) {
              n++;
              var vvR = Number(c.get("valor_comissao") || 0);
              if (vvR > 0) cents += Math.round(vvR * 100);
              if (!profNome) {
                profNome = String(c.get("profissional_nome") || "").trim();
              }
            }
          }
        } else if (want === "paga" && atualC === "pendente") {
          // 👍 linha do ciclo / Fechar ciclo
          var vv = Number(c.get("valor_comissao") || 0);
          if (_sqlSetComissaoStatus(app, cid, "paga", dataLanc)) {
            n++;
            if (vv > 0) cents += Math.round(vv * 100);
            if (!profNome) {
              profNome = String(c.get("profissional_nome") || "").trim();
            }
          }
        }
      }

      if (!profNome) {
        try {
          var u = app.findRecordById("users", profId);
          profNome = String(u.get("name") || u.get("nome") || "");
        } catch (_) {}
      }
      if (!profNome) profNome = profId.slice(0, 8);

      // Metadados da MESMA linha via SQL (sem fin_saldo).
      // e.next() já deixou status pago/pendente e valor; só texto/obs/data.
      if (!isPagoSlice && want === "paga" && n > 0) {
        var descLote = "Comissão - " + profNome + " - " + n + " OS";
        var obsLote =
          "repasse_ciclo_pago:" + ini + ":" + fim + ":" + dataLanc;
        // NÃO alterar valor aqui se já está correto no e.next() — evita
        // divergência; se precisar alinhar, o total deve == valor já debitado.
        var valorAtual = Number(lancamento.get("valor") || 0);
        var total = cents / 100.0;
        var meta = {
          descricao: descLote,
          observacao: obsLote,
          data: dataLanc,
        };
        // Só mexe em valor via SQL se divergir E ajustamos saldo à mão.
        if (Math.round(valorAtual * 100) !== Math.round(total * 100) && total > 0) {
          meta.valor = total;
          var delta = total - valorAtual; // despesa: efeito = -valor
          // e.next debitou -valorAtual; queremos -total ⇒ delta_saldo = -(total-valorAtual)
          try {
            var contaId = String(lancamento.get("conta_id") || "");
            if (contaId && Math.round(delta * 100) !== 0) {
              app
                .db()
                .newQuery(
                  "UPDATE fin_contas SET saldo_atual = saldo_atual - {:d} WHERE id = {:id}",
                )
                .bind({ d: delta, id: contaId })
                .execute();
            }
          } catch (eSaldo) {
            console.error("[comissao-pago] ajuste saldo lote: " + eSaldo);
          }
        }
        _sqlUpdateLancMeta(app, lancamento.id, meta);
        console.log(
          "[comissao-pago] lote meta " +
            lancamento.id +
            " · " +
            descLote +
            " · R$ " +
            (meta.valor != null ? meta.valor : valorAtual) +
            " · " +
            dataLanc +
            " (sem 2º app.save)",
        );
      }

      if (isPagoSlice && want === "pendente") {
        // e.next() já creditou o valor (pago→pendente). Só obs/desc.
        var nPend = 0;
        var centsPend = 0;
        // recalcula pendentes do ciclo (inclui as que reabrimos)
        try {
          var list2 =
            app.findRecordsByFilter(
              "prof_comissoes",
              "profissional = {:pid}",
              "",
              500,
              0,
              { pid: profId },
            ) || [];
          for (var j = 0; j < list2.length; j++) {
            var c2 = list2[j];
            if (String(c2.get("status") || "") !== "pendente") continue;
            var cd2 = String(c2.get("data") || "")
              .trim()
              .slice(0, 10);
            if (cd2 < ini || cd2 > fim) continue;
            var v2 = Number(c2.get("valor_comissao") || 0);
            if (!(v2 > 0)) continue;
            nPend++;
            centsPend += Math.round(v2 * 100);
          }
        } catch (_) {}
        var periodoBr = _labelPeriodoBr(ini, fim);
        var descPend =
          "Comissão · " +
          profNome +
          " · " +
          periodoBr +
          " (" +
          nPend +
          " OS)";
        var metaR = {
          descricao: descPend,
          observacao: "repasse_ciclo:" + ini + ":" + fim,
          data: fim,
        };
        if (nPend > 0) metaR.valor = centsPend / 100.0;
        // valor: e.next já zerou efeito (pendente); se mudarmos valor via SQL
        // sem status pago, saldo não mexe. OK.
        _sqlUpdateLancMeta(app, lancamento.id, metaR);
        console.log(
          "[comissao-pago] lote reopen meta " +
            lancamento.id +
            " · " +
            descPend,
        );
      }

      // NÃO chamar sincronizarCiclosDoProf aqui no pay/reopen da linha de ciclo:
      // ele recriava/apagava lançamentos e dobrava o efeito no saldo.
      // Individuais e novos ciclos continuam pelo onComissaoCriada / setStatus.

      console.log(
        "[comissao-pago] ciclo " +
          ini +
          "…" +
          fim +
          " prof " +
          profId +
          " → " +
          want +
          " (" +
          n +
          " OS) via lanç. " +
          lancamento.id +
          (isPagoSlice ? " [lote-reopen]" : " [lote-pay]"),
      );
    } finally {
      _setSkip1x1(false);
    }
  } finally {
    _endSync();
  }
}

/**
 * Backfill: **não** cria despesa por OS pendente.
 * Só recalcula repasses de comissões já **pagas** (agrupado por prof + pago_em).
 */
function backfillDespesasComissao(app) {
  let list = [];
  try {
    list = app.findRecordsByFilter(
      "prof_comissoes",
      "status = 'paga'",
      "-created",
      500,
      0,
      {},
    );
  } catch (_) {
    list = [];
  }
  var pairs = {};
  for (var i = 0; i < (list || []).length; i++) {
    var c = list[i];
    var pid = String(c.get("profissional") || "").trim();
    var pe = String(c.get("pago_em") || c.get("data") || "")
      .trim()
      .slice(0, 10);
    if (!pid || !/^\d{4}-\d{2}-\d{2}$/.test(pe)) continue;
    pairs[pid + "|" + pe] = { pid: pid, pe: pe };
  }
  var n = 0;
  var keys = Object.keys(pairs);
  for (var k = 0; k < keys.length; k++) {
    try {
      recalcularDespesaRepasse(app, pairs[keys[k]].pid, pairs[keys[k]].pe);
      n++;
    } catch (err) {
      console.error("[comissao-pago] backfill repasse falhou: " + err);
    }
  }
  console.log("[comissao-pago] backfill recalculou " + n + " repasse(s).");
  return n;
}

/**
 * Realinha data de prof_comissoes + despesa via_comissao para a data da OS
 * (mesma da receita via_os). Corrige backfill que gravou tudo em "hoje".
 * Só altera o campo `data` — não mexe em status/valor/saldo (R1).
 */
function realinharDatasComissaoComOs(app) {
  let list = [];
  try {
    list = app.findRecordsByFilter(
      "prof_comissoes",
      "id != ''",
      "-created",
      500,
      0,
      {},
    );
  } catch (_) {
    list = [];
  }
  var nCom = 0;
  var nLanc = 0;
  for (var i = 0; i < list.length; i++) {
    var c = list[i];
    var want = dataLancamentoComissao(app, c);
    if (!want) continue;

    var curCom = String(c.get("data") || "").trim().slice(0, 10);
    if (curCom !== want) {
      c.set("data", want);
      try {
        app.save(c);
        nCom++;
      } catch (err) {
        console.error(
          "[comissao-pago] realinhar comissão " + c.id + ": " + err,
        );
      }
    }

    var lanc = acharLancamentoDaComissao(app, c.id);
    if (!lanc) continue;
    var curLanc = String(lanc.get("data") || "").trim().slice(0, 10);
    if (curLanc !== want) {
      lanc.set("data", want);
      try {
        app.save(lanc);
        nLanc++;
      } catch (err) {
        console.error(
          "[comissao-pago] realinhar lançamento " + lanc.id + ": " + err,
        );
      }
    }
  }
  console.log(
    "[comissao-pago] realinhar datas: " +
      nCom +
      " comissão(ões), " +
      nLanc +
      " despesa(s).",
  );
  return { comissoes: nCom, lancamentos: nLanc };
}

/**
 * Realinha categoria/sub de todas as despesas via_comissao para
 * **Equipe → profissional**. Não mexe em status/valor/saldo (R1).
 */
function realinharCategoriasComissao(app) {
  const equipe = acharCategoriaComissao(app);
  if (!equipe || !equipe.categoriaId) {
    console.log("[comissao-pago] realinhar categorias: sem Equipe.");
    return 0;
  }

  let list = [];
  try {
    list = app.findRecordsByFilter(
      "fin_lancamentos",
      "origem = 'via_comissao'",
      "-created",
      500,
      0,
      {},
    );
  } catch (_) {
    list = [];
  }
  var n = 0;
  for (var i = 0; i < list.length; i++) {
    var lanc = list[i];
    var profNome = "";
    var profId = "";
    try {
      var comissaoId = String(lanc.get("comissao_id") || "");
      if (comissaoId) {
        var comissao = app.findRecordById("prof_comissoes", comissaoId);
        profId = String(comissao.get("profissional") || "");
        profNome = String(comissao.get("profissional_nome") || "").trim();
        if (!profNome && profId) {
          var user = app.findRecordById("users", profId);
          profNome = String(user.get("name") || user.get("nome") || "");
        }
      }
    } catch (_) {}
    var cats = acharCategoriaComissao(app, profNome, profId);
    if (!cats || !cats.categoriaId) continue;
    var wantSub = cats.subcategoriaId || "";
    var mudou = false;
    if (String(lanc.get("categoria_id") || "") !== cats.categoriaId) {
      lanc.set("categoria_id", cats.categoriaId);
      mudou = true;
    }
    if (String(lanc.get("subcategoria_id") || "") !== wantSub) {
      lanc.set("subcategoria_id", wantSub);
      mudou = true;
    }
    if (!mudou) continue;
    try {
      app.save(lanc);
      n++;
    } catch (err) {
      console.error(
        "[comissao-pago] realinhar categoria " + lanc.id + ": " + err,
      );
    }
  }
  console.log(
    "[comissao-pago] realinhar categorias: " +
      n +
      " despesa(s) → categoria configurada/profissional.",
  );
  return n;
}

module.exports = {
  sincronizarLancamento,
  apagarLancamentoDaComissao,
  acharLancamentoDaComissao,
  acharLancamentoRepasse,
  listarLancamentosRepasse,
  recalcularDespesaRepasse,
  criarLancamentoDaComissao,
  garantirLancamentoStatus,
  onComissaoCriada,
  sincronizarComissaoDoLancamento,
  backfillDespesasComissao,
  dataLancamentoComissao,
  dataBrtHojeYmd,
  realinharDatasComissaoComOs,
  realinharCategoriasComissao,
  acharCategoriaComissao,
  sincronizarRepasseCicloPendente,
  sincronizarCiclosDoProf,
  cicloCorrenteDoProf,
  cicloDoProfEm,
};
