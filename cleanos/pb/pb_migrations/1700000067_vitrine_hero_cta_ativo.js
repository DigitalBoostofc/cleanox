/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — toggle do botão do hero na Vitrine (hero_cta_ativo).
 * Aditiva: default true (botão visível como hoje).
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

    if (!config.fields.getByName("hero_cta_ativo")) {
      config.fields.add(
        new BoolField({ name: "hero_cta_ativo", required: false }),
      );
      app.save(config);
    }

    try {
      const list = app.findRecordsByFilter("vitrine_config", "", "", 50, 0);
      for (let i = 0; i < list.length; i++) {
        const r = list[i];
        const v = r.get("hero_cta_ativo");
        if (v === null || v === undefined || v === "") {
          r.set("hero_cta_ativo", true);
          app.save(r);
        }
      }
    } catch (_) {}
  },
  (app) => {
    let config = null;
    try {
      config = app.findCollectionByNameOrId("vitrine_config");
    } catch (_) {
      config = app.findCollectionByNameOrId("vitrineconfig0001");
    }
    if (!config) return;
    const field = config.fields.getByName("hero_cta_ativo");
    if (field) {
      config.fields.removeById(field.id);
      app.save(config);
    }
  },
);
