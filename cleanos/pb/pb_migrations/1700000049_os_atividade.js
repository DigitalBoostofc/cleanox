/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 49: atividade / comentários de OS + notificações in-app.
 *
 * Feed interno (admin/gerente only — profissional NÃO lê):
 *   - `os_atividade`: comentários manuais + log automático de alterações + sistema
 *   - `notificacoes`: menções @ de admin/gerente (in-app)
 *
 * ADITIVA / REVERSÍVEL / IDEMPOTENTE.
 */

migrate(
  (app) => {
    const COFRE_INTERNO =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';

    function tryFind(id) {
      try {
        return app.findCollectionByNameOrId(id);
      } catch (_) {
        return null;
      }
    }

    const usersId = app.findCollectionByNameOrId("users").id;
    const osColId = app.findCollectionByNameOrId("ordserv00000001").id;

    // =========================================================================
    // 1) os_atividade — feed da OS (comentário | alteração | sistema)
    // =========================================================================
    if (!tryFind("osatividade00001")) {
      const c = new Collection({
        type: "base",
        name: "os_atividade",
        id: "osatividade00001",
      });

      c.fields.add(
        new RelationField({
          name: "os",
          required: true,
          maxSelect: 1,
          minSelect: 1,
          collectionId: osColId,
          cascadeDelete: true,
        }),
      );
      c.fields.add(
        new SelectField({
          name: "tipo",
          required: true,
          maxSelect: 1,
          values: ["comentario", "alteracao", "sistema"],
        }),
      );
      // Autor pode ser vazio em entradas "sistema" (cron/hook sem auth).
      c.fields.add(
        new RelationField({
          name: "autor",
          required: false,
          maxSelect: 1,
          collectionId: usersId,
          cascadeDelete: false,
        }),
      );
      c.fields.add(
        new TextField({ name: "texto", required: true, max: 4000 }),
      );
      // Só em tipo=alteracao: campo técnico + valores legíveis.
      c.fields.add(new TextField({ name: "campo", required: false, max: 80 }));
      c.fields.add(
        new TextField({ name: "valor_antes", required: false, max: 2000 }),
      );
      c.fields.add(
        new TextField({ name: "valor_depois", required: false, max: 2000 }),
      );
      // Menções @ (só admin/gerente) — multi-relation.
      c.fields.add(
        new RelationField({
          name: "mentions",
          required: false,
          maxSelect: 20,
          collectionId: usersId,
          cascadeDelete: false,
        }),
      );
      c.fields.add(
        new AutodateField({ name: "created", onCreate: true, onUpdate: false }),
      );
      c.fields.add(
        new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
      );

      c.indexes = [
        "CREATE INDEX idx_os_atividade_os_created ON os_atividade (os, created)",
      ];

      // Profissional: zero acesso. Admin/gerente: leem tudo; criam só comentários
      // (hook força tipo=comentario + autor=auth). Alteração/sistema = $app.save.
      c.listRule = COFRE_INTERNO;
      c.viewRule = COFRE_INTERNO;
      c.createRule = COFRE_INTERNO;
      c.updateRule = null; // imutável via API
      c.deleteRule = '@request.auth.role = "admin"';
      app.save(c);
    }

    // =========================================================================
    // 2) notificacoes — in-app para menções e avisos internos
    // =========================================================================
    if (!tryFind("notificacoes0001")) {
      const n = new Collection({
        type: "base",
        name: "notificacoes",
        id: "notificacoes0001",
      });

      n.fields.add(
        new RelationField({
          name: "destinatario",
          required: true,
          maxSelect: 1,
          minSelect: 1,
          collectionId: usersId,
          cascadeDelete: true,
        }),
      );
      n.fields.add(
        new SelectField({
          name: "tipo",
          required: true,
          maxSelect: 1,
          values: ["mencao_os", "atividade_os"],
        }),
      );
      n.fields.add(new TextField({ name: "titulo", required: true, max: 200 }));
      n.fields.add(new TextField({ name: "corpo", required: false, max: 1000 }));
      n.fields.add(
        new RelationField({
          name: "os",
          required: false,
          maxSelect: 1,
          collectionId: osColId,
          cascadeDelete: true,
        }),
      );
      n.fields.add(
        new RelationField({
          name: "atividade",
          required: false,
          maxSelect: 1,
          collectionId: "osatividade00001",
          cascadeDelete: true,
        }),
      );
      n.fields.add(new BoolField({ name: "lida", required: false }));
      n.fields.add(
        new AutodateField({ name: "created", onCreate: true, onUpdate: false }),
      );
      n.fields.add(
        new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
      );

      n.indexes = [
        "CREATE INDEX idx_notif_dest_lida ON notificacoes (destinatario, lida, created)",
      ];

      // Só o dono da notificação (admin/gerente) lê/atualiza (marcar lida).
      // Create sempre server-side ($app.save).
      const OWNER =
        'destinatario = @request.auth.id && (' + COFRE_INTERNO + ")";
      n.listRule = OWNER;
      n.viewRule = OWNER;
      n.createRule = null;
      n.updateRule = OWNER;
      n.deleteRule = OWNER;
      app.save(n);
    }
  },

  (app) => {
    try {
      app.delete(app.findCollectionByNameOrId("notificacoes0001"));
    } catch (_) {}
    try {
      app.delete(app.findCollectionByNameOrId("osatividade00001"));
    } catch (_) {}
  },
);
