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
  e.next(); // persiste o lançamento (comita)
  try {
    require(`${__hooks}/fin_saldo_lib.js`).applyCreate(e.app, e.record);
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
  e.next(); // apaga o lançamento
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
