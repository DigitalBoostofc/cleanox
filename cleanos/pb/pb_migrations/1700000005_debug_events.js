/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 5: coleção temporária de captura de webhooks WhatsApp.
 *
 * Cria a coleção `whatsapp_events` para diagnóstico do formato bruto de
 * payloads recebidos via UAZAPI. Regras SOMENTE superuser (null) — nenhum
 * papel de negócio acessa via API pública.
 *
 * Leitura dos eventos: sqlite3 /opt/cleanos/pb/pb_data/data.db \
 *   "SELECT raw FROM whatsapp_events ORDER BY created DESC LIMIT 5;"
 */

migrate(
  (app) => {
    const col = new Collection({
      type: "base",
      name: "whatsapp_events",
      id: "wevents00000001",
    });

    col.fields.add(new TextField({ name: "raw", required: false, max: 0 }));
    col.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));

    // Regras null = somente superuser (nenhum papel de negócio acessa)
    col.listRule   = null;
    col.viewRule   = null;
    col.createRule = null;
    col.updateRule = null;
    col.deleteRule = null;

    app.save(col);
  },

  // ── DOWN ──────────────────────────────────────────────────────────────────
  (app) => {
    try {
      const col = app.findCollectionByNameOrId("wevents00000001");
      app.delete(col);
    } catch (_) {}
  }
);
