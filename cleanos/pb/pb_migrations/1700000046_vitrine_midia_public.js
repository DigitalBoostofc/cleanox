/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Vitrine mídia pública (leitura).
 *
 * Arquivos de `vitrine_midia` e `foto` de order bumps precisam de viewRule
 * pública para o site agendar carregar imagens sem auth.
 * Escrita continua restrita a admin/gerente.
 *
 * IDEMPOTENTE.
 */

migrate(
  (app) => {
    const COFRE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';

    function openRead(name) {
      try {
        const c = app.findCollectionByNameOrId(name);
        // "" = público (sem auth). create/update/delete permanecem COFRE.
        c.listRule = "";
        c.viewRule = "";
        c.createRule = COFRE;
        c.updateRule = COFRE;
        c.deleteRule = COFRE;
        app.save(c);
      } catch (e) {
        console.log("[0046] skip " + name + ": " + e);
      }
    }

    openRead("vitrine_midia");
    openRead("vitrine_order_bumps");
  },
  (app) => {
    const COFRE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';
    for (const name of ["vitrine_midia", "vitrine_order_bumps"]) {
      try {
        const c = app.findCollectionByNameOrId(name);
        c.listRule = COFRE;
        c.viewRule = COFRE;
        app.save(c);
      } catch (_) {}
    }
  },
);
