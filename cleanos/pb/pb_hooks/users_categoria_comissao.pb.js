/// <reference path="../pb_data/types.d.ts" />

/**
 * Ao criar/atualizar usuário com papel profissional via API, vincula
 * users.categoria_comissao em Equipe → nome (server-side).
 *
 * Semântica PB 0.39.4:
 *   - onRecordCreate/Update (modelo) rodam em QUALQUER $app.save — inclusive
 *     migrate/seed. 0002 cria profissionais ANTES de Equipe existir → quebra
 *     instalação limpa. Por isso esta regra é REQUEST, não modelo.
 *   - onRecordCreateRequest / onRecordUpdateRequest: só Flutter, Admin UI e API.
 *     Dá para preparar e.record antes de e.next() (docs oficiais).
 *   - e.next() persiste o usuário. Se falhar depois de CRIAR a sub nesta
 *     tentativa, o catch apaga só essa órfã (created===true). Sub reutilizada
 *     nunca é apagada. Sem AfterCreateError.
 */

onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/users_categoria_comissao_lib.js`);
  const created = lib.aplicarCategoriaNoCreate(e.app, e.record);
  try {
    e.next();
  } catch (err) {
    lib.compensarSubcategoriaOrfa(e.app, created);
    throw err;
  }
}, "users");

onRecordUpdateRequest((e) => {
  const lib = require(`${__hooks}/users_categoria_comissao_lib.js`);
  const created = lib.aplicarCategoriaNoUpdate(e.app, e.record);
  try {
    e.next();
  } catch (err) {
    lib.compensarSubcategoriaOrfa(e.app, created);
    throw err;
  }
}, "users");
