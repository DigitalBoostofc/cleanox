/// <reference path="../pb_data/types.d.ts" />

// Remove a coleção temporária de captura de webhooks (LGPD — PII capturado).
// Diagnóstico concluído; estrutura do payload documentada no PR de remoção.

migrate(
  (app) => {
    try {
      const col = app.findCollectionByNameOrId("whatsapp_events");
      app.delete(col);
    } catch (_) {
      // Já inexistente — ok
    }
  },

  // ── DOWN ──────────────────────────────────────────────────────────────────
  (app) => {
    // Sem rollback: dados de PII não devem ser restaurados.
  }
);
