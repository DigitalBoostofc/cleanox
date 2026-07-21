/// 1700000042_fin_objetivos.js
///
/// Metas de caixa (Financeiro v2 — Objetivos).
/// COFRE_FIN: só admin/gerente.
migrate((app) => {
  const COFRE_FIN =
    '@request.auth.role = "admin" || @request.auth.role = "gerente"';

  function tryFind(id) {
    try {
      return app.findCollectionByNameOrId(id);
    } catch (_) {
      return null;
    }
  }

  if (!tryFind("finobjetivos0001")) {
    const c = new Collection({
      type: "base",
      name: "fin_objetivos",
      id: "finobjetivos0001",
    });
    c.fields.add(new TextField({ name: "nome", required: true, max: 120 }));
    c.fields.add(new NumberField({ name: "meta_valor", required: true, min: 0 }));
    c.fields.add(
      new NumberField({ name: "valor_atual", required: false, min: 0 }),
    );
    c.fields.add(new DateField({ name: "data_limite", required: false }));
    c.fields.add(new BoolField({ name: "ativo", required: false }));
    c.fields.add(new TextField({ name: "cor", required: false, max: 20 }));
    c.fields.add(new TextField({ name: "icone", required: false, max: 40 }));
    c.fields.add(new TextField({ name: "observacao", required: false, max: 500 }));
    c.fields.add(
      new AutodateField({ name: "created", onCreate: true, onUpdate: false }),
    );
    c.fields.add(
      new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
    );
    c.listRule = COFRE_FIN;
    c.viewRule = COFRE_FIN;
    c.createRule = COFRE_FIN;
    c.updateRule = COFRE_FIN;
    c.deleteRule = COFRE_FIN;
    app.save(c);
  }
}, (app) => {
  try {
    const c = app.findCollectionByNameOrId("finobjetivos0001");
    app.delete(c);
  } catch (_) {
    /* já ausente */
  }
});
