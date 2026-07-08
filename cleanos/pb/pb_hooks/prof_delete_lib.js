/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — exclusão segura de profissional (prof_delete_lib.js).
 *
 * Um "profissional" é um registro de `users` com `role = "profissional"` (NÃO há
 * coleção `profissionais`). Excluir um profissional hoje ESBARRA na relation
 * obrigatória `disponibilidade.profissional` (required=true, cascadeDelete=false):
 * o PocketBase RECUSA apagar o usuário enquanto existir uma disponibilidade
 * apontando pra ele. Além disso, apagar um profissional que ainda tem OS em aberto
 * (atribuída e não finalizada) é um erro de negócio — a OS ficaria órfã.
 *
 * Este módulo (CommonJS, carregado via require() de dentro do handler — cada VM do
 * PocketBase é isolada, mesmo padrão de fin_saldo_lib.js / os_logic.js) concentra:
 *   1. BLOQUEIO: se o profissional tem OS "em aberto", a exclusão é abortada com
 *      uma mensagem clara em PT-BR.  ⚠️ Esse throw PRECISA acontecer ANTES de
 *      `e.next()` no handler — `e.next()` COMITA a exclusão e um throw posterior
 *      NÃO faz rollback (armadilha documentada em fin_saldo.pb.js).
 *   2. LIMPEZA: remove as `disponibilidade` do profissional (que, required=true &
 *      cascadeDelete=false, fariam o próprio `e.next()` FALHAR). Também roda ANTES
 *      de `e.next()`.
 *
 * Enum canônico de `ordens_servico.status` (migration 1700000001_init_collections):
 *   ["agendada", "atribuida", "em_andamento", "concluida", "cancelada"]
 * "Encerradas" = concluida | cancelada. "Em aberto" = as demais (agendada,
 * atribuida, em_andamento) — atribuídas ao profissional e ainda não finalizadas.
 *
 * Outras relations que apontam pra `users` e o que acontece ao excluir o
 * profissional (enumeradas no schema de produção):
 *   - disponibilidade.profissional (required=true,  cascade=false) → BLOQUEARIA →
 *     tratada aqui (LIMPEZA).
 *   - ordens_servico.profissional  (required=false, cascade=false) → o PB apenas
 *     ESVAZIA a referência nas OS encerradas (não bloqueia); OS em aberto já são
 *     barradas pelo BLOQUEIO acima.
 *   - os_evidencias.enviado_por    (required=false, cascade=false) → PB esvazia.
 *   - push_tokens.usuario          (required=true,  cascade=true)  → PB apaga junto.
 */

/** Status de OS que contam como ENCERRADAS (não bloqueiam a exclusão). */
const STATUS_ENCERRADOS = ["concluida", "cancelada"];

/** true se o registro de `users` é um profissional (role === "profissional"). */
function isProfissional(rec) {
  return !!rec && String(rec.get("role") || "") === "profissional";
}

/**
 * OS "em aberto" atribuídas a este profissional: `profissional = id` e status
 * NÃO encerrado (agendada | atribuida | em_andamento). Retorna o array de
 * registros (vazio = nenhuma). Cap de 500 é folga — só serve pra decidir o bloqueio
 * e informar a quantidade; a existência (length > 0) é o que importa.
 */
function ordensEmAberto(app, profId) {
  const id = String(profId || "");
  if (!id) return [];
  return app.findRecordsByFilter(
    "ordens_servico",
    "profissional = {:pid} && status != 'concluida' && status != 'cancelada'",
    "-created",
    500,
    0,
    { pid: id }
  );
}

/** Mensagem de bloqueio (PT-BR) — nomeia POR QUE a exclusão foi recusada. */
function mensagemBloqueio(n) {
  const alvo = n === 1
    ? "uma ordem de serviço em aberto"
    : n + " ordens de serviço em aberto";
  const pron = n === 1 ? "essa ordem" : "essas ordens";
  return "Não é possível excluir este profissional: ele possui " + alvo +
    " (não concluída/cancelada). Conclua ou cancele " + pron +
    " de serviço antes de excluir o profissional.";
}

/**
 * Remove as `disponibilidade` do profissional ANTES da exclusão do usuário.
 * Sem isso, `e.next()` falharia (required=true & cascadeDelete=false). A unicidade
 * garante 0..1 registro, mas o loop é seguro pra qualquer quantidade.
 * Retorna quantos registros foram removidos.
 */
function limparReferencias(app, profId) {
  const id = String(profId || "");
  if (!id) return 0;
  const disps = app.findRecordsByFilter(
    "disponibilidade",
    "profissional = {:pid}",
    "",
    500,
    0,
    { pid: id }
  );
  let removidos = 0;
  for (const d of disps) {
    if (!d) continue;
    app.delete(d);
    removidos++;
  }
  return removidos;
}

/**
 * Orquestra a exclusão segura de um profissional na ordem correta em relação ao
 * `next` (que COMITA a exclusão). Chamada pelo handler onRecordDelete (prof_delete.pb.js).
 *
 *   - `record` não é profissional → `next()` (comportamento padrão) e retorna.
 *   - profissional COM OS em aberto → lança BadRequestError ANTES de `next()`
 *     (bloqueia; nada é apagado).
 *   - profissional SEM OS em aberto → limpa `disponibilidade` ANTES de `next()`
 *     (senão o próprio delete falharia) e então `next()` apaga o usuário.
 *
 * `next` é injetado (e.next no handler) pra manter esta função testável fora do PB.
 */
function handleDelete(app, record, next) {
  if (!isProfissional(record)) {
    next();
    return;
  }
  const profId = record.id;

  const abertas = ordensEmAberto(app, profId);
  if (abertas.length > 0) {
    throw new BadRequestError(mensagemBloqueio(abertas.length));
  }

  limparReferencias(app, profId);
  next();
}

module.exports = {
  STATUS_ENCERRADOS,
  isProfissional,
  ordensEmAberto,
  mensagemBloqueio,
  limparReferencias,
  handleDelete,
};
