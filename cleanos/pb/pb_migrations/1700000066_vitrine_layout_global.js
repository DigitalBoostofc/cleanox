/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — layout global controlado da Vitrine.
 *
 * Aditiva: mantém rascunho e snapshot publicado separados no singleton
 * vitrine_config. O hook fornece defaults para registros antigos/vazios.
 */
migrate(
  (app) => {
    let config = null;
    try {
      config = app.findCollectionByNameOrId("vitrine_config");
    } catch (_) {
      config = app.findCollectionByNameOrId("vitrineconfig0001");
    }

    if (!config.fields.getByName("layout_rascunho")) {
      config.fields.add(
        new JSONField({ name: "layout_rascunho", required: false }),
      );
    }
    if (!config.fields.getByName("layout_publicado")) {
      config.fields.add(
        new JSONField({ name: "layout_publicado", required: false }),
      );
    }
    app.save(config);
  },
  (app) => {
    let config = null;
    try {
      config = app.findCollectionByNameOrId("vitrine_config");
    } catch (_) {
      config = app.findCollectionByNameOrId("vitrineconfig0001");
    }
    for (const name of ["layout_rascunho", "layout_publicado"]) {
      const field = config.fields.getByName(name);
      if (field) config.fields.removeById(field.id);
    }
    app.save(config);
  },
);
