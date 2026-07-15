/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — F-231 + ciclo dono 2026-07: comissão ↔ despesa via_comissao.
 *
 * Lógica em `prof_comissao_pago_lib.js`.
 *
 * ── R3 (e.next() COMMITA) ───────────────────────────────────────────────────
 * Status ORIGINAL capturado ANTES do e.next(); efeito DEPOIS, em try/catch.
 */

// CREATE: pendente → despesa pendente; paga → despesa paga
onRecordCreate((e) => {
  e.next();
  try {
    require(`${__hooks}/prof_comissao_pago_lib.js`).onComissaoCriada(
      e.app,
      e.record,
    );
  } catch (err) {
    console.error("[comissao-pago] erro no create (ignorado): " + err);
  }
}, "prof_comissoes");

// UPDATE: paga ↔ pendente sincroniza status da despesa (não apaga mais)
onRecordUpdate((e) => {
  const orig = e.record.original ? e.record.original() : null;
  const origStatus = orig ? String(orig.get("status") || "") : "";

  e.next();

  try {
    require(`${__hooks}/prof_comissao_pago_lib.js`).sincronizarLancamento(
      e.app,
      e.record,
      origStatus,
    );
  } catch (err) {
    console.error("[comissao-pago] erro no update (ignorado): " + err);
  }
}, "prof_comissoes");

// DELETE: remove a despesa ligada (paga ou pendente)
onRecordDelete((e) => {
  const comissaoId = e.record.id;
  e.next();
  try {
    require(`${__hooks}/prof_comissao_pago_lib.js`).apagarLancamentoDaComissao(
      e.app,
      comissaoId,
    );
  } catch (err) {
    console.error("[comissao-pago] erro no delete (ignorado): " + err);
  }
}, "prof_comissoes");
