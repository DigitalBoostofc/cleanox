/// <reference path="../pb_data/types.d.ts" />

/**
 * Ao criar/atualizar usuário com papel profissional, vincula
 * users.categoria_comissao em Equipe → nome (server-side).
 *
 * Semântica PB 0.39.4 (docs + fin_saldo.pb.js):
 *   - onRecordCreate BEFORE e.next(): valida e pode gravar a subcategoria.
 *   - e.next() persiste o usuário na própria transação e comita (R3).
 *   - e.next() dentro de runInTransaction deadlocka — não usamos.
 *   - Se o create do auth falhar depois de CRIAR a sub nesta tentativa,
 *     o catch de e.next() apaga só essa órfã (created:true). Sub reutilizada
 *     nunca é apagada. Sem onRecordAfterCreateError: ele não sabe se a sub
 *     nasceu agora e apagaria Equipe→nome pré-existente sem vínculo.
 */

onRecordCreate((e) => {
  const lib = require(`${__hooks}/users_categoria_comissao_lib.js`);
  const created = lib.aplicarCategoriaNoCreate(e.app, e.record);
  try {
    e.next();
  } catch (err) {
    lib.compensarSubcategoriaOrfa(e.app, created);
    throw err;
  }
}, "users");

onRecordUpdate((e) => {
  const lib = require(`${__hooks}/users_categoria_comissao_lib.js`);
  lib.aplicarCategoriaNoUpdate(e.app, e.record);
  e.next();
}, "users");
