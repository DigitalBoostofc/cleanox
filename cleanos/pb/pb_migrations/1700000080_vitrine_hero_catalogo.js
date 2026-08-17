/// <reference path="../pb_data/types.d.ts" />

/**
 * JSON do cabeçalho navy da estética automotiva
 * (texto + posição). Aditivo.
 */
migrate(
  (app) => {
    let config = null;
    try {
      config = app.findCollectionByNameOrId("vitrine_config");
    } catch (_) {
      config = app.findCollectionByNameOrId("vitrineconfig0001");
    }
    if (!config) return;

    if (!config.fields.getByName("hero_catalogo_json")) {
      config.fields.add(
        new TextField({
          name: "hero_catalogo_json",
          required: false,
          max: 800,
        }),
      );
      app.save(config);
    }
  },
  (app) => {
    let config = null;
    try {
      config = app.findCollectionByNameOrId("vitrine_config");
    } catch (_) {
      config = app.findCollectionByNameOrId("vitrineconfig0001");
    }
    if (!config) return;
    const field = config.fields.getByName("hero_catalogo_json");
    if (field) {
      config.fields.removeById(field.id);
      app.save(config);
    }
  },
);
