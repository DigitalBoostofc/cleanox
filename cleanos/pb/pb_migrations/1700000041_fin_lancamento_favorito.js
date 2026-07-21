/// 1700000041_fin_lancamento_favorito.js
///
/// Flag `favorito` em fin_lancamentos (pin na lista de Transações).
/// Default false; opcional.
migrate((app) => {
  const col = app.findCollectionByNameOrId("fin_lancamentos");
  if (!col.fields.getByName("favorito")) {
    col.fields.add(
      new BoolField({
        name: "favorito",
        required: false,
      }),
    );
    app.save(col);
  }
}, (app) => {
  const col = app.findCollectionByNameOrId("fin_lancamentos");
  const f = col.fields.getByName("favorito");
  if (f) {
    col.fields.removeById(f.id);
    app.save(col);
  }
});
