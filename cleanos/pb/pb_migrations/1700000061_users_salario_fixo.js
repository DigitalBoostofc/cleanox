/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 61: remuneração alternativa por salário fixo.
 *
 * Comissão continua em users.comissao_tipo=nenhuma. A remuneração fixa é
 * separada para não ser interpretada pelos hooks de comissão por OS.
 */
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    if (!users.fields.getByName("remuneracao_tipo")) {
      users.fields.add(
        new SelectField({
          name: "remuneracao_tipo",
          required: false,
          maxSelect: 1,
          values: ["nenhuma", "salario_fixo"],
        }),
      );
    }
    if (!users.fields.getByName("remuneracao_valor")) {
      users.fields.add(
        new NumberField({ name: "remuneracao_valor", required: false, min: 0 }),
      );
    }
    app.save(users);
    console.log("[mig 61] users.remuneracao_tipo=salario_fixo");
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const rows = app.findRecordsByFilter(
      "users",
      'remuneracao_tipo = "salario_fixo"',
      "",
      500,
      0,
    );
    if (rows.length > 0) {
      throw new Error("Não é seguro remover salario_fixo enquanto houver usuários configurados");
    }
    for (const name of ["remuneracao_tipo", "remuneracao_valor"]) {
      const field = users.fields.getByName(name);
      if (field) users.fields.removeById(field.id);
    }
    app.save(users);
  },
);
