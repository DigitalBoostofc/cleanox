/// 1700000059_users_categoria_comissao.js
/// Categoria financeira configurável por profissional.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const cats = app.findCollectionByNameOrId("fin_categorias");
    if (!users.fields.getByName("categoria_comissao")) {
      users.fields.add(
        new RelationField({
          name: "categoria_comissao",
          required: false,
          maxSelect: 1,
          collectionId: cats.id,
          cascadeDelete: false,
        }),
      );
      app.save(users);
      console.log("[mig 59] users.categoria_comissao criado");
    }
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const field = users.fields.getByName("categoria_comissao");
    if (field) {
      users.fields.removeById(field.id);
      app.save(users);
    }
  },
);
