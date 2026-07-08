/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — hook de exclusão segura de profissional (prof_delete.pb.js).
 *
 * Registra o hook de MODELO `onRecordDelete` em `users`. Só altera o comportamento
 * de exclusão para registros com `role = "profissional"`; admin/gerente seguem o
 * fluxo padrão do PocketBase.
 *
 * Semântica de transação (ver header de fin_saldo.pb.js):
 *   - `e.next()` PERSISTE (aqui: APAGA o usuário) e comita na própria transação;
 *     um throw DEPOIS de e.next() NÃO faz rollback. Por isso TODA validação/bloqueio
 *     e TODA limpeza de referências rodam ANTES de e.next().
 *   - Ordem: (1) bloqueia se há OS em aberto → throw ANTES de e.next(); (2) limpa
 *     as disponibilidades (que, required=true & cascade=false, fariam e.next()
 *     FALHAR); (3) e.next() apaga o usuário.
 */
onRecordDelete((e) => {
  const lib = require(`${__hooks}/prof_delete_lib.js`);
  // Toda a lógica (bloqueio + limpeza + ordem em relação a e.next()) vive em
  // handleDelete, testável fora do PB. e.next é passado como callback pra que o
  // COMMIT aconteça só depois do bloqueio/limpeza (throw ANTES = rollback honesto).
  lib.handleDelete(e.app, e.record, () => e.next());
}, "users");
