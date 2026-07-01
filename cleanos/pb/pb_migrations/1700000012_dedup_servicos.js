/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 12: dedup do catálogo de serviços (F-001).
 *
 * Causa: duas migrations com prefixo 1700000002_ (seed.js + catalog_prod.js)
 * semearam os mesmos 7 nomes duas vezes, resultando em 14 registros para 7 nomes.
 *
 * UP: agrupa por `nome`; para cada nome com >1 registro, mantém o mais ANTIGO
 * (menor `created`) e deleta os demais. Idempotente — se não houver duplicata,
 * não faz nada.
 *
 * DOWN: no-op (não é possível recriar os registros deletados sem os dados originais).
 */

migrate(
  (app) => {
    const all = app.findAllRecords("servicos");

    // agrupa por nome
    const byNome = {};
    for (let i = 0; i < all.length; i++) {
      const rec  = all[i];
      const nome = rec.getString("nome");
      if (!byNome[nome]) byNome[nome] = [];
      byNome[nome].push(rec);
    }

    for (const nome in byNome) {
      const group = byNome[nome];
      if (group.length <= 1) continue;

      // ordena por created ASC (string ISO é lexicograficamente comparável)
      group.sort(function(a, b) {
        const ca = a.getString("created");
        const cb = b.getString("created");
        return ca < cb ? -1 : ca > cb ? 1 : 0;
      });

      // mantém o primeiro (mais antigo), deleta os demais
      for (let i = 1; i < group.length; i++) {
        app.delete(group[i]);
      }
    }
  },

  // DOWN: no-op
  (app) => {}
);
