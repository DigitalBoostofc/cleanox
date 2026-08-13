/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — macros “O que você procura?” editáveis na Vitrine.
 * Títulos, subtítulos, ícones e ordem (automotiva primeiro por default).
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
        new TextField({ name: name, required: false, max: max || 200 }),
      );
      return true;
    }

    let mudou = false;
    if (!config.fields.getByName("macro_auto_primeiro")) {
      config.fields.add(
        new BoolField({ name: "macro_auto_primeiro", required: false }),
      );
      mudou = true;
    }
    mudou = addText("macro_resid_titulo", 80) || mudou;
    mudou = addText("macro_resid_subtitulo", 160) || mudou;
    mudou = addText("macro_resid_icone", 40) || mudou;
    mudou = addText("macro_auto_titulo", 80) || mudou;
    mudou = addText("macro_auto_subtitulo", 160) || mudou;
    mudou = addText("macro_auto_icone", 40) || mudou;
    if (mudou) app.save(config);

    // Defaults em registros existentes
    try {
      const list = app.findRecordsByFilter("vitrine_config", "", "", 20, 0);
      for (let i = 0; i < (list || []).length; i++) {
        const r = list[i];
        let ch = false;
        if (r.get("macro_auto_primeiro") == null || r.get("macro_auto_primeiro") === "") {
          r.set("macro_auto_primeiro", true);
          ch = true;
        }
        if (!String(r.get("macro_resid_titulo") || "").trim()) {
          r.set("macro_resid_titulo", "Higienização residencial");
          ch = true;
        }
        if (!String(r.get("macro_resid_subtitulo") || "").trim()) {
          r.set(
            "macro_resid_subtitulo",
            "Sofá, colchão, poltrona, tapete e mais",
          );
          ch = true;
        }
        if (!String(r.get("macro_resid_icone") || "").trim()) {
          r.set("macro_resid_icone", "cleaning");
          ch = true;
        }
        if (!String(r.get("macro_auto_titulo") || "").trim()) {
          r.set("macro_auto_titulo", "Estética automotiva");
          ch = true;
        }
        if (!String(r.get("macro_auto_subtitulo") || "").trim()) {
          r.set(
            "macro_auto_subtitulo",
            "Bancos, teto, carpete e pacotes Cleanox",
          );
          ch = true;
        }
        if (!String(r.get("macro_auto_icone") || "").trim()) {
          r.set("macro_auto_icone", "car");
          ch = true;
        }
        if (ch) app.save(r);
      }
    } catch (_) {}
  },
  (app) => {
    // no destructive down
  },
);
