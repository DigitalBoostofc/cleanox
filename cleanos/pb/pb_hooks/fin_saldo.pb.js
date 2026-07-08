/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — hooks de integridade de saldo (fin_saldo.pb.js).
 *
 * Registra os hooks de MODELO em `fin_lancamentos` que ajustam o saldo da conta
 * de forma atômica (fonte única — ver fin_saldo_lib.js) e o guard de REQUEST em
 * `fin_contas` que impede o cliente de gravar `saldo_atual` diretamente.
 *
 * Semântica de transação (verificada empiricamente neste binário):
 *   - `e.next()` PERSISTE o registro na sua própria transação e comita ali; uma
 *     exceção DEPOIS de e.next() NÃO faz rollback. Envolver e.next() em
 *     runInTransaction DEADLOCKA (e.next() gerencia a própria conexão).
 *   - Por isso: chamamos `e.next()` primeiro (persiste o lançamento) e SÓ ENTÃO
 *     mutamos o saldo. Se o persist falhar, e.next() lança e o saldo não muda
 *     (consistente). O incremento em si é um UPDATE por PK numa conta garantida
 *     pela FK obrigatória `conta_id` — praticamente infalível. Casos multi-conta
 *     (troca de conta) rodam os dois incrementos numa runInTransaction própria.
 */

// ── CREATE: aplica o efeito do lançamento (se pago) ──────────────────────────
onRecordCreate((e) => {
  const lib = require(`${__hooks}/fin_saldo_lib.js`);
  // Pré-validação ANTES de e.next(): se o lançamento vai mexer no saldo, a
  // conta_id PRECISA existir. Um throw aqui aborta o save antes de qualquer
  // persist — nada fica órfão e nada de "revert" mentiroso pós-commit (D2-001).
  lib.assertCreateResolves(e.app, e.record);
  e.next(); // persiste o lançamento (comita)
  try {
    lib.applyCreate(e.app, e.record);
  } catch (err) {
    // Falha ao ajustar o saldo de um lançamento JÁ persistido (dinheiro): loga
    // ALTO e relança para o cliente ver o erro e reconciliar (não engole).
    console.error("[fin_saldo] Falha ao aplicar saldo no create do lançamento " + e.record.id + ": " + err);
    throw err;
  }
}, "fin_lancamentos");

// ── UPDATE: estorna o efeito antigo + aplica o novo (trata troca de conta) ────
onRecordUpdate((e) => {
  const lib = require(`${__hooks}/fin_saldo_lib.js`);
  // Snapshot do ORIGINAL capturado ANTES de e.next() (que sobrescreve o registro).
  const orig = e.record.original ? e.record.original() : null;
  const before = orig ? lib.snapshot(orig) : { contaId: "", efeito: 0 };
  // Pré-validação ANTES de e.next(): toda conta que sofrerá incremento não-nulo
  // (destino, e a antiga no caso de troca de conta) precisa existir. Aborta o
  // save antes de persistir se cairia num saldo-orphan (D2-001).
  lib.assertUpdateResolves(e.app, before, e.record);
  e.next(); // persiste a atualização
  try {
    lib.applyUpdate(e.app, before, e.record);
  } catch (err) {
    console.error("[fin_saldo] Falha ao aplicar saldo no update do lançamento " + e.record.id + ": " + err);
    throw err;
  }
}, "fin_lancamentos");

// ── DELETE: estorna o efeito do lançamento removido ──────────────────────────
onRecordDelete((e) => {
  const lib = require(`${__hooks}/fin_saldo_lib.js`);
  const before = lib.snapshot(e.record); // ANTES de e.next() apagar
  // Pré-checa a conta ANTES de apagar. Ao contrário de create/update, aqui NÃO
  // abortamos se a conta sumiu: apagar um lançamento sempre deve ser possível e,
  // se a conta já não existe, não há saldo a estornar (D2-001 — sem throw pós-
  // commit mentindo "revertida"). Se a conta existe, o estorno roda normalmente.
  const precisaEstorno = before.efeito !== 0;
  const contaViva = precisaEstorno && lib.contaExiste(e.app, before.contaId);
  e.next(); // apaga o lançamento
  if (precisaEstorno && !contaViva) {
    console.error("[fin_saldo] delete do lançamento " + before.id + " com conta '" +
      before.contaId + "' inexistente — sem estorno de saldo (conta já removida).");
    return;
  }
  try {
    lib.applyDelete(e.app, before);
  } catch (err) {
    console.error("[fin_saldo] Falha ao estornar saldo no delete do lançamento " + e.record.id + ": " + err);
    throw err;
  }
}, "fin_lancamentos");

// ── GUARD: cliente NÃO pode gravar saldo_atual direto em fin_contas ──────────
// O saldo só é mutado pelo servidor (hooks acima + endpoints /fin/*). Uma
// tentativa de PATCH que mude `saldo_atual` é IGNORADA (reposta ao valor
// original) — o CRUD dos demais campos (nome, tipo, cor, ativo, padrao…) segue
// normal. Não travamos o CREATE: a abertura de conta com saldo inicial é
// legítima e não sofre lost-update. Os endpoints usam SQL direto (não passam
// por este hook de request), então continuam podendo ajustar o saldo.
onRecordUpdateRequest((e) => {
  const orig = e.record.original ? e.record.original() : null;
  if (orig) {
    const antes = Number(orig.get("saldo_atual") || 0);
    const depois = Number(e.record.get("saldo_atual") || 0);
    if (Math.round(antes * 100) !== Math.round(depois * 100)) {
      // Ignora a alteração do saldo pelo cliente — reconciliação é server-side.
      e.record.set("saldo_atual", antes);
    }
  }
  e.next();
}, "fin_contas");
