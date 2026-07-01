/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 13: emailVisibility=true para todos os users (F-005).
 *
 * Causa: users criados antes desta migration têm emailVisibility=false (default
 * do PocketBase), tornando o campo `email` invisível para o admin na tela de
 * Usuários — o admin não consegue identificar contas por credencial de login.
 *
 * UP: percorre todos os registros de `users`; para cada um com emailVisibility
 * diferente de true, seta true e salva. Idempotente.
 *
 * DOWN: no-op.
 */

migrate(
  (app) => {
    const all = app.findAllRecords("users");

    for (let i = 0; i < all.length; i++) {
      const u = all[i];
      if (u.getBool("emailVisibility")) continue;
      u.set("emailVisibility", true);
      app.save(u);
    }
  },

  // DOWN: no-op
  (app) => {}
);
