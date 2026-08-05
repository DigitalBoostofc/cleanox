/// <reference path="../pb_data/types.d.ts" />
/**
 * CleanOS — Migration 55: admin/gerente podem criar usuários + senha min 4 no campo.
 *
 * Causa (prod 2026-08):
 * - collection.manageRule vazio/null → só _superuser gerencia auth users.
 *   Admin no painel recebe 400 "Failed to create record." (sem detalhe).
 * - Campo system `password.min` ainda 8; mig 53 só alterou
 *   passwordAuth.minPasswordLength=4 (UI aceita 4–7 → 400).
 *
 * IDEMPOTENTE.
 */
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const COFRE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';

    // manageRule: criar/gerir OUTRAS contas (senha, email, verified…).
    users.manageRule = COFRE;

    // createRule já deveria ser admin|gerente — reforça se vazio.
    if (!users.createRule || String(users.createRule).trim() === "") {
      users.createRule = COFRE;
    }

    // passwordAuth.minPasswordLength = 4 (reforço da 53)
    try {
      if (users.passwordAuth) {
        users.passwordAuth.minPasswordLength = 4;
      }
    } catch (_) {}
    try {
      const opt = users.options || {};
      const pa = Object.assign(
        {},
        opt.passwordAuth || { enabled: true, identityFields: ["email"] },
      );
      pa.minPasswordLength = 4;
      opt.passwordAuth = pa;
      // keep manageRule also in options blob (PB serializes both)
      opt.manageRule = COFRE;
      users.options = opt;
    } catch (_) {}

    // Campo password: min length alinhado ao produto.
    const pw = users.fields.getByName("password");
    if (pw) {
      pw.min = 4;
    }

    app.save(users);
    console.log("[mig 55] users.manageRule=admin|gerente; password.min=4");
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.manageRule = null;
    const pw = users.fields.getByName("password");
    if (pw) pw.min = 8;
    app.save(users);
  },
);
