/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Origem do cliente (atribuição de lead).
 *
 * Adiciona `clientes.origem` (select, opcional): de onde veio o cliente.
 * Alimenta relatório de origem e, futuramente, o Meta CAPI (atribuição).
 *
 * Campo opcional guarda "" quando vazio (nunca null) — ver regra R2 do CLAUDE.md.
 * IDEMPOTENTE. DOWN remove o campo.
 */

migrate(
  (app) => {
    const clientes = app.findCollectionByNameOrId("clientes0000001");
    if (!clientes.fields.getByName("origem")) {
      clientes.fields.add(
        new SelectField({
          name: "origem",
          required: false,
          maxSelect: 1,
          values: [
            "instagram",
            "facebook",
            "google",
            "site",
            "indicacao",
            "whatsapp",
            "parceria",
            "outro",
          ],
        }),
      );
      app.save(clientes);
    }
  },
  (app) => {
    try {
      const clientes = app.findCollectionByNameOrId("clientes0000001");
      const f = clientes.fields.getByName("origem");
      if (f) clientes.fields.removeById(f.id);
      app.save(clientes);
    } catch (_) {}
  },
);
