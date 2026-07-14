/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 24: campo `avatar` (foto de perfil) em `users`.
 *
 * FileField opcional, 1 arquivo, max 2MB, JPEG/PNG/WebP.
 * Público (não protected): avatares aparecem em cards/listas sem file token.
 * IDEMPOTENTE: só adiciona se ainda não existir.
 */
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    if (!users.fields.getByName("avatar")) {
      users.fields.add(
        new FileField({
          name: "avatar",
          required: false,
          maxSelect: 1,
          maxSize: 2 * 1024 * 1024,
          mimeTypes: ["image/jpeg", "image/png", "image/webp", "image/jpg"],
          thumbs: ["100x100", "200x200"],
        }),
      );
      app.save(users);
    }
  },

  (app) => {
    try {
      const users = app.findCollectionByNameOrId("users");
      const f = users.fields.getByName("avatar");
      if (f) {
        users.fields.removeById(f.id);
        app.save(users);
      }
    } catch (_) {
      /* coleção ausente */
    }
  },
);
