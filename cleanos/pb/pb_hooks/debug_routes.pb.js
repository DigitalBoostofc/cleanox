/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — endpoint de captura de webhook para diagnóstico.
 *
 * ROTA DE SERVIÇO (sem auth de usuário PocketBase; autenticada por x-cleanos-secret):
 *   POST /api/cleanos/whatsapp/debug-log
 *     Body:    qualquer JSON (payload bruto do UAZAPI / WhatsApp)
 *     Returns: { ok: true }
 *
 * Grava o corpo recebido em `whatsapp_events.raw` (JSON.stringify).
 * Regras da coleção são null (somente superuser); leitura direta via SQLite:
 *   SELECT raw FROM whatsapp_events ORDER BY created DESC LIMIT 5;
 *
 * Uso temporário — remover após diagnóstico concluído.
 */

routerAdd("POST", "/api/cleanos/whatsapp/debug-log", (e) => {
  try {
    const secret = $os.getenv("CLEANOS_SERVICE_SECRET") || "";
    const hdrs   = e.requestInfo().headers || {};
    const clientSecret = String(hdrs["x_cleanos_secret"] || "");
    if (!secret || clientSecret !== secret) {
      return e.json(401, { error: "Unauthorized" });
    }

    const body    = e.requestInfo().body || {};
    const rawJson = JSON.stringify(body);

    const col = $app.findCollectionByNameOrId("whatsapp_events");
    const rec = new Record(col);
    rec.set("raw", rawJson);
    $app.save(rec);
  } catch (err) {
    // Captura de diagnóstico nunca deve travar — engole o erro e loga
    $app.logger().warn("debug-log: erro ao gravar evento", "err", String(err));
  }

  return e.json(200, { ok: true });
});
