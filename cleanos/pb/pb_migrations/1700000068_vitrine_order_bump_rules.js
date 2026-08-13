/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — regras E/OU nos order bumps da Vitrine.
 * Estende gatilho_tipo: qualquer_grupo | todos_grupos | qualquer_servico | todos_servicos.
 */
migrate(
  (app) => {
    let col = null;
    try {
      col = app.findCollectionByNameOrId("vitrine_order_bumps");
    } catch (_) {
      try {
        col = app.findCollectionByNameOrId("vitrinebumps00001");
      } catch (__) {
        return;
      }
    }
    if (!col) return;

    const field = col.fields.getByName("gatilho_tipo");
    if (!field) return;

    // SelectField.values no PB 0.22+
    const wanted = [
      "qualquer_grupo",
      "todos_grupos",
      "qualquer_servico",
      "todos_servicos",
    ];
    try {
      field.values = wanted;
      app.save(col);
    } catch (e) {
      // Fallback: recria campo se a API exigir
      try {
        const id = field.id;
        col.fields.removeById(id);
        col.fields.add(
          new SelectField({
            name: "gatilho_tipo",
            required: true,
            maxSelect: 1,
            values: wanted,
          }),
        );
        app.save(col);
      } catch (_) {}
    }
  },
  (app) => {
    // sem down destrutivo
  },
);
