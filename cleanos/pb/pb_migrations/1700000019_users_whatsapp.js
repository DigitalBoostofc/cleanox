/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 19: campo `whatsapp` na coleção `users`.
 *
 * Habilita a notificação "Nova OS atribuída" pelo WhatsApp do PROFISSIONAL
 * (notifyProfNovaOS em whatsapp_helpers.js): quando uma OS é criada/reatribuída
 * a um profissional, o backend manda uma mensagem no WhatsApp dele com um
 * deep-link (App Link) que abre o app direto na OS.
 *
 * O número é o contato do PRÓPRIO profissional (não é PII de cliente) — é
 * cadastrado pelo admin na tela de Usuários. Opcional: sem número, a
 * notificação apenas é pulada (degradação graciosa), nada quebra.
 *
 * IDEMPOTENTE: só adiciona o campo se ainda não existir.
 * REVERSÍVEL: o DOWN remove o campo.
 */
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    if (!users.fields.getByName("whatsapp")) {
      users.fields.add(new TextField({ name: "whatsapp", required: false, max: 30 }));
      app.save(users);
    }
  },

  (app) => {
    try {
      const users = app.findCollectionByNameOrId("users");
      const f = users.fields.getByName("whatsapp");
      if (f) {
        users.fields.removeById(f.id);
        app.save(users);
      }
    } catch (_) {}
  }
);
