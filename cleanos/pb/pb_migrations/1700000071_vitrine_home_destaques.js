/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — textos da seção de destaques/promoções na home da Vitrine.
 */
migrate(
  (app) => {
    let config = null;
    try {
      config = app.findCollectionByNameOrId("vitrine_config");
    } catch (_) {
      try {
        config = app.findCollectionByNameOrId("vitrineconfig0001");
      } catch (_) {
        return;
      }
    }
    if (!config) return;

    function addText(name, max) {
      if (config.fields.getByName(name)) return false;
      config.fields.add(
        new TextField({ name: name, required: false, max: max || 120 }),
      );
      return true;
    }

    let mudou = false;
    mudou = addText("home_destaques_titulo", 80) || mudou;
    mudou = addText("home_destaques_cta", 40) || mudou;
    if (mudou) app.save(config);

    try {
      const list = app.findRecordsByFilter("vitrine_config", "", "", 20, 0);
      for (let i = 0; i < (list || []).length; i++) {
        const r = list[i];
        let ch = false;
        if (!String(r.get("home_destaques_titulo") || "").trim()) {
          r.set("home_destaques_titulo", "Promoções da Semana");
          ch = true;
        }
        if (!String(r.get("home_destaques_cta") || "").trim()) {
          r.set("home_destaques_cta", "Ver todos");
          ch = true;
        }
        if (ch) app.save(r);
      }
    } catch (_) {}
  },
  (app) => {},
);
