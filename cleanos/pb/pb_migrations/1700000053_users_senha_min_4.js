/// <reference path="../pb_data/types.d.ts" />
/**
 * CleanOS — Migration 53: senha mínima de users = 4 caracteres.
 * Só comprimento mínimo; sem regra de complexidade.
 * IDEMPOTENTE.
 */
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    // PB 0.22+: passwordAuth fica em collection.options.passwordAuth
    const opt = users.options || {};
    const pa = Object.assign({}, opt.passwordAuth || { enabled: true, identityFields: ["email"] });
    pa.minPasswordLength = 4;
    opt.passwordAuth = pa;
    users.options = opt;
    // Algumas builds expõem getter/setter direto:
    try {
      if (users.passwordAuth) {
        users.passwordAuth.minPasswordLength = 4;
      }
    } catch (_) {}
    app.save(users);
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const opt = users.options || {};
    const pa = Object.assign({}, opt.passwordAuth || {});
    pa.minPasswordLength = 8;
    opt.passwordAuth = pa;
    users.options = opt;
    try {
      if (users.passwordAuth) users.passwordAuth.minPasswordLength = 8;
    } catch (_) {}
    app.save(users);
  },
);
