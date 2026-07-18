/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — auditoria de cancelamento de OS.
 *
 *  - motivo_cancelamento (text) — obrigatório na prática via rota/hook
 *  - cancelado_por (relation users) — quem cancelou
 *  - cancelado_por_nome (text) — denorm para sobreviver a exclusão de user
 *  - cancelado_em (date) — carimbo server-side
 *
 * IDEMPOTENTE.
 */

migrate(
  (app) => {
    const os = app.findCollectionByNameOrId("ordens_servico");
    const users = app.findCollectionByNameOrId("users");

    if (!os.fields.getByName("motivo_cancelamento")) {
      os.fields.add(
        new TextField({
          name: "motivo_cancelamento",
          required: false,
          max: 1000,
        }),
      );
    }
    if (!os.fields.getByName("cancelado_por")) {
      os.fields.add(
        new RelationField({
          name: "cancelado_por",
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        }),
      );
    }
    if (!os.fields.getByName("cancelado_por_nome")) {
      os.fields.add(
        new TextField({
          name: "cancelado_por_nome",
          required: false,
          max: 200,
        }),
      );
    }
    if (!os.fields.getByName("cancelado_em")) {
      os.fields.add(new DateField({ name: "cancelado_em", required: false }));
    }
    app.save(os);
  },
  (app) => {
    const os = app.findCollectionByNameOrId("ordens_servico");
    for (const name of [
      "motivo_cancelamento",
      "cancelado_por",
      "cancelado_por_nome",
      "cancelado_em",
    ]) {
      const f = os.fields.getByName(name);
      if (f) os.fields.removeById(f.id);
    }
    app.save(os);
  },
);
