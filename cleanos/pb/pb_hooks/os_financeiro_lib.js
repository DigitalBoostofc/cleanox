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
 */
function criarLancamentoFinanceiro(app, record) {
  const newStatus = String(record.get("status") || "");
  if (newStatus !== "concluida") return;

  const orig = record.original ? record.original() : null;
  // UPDATE: só age na TRANSIÇÃO; saves subsequentes numa OS concluida não reagem.
  // CREATE: orig === null → OS nascendo concluida (ex.: admin import) → prossegue.
  if (orig && String(orig.get("status") || "") === "concluida") return;

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

  // Conta padrão: primeira fin_conta ativa (order by nome asc, limit 1).
  let contaId = null;
  try {
    const contas = app.findRecordsByFilter("fin_contas", "ativo = true", "nome", 1, 0, {});
    if (contas && contas.length > 0) contaId = contas[0].id;
  } catch (_) {}

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
  const now = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";

  const finLancCol = app.findCollectionByNameOrId("fin_lancamentos");
  const lanc = new Record(finLancCol);
  lanc.set("tipo",            "receita");
  lanc.set("descricao",        descricao);
  lanc.set("categoria_id",     categoriaId);
  lanc.set("valor",            valorPago);
  lanc.set("conta_id",         contaId);
  lanc.set("data",             now);
  lanc.set("status",           "pago");
  lanc.set("recorrencia",      "unica");
  lanc.set("origem",           "via_os");
  lanc.set("os_id",            osId);
  lanc.set("os_numero",        osNumero);
  lanc.set("cliente_nome",     clienteNome);
  lanc.set("servico_nome",     servicoNome);
  lanc.set("forma_pagamento",  formaPagamento);

  app.save(lanc);
  console.log("[fin] Lançamento receita criado (OS " + osId + ", R$ " + valorPago + ", cat=" + categoriaId + ", conta=" + contaId + ").");

  // Ajusta saldo_atual da conta — espelha o modelo incremental do frontend (A-001):
  // receita paga soma no saldo. Best-effort: falha não quebra o fluxo (lançamento já criado).
  try {
    const conta = app.findRecordById("fin_contas", contaId);
    conta.set("saldo_atual", Number(conta.get("saldo_atual") || 0) + valorPago);
    app.save(conta);
    console.log("[fin] saldo_atual da conta " + contaId + " ajustado em +" + valorPago + ".");
  } catch (e) {
    console.log("[fin] Falha ao ajustar saldo_atual da conta " + contaId + " (ignorado): " + e);
  }
}

module.exports = { criarLancamentoFinanceiro };
