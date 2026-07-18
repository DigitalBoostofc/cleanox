/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — dia do repasse configurável no perfil do profissional.
 *
 *  - pagamento_dia: dia âncora
 *      semanal   → weekday 1–7 (1=seg … 7=dom; default 5=sexta)
 *      quinzenal → 1º dia de corte da quinzena (default 15)
 *      mensal    → dia do mês 1–31 (default 1)
 *      diario    → ignorado
 *  - pagamento_dia_2: 2º dia quinzenal (default 0 = último dia do mês)
 *
 * IDEMPOTENTE.
 */

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    if (!users.fields.getByName("pagamento_dia")) {
      users.fields.add(
        new NumberField({
          name: "pagamento_dia",
          required: false,
          min: 0,
          max: 31,
        }),
      );
    }
    if (!users.fields.getByName("pagamento_dia_2")) {
      users.fields.add(
        new NumberField({
          name: "pagamento_dia_2",
          required: false,
          min: 0,
          max: 31,
        }),
      );
    }
    app.save(users);
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    for (const name of ["pagamento_dia", "pagamento_dia_2"]) {
      const f = users.fields.getByName(name);
      if (f) users.fields.removeById(f.id);
    }
    app.save(users);
  },
);
