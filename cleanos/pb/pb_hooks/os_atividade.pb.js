/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — hooks da coleção os_atividade (comentários internos + menções).
 *
 * Create via API: só admin/gerente, sempre tipo=comentario, autor=auth.
 * Notificações de @menção são criadas DEPOIS de e.next() (best-effort).
 */

// Guard + normalização no request (antes do save).
onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/os_atividade_lib.js`);
  lib.guardComentarioCreate(e);
  e.next();
}, "os_atividade");

// Bloqueia update/delete de alteração/sistema via API de forma extra
// (updateRule já é null; delete só admin — reforço no request).
onRecordUpdateRequest((e) => {
  throw new ForbiddenError("Atividade da OS é imutável.");
}, "os_atividade");

// Pós-create: notificações de menção.
onRecordCreate((e) => {
  const lib = require(`${__hooks}/os_atividade_lib.js`);
  const auth = e.auth;
  e.next();
  try {
    lib.afterComentarioCreate(e.app, e.record, auth);
  } catch (err) {
    console.error("[os_atividade] afterComentarioCreate (ignorado): " + err);
  }
}, "os_atividade");
