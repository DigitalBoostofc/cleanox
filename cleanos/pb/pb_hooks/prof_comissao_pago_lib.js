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
 * Resolve categoria de despesa da comissão/repasse.
 * Retorna { categoriaId, subcategoriaId } — sub sempre vazia ("").
 *
 * Canônico (dono 2026-07-24): só a raiz **"Equipe"** (sem subcategorias
 * Comissões/Profissionais). Subs legadas, se ainda existirem, são ignoradas
 * (migração 1700000047 remove e re-aponta lançamentos).
 */
function acharCategoriaComissao(app) {
  // 1) Raiz Equipe
  try {
    const equipe = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && nome = 'Equipe' && (parent_id = '' || parent_id = null)",
    );
    if (equipe) {
      return { categoriaId: equipe.id, subcategoriaId: null };
    }
  } catch (_) {}

  // 2) Fallback: id canônico do seed
  try {
    const e = app.findRecordById("fin_categorias", "catdequipe00001");
    if (e) return { categoriaId: e.id, subcategoriaId: null };
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
      return { categoriaId: list[0].id, subcategoriaId: null };
    }
  } catch (_) {}
  return null;
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
 * Lista despesas de **repasse** do prof no dia (via_comissao, sem comissao_id).
 *
 * IMPORTANTE: `data` no PB grava como `YYYY-MM-DD 00:00:00.000Z`. Filtro
 * `data = 'YYYY-MM-DD'` **não casa** e fazia o upsert sempre CRIAR de novo
 * (explosão de despesas ao marcar lote paga — bug 2026-07-21).
 * Usar janela half-open [dia, dia+1).
 */
function listarLancamentosRepasse(app, profId, ymd) {
  const p = String(profId || "").replace(/"/g, '\\"');
  const d = String(ymd || "").slice(0, 10);
  if (!p || !/^\d{4}-\d{2}-\d{2}$/.test(d)) return [];
  const next = _nextDayYmd(d);
  if (!next) return [];

  // Preferência: profissional_id + janela de data
  try {
    const list = app.findRecordsByFilter(
      "fin_lancamentos",
      'origem = "via_comissao" && profissional_id = "' +
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
    if (list && list.length) return list;
  } catch (_) {}

  // Fallback: data literal YYYY-MM-DD (mocks / legado)
  try {
    const list = app.findRecordsByFilter(
      "fin_lancamentos",
      'origem = "via_comissao" && profissional_id = "' +
        p +
        '" && data = "' +
        d +
        '" && (comissao_id = "" || comissao_id = null)',
      "created",
      50,
      0,
    );
    if (list && list.length) return list;
  } catch (_) {}

  // Fallback sem profissional_id: descrição de repasse
  try {
    const list = app.findRecordsByFilter(
      "fin_lancamentos",
      'origem = "via_comissao" && data >= "' +
        d +
        ' 00:00:00.000Z" && data < "' +
        next +
        ' 00:00:00.000Z" && descricao ~ "Repasse" && (comissao_id = "" || comissao_id = null)',
      "created",
      50,
      0,
    );
    return list || [];
  } catch (_) {
    return [];
  }
}

/**
 * Uma despesa de repasse (a mais antiga). Consolida/apaga duplicatas se houver.
 */
function acharLancamentoRepasse(app, profId, ymd) {
  const list = listarLancamentosRepasse(app, profId, ymd);
  if (!list || list.length === 0) return null;
  // Mantém o primeiro (created asc se o sort funcionou); apaga o resto.
  const keep = list[0];
  for (var i = 1; i < list.length; i++) {
    try {
      app.delete(list[i]);
      console.log(
        "[comissao-pago] repasse duplicado " +
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

  var cats = acharCategoriaComissao(app);
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

  const cats = acharCategoriaComissao(app);
  if (!cats || !cats.categoriaId) {
    console.log("[comissao-pago] nenhuma categoria de despesa; skip.");
    return null;
  }
  const contaId = acharConta(app);
  if (!contaId) {
    console.log("[comissao-pago] nenhuma conta ativa; skip.");
    return null;
  }

  let profNome = String(comissao.get("profissional_nome") || "").trim();
  if (!profNome) {
    try {
      const profId = String(comissao.get("profissional") || "");
      if (profId) {
        const p = app.findRecordById("users", profId);
        profNome = String(p.get("name") || "");
      }
    } catch (_) {}
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
  const cats = acharCategoriaComissao(app);
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
 * Sincroniza despesa de **repasse** com o status da comissão (DEPOIS do e.next()).
 *   paga     → grava pago_em (dia do pagamento) e recalcula 1 despesa total do dia
 *   pendente → limpa pago_em, remove despesa 1:1 legada e recalcula repasse
 *
 * NÃO cria despesa por OS.
 */
function sincronizarLancamento(app, comissao, origStatus) {
  const novo = String(comissao.get("status") || "");
  const velho = String(origStatus || "");
  const profId = String(comissao.get("profissional") || "").trim();

  // Remove despesa legada 1:1 (uma por OS), se ainda existir.
  try {
    apagarLancamentoDaComissao(app, comissao.id);
  } catch (_) {}

  if (!profId) {
    // Sem profissional: se paga, cria despesa 1:1 só como fallback de histórico.
    if (novo === "paga" && velho !== "paga") {
      garantirLancamentoStatus(app, comissao, "pago");
    }
    return;
  }

  if (novo === "paga") {
    var pe = String(comissao.get("pago_em") || "")
      .trim()
      .slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(pe)) {
      pe = dataBrtHojeYmd();
      // NÃO app.save aqui: reentrada no onRecordUpdate duplicava o repasse.
      // pago_em deve vir no body do update (Flutter) ou no handler pré-e.next().
      try {
        comissao.set("pago_em", pe);
      } catch (_) {}
    }
    // Só recalcula na transição pendente→paga OU se o valor mudou em paga.
    // Reentrada só por pago_em (velho já paga) ainda precisa upsert 1× (ok).
    recalcularDespesaRepasse(app, profId, pe);
    try {
      sincronizarRepasseCicloPendente(app, profId);
    } catch (_) {}
    return;
  }

  // → pendente (ou outro)
  var peOld = String(comissao.get("pago_em") || "")
    .trim()
    .slice(0, 10);
  if (peOld) {
    try {
      comissao.set("pago_em", "");
      app.save(comissao);
    } catch (_) {}
    recalcularDespesaRepasse(app, profId, peOld);
  } else if (velho === "paga") {
    // Sem pago_em (legado): recalcula o dia de hoje e a data da comissão
    recalcularDespesaRepasse(app, profId, dataBrtHojeYmd());
    var dCom = String(comissao.get("data") || "")
      .trim()
      .slice(0, 10);
    if (dCom && dCom !== dataBrtHojeYmd()) {
      recalcularDespesaRepasse(app, profId, dCom);
    }
  }
  try {
    sincronizarRepasseCicloPendente(app, profId);
  } catch (_) {}
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
 * Janela do ciclo corrente do profissional (espelha Flutter cicloCorrente).
 * Semanal sáb: domingo→sábado. Retorna {inicio, fim} YYYY-MM-DD ou null.
 */
function cicloCorrenteDoProf(app, profId) {
  var u;
  try {
    u = app.findRecordById("users", profId);
  } catch (_) {
    return null;
  }
  var freq = String(u.get("pagamento_frequencia") || "").toLowerCase();
  if (!freq) return null;
  var hoje = dataBrtHojeYmd();
  var dia = Number(u.get("pagamento_dia") || 0);

  if (freq === "diario") {
    return { inicio: hoje, fim: hoje };
  }
  if (freq === "semanal") {
    var target = dia >= 1 && dia <= 7 ? dia : 5;
    var w = _ourWeekdayYmd(hoje);
    var delta = (target - w + 7) % 7;
    var fim = _addDaysYmd(hoje, delta);
    var inicio = _addDaysYmd(fim, -6);
    return { inicio: inicio, fim: fim };
  }
  // quinzenal/mensal: fallback 7 dias até o dia de pagamento no mês (simplificado)
  if (freq === "mensal" || freq === "quinzenal") {
    var t = dia >= 1 && dia <= 31 ? dia : 15;
    var parts = hoje.split("-");
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
      // início = dia após corte do mês anterior
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
  return null;
}

/**
 * Upsert despesa PENDENTE do ciclo (não mexe no saldo até ficar paga).
 * Observação chave: repasse_ciclo:YYYY-MM-DD:YYYY-MM-DD
 * Descrição: "Comissão · Nome · 20/07 a 26/07/2026 (N OS) · em aberto"
 */
function sincronizarRepasseCicloPendente(app, profId) {
  var p = String(profId || "").trim();
  if (!p) return null;
  var win = cicloCorrenteDoProf(app, p);
  if (!win || !win.inicio || !win.fim) return null;

  var list = [];
  try {
    list = app.findRecordsByFilter(
      "prof_comissoes",
      "profissional = {:pid} && status = 'pendente'",
      "",
      500,
      0,
      { pid: p },
    );
  } catch (_) {
    list = [];
  }

  var cents = 0;
  var n = 0;
  var profNome = "";
  for (var i = 0; i < (list || []).length; i++) {
    var c = list[i];
    var cd = String(c.get("data") || "")
      .trim()
      .slice(0, 10);
    if (cd < win.inicio || cd > win.fim) continue;
    var v = Number(c.get("valor_comissao") || 0);
    if (!(v > 0)) continue;
    cents += Math.round(v * 100);
    n++;
    if (!profNome) {
      profNome = String(c.get("profissional_nome") || "").trim();
    }
  }
  var total = cents / 100.0;
  var obsKey = "repasse_ciclo:" + win.inicio + ":" + win.fim;

  // Localiza lançamento pendente do ciclo
  var existente = null;
  try {
    var cands = app.findRecordsByFilter(
      "fin_lancamentos",
      'origem = "via_comissao" && status = "pendente" && profissional_id = "' +
        p.replace(/"/g, '\\"') +
        '" && observacao ~ "repasse_ciclo:"',
      "-updated",
      20,
      0,
    );
    for (var j = 0; j < (cands || []).length; j++) {
      var o = String(cands[j].get("observacao") || "");
      if (o.indexOf(obsKey) === 0 || o === obsKey) {
        existente = cands[j];
        break;
      }
    }
    // Ciclo antigo pendente (outro período): apaga se total zero no novo
    if (!existente) {
      for (var k = 0; k < (cands || []).length; k++) {
        // limpa órfãos de ciclos passados sem comissão pendente
        var ok = String(cands[k].get("observacao") || "");
        if (ok.indexOf("repasse_ciclo:") === 0 && ok !== obsKey) {
          try {
            app.delete(cands[k]);
          } catch (_) {}
        }
      }
    }
  } catch (_) {}

  if (!(total > 0) || n === 0) {
    if (existente) {
      try {
        app.delete(existente);
      } catch (_) {}
    }
    return null;
  }

  if (!profNome) {
    try {
      var u = app.findRecordById("users", p);
      profNome = String(u.get("name") || u.get("nome") || "");
    } catch (_) {}
  }

  var cats = acharCategoriaComissao(app);
  if (!cats || !cats.categoriaId) return null;
  var contaId = acharConta(app);
  if (!contaId) return null;

  var periodo = _labelPeriodoBr(win.inicio, win.fim);
  var descricao =
    "Comissão · " +
    (profNome || p.slice(0, 8)) +
    " · " +
    periodo +
    " (" +
    n +
    " OS) · em aberto";

  if (existente) {
    var mudou = false;
    if (Number(existente.get("valor") || 0) !== total) {
      existente.set("valor", total);
      mudou = true;
    }
    if (String(existente.get("descricao") || "") !== descricao) {
      existente.set("descricao", descricao);
      mudou = true;
    }
    if (String(existente.get("data") || "").slice(0, 10) !== win.fim) {
      existente.set("data", win.fim);
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
  lanc.set("data", win.fim); // data do pagamento previsto (fim do ciclo)
  lanc.set("status", "pendente");
  lanc.set("recorrencia", "unica");
  lanc.set("origem", "via_comissao");
  lanc.set("comissao_id", "");
  lanc.set("os_id", "");
  lanc.set("observacao", obsKey);
  try {
    lanc.set("profissional_id", p);
  } catch (_) {}
  app.save(lanc);
  console.log(
    "[comissao-pago] ciclo pendente " +
      lanc.id +
      " · " +
      (profNome || p) +
      " · R$ " +
      total +
      " · " +
      periodo,
  );
  return lanc;
}

/**
 * Ao criar comissão (OS concluída): atualiza acumulado pendente do ciclo
 * em Movimentações (status pendente — sem debitar saldo).
 * Se já nascer "paga", gera repasse pago do dia.
 */
function onComissaoCriada(app, comissao) {
  const st = String(comissao.get("status") || "");
  const profId = String(comissao.get("profissional") || "").trim();
  // Só se já nascer "paga" (raro): gera/atualiza repasse do dia.
  if (st === "paga") {
    var pe = String(comissao.get("pago_em") || "")
      .trim()
      .slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(pe)) {
      pe = dataBrtHojeYmd();
      try {
        comissao.set("pago_em", pe);
        app.save(comissao);
      } catch (_) {}
    }
    if (profId) recalcularDespesaRepasse(app, profId, pe);
  } else if (profId) {
    try {
      sincronizarRepasseCicloPendente(app, profId);
    } catch (err) {
      console.error("[comissao-pago] ciclo pendente (create): " + err);
    }
  }
}

/**
 * Bidirecional: status da despesa via_comissao → status da comissão.
 * pago → paga; qualquer outro → pendente.
 * Idempotente (só grava se diferir) para não loopar com sincronizarLancamento.
 */
function sincronizarComissaoDoLancamento(app, lancamento, origStatusLanc) {
  const origem = String(lancamento.get("origem") || "");
  if (origem !== "via_comissao") return;

  const comissaoId = String(lancamento.get("comissao_id") || "").trim();
  if (!comissaoId) return;

  const novoLanc = String(lancamento.get("status") || "");
  const velhoLanc = String(origStatusLanc || "");
  if (novoLanc === velhoLanc) return;

  let comissao;
  try {
    comissao = app.findRecordById("prof_comissoes", comissaoId);
  } catch (_) {
    console.log(
      "[comissao-pago] comissão " + comissaoId + " não encontrada; skip sync.",
    );
    return;
  }

  const want = novoLanc === "pago" ? "paga" : "pendente";
  const atual = String(comissao.get("status") || "");
  if (atual === want) return;

  comissao.set("status", want);
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
 * a raiz **Equipe** (sem sub). Não mexe em status/valor/saldo (R1).
 */
function realinharCategoriasComissao(app) {
  const cats = acharCategoriaComissao(app);
  if (!cats || !cats.categoriaId) {
    console.log("[comissao-pago] realinhar categorias: sem Equipe.");
    return 0;
  }
  const wantSub = "";
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
      " despesa(s) → Equipe (raiz).",
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
  cicloCorrenteDoProf,
};
