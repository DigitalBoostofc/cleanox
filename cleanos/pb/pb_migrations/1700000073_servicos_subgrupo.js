/// Categoria → Grupo → Subgrupo em `servicos`.
migrate(
  (app) => {
    const servicos = app.findCollectionByNameOrId('servicos');
    if (!servicos.fields.getByName('subgrupo')) {
      servicos.fields.add(
        new TextField({ name: 'subgrupo', required: false, max: 80 }),
      );
      app.save(servicos);
    }
  },
  (app) => {
    const servicos = app.findCollectionByNameOrId('servicos');
    const f = servicos.fields.getByName('subgrupo');
    if (f) {
      servicos.fields.removeById(f.id);
      app.save(servicos);
    }
  },
);
