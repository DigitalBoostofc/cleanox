/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 48: `users.fin_dash_layout` (JSON).
 *
 * Preferência de layout freeform do Dashboard financeiro (desktop),
 * por usuário — sincroniza entre browsers/dispositivos.
 *
 * Self-update liberado pela updateRule existente
 * (`admin|gerente || id = @request.auth.id`).
 * IDEMPOTENTE.
 */
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    if (!users.fields.getByName("fin_dash_layout")) {
      users.fields.add(
        new JSONField({
          name: "fin_dash_layout",
          required: false,
        }),
      );
      app.save(users);
    }
  },

  (app) => {
    try {
      const users = app.findCollectionByNameOrId("users");
      const f = users.fields.getByName("fin_dash_layout");
      if (f) {
        users.fields.removeById(f.id);
        app.save(users);
      }
    } catch (_) {
      /* coleção ausente */
    }
  },
);
