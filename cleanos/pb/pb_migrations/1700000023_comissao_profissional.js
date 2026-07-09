/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Comissão por profissional.
 *
 * 1) users: comissao_tipo (nenhuma|percentual|fixo) + comissao_valor
 * 2) prof_comissoes: extrato por OS concluída (profissional vê só as próprias)
 *
 * IDEMPOTENTE. DOWN remove campos e coleção.
 */

migrate(
  (app) => {
    const COFRE = '@request.auth.role = "admin" || @request.auth.role = "gerente"';
    const PROF_OWN =
      '@request.auth.role = "profissional" && profissional = @request.auth.id';

    // ── A) campos em users ───────────────────────────────────────────────────
    const users = app.findCollectionByNameOrId("users");
    if (!users.fields.getByName("comissao_tipo")) {
      users.fields.add(
        new SelectField({
          name: "comissao_tipo",
          required: false,
          maxSelect: 1,
          values: ["nenhuma", "percentual", "fixo"],
        }),
      );
    }
    if (!users.fields.getByName("comissao_valor")) {
      users.fields.add(
        new NumberField({ name: "comissao_valor", required: false, min: 0 }),
      );
    }
    app.save(users);

    // ── B) prof_comissoes ────────────────────────────────────────────────────
    function tryFind(id) {
      try {
        return app.findCollectionByNameOrId(id);
      } catch (_) {
        return null;
      }
    }

    if (!tryFind("profcomissoes001")) {
      const c = new Collection({
        type: "base",
        name: "prof_comissoes",
        id: "profcomissoes001",
      });
      c.fields.add(
        new RelationField({
          name: "profissional",
          required: true,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: true,
        }),
      );
      c.fields.add(
        new RelationField({
          name: "os",
          required: true,
          maxSelect: 1,
          collectionId: "ordserv00000001",
          cascadeDelete: false,
        }),
      );
      c.fields.add(new NumberField({ name: "valor_os", required: true, min: 0 }));
      c.fields.add(
        new NumberField({ name: "valor_comissao", required: true, min: 0 }),
      );
      c.fields.add(
        new SelectField({
          name: "tipo_aplicado",
          required: true,
          maxSelect: 1,
          values: ["percentual", "fixo"],
        }),
      );
      c.fields.add(
        new NumberField({ name: "base_valor", required: false, min: 0 }),
      );
      c.fields.add(
        new SelectField({
          name: "status",
          required: true,
          maxSelect: 1,
          values: ["pendente", "paga"],
        }),
      );
      c.fields.add(new DateField({ name: "data", required: true }));
      c.fields.add(
        new TextField({ name: "descricao", required: false, max: 300 }),
      );
      c.fields.add(
        new AutodateField({ name: "created", onCreate: true, onUpdate: false }),
      );
      c.fields.add(
        new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
      );

      // Admin/gerente: full. Profissional: só as próprias (list/view).
      c.listRule = COFRE + " || (" + PROF_OWN + ")";
      c.viewRule = COFRE + " || (" + PROF_OWN + ")";
      c.createRule = COFRE; // criação é server-side (hook); admin pode ajustar
      c.updateRule = COFRE; // marcar paga
      c.deleteRule = COFRE;
      app.save(c);

      // Índice único parcial: no máximo 1 comissão por OS
      try {
        app.db()
          .newQuery(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_prof_comissoes_os " +
              "ON prof_comissoes (os) WHERE os != ''",
          )
          .execute();
      } catch (e) {
        console.log("[mig 23] idx_prof_comissoes_os: " + e);
      }
    }
  },
  (app) => {
    try {
      const c = app.findCollectionByNameOrId("profcomissoes001");
      app.delete(c);
    } catch (_) {}

    try {
      const users = app.findCollectionByNameOrId("users");
      const t = users.fields.getByName("comissao_tipo");
      if (t) users.fields.removeById(t.id);
      const v = users.fields.getByName("comissao_valor");
      if (v) users.fields.removeById(v.id);
      app.save(users);
    } catch (_) {}
  },
);
