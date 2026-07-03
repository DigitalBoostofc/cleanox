/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — rotas transacionais do Financeiro (fin_routes.pb.js).
 *
 * Endpoints que mutam saldo de forma ATÔMICA e transacional, para a tela de
 * Carteiras (ajuste manual) e transferência entre contas. Espelham o padrão
 * routerAdd + $apis.requireAuth() + checagem de papel + runInTransaction dos
 * outros arquivos de rota (whatsapp_routes / ratings_routes).
 *
 * Auth: usuário PocketBase autenticado com papel admin OU gerente (o cofre
 * financeiro — COFRE_FIN — é admin/gerente). A mutação de saldo usa incremento
 * atômico em SQL (ver fin_saldo_lib.js), NUNCA read-then-write da aplicação.
 *
 * Sem PII: as respostas trazem só ids de conta e saldos (nenhum dado de cliente).
 *
 * NOTA JSVM: cada handler roda numa VM isolada que NÃO enxerga o escopo do
 * arquivo — por isso a checagem de auth (assertFinAuth) mora no módulo
 * fin_saldo_lib.js e é chamada via require() DENTRO de cada handler.
 */

// ── POST /api/cleanos/fin/conta/{id}/ajuste  { delta }  ou  { novoSaldo } ─────
// Ajuste manual do saldo de uma conta. Corpo aceita `delta` (incremento) OU
// `novoSaldo` (convertido para delta lendo o saldo DENTRO da transação).
routerAdd("POST", "/api/cleanos/fin/conta/{id}/ajuste", (e) => {
  const lib = require(`${__hooks}/fin_saldo_lib.js`);
  lib.assertFinAuth(e);
  const contaId = e.request.pathValue("id");
  const body = e.requestInfo().body || {};
  if (body.delta == null && body.novoSaldo == null) {
    throw new BadRequestError("Informe 'delta' ou 'novoSaldo'.");
  }

  let novoSaldo;
  $app.runInTransaction((txApp) => {
    novoSaldo = lib.ajusteConta(txApp, contaId, {
      delta: body.delta,
      novoSaldo: body.novoSaldo,
    });
  });

  return e.json(200, { ok: true, conta_id: String(contaId), saldo_atual: novoSaldo });
}, $apis.requireAuth());

// ── POST /api/cleanos/fin/transferencia  { from, to, valor } ─────────────────
// Débito na origem + crédito no destino na MESMA transação (incremento atômico).
// Se qualquer passo falhar, NADA é aplicado (sem a janela do rollback client-side).
routerAdd("POST", "/api/cleanos/fin/transferencia", (e) => {
  const lib = require(`${__hooks}/fin_saldo_lib.js`);
  lib.assertFinAuth(e);
  const body = e.requestInfo().body || {};

  let out;
  $app.runInTransaction((txApp) => {
    out = lib.transferir(txApp, body.from, body.to, body.valor);
  });

  return e.json(200, {
    ok: true,
    from: { conta_id: String(body.from), saldo_atual: out.fromSaldo },
    to: { conta_id: String(body.to), saldo_atual: out.toSaldo },
  });
}, $apis.requireAuth());
