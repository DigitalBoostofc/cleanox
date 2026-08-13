/// Aumenta `servicos.vitrine_descricao` para textos longos de “o que inclui”.
migrate(
  (app) => {
    const servicos = app.findCollectionByNameOrId('servicos');
    const f = servicos.fields.getByName('vitrine_descricao');
    if (f) {
      f.max = 2000;
      app.save(servicos);
    }
  },
  (app) => {
    const servicos = app.findCollectionByNameOrId('servicos');
    const f = servicos.fields.getByName('vitrine_descricao');
    if (f) {
      f.max = 500;
      app.save(servicos);
    }
  },
);
