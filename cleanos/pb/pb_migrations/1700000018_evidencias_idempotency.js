/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 18: dedupe idempotente de evidências (os_evidencias).
 *
 * ADITIVA — não altera nada do comportamento existente. Serve ao app Flutter do
 * profissional, que agora envia um campo `idempotency_key` (uuid, string) no
 * multipart de criação de `os_evidencias`. Se a resposta do POST se perde e o app
 * refaz o retry, a MESMA (os, idempotency_key) NÃO deve gerar uma evidência
 * duplicada.
 *
 * Adiciona:
 *   - `os_evidencias.idempotency_key` (text, opcional, max 100) — a chave enviada
 *     pelo app. Vazia por padrão (evidências criadas sem chave seguem inalteradas).
 *   - Índice ÚNICO PARCIAL por (os, idempotency_key) SOMENTE quando a chave não é
 *     vazia — impede duplicata mesmo sob corrida (2 POSTs concorrentes). Evidências
 *     sem chave (idempotency_key = '') ficam de FORA do índice, então nada muda para
 *     o fluxo atual (várias fotos por OS sem chave continuam permitidas).
 *
 * O curto-circuito de sucesso idempotente (retornar o registro existente no 2º
 * create) vive no hook de request `evidencias.pb.js`; este índice é o backstop de
 * consistência a nível de banco.
 *
 * IDEMPOTENTE / REVERSÍVEL: só age se a coleção existir; o DOWN remove índice+campo.
 */
migrate(
  (app) => {
    let evid = null;
    try { evid = app.findCollectionByNameOrId("osevidenc000001"); } catch (_) { evid = null; }
    if (!evid) return; // base muito antiga sem a coleção — nada a fazer

    // 1) Campo idempotency_key (aditivo, opcional).
    if (!evid.fields.getByName("idempotency_key")) {
      evid.fields.add(new TextField({ name: "idempotency_key", required: false, max: 100 }));
    }

    // 2) Índice único PARCIAL por (os, idempotency_key) quando não vazio.
    //    SQLite suporta `WHERE` em CREATE UNIQUE INDEX (índice parcial): chaves
    //    vazias não colidem entre si; só bloqueia a duplicata real de retry.
    const IDX = "idx_evid_idem";
    const hasIdx = (evid.indexes || []).some(function (s) {
      return String(s).indexOf(IDX) !== -1;
    });
    if (!hasIdx) {
      evid.indexes = (evid.indexes || []).concat([
        "CREATE UNIQUE INDEX `" + IDX + "` ON `os_evidencias` (`os`, `idempotency_key`) WHERE `idempotency_key` != ''",
      ]);
    }

    app.save(evid);
  },

  // ── DOWN ──────────────────────────────────────────────────────────────────
  (app) => {
    let evid = null;
    try { evid = app.findCollectionByNameOrId("osevidenc000001"); } catch (_) { evid = null; }
    if (!evid) return;

    evid.indexes = (evid.indexes || []).filter(function (s) {
      return String(s).indexOf("idx_evid_idem") === -1;
    });

    const f = evid.fields.getByName("idempotency_key");
    if (f) evid.fields.removeById(f.id);

    app.save(evid);
  }
);
