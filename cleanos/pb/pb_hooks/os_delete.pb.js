/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — hook de exclusão de OS (os_delete.pb.js).
 *
 * Registra o hook de MODELO `onRecordDelete` em `ordens_servico` — vale para a
 * API (painel Flutter, deleteRule ADMIN_GERENTE) e para a Admin UI.
 *
 * Toda a lógica (estorno da receita via_os, remoção de comissão + despesa, e a
 * ordem em relação a e.next()) vive em os_delete_lib.js, testável fora do PB.
 * e.next é passado como callback para que o COMMIT aconteça só depois da
 * limpeza (throw ANTES = rollback honesto; ver header do lib).
 */
onRecordDelete((e) => {
  const lib = require(`${__hooks}/os_delete_lib.js`);
  lib.handleDelete(e.app, e.record, () => e.next());
}, "ordens_servico");
