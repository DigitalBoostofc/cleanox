/// <reference path="../pb_data/types.d.ts" />

/**
 * Profissional pode atualizar a própria tarefa (status).
 * Create/delete continuam só admin/gerente.
 */
migrate(
  (app) => {
    let col;
    try {
      col = app.findCollectionByNameOrId("agenda_compromissos");
    } catch (_) {
      return;
    }
    const COFRE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';
    const DONO =
      '(@request.auth.role = "profissional" || @request.auth.roles ?= "profissional")' +
      ' && profissional = @request.auth.id';
    col.updateRule = COFRE + " || (" + DONO + ")";
    app.save(col);
  },
  (app) => {
    // no destructive down
  },
);
