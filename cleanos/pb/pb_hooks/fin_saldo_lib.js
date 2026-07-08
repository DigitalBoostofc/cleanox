/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — integridade de saldo server-side (fin_saldo_lib.js).
 *
 * FONTE ÚNICA de mutação de `fin_contas.saldo_atual`. Módulo CommonJS carregado
 * via require() de dentro dos handlers (cada VM do PocketBase é isolada — mesmo
 * padrão de os_logic.js / os_financeiro_lib.js).
 *
 * PRINCÍPIO (dinheiro real): o saldo NUNCA é gravado por read-then-write da
 * aplicação (que perde updates concorrentes — o lost-update do cliente Flutter).
 * Em vez disso, é SEMPRE mutado por um INCREMENTO ATÔMICO em SQL:
 *
 *     UPDATE fin_contas SET saldo_atual = ROUND(saldo_atual + {delta}, 2) ...
 *
 * Um único statement UPDATE lê-e-escreve sob o lock da linha — dois incrementos
 * concorrentes SOMAM corretamente (não há janela de lost-update). O ROUND(...,2)
 * mantém o saldo exato até o centavo (espelha a soma em centavos do cliente B2),
 * evitando drift de ponto flutuante ao acumular deltas.
 *
 * RECONCILIAÇÃO (evita saldo em dobro): esta é a ÚNICA fonte que mexe no saldo a
 * partir de `fin_lancamentos`. O hook OS→Financeiro (os_financeiro_lib.js) agora
 * só CRIA o lançamento `via_os`; quando ele salva o lançamento, o hook de modelo
 * `onRecordCreate` de fin_lancamentos (fin_saldo.pb.js) dispara e credita o saldo
 * exatamente uma vez. Se o OS→Financeiro também mexesse no saldo, contaria em
 * dobro — por isso foi removido de lá.
 *
 * SALDO-ORPHAN → REVERTE (dinheiro real, sem meio-termo): se `incSaldo` afetar 0
 * linhas (conta_id inexistente — relations do PB nem sempre têm FK SQL forçada),
 * o crédito/estorno NÃO pegou. Antes isso era best-effort (só logava um warn) e o
 * lançamento persistia SEM ajuste de saldo — um sub-crédito silencioso. Agora
 * `applyCreate/Update/Delete` LOGAM em nível ALTO e **lançam**: como estes
 * aplicadores rodam DENTRO da transação do hook de modelo (via `e.app`), o throw
 * propaga e a operação inteira faz ROLLBACK (o lançamento nem chega a existir).
 * Nada de saldo em conta fantasma; o erro sobe ao cliente para correção. Reverter
 * > orfanar. (Os endpoints /fin/* já revertiam via BadRequestError em ajusteConta.)
 */

/**
 * Efeito de um lançamento no saldo da conta — espelha `efeitoNoSaldo` do Flutter
 * (fin_derivations.dart): só lançamentos PAGOS mexem no saldo; receita soma,
 * despesa subtrai. Pendente/previsto/em_atraso = 0.
 */
function efeito(rec) {
  if (!rec) return 0;
  if (String(rec.get("status") || "") !== "pago") return 0;
  const valor = Number(rec.get("valor") || 0);
  if (!isFinite(valor)) return 0;
  return String(rec.get("tipo") || "") === "receita" ? valor : -valor;
}

/** Normaliza uma relation (single) para id string — trata array/null (goja). */
function relId(v) {
  if (v == null) return "";
  if (Array.isArray(v)) return v.length ? String(v[0]) : "";
  return String(v);
}

/** Snapshot dos campos relevantes de um lançamento (valores puros, estáveis
 *  ANTES de um e.next() que persiste/apaga o registro). Inclui o `id` do
 *  lançamento para permitir sinalizar reconciliação por lançamento. */
function snapshot(rec) {
  return { id: String(rec.id || ""), contaId: relId(rec.get("conta_id")), efeito: efeito(rec) };
}

/**
 * SALDO-ORPHAN: um ajuste de saldo que NÃO afetou linha alguma (delta não-nulo,
 * 0 linhas) — quase sempre conta_id inexistente (relation sem FK SQL forçada).
 * Loga em nível ALTO (logger estruturado + console, garantia) e LANÇA: rodando
 * dentro da transação do hook de modelo, o throw força o ROLLBACK da operação
 * inteira, então o lançamento não persiste sem o crédito/estorno correspondente.
 */
function failNoRows(app, kind, lancId, contaId, delta) {
  const msg =
    "[fin_saldo][SALDO-ORPHAN] incSaldo afetou 0 linhas (" + kind + "): " +
    "lancamento=" + (lancId || "?") + " conta=" + (contaId || "?") +
    " delta=" + delta + " — conta inexistente/relation quebrada. Operação " +
    "REVERTIDA (rollback) para não persistir lançamento sem ajuste de saldo.";
  try { app.logger().error(msg); } catch (_) {}
  console.error(msg);
  throw new BadRequestError(
    "Conta '" + (contaId || "?") + "' não encontrada ao ajustar o saldo; operação revertida."
  );
}

/** Aplica um incremento e REVERTE (throw) se um delta não-nulo não afetou linha
 *  alguma. Espelha o guard de ajusteConta (rowsAffected==0 && delta!=0 → erro). */
function incSaldoOrThrow(app, kind, lancId, contaId, delta) {
  const affected = incSaldo(app, contaId, delta);
  if (affected === 0 && Math.round(Number(delta) * 100) !== 0) {
    failNoRows(app, kind, lancId, contaId, delta);
  }
  return affected;
}

/**
 * INCREMENTO ATÔMICO do saldo de UMA conta. `app` deve ser o app da transação
 * corrente quando chamado dentro de runInTransaction (para compor com outros
 * incrementos atomicamente). Um único UPDATE — nunca read-then-write.
 *
 * Retorna o nº de linhas afetadas (0 = conta inexistente → caller decide).
 */
function incSaldo(app, contaId, delta) {
  const id = String(contaId || "");
  if (!id) return 0;
  // Soma em centavos inteiros para decidir no-op sem drift; o UPDATE em si
  // arredonda a 2 casas (ROUND) mantendo o saldo exato ao centavo.
  const cents = Math.round(Number(delta) * 100);
  if (!cents) return 0; // delta nulo → nada a fazer
  const now = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
  const res = app.db()
    .newQuery(
      "UPDATE fin_contas SET saldo_atual = ROUND(COALESCE(saldo_atual, 0) + {:delta}, 2), updated = {:now} WHERE id = {:id}"
    )
    .bind({ delta: cents / 100, now: now, id: id })
    .execute();
  return res.rowsAffected();
}

/** Lê o saldo_atual corrente de uma conta (para conversão novoSaldo→delta e
 *  respostas de endpoint). Lança se a conta não existir. */
function saldoAtual(app, contaId) {
  const conta = app.findRecordById("fin_contas", String(contaId));
  return Number(conta.get("saldo_atual") || 0);
}

/* ─────────────────────────── Aplicadores (model hooks) ─────────────────────── */

/** CREATE de lançamento: aplica o efeito (se pago). Chamar APÓS e.next(). */
function applyCreate(app, rec) {
  const s = snapshot(rec);
  if (s.efeito !== 0) incSaldoOrThrow(app, "create", s.id, s.contaId, s.efeito);
}

/**
 * UPDATE de lançamento: estorna o efeito antigo e aplica o novo. Trata troca de
 * conta e mudança de status (pendente↔pago). `before` é o snapshot do original
 * (capturado ANTES de e.next()); `rec` é o registro já atualizado.
 * Quando há troca de conta, os dois incrementos rodam na MESMA transação.
 */
function applyUpdate(app, before, rec) {
  const after = snapshot(rec);
  if (before.contaId === after.contaId) {
    const delta = after.efeito - before.efeito;
    if (delta !== 0) incSaldoOrThrow(app, "update", after.id, after.contaId, delta);
    return;
  }
  // Troca de conta: estorna na antiga + aplica na nova, atomicamente. Um throw
  // de incSaldoOrThrow reverte esta runInTransaction E propaga p/ o hook de
  // modelo, revertendo a operação inteira (conta antiga/nova inconsistente).
  app.runInTransaction((txApp) => {
    if (before.efeito !== 0) incSaldoOrThrow(txApp, "update-estorno", after.id, before.contaId, -before.efeito);
    if (after.efeito !== 0) incSaldoOrThrow(txApp, "update-aplica", after.id, after.contaId, after.efeito);
  });
}

/** DELETE de lançamento: estorna o efeito. `before` é o snapshot capturado
 *  ANTES de e.next() apagar o registro. */
function applyDelete(app, before) {
  if (before.efeito !== 0) incSaldoOrThrow(app, "delete", before.id, before.contaId, -before.efeito);
}

/* ─────────────────────────── Operações de endpoint ─────────────────────────── */

/**
 * Autorização das rotas do financeiro: exige usuário autenticado com papel
 * admin OU gerente (o COFRE_FIN das regras de coleção). Definida aqui (e não no
 * escopo do arquivo de rotas) porque cada handler roda numa VM isolada que NÃO
 * enxerga o escopo do arquivo — só o que é importado via require(). Lança
 * UnauthorizedError (401) / ForbiddenError (403), globais do PocketBase.
 */
function assertFinAuth(e) {
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  const role = String(e.auth.get("role") || "");
  if (role !== "admin" && role !== "gerente") {
    throw new ForbiddenError("Rota exclusiva para admin/gerente (cofre financeiro).");
  }
}

/**
 * Ajuste manual de saldo de uma conta. Aceita `delta` (incremento direto) OU
 * `novoSaldo` (converte para delta lendo o saldo DENTRO da transação — sem
 * janela de lost-update). Retorna o novo saldo. Lança BadRequestError/
 * 404 (findRecordById) conforme o caso. `app` é o app da transação.
 */
function ajusteConta(app, contaId, opts) {
  const id = String(contaId || "");
  if (!id) throw new BadRequestError("conta inválida.");
  let delta;
  if (opts && opts.delta != null) {
    delta = Number(opts.delta);
  } else if (opts && opts.novoSaldo != null) {
    const atual = saldoAtual(app, id); // 404 se a conta não existir
    delta = Number(opts.novoSaldo) - atual;
  } else {
    throw new BadRequestError("Informe 'delta' ou 'novoSaldo'.");
  }
  if (!isFinite(delta)) throw new BadRequestError("Valor de ajuste inválido.");
  const affected = incSaldo(app, id, delta);
  if (affected === 0 && Math.round(delta * 100) !== 0) {
    // delta não-nulo mas nenhuma linha mudou → conta inexistente.
    throw new BadRequestError("Conta '" + id + "' não encontrada.");
  }
  return saldoAtual(app, id);
}

/**
 * Transferência entre contas: débito na origem + crédito no destino na MESMA
 * transação, ambos por incremento atômico. Sem a janela de inconsistência do
 * rollback client-side (débito comita, crédito falha). `app` é o app da
 * transação. Retorna { fromSaldo, toSaldo }.
 */
function transferir(app, fromId, toId, valor) {
  const from = String(fromId || "");
  const to = String(toId || "");
  const v = Number(valor);
  if (!from || !to) throw new BadRequestError("Informe 'from' e 'to'.");
  if (from === to) throw new BadRequestError("Origem e destino são iguais.");
  if (!isFinite(v) || v <= 0) throw new BadRequestError("'valor' deve ser > 0.");
  // Valida existência das duas contas ANTES de mexer (404 → nada é debitado).
  saldoAtual(app, from);
  saldoAtual(app, to);
  incSaldo(app, from, -v);
  incSaldo(app, to, v);
  return { fromSaldo: saldoAtual(app, from), toSaldo: saldoAtual(app, to) };
}

module.exports = {
  efeito,
  relId,
  snapshot,
  incSaldo,
  saldoAtual,
  applyCreate,
  applyUpdate,
  applyDelete,
  assertFinAuth,
  ajusteConta,
  transferir,
};
