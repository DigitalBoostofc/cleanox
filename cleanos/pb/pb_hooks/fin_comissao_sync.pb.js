/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — bidirecional despesa via_comissao → prof_comissoes.
 *
 * Quando o dono marca a comissão como paga/pendente pela mãozinha em
 * Movimentações (update de fin_lancamentos), espelha o status na Equipe.
 *
 * R3: snapshot do status ANTES de e.next(); efeito DEPOIS, best-effort.
 * Idempotente em prof_comissao_pago_lib (não regrava se já igual → sem loop).
 */

onRecordUpdate((e) => {
  const orig = e.record.original ? e.record.original() : null;
  const origStatus = orig ? String(orig.get("status") || "") : "";

  e.next();

  try {
    require(`${__hooks}/prof_comissao_pago_lib.js`).sincronizarComissaoDoLancamento(
      e.app,
      e.record,
      origStatus,
    );
  } catch (err) {
    console.error("[fin-comissao-sync] erro (ignorado): " + err);
  }
}, "fin_lancamentos");
