/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — partida + km planejado do dia do profissional (mapa).
 *
 * Coleção `prof_deslocamento_dia`: 1 registro por (profissional, dia BRT).
 * Escrita só via rota custom POST /prof/deslocamento-dia/partida.
 * IDEMPOTENTE.
 */

migrate(
  (app) => {
    function tryFind(id) {
      try {
        return app.findCollectionByNameOrId(id);
      } catch (_) {
        return null;
      }
    }

    if (tryFind("profdeslocdia001")) return;

    const usersId = app.findCollectionByNameOrId("users").id;
    const OWNER =
      '@request.auth.id != "" && profissional = @request.auth.id';
    const ADMIN =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';

    const c = new Collection({
      type: "base",
      name: "prof_deslocamento_dia",
      id: "profdeslocdia001",
    });
    c.fields.add(
      new RelationField({
        name: "profissional",
        required: true,
        maxSelect: 1,
        minSelect: 1,
        collectionId: usersId,
        cascadeDelete: true,
      }),
    );
    c.fields.add(new TextField({ name: "dia", required: true, max: 10 }));
    c.fields.add(new NumberField({ name: "partida_lat", required: true }));
    c.fields.add(new NumberField({ name: "partida_lng", required: true }));
    c.fields.add(new DateField({ name: "partida_em", required: false }));
    c.fields.add(new NumberField({ name: "km_planejado", required: false }));
    c.fields.add(
      new AutodateField({ name: "created", onCreate: true, onUpdate: false }),
    );
    c.fields.add(
      new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
    );

    // Leitura: dono ou admin/gerente. Create/update/delete: só superuser
    // (app usa rotas custom com $app).
    c.listRule = OWNER + " || " + ADMIN;
    c.viewRule = OWNER + " || " + ADMIN;
    c.createRule = null;
    c.updateRule = null;
    c.deleteRule = null;

    c.indexes = [
      "CREATE UNIQUE INDEX idx_prof_desloc_dia ON prof_deslocamento_dia (profissional, dia)",
    ];

    app.save(c);
  },
  (app) => {
    try {
      const c = app.findCollectionByNameOrId("profdeslocdia001");
      app.delete(c);
    } catch (_) {
      /* already gone */
    }
  },
);
