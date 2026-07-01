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
 */

// Caminho 1: UPDATE — transição any → 'concluida'
onRecordUpdate((e) => {
  const lib = require(`${__hooks}/os_financeiro_lib.js`);
  try {
    lib.criarLancamentoFinanceiro(e.app, e.record);
  } catch (err) {
    console.error("[fin] Erro ao criar lançamento (update, ignorado): " + err);
  }
  e.next();
}, "ordens_servico");

// Caminho 2: CREATE — OS nascendo já 'concluida' (ex.: admin lançando OS já finalizada)
onRecordCreate((e) => {
  const lib = require(`${__hooks}/os_financeiro_lib.js`);
  try {
    lib.criarLancamentoFinanceiro(e.app, e.record);
  } catch (err) {
    console.error("[fin] Erro ao criar lançamento (create, ignorado): " + err);
  }
  e.next();
}, "ordens_servico");
