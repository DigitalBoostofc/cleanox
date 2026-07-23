/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Vitrine pública (Fase 1):
 *  - clientes.origem aceita "vitrine"
 *  - ordens_servico.canal_origem (manual|vitrine|whatsapp|outro) — de onde nasceu a OS
 *
 * IDEMPOTENTE.
 */

migrate(
  (app) => {
    const clientes = app.findCollectionByNameOrId("clientes");
    const origem = clientes.fields.getByName("origem");
    if (origem && origem.values && origem.values.indexOf("vitrine") === -1) {
      origem.values = origem.values.concat(["vitrine"]);
      app.save(clientes);
    }

    const ordens = app.findCollectionByNameOrId("ordens_servico");
    if (!ordens.fields.getByName("canal_origem")) {
      ordens.fields.add(
        new SelectField({
          name: "canal_origem",
          required: false,
          maxSelect: 1,
          values: ["manual", "vitrine", "whatsapp", "outro"],
        }),
      );
      app.save(ordens);
    }
  },
  (app) => {
    // DOWN: não remove valor "vitrine" do select (dados podem existir).
    try {
      const ordens = app.findCollectionByNameOrId("ordens_servico");
      const f = ordens.fields.getByName("canal_origem");
      if (f) {
        ordens.fields.removeById(f.id);
        app.save(ordens);
      }
    } catch (_) {}
  },
);
