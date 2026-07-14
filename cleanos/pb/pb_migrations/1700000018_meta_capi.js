/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 18: config Meta CAPI (Purchase → cleanox-ads).
 *
 * ADITIVA. Campos em app_config para o hook meta_capi_lib.js:
 *   meta_capi_enabled  — "true" | "false"
 *   meta_capi_url      — URL do webhook cleanox-ads
 *   meta_capi_secret   — Bearer secret (igual CLEANOS_WEBHOOK_SECRET)
 */

migrate(
  (app) => {
    const cfg = app.findCollectionByNameOrId("appconfigwh0001");
    cfg.fields.add(new TextField({ name: "meta_capi_enabled", required: false, max: 10 }));
    cfg.fields.add(new TextField({ name: "meta_capi_url", required: false, max: 500 }));
    cfg.fields.add(new TextField({ name: "meta_capi_secret", required: false, max: 200 }));
    app.save(cfg);

    try {
      const cfgRecord = app.findFirstRecordByFilter("app_config", "id != ''");
      cfgRecord.set("meta_capi_enabled", "false");
      cfgRecord.set("meta_capi_url", "");
      cfgRecord.set("meta_capi_secret", "");
      app.save(cfgRecord);
    } catch (_) {
      /* sem registro ainda */
    }
  },
  (app) => {
    const cfg = app.findCollectionByNameOrId("appconfigwh0001");
    const names = ["meta_capi_enabled", "meta_capi_url", "meta_capi_secret"];
    for (const n of names) {
      try {
        const f = cfg.fields.getByName(n);
        if (f) cfg.fields.removeById(f.id);
      } catch (_) {}
    }
    app.save(cfg);
  },
);
