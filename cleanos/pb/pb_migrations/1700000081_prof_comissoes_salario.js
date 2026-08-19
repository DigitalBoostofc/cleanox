/// <reference path="../pb_data/types.d.ts" />

/**
 * prof_comissoes.tipo_aplicado aceita `salario` (parcela de salário fixo).
 */
migrate(
  (app) => {
    const col = app.findCollectionByNameOrId("prof_comissoes");
    if (!col) return;
    const tipo = col.fields.getByName("tipo_aplicado");
    if (tipo && tipo.values && tipo.values.indexOf("salario") === -1) {
      tipo.values = tipo.values.concat(["salario"]);
      app.save(col);
    }
  },
  (app) => {
    const col = app.findCollectionByNameOrId("prof_comissoes");
    if (!col) return;
    const tipo = col.fields.getByName("tipo_aplicado");
    if (tipo && tipo.values) {
      tipo.values = tipo.values.filter((v) => v !== "salario");
      app.save(col);
    }
  },
);
