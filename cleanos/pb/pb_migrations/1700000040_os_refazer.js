/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — etiqueta "Refazer" em OS reaberta a partir de concluída.
 * IDEMPOTENTE.
 */

migrate(
  (app) => {
    const os = app.findCollectionByNameOrId("ordens_servico");
    if (!os.fields.getByName("refazer")) {
      os.fields.add(new BoolField({ name: "refazer", required: false }));
      app.save(os);
    }
  },
  (app) => {
    const os = app.findCollectionByNameOrId("ordens_servico");
    const f = os.fields.getByName("refazer");
    if (f) {
      os.fields.removeById(f.id);
      app.save(os);
    }
  },
);
