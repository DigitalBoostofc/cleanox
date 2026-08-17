/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — liga/desliga da faixa Ofertas em destaque.
 * Aditiva: default true (faixa visível como no preview).
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

    if (!config.fields.getByName("home_destaques_ativo")) {
      config.fields.add(
        new BoolField({ name: "home_destaques_ativo", required: false }),
      );
      app.save(config);
    }

    try {
      const list = app.findRecordsByFilter("vitrine_config", "", "", 50, 0);
      for (let i = 0; i < list.length; i++) {
        const r = list[i];
        const v = r.get("home_destaques_ativo");
        if (v === null || v === undefined || v === "") {
          r.set("home_destaques_ativo", true);
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
    const field = config.fields.getByName("home_destaques_ativo");
    if (field) {
      config.fields.removeById(field.id);
      app.save(config);
    }
  },
);
