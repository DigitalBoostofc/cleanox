/// <reference path="../pb_data/types.d.ts" />
/**
 * CleanOS — Migration 30: limites de gasto por mês (estilo Organizze).
 *
 * `fin_limites.ano_mes` = 'YYYY-MM' (mês civil BRT do orçamento).
 * Um teto por (categoria, mês). Limites legados sem mês recebem o mês BRT atual.
 */
migrate(
  (app) => {
    const col = app.findCollectionByNameOrId("fin_limites");
    if (!col.fields.getByName("ano_mes")) {
      col.fields.add(
        new TextField({ name: "ano_mes", required: false, max: 7 }),
      );
      app.save(col);
    }

    // Backfill: registros antigos → mês BRT corrente.
    const now = new Date(Date.now() - 3 * 60 * 60 * 1000);
    const y = now.getUTCFullYear();
    const m = String(now.getUTCMonth() + 1).padStart(2, "0");
    const anoMes = y + "-" + m;

    let list = [];
    try {
      list = app.findRecordsByFilter(
        "fin_limites",
        "id != ''",
        "",
        500,
        0,
        {},
      );
    } catch (_) {
      list = [];
    }
    for (let i = 0; i < list.length; i++) {
      const r = list[i];
      const cur = String(r.get("ano_mes") || "").trim();
      if (!cur) {
        r.set("ano_mes", anoMes);
        app.save(r);
      }
    }

    try {
      app.db().newQuery(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_fin_limites_cat_mes " +
          "ON fin_limites (categoria_id, ano_mes)",
      ).execute();
    } catch (e) {
      console.log("[mig 30] idx_fin_limites_cat_mes: " + e);
    }
  },
  (app) => {
    try {
      app.db().newQuery("DROP INDEX IF EXISTS idx_fin_limites_cat_mes").execute();
    } catch (_) {}
    const col = app.findCollectionByNameOrId("fin_limites");
    const f = col.fields.getByName("ano_mes");
    if (f) {
      col.fields.removeById(f.id);
      app.save(col);
    }
  },
);
