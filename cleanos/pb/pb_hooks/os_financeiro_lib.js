/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — lógica da integração OS → Financeiro (módulo CommonJS).
 *
 * Carregado via require() de dentro dos handlers em os_financeiro.pb.js.
 * Cada handler do PocketBase roda numa VM isolada e NÃO enxerga o escopo
 * do arquivo — mesmo padrão de os_logic.js requerido por os_servicos.pb.js.
 *
 * Ciclo de vida do lançamento `via_os`:
 *   - OS atribuida | em_andamento + valor_servico > 0
 *       → receita status=previsto (não mexe no saldo_atual)
 *   - OS → concluida + valor_pago > 0
 *       → promove previsto→pago ou cria pago (credita saldo via fin_saldo)
 *   - OS → cancelada | agendada
 *       → remove só o via_os ainda previsto (não toca pago histórico)
 *
 * Best-effort: NUNCA lança — erros logados e engolidos pelo caller.
 */

var FORMA_MAP = {
  debito: "Débito",
  credito: "Crédito",
  pix_maquininha: "Pix",
  pix: "Pix",
  dinheiro: "Dinheiro em espécie",
  outros: "Outros",
};

/**
 * Ponto único chamado pelos hooks create/update DEPOIS de e.next().
 * Roteia por status da OS.
 */
function sincronizarReceitaOs(app, record, origStatus) {
  const status = String(record.get("status") || "");
  if (status === "concluida") {
    criarLancamentoFinanceiro(app, record, origStatus);
    return;
  }
  if (status === "atribuida" || status === "em_andamento") {
    upsertReceitaPrevista(app, record);
    return;
  }
  // agendada / cancelada: limpa previsto; não apaga receita já paga
  if (status === "agendada" || status === "cancelada") {
    removeReceitaPrevista(app, record.id);
  }
}

/**
 * Cria/atualiza receita PREVISTA quando a OS está atribuída (ou em andamento)
 * e ainda não foi concluída. Usa valor_servico (orçamento), não valor_pago.
 */
function upsertReceitaPrevista(app, record) {
  const valorServico = Number(record.get("valor_servico") || 0);
  const osId = record.id;

  if (!(valorServico > 0)) {
    removeReceitaPrevista(app, osId);
    return;
  }

  const meta = _metaLancamento(app, record);
  if (!meta) return;

  let existente = null;
  try {
    existente = app.findFirstRecordByFilter(
      "fin_lancamentos",
      "os_id = {:id} && origem = 'via_os'",
      { id: osId },
    );
  } catch (_) {
    existente = null;
  }

  if (existente) {
    // Se já está pago (OS reaberta indevidamente), não rebaixa silenciosamente
    // aqui — reabertura trata valor_pago=0 em fluxo operacional à parte.
    if (String(existente.get("status") || "") === "pago") {
      console.log(
        "[fin] via_os já pago para OS " + osId + "; skip previsto.",
      );
      return;
    }
    existente.set("tipo", "receita");
    existente.set("descricao", meta.descricao);
    existente.set("categoria_id", meta.categoriaId);
    existente.set("valor", valorServico);
    existente.set("conta_id", meta.contaId);
    existente.set("data", meta.dataParede);
    existente.set("status", "previsto");
    existente.set("recorrencia", "unica");
    existente.set("origem", "via_os");
    existente.set("os_id", osId);
    existente.set("os_numero", meta.osNumero);
    existente.set("cliente_nome", meta.clienteNome);
    existente.set("servico_nome", meta.servicoNome);
    existente.set("forma_pagamento", "");
    app.save(existente);
    console.log(
      "[fin] Receita prevista atualizada — OS " +
        osId +
        ", R$ " +
        valorServico,
    );
    return;
  }

  const finLancCol = app.findCollectionByNameOrId("fin_lancamentos");
  const lanc = new Record(finLancCol);
  lanc.set("tipo", "receita");
  lanc.set("descricao", meta.descricao);
  lanc.set("categoria_id", meta.categoriaId);
  lanc.set("valor", valorServico);
  lanc.set("conta_id", meta.contaId);
  lanc.set("data", meta.dataParede);
  lanc.set("status", "previsto");
  lanc.set("recorrencia", "unica");
  lanc.set("origem", "via_os");
  lanc.set("os_id", osId);
  lanc.set("os_numero", meta.osNumero);
  lanc.set("cliente_nome", meta.clienteNome);
  lanc.set("servico_nome", meta.servicoNome);
  lanc.set("forma_pagamento", "");
  app.save(lanc);
  console.log(
    "[fin] Receita prevista criada — OS " + osId + ", R$ " + valorServico,
  );
}

/**
 * Remove lançamento via_os SOMENTE se ainda estiver previsto/pendente/em_atraso.
 * Não remove receita já paga.
 */
function removeReceitaPrevista(app, osId) {
  if (!osId) return;
  try {
    const existente = app.findFirstRecordByFilter(
      "fin_lancamentos",
      "os_id = {:id} && origem = 'via_os'",
      { id: osId },
    );
    const st = String(existente.get("status") || "");
    if (st === "pago") return;
    app.delete(existente);
    console.log("[fin] Receita prevista removida — OS " + osId);
  } catch (_) {
    /* não existe */
  }
}

/**
 * Cria um lançamento de RECEITA paga quando uma OS transiciona
 * para 'concluida' com valor_pago > 0. Se já existir via_os previsto,
 * promove a pago (evita duplicata e preserva o id).
 */
function criarLancamentoFinanceiro(app, record, origStatus) {
  const newStatus = String(record.get("status") || "");
  if (newStatus !== "concluida") return;

  // Detecta a TRANSIÇÃO real para 'concluida' (saves subsequentes não reagem).
  let prevStatus;
  if (arguments.length >= 3) {
    prevStatus = String(origStatus || "");
  } else {
    const orig = record.original ? record.original() : null;
    prevStatus = orig ? String(orig.get("status") || "") : "";
  }
  if (prevStatus === "concluida") return;

  const valorPago = Number(record.get("valor_pago") || 0);
  if (!(valorPago > 0)) {
    console.log("[fin] OS concluída sem valor_pago > 0; lançamento não criado.");
    return;
  }

  const osId = record.id;
  const meta = _metaLancamento(app, record);
  if (!meta) return;

  const formaRaw = record.getString("forma_pagamento");
  let formaPagamento = FORMA_MAP[formaRaw] || formaRaw;
  // "Outros" com detalhe preenchido pelo profissional → o detalhe vira a forma
  // no lançamento (ex.: "Transferência", "Cortesia").
  if (formaRaw === "outros") {
    const outro = record.getString("forma_pagamento_outro").trim();
    if (outro) formaPagamento = outro;
  }

  // Se já existe via_os (previsto da atribuição): promove a pago.
  try {
    const existente = app.findFirstRecordByFilter(
      "fin_lancamentos",
      "os_id = {:id} && origem = 'via_os'",
      { id: osId },
    );
    if (String(existente.get("status") || "") === "pago") {
      console.log(
        "[fin] Lançamento via_os já pago para OS " +
          osId +
          "; skip (anti-duplicata).",
      );
      return;
    }
    existente.set("tipo", "receita");
    existente.set("descricao", meta.descricao);
    existente.set("categoria_id", meta.categoriaId);
    existente.set("valor", valorPago);
    existente.set("conta_id", meta.contaId);
    existente.set("data", meta.dataParede);
    existente.set("status", "pago");
    existente.set("recorrencia", "unica");
    existente.set("origem", "via_os");
    existente.set("os_id", osId);
    existente.set("os_numero", meta.osNumero);
    existente.set("cliente_nome", meta.clienteNome);
    existente.set("servico_nome", meta.servicoNome);
    existente.set("forma_pagamento", formaPagamento);
    app.save(existente);
    console.log(
      "[fin] Receita prevista promovida a paga — OS " +
        osId +
        ", R$ " +
        valorPago,
    );
    return;
  } catch (_) {
    /* not found → cria */
  }

  const finLancCol = app.findCollectionByNameOrId("fin_lancamentos");
  const lanc = new Record(finLancCol);
  lanc.set("tipo", "receita");
  lanc.set("descricao", meta.descricao);
  lanc.set("categoria_id", meta.categoriaId);
  lanc.set("valor", valorPago);
  lanc.set("conta_id", meta.contaId);
  lanc.set("data", meta.dataParede);
  lanc.set("status", "pago");
  lanc.set("recorrencia", "unica");
  lanc.set("origem", "via_os");
  lanc.set("os_id", osId);
  lanc.set("os_numero", meta.osNumero);
  lanc.set("cliente_nome", meta.clienteNome);
  lanc.set("servico_nome", meta.servicoNome);
  lanc.set("forma_pagamento", formaPagamento);
  app.save(lanc);
  console.log(
    "[fin] Lançamento receita criado (saldo creditado pelo hook de fin_lancamentos) — OS " +
      osId +
      ", R$ " +
      valorPago +
      ", cat=" +
      meta.categoriaId +
      ", conta=" +
      meta.contaId +
      ".",
  );
}

/**
 * Resolve categoria, conta e campos denormalizados comuns do via_os.
 * null se faltar categoria ou conta (não cria lançamento).
 */
function _metaLancamento(app, record) {
  const osId = record.id;

  let catNomeDesejado = "Serviço Automotivo";
  try {
    const snapStr = record.getString("service_snapshot");
    if (snapStr && snapStr !== "null" && snapStr !== "") {
      const snap = JSON.parse(snapStr);
      if (
        snap &&
        String(snap.categoria || "").toLowerCase() === "residencial"
      ) {
        catNomeDesejado = "Serviço Residencial";
      }
    }
  } catch (_) {
    /* mantém padrão */
  }

  let categoriaId = null;
  try {
    const cat = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'receita' && nome = {:n}",
      { n: catNomeDesejado },
    );
    categoriaId = cat.id;
  } catch (_) {}

  if (!categoriaId) {
    try {
      const cats = app.findRecordsByFilter(
        "fin_categorias",
        "tipo = 'receita' && arquivada = false",
        "nome",
        1,
        0,
        {},
      );
      if (cats && cats.length > 0) categoriaId = cats[0].id;
    } catch (_) {}
  }
  if (!categoriaId) {
    console.log(
      "[fin] Nenhuma categoria receita em fin_categorias; lançamento não criado.",
    );
    return null;
  }

  let contaId = null;
  try {
    const padrao = app.findRecordsByFilter(
      "fin_contas",
      "ativo = true && padrao = true",
      "nome",
      1,
      0,
      {},
    );
    if (padrao && padrao.length > 0) contaId = padrao[0].id;
  } catch (_) {}
  if (!contaId) {
    try {
      const contas = app.findRecordsByFilter(
        "fin_contas",
        "ativo = true",
        "nome",
        1,
        0,
        {},
      );
      if (contas && contas.length > 0) contaId = contas[0].id;
    } catch (_) {}
  }
  if (!contaId) {
    console.log(
      "[fin] Nenhuma conta ativa em fin_contas — lançamento da OS não criado.",
    );
    return null;
  }

  const servicoNome = record.getString("tipo_servico_nome") || "";
  const clienteNome = record.getString("nome_curto") || "";
  const osNumero = String(osId).slice(-6).toUpperCase();
  const descricao =
    "OS " + osNumero + (clienteNome ? " - " + clienteNome : "");
  const dataParede = dataParedeBrtDaOs(record);

  return {
    categoriaId: categoriaId,
    contaId: contaId,
    servicoNome: servicoNome,
    clienteNome: clienteNome,
    osNumero: osNumero,
    descricao: descricao,
    dataParede: dataParede,
  };
}

/**
 * Parte-data parede BRT ('YYYY-MM-DD') da OS a partir de `data_hora` (UTC no PB).
 * Fallback: dia BRT de agora (conclusão sem data_hora).
 */
function dataParedeBrtDaOs(record) {
  var BRT_OFFSET_MS = 3 * 60 * 60 * 1000;
  var raw = "";
  try {
    raw =
      record && record.getString
        ? String(record.getString("data_hora") || "")
        : "";
  } catch (_) {
    raw = "";
  }
  if (raw) {
    try {
      var iso = raw.indexOf("T") >= 0 ? raw : raw.replace(" ", "T");
      if (!/[zZ]$|[+-]\d{2}:?\d{2}$/.test(iso)) iso += "Z";
      var d = new Date(iso);
      if (!isNaN(d.getTime())) {
        var brt = new Date(d.getTime() - BRT_OFFSET_MS);
        var y = brt.getUTCFullYear();
        var m = String(brt.getUTCMonth() + 1).padStart(2, "0");
        var day = String(brt.getUTCDate()).padStart(2, "0");
        return y + "-" + m + "-" + day;
      }
    } catch (_) {
      /* fallback abaixo */
    }
  }
  var agora = new Date(Date.now() - BRT_OFFSET_MS);
  var ay = agora.getUTCFullYear();
  var am = String(agora.getUTCMonth() + 1).padStart(2, "0");
  var ad = String(agora.getUTCDate()).padStart(2, "0");
  return ay + "-" + am + "-" + ad;
}

module.exports = {
  sincronizarReceitaOs,
  criarLancamentoFinanceiro,
  upsertReceitaPrevista,
  removeReceitaPrevista,
  dataParedeBrtDaOs,
};
