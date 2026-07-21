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
 * Resolve categoria Equipe + subcategoria Profissionais (comissão da equipe).
 * Retorna { categoriaId, subcategoriaId } ou null.
 *
 * Preferência (dono 2026-07):
 *   1) sub "Profissionais" filha de "Equipe"  ← canônico (seed catdequipeprof1)
 *   2) sub "Comissões"/"Comissão" filha de "Equipe" (legado)
 *   3) sub "Profissionais" com qualquer parent
 *   4) raiz "Equipe" só (sem sub)
 *   5) qualquer despesa (fallback)
 */
function acharCategoriaComissao(app) {
  // 1) Equipe → Profissionais (canônico)
  try {
    const equipe = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && nome = 'Equipe' && (parent_id = '' || parent_id = null)",
    );
    if (equipe) {
      try {
        const prof = app.findFirstRecordByFilter(
          "fin_categorias",
          "tipo = 'despesa' && parent_id = {:pid} && nome = 'Profissionais'",
          { pid: equipe.id },
        );
        if (prof) {
          return { categoriaId: equipe.id, subcategoriaId: prof.id };
        }
      } catch (_) {}
      // 2) Legado: Comissões sob Equipe
      try {
        const sub = app.findFirstRecordByFilter(
          "fin_categorias",
          "tipo = 'despesa' && parent_id = {:pid} && (nome = 'Comissões' || nome = 'Comissão')",
          { pid: equipe.id },
        );
        if (sub) {
          return { categoriaId: equipe.id, subcategoriaId: sub.id };
        }
      } catch (_) {}
      // Equipe sem sub conhecida — usa a raiz
      return { categoriaId: equipe.id, subcategoriaId: null };
    }
  } catch (_) {}

  // 3) Qualquer "Profissionais" com parent
  try {
    const sub = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && nome = 'Profissionais' && parent_id != '' && parent_id != null",
    );
    if (sub) {
      const parentId = String(sub.get("parent_id") || "");
      return {
        categoriaId: parentId || sub.id,
        subcategoriaId: parentId ? sub.id : null,
      };
    }
  } catch (_) {}

  // 4) Legado: "Comissões" com parent
  try {
    const sub = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && (nome = 'Comissões' || nome = 'Comissão') && parent_id != '' && parent_id != null",
    );
    if (sub) {
      const parentId = String(sub.get("parent_id") || "");
      return {
        categoriaId: parentId || sub.id,
        subcategoriaId: parentId ? sub.id : null,
      };
    }
  } catch (_) {}

  // 5) Fallback: 1ª despesa
  try {
    const list = app.findRecordsByFilter(
      "fin_categorias",
      "tipo = 'despesa'",
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
 * Despesa de **repasse** do profissional no dia (1 por prof + data).
 * Filtro por profissional_id + data + origem via_comissao + sem comissao_id.
 */
function acharLancamentoRepasse(app, profId, ymd) {
  const p = String(profId || "").replace(/'/g, "\\'");
  const d = String(ymd || "").slice(0, 10);
  if (!p || !/^\d{4}-\d{2}-\d{2}$/.test(d)) return null;
  try {
    return app.findFirstRecordByFilter(
      "fin_lancamentos",
      "origem = 'via_comissao' && profissional_id = '" +
        p +
        "' && data = '" +
        d +
        "' && (comissao_id = '' || comissao_id = null)",
    );
  } catch (_) {
    // Fallback sem campo profissional_id (pré-migração): descrição
    try {
      return app.findFirstRecordByFilter(
        "fin_lancamentos",
        "origem = 'via_comissao' && data = '" +
          d +
          "' && descricao ~ 'Repasse comissões' && (comissao_id = '' || comissao_id = null)",
      );
    } catch (_) {
      return null;
    }
  }
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
  for (var i = 0; i < (list || []).length; i++) {
    var c = list[i];
    var v = Number(c.get("valor_comissao") || 0);
    if (!(v > 0)) continue;
    cents += Math.round(v * 100);
    n++;
    if (!profNome) {
      profNome = String(c.get("profissional_nome") || "").trim();
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

  var descricao =
    "Repasse comissões · " +
    (profNome || p.slice(0, 8)) +
    " · " +
    d +
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
  // Subcategoria Profissionais sob Equipe (PB: "" se vazia, nunca null — R2)
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
  // Mantém categoria Equipe / sub Profissionais alinhadas
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
      try {
        comissao.set("pago_em", pe);
        app.save(comissao);
      } catch (err) {
        console.error("[comissao-pago] falha ao gravar pago_em: " + err);
      }
    }
    recalcularDespesaRepasse(app, profId, pe);
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
}

/**
 * Ao criar comissão (OS concluída): **não** gera despesa.
 * A despesa só nasce no repasse (marcar paga / fechar ciclo).
 */
function onComissaoCriada(app, comissao) {
  const st = String(comissao.get("status") || "");
  // Só se já nascer "paga" (raro): gera/atualiza repasse do dia.
  if (st === "paga") {
    const profId = String(comissao.get("profissional") || "").trim();
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
  }
  // pendente: sem despesa — acumula só em Equipe / prof_comissoes
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
 * Equipe → Profissionais (canônico). Não mexe em status/valor/saldo (R1).
 */
function realinharCategoriasComissao(app) {
  const cats = acharCategoriaComissao(app);
  if (!cats || !cats.categoriaId) {
    console.log("[comissao-pago] realinhar categorias: sem Equipe/Profissionais.");
    return 0;
  }
  const wantSub = cats.subcategoriaId || "";
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
      " despesa(s) → Equipe/Profissionais.",
  );
  return n;
}

module.exports = {
  sincronizarLancamento,
  apagarLancamentoDaComissao,
  acharLancamentoDaComissao,
  acharLancamentoRepasse,
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
};
