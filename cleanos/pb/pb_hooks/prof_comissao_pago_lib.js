/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — comissão ↔ despesa em fin_lancamentos (origem "via_comissao").
 *
 * Ciclo desejado (dono, 2026-07):
 *   OS concluída → cria prof_comissoes (pendente)
 *                 → cria despesa via_comissao status **pendente** (não mexe saldo)
 *   Marcar paga (Equipe OU mãozinha em Movimentações)
 *                 → despesa vira **pago** (fin_saldo debita)
 *                 → comissão vira **paga**
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

function apagarLancamentoDaComissao(app, comissaoId) {
  const lanc = acharLancamentoDaComissao(app, comissaoId);
  if (!lanc) return false;
  app.delete(lanc);
  console.log("[comissao-pago] lançamento " + lanc.id + " removido.");
  return true;
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
 * Sincroniza o lançamento com o status da comissão (chamar DEPOIS do e.next()).
 *   paga     → despesa **pago**
 *   pendente → despesa **pendente** (mantém o lançamento; não apaga)
 */
function sincronizarLancamento(app, comissao, origStatus) {
  const novo = String(comissao.get("status") || "");
  const velho = String(origStatus || "");
  if (novo === velho && acharLancamentoDaComissao(app, comissao.id)) return;

  if (novo === "paga") {
    garantirLancamentoStatus(app, comissao, "pago");
  } else {
    // pendente (ou outro): despesa em aberto, visível em Movimentações
    garantirLancamentoStatus(app, comissao, "pendente");
  }
}

/**
 * Ao criar comissão pendente (OS concluída): já abre a despesa não paga.
 * Ao criar já paga: despesa paga.
 */
function onComissaoCriada(app, comissao) {
  const st = String(comissao.get("status") || "");
  if (st === "paga") {
    criarLancamentoDaComissao(app, comissao, "pago");
  } else {
    criarLancamentoDaComissao(app, comissao, "pendente");
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

/** Backfill: toda comissão sem despesa ganha uma (pendente ou paga). */
function backfillDespesasComissao(app) {
  let list = [];
  try {
    list = app.findRecordsByFilter("prof_comissoes", "id != ''", "-created", 500, 0, {});
  } catch (_) {
    list = [];
  }
  var n = 0;
  for (var i = 0; i < list.length; i++) {
    var c = list[i];
    if (acharLancamentoDaComissao(app, c.id)) continue;
    var st = String(c.get("status") || "") === "paga" ? "pago" : "pendente";
    try {
      criarLancamentoDaComissao(app, c, st);
      n++;
    } catch (err) {
      console.error("[comissao-pago] backfill falhou " + c.id + ": " + err);
    }
  }
  console.log("[comissao-pago] backfill criou " + n + " despesa(s).");
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
  criarLancamentoDaComissao,
  garantirLancamentoStatus,
  onComissaoCriada,
  sincronizarComissaoDoLancamento,
  backfillDespesasComissao,
  dataLancamentoComissao,
  realinharDatasComissaoComOs,
  realinharCategoriasComissao,
  acharCategoriaComissao,
};
