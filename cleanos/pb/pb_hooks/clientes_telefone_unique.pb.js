/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — unicidade de telefone em `clientes`.
 *
 * Impede criar (ou atualizar) um cliente com o mesmo número de celular de outro
 * já cadastrado. Comparação via `phonesMatch` (máscara, DDI 55, 9º dígito).
 *
 * Modelo (onRecordCreate/Update): roda em qualquer gravação (API, seed, admin).
 * Validar SEMPRE antes de `e.next()` (R3). require() da lib DENTRO do handler (R9).
 *
 * Mensagem estável para a UI:
 *   "Cliente já existente com este número de celular (Nome)."
 */

onRecordCreate((e) => {
  const lib = require(`${__hooks}/clientes_telefone_unique_lib.js`);
  lib.assertTelefoneUnico(e.app, e.record);
  e.next();
}, "clientes");

onRecordUpdate((e) => {
  const lib = require(`${__hooks}/clientes_telefone_unique_lib.js`);
  lib.assertTelefoneUnico(e.app, e.record);
  e.next();
}, "clientes");
