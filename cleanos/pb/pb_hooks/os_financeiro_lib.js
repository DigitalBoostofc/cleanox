/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — lógica da integração OS → Financeiro (módulo CommonJS).
 *
 * Carregado via require() de dentro dos handlers em os_financeiro.pb.js.
 * Cada handler do PocketBase roda numa VM isolada e NÃO enxerga o escopo
 * do arquivo — mesmo padrão de os_logic.js requerido por os_servicos.pb.js.
 */

/**
 * Cria um lançamento de RECEITA em fin_lancamentos quando uma OS transiciona
 * para 'concluida' com valor_pago > 0.
 *
 * Cobre os DOIS caminhos (espelha setRepasseIfConcluida em os_logic.js):
 *   - onRecordUpdate: OS transiciona para 'concluida'
 *   - onRecordCreate: OS criada já 'concluida' (admin, import)
 *
 * Best-effort: NUNCA lança — todos os erros são logados e engolidos.
 * Anti-duplicata: verifica fin_lancamentos com os_id+origem antes de criar.
 *
 * ORDEM (janela de receita órfã fechada): os handlers em os_financeiro.pb.js
 * chamam esta função DEPOIS de e.next() (após a OS estar persistida). Como
 * `record.original()` já reflete o novo estado nesse ponto, o status ORIGINAL é
 * passado em `origStatus` (capturado no handler ANTES do e.next()):
 *   - UPDATE: string do status anterior à transição (pode ser "").
 *   - CREATE: null → OS nascendo concluida (sem estado anterior) → prossegue.
 * Fallback (chamada legada sem o 3º arg): lê record.original().
 */
function criarLancamentoFinanceiro(app, record, origStatus) {
  const newStatus = String(record.get("status") || "");
  if (newStatus !== "concluida") return;

  // Detecta a TRANSIÇÃO real para 'concluida' (saves subsequentes não reagem).
  // Usa origStatus quando informado (3º arg); senão cai no record.original()
  // — que só é confiável se a função for chamada ANTES de e.next().
  let prevStatus;
  if (arguments.length >= 3) {
    prevStatus = String(origStatus || ""); // CREATE passa null → "" → prossegue
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

  // Anti-duplicata: findFirstRecordByFilter lança quando NÃO encontra.
  // Se NÃO lançar: registro já existe → idempotente, não duplica.
  // Se lançar: registro não existe (ou coleção ausente) → prossegue.
  try {
    app.findFirstRecordByFilter(
      "fin_lancamentos",
      "os_id = '" + osId + "' && origem = 'via_os'"
    );
    console.log("[fin] Lançamento via_os já existe para OS " + osId + "; skip (anti-duplicata).");
    return;
  } catch (_) { /* not found → cria */ }

  // Categoria via service_snapshot.categoria (campo SelectField em `servicos`).
  // Valores possíveis: 'veicular' ou 'residencial' (migration 8 / os_logic.js fillServiceSnapshot).
  // IMPORTANTE (goja/PB): getString() faz cast []byte→string corretamente; get() devolve JSONRaw.
  //
  // Lookup por NOME em fin_categorias — robusto a qualquer remapeamento de ID futuro.
  //   'residencial' → nome='Serviço Residencial'
  //   'veicular' / outros → nome='Serviço Automotivo' (padrão de negócio)
  let catNomeDesejado = "Serviço Automotivo"; // padrão (veicular ou desconhecido)
  try {
    const snapStr = record.getString("service_snapshot");
    if (snapStr && snapStr !== "null" && snapStr !== "") {
      const snap = JSON.parse(snapStr);
      if (snap && String(snap.categoria || "").toLowerCase() === "residencial") {
        catNomeDesejado = "Serviço Residencial";
      }
      // 'veicular' e qualquer outro → 'Serviço Automotivo'
    }
  } catch (_) { /* mantém padrão */ }

  // Resolve por nome — nunca depende de IDs hardcoded.
  let categoriaId = null;
  try {
    const cat = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'receita' && nome = '" + catNomeDesejado + "'"
    );
    categoriaId = cat.id;
  } catch (_) {}

  // Fallback: primeira categoria receita não-arquivada (último recurso).
  if (!categoriaId) {
    try {
      const cats = app.findRecordsByFilter("fin_categorias", "tipo = 'receita' && arquivada = false", "nome", 1, 0, {});
      if (cats && cats.length > 0) categoriaId = cats[0].id;
    } catch (_) {}
  }
  if (!categoriaId) {
    console.log("[fin] Nenhuma categoria receita em fin_categorias (migration 15 pendente?); lançamento não criado.");
    return;
  }

  // Conta-destino DETERMINÍSTICA (F-223): prefere a conta marcada como `padrao=true`
  // (e ativa) — destino explícito/intencional, imune a uma nova conta cujo nome
  // ordene antes. Fallback à 1ª conta ativa por nome asc (comportamento legado)
  // quando nenhuma conta está marcada como padrão.
  let contaId = null;
  try {
    const padrao = app.findRecordsByFilter("fin_contas", "ativo = true && padrao = true", "nome", 1, 0, {});
    if (padrao && padrao.length > 0) contaId = padrao[0].id;
  } catch (_) { /* campo padrao ausente (migration 16 pendente) ou nenhuma marcada → fallback */ }
  if (!contaId) {
    try {
      const contas = app.findRecordsByFilter("fin_contas", "ativo = true", "nome", 1, 0, {});
      if (contas && contas.length > 0) contaId = contas[0].id;
    } catch (_) {}
  }

  if (!contaId) {
    console.log("[fin] Nenhuma conta ativa em fin_contas — lançamento da OS não criado.");
    return;
  }

  // Campos denormalizados da OS.
  const servicoNome = record.getString("tipo_servico_nome") || "";
  const clienteNome = record.getString("nome_curto") || "";
  // ordens_servico não tem campo `numero` sequencial no MVP (ver PLANO R7); usa sufixo do ID como referência.
  const osNumero = osId.slice(-6).toUpperCase();

  // Mapeamento forma_pagamento: SelectField OS → texto livre em fin_lancamentos (TextField max:100).
  var FORMA_MAP = { debito: "Débito", credito: "Crédito", pix_maquininha: "Pix", dinheiro: "Dinheiro" };
  const formaRaw = record.getString("forma_pagamento");
  const formaPagamento = FORMA_MAP[formaRaw] || formaRaw;

  const descricao = "OS " + osNumero + (clienteNome ? " - " + clienteNome : "");
  // Data do lançamento = DIA DO SERVIÇO (data_hora da OS em BRT), não "agora".
  // Assim OS históricas (backfill com data no passado) caem no mês/dia certos
  // nos relatórios. Fallback: dia BRT da conclusão (F-222) se data_hora faltar.
  // DateField do PB: 'YYYY-MM-DD' (parede) — mesmo formato do form manual.
  const dataParede = dataParedeBrtDaOs(record);

  const finLancCol = app.findCollectionByNameOrId("fin_lancamentos");
  const lanc = new Record(finLancCol);
  lanc.set("tipo",            "receita");
  lanc.set("descricao",        descricao);
  lanc.set("categoria_id",     categoriaId);
  lanc.set("valor",            valorPago);
  lanc.set("conta_id",         contaId);
  lanc.set("data",             dataParede);
  lanc.set("status",           "pago");
  lanc.set("recorrencia",      "unica");
  lanc.set("origem",           "via_os");
  lanc.set("os_id",            osId);
  lanc.set("os_numero",        osNumero);
  lanc.set("cliente_nome",     clienteNome);
  lanc.set("servico_nome",     servicoNome);
  lanc.set("forma_pagamento",  formaPagamento);

  // RECONCILIAÇÃO / FONTE ÚNICA DE SALDO (integridade server-side): este hook
  // agora SÓ CRIA o lançamento `via_os` — ele NÃO ajusta mais o saldo. Ao salvar
  // o lançamento, o hook de modelo `onRecordCreate` de fin_lancamentos
  // (fin_saldo.pb.js → fin_saldo_lib.applyCreate) credita `fin_contas.saldo_atual`
  // EXATAMENTE UMA VEZ, por incremento atômico em SQL. Se ajustássemos o saldo
  // AQUI também, contaria em DOBRO — por isso o ajuste foi movido para o hook
  // genérico (fonte única). A conclusão da OS segue best-effort: o caller
  // (os_financeiro.pb.js) envolve em try/catch e sempre chama e.next().
  //
  // Espelha o modelo do frontend: receita paga soma no saldo — só que agora o
  // servidor é quem soma, atomicamente, sem lost-update.
  app.save(lanc);
  console.log("[fin] Lançamento receita criado (saldo creditado pelo hook de fin_lancamentos) — OS " + osId + ", R$ " + valorPago + ", cat=" + categoriaId + ", conta=" + contaId + ".");
}

/**
 * Parte-data parede BRT ('YYYY-MM-DD') da OS a partir de `data_hora` (UTC no PB).
 * Fallback: dia BRT de agora (conclusão sem data_hora).
 */
function dataParedeBrtDaOs(record) {
  var BRT_OFFSET_MS = 3 * 60 * 60 * 1000;
  var raw = "";
  try {
    raw = record && record.getString ? String(record.getString("data_hora") || "") : "";
  } catch (_) {
    raw = "";
  }
  if (raw) {
    try {
      // PB grava "2026-07-14 17:00:00.000Z" (espaço, não T).
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
    } catch (_) { /* fallback abaixo */ }
  }
  var agora = new Date(Date.now() - BRT_OFFSET_MS);
  var ay = agora.getUTCFullYear();
  var am = String(agora.getUTCMonth() + 1).padStart(2, "0");
  var ad = String(agora.getUTCDate()).padStart(2, "0");
  return ay + "-" + am + "-" + ad;
}

module.exports = { criarLancamentoFinanceiro, dataParedeBrtDaOs };
