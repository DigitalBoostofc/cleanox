/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 50: OS em dupla (2 profissionais).
 *
 * 1) ordens_servico.execucao_modo: solo | dupla (default solo)
 * 2) ordens_servico.profissional2: 2º profissional (opcional)
 * 3) Regras list/view/update: profissional OU profissional2
 * 4) os_evidencias: idem via os.profissional2
 * 5) prof_comissoes: unique (os, profissional) — permite 2 linhas por OS
 *
 * IDEMPOTENTE. DOWN reverte campos/regras/índice.
 */

migrate(
  (app) => {
    const ADMIN_GERENTE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';
    const PROF_OS =
      "profissional = @request.auth.id || profissional2 = @request.auth.id";

    const ordens = app.findCollectionByNameOrId("ordens_servico");
    const users = app.findCollectionByNameOrId("users");

    // ── A) campos ──────────────────────────────────────────────────────────
    if (!ordens.fields.getByName("execucao_modo")) {
      ordens.fields.add(
        new SelectField({
          name: "execucao_modo",
          required: false,
          maxSelect: 1,
          values: ["solo", "dupla"],
        }),
      );
    }
    if (!ordens.fields.getByName("profissional2")) {
      ordens.fields.add(
        new RelationField({
          name: "profissional2",
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        }),
      );
    }

    // ── B) regras de acesso ────────────────────────────────────────────────
    ordens.listRule = ADMIN_GERENTE + " || " + PROF_OS;
    ordens.viewRule = ADMIN_GERENTE + " || " + PROF_OS;
    ordens.updateRule = ADMIN_GERENTE + " || " + PROF_OS;

    // índice auxiliar (filtro por 2º prof / agenda)
    try {
      const hasIdx = (ordens.indexes || []).some(function (s) {
        return String(s).indexOf("idx_os_profissional2") !== -1;
      });
      if (!hasIdx) {
        ordens.indexes = (ordens.indexes || []).concat([
          "CREATE INDEX IF NOT EXISTS idx_os_profissional2 ON ordens_servico (profissional2)",
        ]);
      }
    } catch (e) {
      console.log("[mig 50] idx profissional2: " + e);
    }

    app.save(ordens);

    // Default solo em registros antigos (Select vazio → trata como solo no hook)
    try {
      app
        .db()
        .newQuery(
          "UPDATE ordens_servico SET execucao_modo = 'solo' " +
            "WHERE execucao_modo IS NULL OR execucao_modo = ''",
        )
        .execute();
    } catch (e) {
      console.log("[mig 50] backfill execucao_modo: " + e);
    }

    // ── C) evidências: 2º profissional também dono ─────────────────────────
    try {
      const evid = app.findCollectionByNameOrId("os_evidencias");
      const EVID_OWNER =
        '@request.auth.id != "" && (' +
        '@request.auth.role = "admin" || ' +
        '@request.auth.role = "gerente" || ' +
        "os.profissional = @request.auth.id || " +
        "os.profissional2 = @request.auth.id)";
      evid.listRule = EVID_OWNER;
      evid.viewRule = EVID_OWNER;
      evid.createRule = EVID_OWNER;
      evid.updateRule = EVID_OWNER;
      evid.deleteRule = EVID_OWNER;
      app.save(evid);
    } catch (e) {
      console.log("[mig 50] os_evidencias rules: " + e);
    }

    // ── D) comissão: 1 linha por (OS, profissional) ────────────────────────
    try {
      app
        .db()
        .newQuery("DROP INDEX IF EXISTS idx_prof_comissoes_os")
        .execute();
    } catch (e) {
      console.log("[mig 50] drop idx_prof_comissoes_os: " + e);
    }
    try {
      app
        .db()
        .newQuery(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_prof_comissoes_os_prof " +
            "ON prof_comissoes (os, profissional) " +
            "WHERE os != '' AND profissional != ''",
        )
        .execute();
    } catch (e) {
      console.log("[mig 50] idx_prof_comissoes_os_prof: " + e);
    }
  },
  (app) => {
    const ADMIN_GERENTE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';

    try {
      const ordens = app.findCollectionByNameOrId("ordens_servico");
      const fModo = ordens.fields.getByName("execucao_modo");
      if (fModo) ordens.fields.removeById(fModo.id);
      const fP2 = ordens.fields.getByName("profissional2");
      if (fP2) ordens.fields.removeById(fP2.id);
      ordens.listRule = ADMIN_GERENTE + " || profissional = @request.auth.id";
      ordens.viewRule = ADMIN_GERENTE + " || profissional = @request.auth.id";
      ordens.updateRule = ADMIN_GERENTE + " || profissional = @request.auth.id";
      // remove índice profissional2 da lista se presente
      try {
        ordens.indexes = (ordens.indexes || []).filter(function (s) {
          return String(s).indexOf("idx_os_profissional2") === -1;
        });
      } catch (_) {
        /* ignore */
      }
      app.save(ordens);
    } catch (e) {
      console.log("[mig 50 down] ordens: " + e);
    }

    try {
      const evid = app.findCollectionByNameOrId("os_evidencias");
      const EVID_OWNER =
        '@request.auth.id != "" && (' +
        '@request.auth.role = "admin" || ' +
        '@request.auth.role = "gerente" || ' +
        "os.profissional = @request.auth.id)";
      evid.listRule = EVID_OWNER;
      evid.viewRule = EVID_OWNER;
      evid.createRule = EVID_OWNER;
      evid.updateRule = EVID_OWNER;
      evid.deleteRule = EVID_OWNER;
      app.save(evid);
    } catch (e) {
      console.log("[mig 50 down] evid: " + e);
    }

    try {
      app
        .db()
        .newQuery("DROP INDEX IF EXISTS idx_prof_comissoes_os_prof")
        .execute();
    } catch (_) {
      /* ignore */
    }
    try {
      app
        .db()
        .newQuery(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_prof_comissoes_os " +
            "ON prof_comissoes (os) WHERE os != ''",
        )
        .execute();
    } catch (e) {
      console.log("[mig 50 down] restore idx os: " + e);
    }
  },
);
