/// <reference path="../pb_data/types.d.ts" />

/**
 * Tarefa da agenda: vários profissionais no mesmo campo `profissional`.
 * Profissional vê/edita se estiver na lista.
 */
migrate(
  (app) => {
    let col;
    try {
      col = app.findCollectionByNameOrId("agenda_compromissos");
    } catch (_) {
      return;
    }
    const field = col.fields.getByName("profissional");
    if (field) {
      field.maxSelect = 20;
      field.required = true;
    }
    const COFRE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';
    const NA_TAREFA =
      '(@request.auth.role = "profissional" || @request.auth.roles ?= "profissional")' +
      ' && profissional.id ?= @request.auth.id';
    col.listRule = COFRE + " || (" + NA_TAREFA + ")";
    col.viewRule = col.listRule;
    col.updateRule = COFRE + " || (" + NA_TAREFA + ")";
    app.save(col);
  },
  (app) => {
    // no destructive down
  },
);
