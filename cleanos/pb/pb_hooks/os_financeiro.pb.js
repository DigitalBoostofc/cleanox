/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — integração OS → Financeiro (os_financeiro.pb.js).
 *
 * Sincroniza fin_lancamentos `via_os` com o ciclo da OS:
 *   - atribuida | em_andamento → receita status=previsto (não mexe saldo)
 *   - concluida + valor_pago > 0 → receita paga (promove previsto ou cria)
 *   - cancelada | agendada → remove só previsto
 *
 * A lógica mora em os_financeiro_lib.js e é importada via require() dentro
 * de cada handler — idêntico ao padrão os_logic.js / os_servicos.pb.js,
 * pois cada handler do PocketBase roda numa VM isolada.
 *
 * Best-effort: erros NUNCA bloqueiam a gravação da OS.
 *
 * ORDEM (fecha a janela de receita órfã — F-MÉDIO): o lançamento `via_os` (e o
 * crédito de saldo quando vira pago) roda SÓ DEPOIS de `e.next()`.
 * O status ORIGINAL é capturado ANTES do e.next() e passado explicitamente.
 */

// Caminho 1: UPDATE
onRecordUpdate((e) => {
  const orig = e.record.original ? e.record.original() : null;
  const origStatus = orig ? String(orig.get("status") || "") : "";
  e.next(); // 1) persiste a OS PRIMEIRO
  try {
    require(`${__hooks}/os_financeiro_lib.js`).sincronizarReceitaOs(
      e.app,
      e.record,
      origStatus,
    );
  } catch (err) {
    console.error("[fin] Erro ao sincronizar receita (update, ignorado): " + err);
  }
  try {
    require(`${__hooks}/prof_comissao_lib.js`).sincronizarComissaoOs(
      e.app,
      e.record,
      origStatus,
    );
  } catch (err) {
    console.error("[comissao] Erro ao sincronizar comissão (update, ignorado): " + err);
  }
  // Meta CAPI Schedule/Purchase (best-effort) — Cleanox Ads
  try {
    require(`${__hooks}/meta_capi_lib.js`).emitOsCapi(e.app, e.record, origStatus);
  } catch (err) {
    console.error("[meta-capi] Erro CAPI (update, ignorado): " + err);
  }
}, "ordens_servico");

// Caminho 2: CREATE
onRecordCreate((e) => {
  e.next(); // 1) persiste a OS PRIMEIRO
  try {
    require(`${__hooks}/os_financeiro_lib.js`).sincronizarReceitaOs(
      e.app,
      e.record,
      null,
    );
  } catch (err) {
    console.error("[fin] Erro ao sincronizar receita (create, ignorado): " + err);
  }
  try {
    require(`${__hooks}/prof_comissao_lib.js`).sincronizarComissaoOs(
      e.app,
      e.record,
      null,
    );
  } catch (err) {
    console.error("[comissao] Erro ao sincronizar comissão (create, ignorado): " + err);
  }
  try {
    require(`${__hooks}/meta_capi_lib.js`).emitOsCapi(e.app, e.record, null);
  } catch (err) {
    console.error("[meta-capi] Erro CAPI (create, ignorado): " + err);
  }
}, "ordens_servico");
