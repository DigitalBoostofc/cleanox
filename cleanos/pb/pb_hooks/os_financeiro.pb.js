/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — integração OS → Financeiro (os_financeiro.pb.js).
 *
 * Ao concluir uma OS (transição any → 'concluida' com valor_pago > 0),
 * cria automaticamente um Lançamento de RECEITA em fin_lancamentos.
 *
 * A lógica mora em os_financeiro_lib.js e é importada via require() dentro
 * de cada handler — idêntico ao padrão os_logic.js / os_servicos.pb.js,
 * pois cada handler do PocketBase roda numa VM isolada.
 *
 * Cobre os DOIS caminhos (espelha setRepasseIfConcluida em os_logic.js):
 *   - onRecordUpdate: OS transiciona para 'concluida'
 *   - onRecordCreate: OS criada já 'concluida' (admin, import)
 *
 * Best-effort: erros NUNCA bloqueiam a conclusão da OS.
 * Anti-duplicata: idempotente via busca os_id+origem antes de criar.
 *
 * ORDEM (fecha a janela de receita órfã — F-MÉDIO): o lançamento `via_os` (e o
 * crédito de saldo que ele dispara no hook de fin_lancamentos) é criado SÓ
 * DEPOIS de `e.next()` — ou seja, depois de a transição da OS estar persistida.
 * Antes, ele rodava ANTES do e.next(): se o persist da OS falhasse/rollasse
 * depois, sobrava receita fantasma no financeiro. Alinha com a convenção
 * "efeitos colaterais após e.next()" (ver os_logic.js / fin_saldo.pb.js).
 *
 * Como `record.original()` passa a refletir o NOVO estado após e.next() (mesma
 * razão do snapshot em fin_saldo.pb.js), o status ORIGINAL é capturado ANTES do
 * e.next() e passado explicitamente para preservar a detecção de transição.
 */

// Caminho 1: UPDATE — transição any → 'concluida'
onRecordUpdate((e) => {
  // Captura o status ORIGINAL antes de e.next() (depois dele, record.original()
  // já reflete o estado recém-persistido — não serviria para detectar transição).
  const orig = e.record.original ? e.record.original() : null;
  const origStatus = orig ? String(orig.get("status") || "") : "";
  e.next(); // 1) persiste a transição da OS PRIMEIRO (commit)
  try {
    // 2) só então cria o lançamento (crédito de saldo durável só após o commit da OS)
    require(`${__hooks}/os_financeiro_lib.js`).criarLancamentoFinanceiro(e.app, e.record, origStatus);
  } catch (err) {
    console.error("[fin] Erro ao criar lançamento (update, ignorado): " + err);
  }
}, "ordens_servico");

// Caminho 2: CREATE — OS nascendo já 'concluida' (ex.: admin lançando OS já finalizada)
onRecordCreate((e) => {
  e.next(); // 1) persiste a OS PRIMEIRO
  try {
    // origStatus = null → OS nascendo concluida (sem estado anterior) → prossegue
    require(`${__hooks}/os_financeiro_lib.js`).criarLancamentoFinanceiro(e.app, e.record, null);
  } catch (err) {
    console.error("[fin] Erro ao criar lançamento (create, ignorado): " + err);
  }
}, "ordens_servico");
