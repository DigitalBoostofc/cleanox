/// <reference path="../pb_data/types.d.ts" />

/**
 * Backfill: profissionais sem users.categoria_comissao válida recebem
 * Equipe → nome. Preserva só vínculo que resolve para fin_categorias
 * tipo despesa. Sem Equipe (nome ou catdequipe00001 raiz despesa) aborta.
 */
function loadCatLib() {
  try {
    return require(`${__hooks}/users_categoria_comissao_lib.js`);
  } catch (_) {}
  return require("../pb_hooks/users_categoria_comissao_lib.js");
}

migrate(
  (app) => {
    const lib = loadCatLib();
    const out = lib.backfillUsersCategoriaComissao(app);
    console.log(
      "[mig 76] profissionais com categoria_comissao preenchida: " +
        (out && out.alterados ? out.alterados : 0),
    );
  },
  (app) => {
    // Não desfaz vínculos históricos.
  },
);
