/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — F-231: marcar comissão como PAGA cria uma DESPESA de verdade.
 *
 * O problema (QA E2E, 14/07/2026): a comissão vivia num silo (`prof_comissoes`)
 * que NUNCA tocava `fin_lancamentos`. Marcar como paga só trocava um enum. O
 * dinheiro saía do bolso do dono no mundo real, mas o saldo das contas e os
 * relatórios do painel continuavam contando ele como se estivesse lá — INFLADOS
 * pelo total pago aos profissionais, para sempre.
 *
 * Agora:
 *   pendente → paga  ⇒ cria lançamento `despesa` (origem "via_comissao")
 *   paga → pendente  ⇒ APAGA esse lançamento (estorno)
 *   comissão deletada (paga) ⇒ apaga o lançamento junto (não deixa despesa órfã)
 *
 * ── R1 (saldo é server-side atômico) ────────────────────────────────────────
 * Este arquivo NUNCA escreve em `fin_contas.saldo_atual`. Ele só cria/apaga o
 * LANÇAMENTO. Quem debita/estorna o saldo é o `fin_saldo.pb.js` (hook de modelo
 * de fin_lancamentos), por UPDATE SQL atômico. Mexer no saldo aqui contaria em
 * DOBRO — foi exatamente o erro que o os_financeiro_lib.js já documenta.
 *
 * ── Best-effort ─────────────────────────────────────────────────────────────
 * Nunca lança. Se a categoria ou a conta não existirem, loga e desiste — marcar
 * como paga não pode falhar por causa do financeiro.
 */

/** Categoria de despesa "Comissões" (subcategoria de Equipe, já existe na base). */
function acharCategoriaComissao(app) {
  // 1ª escolha: a categoria dedicada.
  try {
    const c = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && nome = 'Comissões'",
    );
    if (c) return c.id;
  } catch (_) {
    /* não existe — cai no fallback */
  }
  // Fallback: qualquer categoria de despesa, pra não perder o lançamento.
  try {
    const list = app.findRecordsByFilter(
      "fin_categorias",
      "tipo = 'despesa'",
      "nome",
      1,
      0,
      {},
    );
    if (list && list.length > 0) return list[0].id;
  } catch (_) {}
  return null;
}

/**
 * Conta de onde sai o dinheiro. Mesma regra determinística do lançamento da OS
 * (F-223): prefere a conta `padrao=true` ativa; senão, a 1ª ativa por nome.
 */
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

/** O lançamento já criado por esta comissão (ou null). */
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
  app.delete(lanc); // fin_saldo.pb.js (onRecordDelete) ESTORNA o saldo.
  console.log("[comissao-pago] lançamento " + lanc.id + " estornado.");
  return true;
}

function criarLancamentoDaComissao(app, comissao) {
  // Idempotência: se já existe lançamento pra esta comissão, não cria outro.
  if (acharLancamentoDaComissao(app, comissao.id)) {
    console.log("[comissao-pago] lançamento já existe; skip.");
    return;
  }

  const valor = Number(comissao.get("valor_comissao") || 0);
  if (!(valor > 0)) {
    console.log("[comissao-pago] valor_comissao <= 0; skip.");
    return;
  }

  const categoriaId = acharCategoriaComissao(app);
  if (!categoriaId) {
    console.log("[comissao-pago] nenhuma categoria de despesa; skip.");
    return;
  }
  const contaId = acharConta(app);
  if (!contaId) {
    console.log("[comissao-pago] nenhuma conta ativa; skip.");
    return;
  }

  // Nome do profissional pra descrição legível no extrato.
  // Prefere o DESNORMALIZADO (F-225): a relação pode estar vazia se o
  // profissional foi excluído, e a despesa não pode virar "Comissão · " pelado.
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

  const col = app.findCollectionByNameOrId("fin_lancamentos");
  const lanc = new Record(col);
  lanc.set("tipo", "despesa");
  lanc.set("descricao", descricao);
  lanc.set("categoria_id", categoriaId);
  lanc.set("valor", valor);
  lanc.set("conta_id", contaId);
  lanc.set("data", require(`${__hooks}/prof_comissao_lib.js`).dataBrtAgora());
  lanc.set("status", "pago");
  lanc.set("recorrencia", "unica");
  lanc.set("origem", "via_comissao");
  lanc.set("comissao_id", comissao.id);
  if (osId) {
    lanc.set("os_id", osId);
    lanc.set("os_numero", osId.slice(-6).toUpperCase());
  }

  // Só cria o lançamento. O DÉBITO do saldo é do fin_saldo.pb.js (R1).
  app.save(lanc);
  console.log(
    "[comissao-pago] comissão " +
      comissao.id +
      " → despesa R$ " +
      valor +
      " (lanç. " +
      lanc.id +
      ")",
  );
}

/**
 * Sincroniza o lançamento com o status da comissão.
 *
 * @param {core.App} app
 * @param {core.Record} comissao   registro JÁ persistido (chamar DEPOIS do e.next())
 * @param {string} origStatus      status ANTES do e.next() — obrigatório, porque
 *                                 `record.original()` já reflete o novo estado
 *                                 depois do commit (mesma razão do snapshot em
 *                                 fin_saldo.pb.js / os_financeiro.pb.js).
 */
function sincronizarLancamento(app, comissao, origStatus) {
  const novo = String(comissao.get("status") || "");
  const velho = String(origStatus || "");
  if (novo === velho) return; // nada de status mudou

  if (novo === "paga") {
    criarLancamentoDaComissao(app, comissao);
  } else if (velho === "paga") {
    // Voltou pra pendente (ou qualquer coisa != paga): estorna.
    apagarLancamentoDaComissao(app, comissao.id);
  }
}

module.exports = {
  sincronizarLancamento,
  apagarLancamentoDaComissao,
  acharLancamentoDaComissao,
};
