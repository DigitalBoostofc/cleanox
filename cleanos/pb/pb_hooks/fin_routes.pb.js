/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — rotas de mutação de SALDO de contas (módulo Financeiro).
 *
 * IMPORTANTE: cada handler de routerAdd roda numa VM isolada do PocketBase —
 * requer os helpers via require() DENTRO do handler (mesmo padrão de
 * whatsapp_routes.pb.js / ratings_routes.pb.js).
 *
 * Rotas restritas a admin/gerente (COFRE_FIN — o mesmo escopo das collection
 * rules de fin_* na migration 14) via $apis.requireAuth() + requireAdminOrGerente.
 *
 * F-220 — SALDO ATÔMICO SERVER-SIDE:
 * O ajuste de saldo saiu do painel (read-modify-write em 2 chamadas REST, com
 * janela de lost-update vs. o incremento concorrente do hook OS→Financeiro) e
 * passou para o SERVIDOR, dentro de `$app.runInTransaction`: a leitura do saldo
 * FRESCO e a gravação do delta acontecem na MESMA transação DB, sem janela entre
 * ler e escrever — espelha o padrão atômico já usado no hook (F-221).
 */

// ── POST /api/cleanos/contas/ajustar ─────────────────────────────────────────
// Body: { contaId, delta }. Aplica `delta` ao saldo_atual da conta de forma
// atômica (lê o saldo fresco DENTRO da transação e soma o delta). Usado pelo
// painel para editar conta e pelos CRUDs de lançamento (efeito incremental).
routerAdd("POST", "/api/cleanos/contas/ajustar", (e) => {
  const h = require(`${__hooks}/whatsapp_helpers.js`);
  h.requireAdminOrGerente(e);

  const body    = e.requestInfo().body || {};
  const contaId = String(body.contaId || "");
  const delta   = Number(body.delta);
  if (!contaId)        throw new BadRequestError("contaId é obrigatório.");
  if (!isFinite(delta)) throw new BadRequestError("delta inválido.");

  let saldoAtual = 0;
  $app.runInTransaction((txApp) => {
    const conta = txApp.findRecordById("fin_contas", contaId); // lança 404 se ausente
    saldoAtual = Number(conta.get("saldo_atual") || 0) + delta;
    conta.set("saldo_atual", saldoAtual);
    txApp.save(conta);
  });

  return e.json(200, { id: contaId, saldoAtual: saldoAtual });
}, $apis.requireAuth());

// ── POST /api/cleanos/contas/transferir ──────────────────────────────────────
// Body: { de, para, valor }. Debita `valor` da origem e credita na destino na
// MESMA transação (−valor/+valor), lendo os dois saldos frescos dentro dela —
// all-or-nothing, sem janela de lost-update e sem necessidade de rollback manual.
routerAdd("POST", "/api/cleanos/contas/transferir", (e) => {
  const h = require(`${__hooks}/whatsapp_helpers.js`);
  h.requireAdminOrGerente(e);

  const body  = e.requestInfo().body || {};
  const de    = String(body.de || "");
  const para  = String(body.para || "");
  const valor = Number(body.valor);
  if (!de || !para)                 throw new BadRequestError("Contas de origem e destino são obrigatórias.");
  if (de === para)                  throw new BadRequestError("Origem e destino devem ser diferentes.");
  if (!isFinite(valor) || valor <= 0) throw new BadRequestError("Valor deve ser maior que zero.");

  let saldoDe = 0, saldoPara = 0;
  $app.runInTransaction((txApp) => {
    const cDe   = txApp.findRecordById("fin_contas", de);   // lança 404 se ausente
    const cPara = txApp.findRecordById("fin_contas", para); // lança 404 se ausente
    saldoDe   = Number(cDe.get("saldo_atual")   || 0) - valor;
    saldoPara = Number(cPara.get("saldo_atual") || 0) + valor;
    cDe.set("saldo_atual", saldoDe);
    cPara.set("saldo_atual", saldoPara);
    txApp.save(cDe);
    txApp.save(cPara);
  });

  return e.json(200, {
    de:   { id: de,   saldoAtual: saldoDe },
    para: { id: para, saldoAtual: saldoPara },
  });
}, $apis.requireAuth());
