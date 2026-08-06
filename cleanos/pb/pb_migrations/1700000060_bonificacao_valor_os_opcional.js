/// <reference path="../pb_data/types.d.ts" />

/**
 * Bonificações são avulsas e não possuem valor de OS.
 * O campo legado valor_os era obrigatório para comissões automáticas;
 * torná-lo opcional permite criar bonificações sem inventar uma OS.
 */
migrate(
  (app) => {
    const col = app.findCollectionByNameOrId("prof_comissoes");
    const valorOs = col.fields.getByName("valor_os");
    if (valorOs && valorOs.required) {
      valorOs.required = false;
      app.save(col);
    }
  },
  (app) => {
    const col = app.findCollectionByNameOrId("prof_comissoes");
    const valorOs = col.fields.getByName("valor_os");
    if (valorOs && !valorOs.required) {
      valorOs.required = true;
      app.save(col);
    }
  },
);
