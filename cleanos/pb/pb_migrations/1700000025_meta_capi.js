/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 25: config Meta CAPI (CÓPIA da 18) (Schedule/Purchase/Lead → cleanox-ads).
 *
 * ADITIVA. Campos em app_config para o hook meta_capi_lib.js:
 *   meta_capi_enabled  — "true" | "false"
 *   meta_capi_url      — URL do webhook cleanox-ads
 *   meta_capi_secret   — Bearer secret (igual CLEANOS_WEBHOOK_SECRET)
 *
 * ⚠️ ESTE ARQUIVO TEM UMA CÓPIA IDÊNTICA: `1700000018_meta_capi.js`, e as DUAS
 * já rodaram em produção (ambas constam em `_migrations`). Por isso ela PRECISA
 * ser idempotente: rodando de novo sobre um banco que já tem os campos
 * preenchidos, não pode re-adicionar campo nem sobrescrever a config.
 *
 * A versão original fazia `fields.add()` cego + `set()` incondicional dos
 * defaults — a segunda passada APAGAVA a URL e o secret do Meta CAPI. Em prod
 * o PocketBase deduplicou os campos por nome e o dono reconfigurou, mas o
 * padrão é uma mina: qualquer banco onde as duas rodem em sequência sobre uma
 * config já existente perde a config.
 */

const CAMPOS = [
  { name: "meta_capi_enabled", max: 10, inicial: "false" },
  { name: "meta_capi_url", max: 500, inicial: "" },
  { name: "meta_capi_secret", max: 200, inicial: "" },
];

migrate(
  (app) => {
    const cfg = app.findCollectionByNameOrId("appconfigwh0001");

    const adicionados = [];
    for (const c of CAMPOS) {
      let existe = false;
      try {
        existe = !!cfg.fields.getByName(c.name);
      } catch (_) {
        existe = false;
      }
      if (!existe) {
        cfg.fields.add(new TextField({ name: c.name, required: false, max: c.max }));
        adicionados.push(c);
      }
    }

    // Nada novo a criar: a config existente fica INTACTA. É este return que
    // impede a segunda passada de zerar url/secret.
    if (adicionados.length === 0) return;

    app.save(cfg);

    // Semeia o valor inicial APENAS dos campos recém-criados.
    try {
      const rec = app.findFirstRecordByFilter("app_config", "id != ''");
      for (const c of adicionados) rec.set(c.name, c.inicial);
      app.save(rec);
    } catch (_) {
      /* ainda não há registro de app_config */
    }
  },
  (app) => {
    const cfg = app.findCollectionByNameOrId("appconfigwh0001");
    for (const c of CAMPOS) {
      try {
        const f = cfg.fields.getByName(c.name);
        if (f) cfg.fields.removeById(f.id);
      } catch (_) {}
    }
    app.save(cfg);
  },
);
