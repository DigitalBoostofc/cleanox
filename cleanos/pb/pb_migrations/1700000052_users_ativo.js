/// <reference path="../pb_data/types.d.ts" />
/**
 * CleanOS — Migration 52: users.ativo (bool).
 *
 * Inativo some das listas de atribuição (OS/agenda/comissões); histórico fica.
 * Na 1ª aplicação, todos os usuários existentes viram ativo=true.
 *
 * ADITIVA / IDEMPOTENTE.
 */
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    let has = false;
    users.fields.forEach((f) => {
      if (f.name === "ativo") has = true;
    });
    if (!has) {
      users.fields.add(
        new BoolField({
          name: "ativo",
          required: false,
        }),
      );
      app.save(users);
    }

    // Backfill seguro: quem ainda não foi marcado fica ativo.
    // (Campo novo no SQLite/PB costuma nascer false.)
    const rows = app.findRecordsByFilter("users", "id != ''", "", 500, 0);
    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      try {
        // Se o campo ainda não existia / veio false no backfill inicial, ativa.
        // Não re-ativa quem o admin já desativou em deploys futuros: só na
        // 1ª passada o default é false para todos — setamos true uma vez.
        if (r.get("ativo") !== true) {
          r.set("ativo", true);
          app.save(r);
        }
      } catch (_) {}
    }
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const remove = [];
    users.fields.forEach((f) => {
      if (f.name === "ativo") remove.push(f);
    });
    for (let i = 0; i < remove.length; i++) {
      users.fields.removeById(remove[i].id);
    }
    if (remove.length) app.save(users);
  },
);
