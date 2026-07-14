/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — F-231: comissão paga vira despesa (e desmarcar estorna).
 *
 * Lógica em `prof_comissao_pago_lib.js`. Aqui só os hooks de modelo.
 *
 * ── R3 (e.next() COMMITA) ───────────────────────────────────────────────────
 * O status ORIGINAL é capturado ANTES do e.next() e passado explicitamente:
 * depois do commit, `record.original()` já reflete o estado NOVO e a transição
 * "pendente → paga" seria indetectável. Mesmo padrão de os_financeiro.pb.js.
 *
 * O efeito colateral (criar/apagar o lançamento) vem DEPOIS do e.next(), em
 * try/catch: marcar como paga não pode falhar por causa do financeiro, e um
 * throw depois do e.next() não faria rollback mesmo.
 */

// ── CREATE: comissão que JÁ NASCE paga também vira despesa ──────────────────
//
// O fluxo normal cria como "pendente" (prof_comissao_lib.js), então este caminho
// é raro — mas sem ele um registro criado direto com status "paga" (import,
// correção manual, API) debitava nada e o saldo voltava a inflar. Buraco achado
// testando o F-225 no PB de verdade, não por leitura de código.
onRecordCreate((e) => {
  e.next(); // persiste a comissão

  if (String(e.record.get("status") || "") !== "paga") return;
  try {
    require(`${__hooks}/prof_comissao_pago_lib.js`).sincronizarLancamento(
      e.app,
      e.record,
      "pendente", // "veio de pendente" → força a criação da despesa
    );
  } catch (err) {
    console.error("[comissao-pago] erro no create (ignorado): " + err);
  }
}, "prof_comissoes");

// ── UPDATE: pendente → paga cria a despesa; paga → pendente estorna ──────────
onRecordUpdate((e) => {
  const orig = e.record.original ? e.record.original() : null;
  const origStatus = orig ? String(orig.get("status") || "") : "";

  e.next(); // commita a troca de status da comissão

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

// ── DELETE: apagar uma comissão PAGA não pode deixar a despesa órfã ──────────
//
// Sem isto, excluir uma comissão já paga deixaria o lançamento de despesa vivo,
// apontando pra uma comissão que não existe mais — e o saldo continuaria
// debitado por uma comissão fantasma.
onRecordDelete((e) => {
  const comissaoId = e.record.id;
  const eraPaga = String(e.record.get("status") || "") === "paga";

  e.next(); // commita a exclusão da comissão

  if (!eraPaga) return;
  try {
    require(`${__hooks}/prof_comissao_pago_lib.js`).apagarLancamentoDaComissao(
      e.app,
      comissaoId,
    );
  } catch (err) {
    console.error("[comissao-pago] erro no delete (ignorado): " + err);
  }
}, "prof_comissoes");
