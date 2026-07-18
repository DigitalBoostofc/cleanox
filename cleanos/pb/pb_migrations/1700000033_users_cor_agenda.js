/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 33: `users.cor_agenda` (cor do profissional na agenda).
 *
 * Hex `#RRGGBB` opcional. Vazio → o Flutter escolhe da paleta estável por id.
 * Seed: tenta fixar Azul p/ João Pedro e Verde p/ Hendrio Piter (se existirem).
 * IDEMPOTENTE.
 */
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    if (!users.fields.getByName("cor_agenda")) {
      users.fields.add(
        new TextField({
          name: "cor_agenda",
          required: false,
          max: 7, // "#RRGGBB"
        }),
      );
      app.save(users);
    }

    // Defaults pedidos pelo dono (só se o campo ainda estiver vazio).
    const seeds = [
      { re: /jo[aã]o\s*pedro/i, cor: "#2563EB" }, // azul
      { re: /hendrio/i, cor: "#16A34A" }, // verde
    ];
    try {
      const rows = app.findRecordsByFilter("users", 'role = "profissional"', "-created", 50, 0);
      for (const r of rows) {
        const atual = String(r.get("cor_agenda") || "").trim();
        if (atual) continue;
        const nome = String(r.get("nome") || r.get("name") || "");
        for (const s of seeds) {
          if (s.re.test(nome)) {
            r.set("cor_agenda", s.cor);
            app.save(r);
            break;
          }
        }
      }
    } catch (_) {
      /* ambiente sem profissionais ainda */
    }
  },

  (app) => {
    try {
      const users = app.findCollectionByNameOrId("users");
      const f = users.fields.getByName("cor_agenda");
      if (f) {
        users.fields.removeById(f.id);
        app.save(users);
      }
    } catch (_) {
      /* coleção ausente */
    }
  },
);
