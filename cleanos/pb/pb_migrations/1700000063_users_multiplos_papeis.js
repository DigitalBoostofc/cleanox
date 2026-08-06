/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Usuário pode ter mais de um papel.
 *
 * `role` continua sendo o papel ativo usado pelas regras do PocketBase.
 * `roles` guarda os papéis permitidos para a conta e permite alternância
 * segura entre Painel e app profissional.
 */
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  if (!users.fields.getByName("roles")) {
    users.fields.add(
      new SelectField({
        name: "roles",
        required: false,
        maxSelect: 3,
        values: ["admin", "gerente", "profissional"],
      }),
    );
  }
  app.save(users);

  const records = app.findRecordsByFilter("users", "", "", 500, 0);
  for (const user of records) {
    const active = String(user.get("role") || "profissional");
    const current = user.get("roles");
    if (!Array.isArray(current) || current.length === 0) {
      user.set("roles", [active]);
      app.save(user);
    }
  }
}, (app) => {
  const users = app.findCollectionByNameOrId("users");
  const roles = users.fields.getByName("roles");
  if (roles) {
    users.fields.removeById(roles.id);
    app.save(users);
  }
});
