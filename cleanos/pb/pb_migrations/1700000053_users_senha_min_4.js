/// <reference path="../pb_data/types.d.ts" />
/**
 * CleanOS — Migration 53: senha mínima de users = 4 caracteres.
 * Só comprimento mínimo; sem regra de complexidade.
 * IDEMPOTENTE.
 */
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    try {
      // PocketBase auth collection: passwordAuth.minPasswordLength
      if (users.passwordAuth) {
        users.passwordAuth.minPasswordLength = 4;
        app.save(users);
      } else if (users.options && users.options.passwordAuth) {
        users.options.passwordAuth.minPasswordLength = 4;
        app.save(users);
      }
    } catch (e) {
      // Fallback: set via raw options if API shape differs.
      try {
        const opt = users.options || {};
        opt.passwordAuth = opt.passwordAuth || { enabled: true, identityFields: ["email"] };
        opt.passwordAuth.minPasswordLength = 4;
        users.options = opt;
        app.save(users);
      } catch (e2) {
        console.log("[mig 53] não foi possível setar minPasswordLength: " + e2);
      }
    }
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    try {
      if (users.passwordAuth) {
        users.passwordAuth.minPasswordLength = 8;
        app.save(users);
      }
    } catch (_) {}
  },
);
