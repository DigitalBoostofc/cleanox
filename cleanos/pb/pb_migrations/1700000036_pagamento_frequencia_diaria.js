/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — pagamento da equipe:
 *  - users.comissao_tipo + valor: aceita `diaria` (R$ por dia com ≥1 OS concluída)
 *  - users.pagamento_frequencia: diario | semanal | quinzenal | mensal
 *  - prof_comissoes.tipo_aplicado: aceita `diaria`
 *
 * IDEMPOTENTE.
 */

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const tipo = users.fields.getByName("comissao_tipo");
    if (tipo && tipo.values && tipo.values.indexOf("diaria") === -1) {
      tipo.values = tipo.values.concat(["diaria"]);
    }
    if (!users.fields.getByName("pagamento_frequencia")) {
      users.fields.add(
        new SelectField({
          name: "pagamento_frequencia",
          required: false,
          maxSelect: 1,
          values: ["diario", "semanal", "quinzenal", "mensal"],
        }),
      );
    }
    app.save(users);

    let col;
    try {
      col = app.findCollectionByNameOrId("prof_comissoes");
    } catch (_) {
      col = null;
    }
    if (col) {
      const ta = col.fields.getByName("tipo_aplicado");
      if (ta && ta.values && ta.values.indexOf("diaria") === -1) {
        ta.values = ta.values.concat(["diaria"]);
        app.save(col);
      }
    }
  },
  (app) => {
    // DOWN: não remove valores de select (dados podem existir); só o campo novo.
    const users = app.findCollectionByNameOrId("users");
    const f = users.fields.getByName("pagamento_frequencia");
    if (f) {
      users.fields.removeById(f.id);
      app.save(users);
    }
  },
);
