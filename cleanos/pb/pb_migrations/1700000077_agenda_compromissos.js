/// <reference path="../pb_data/types.d.ts" />

/**
 * Agenda — tarefas/compromissos do profissional (além das OS).
 *
 * Ocupam horário na mesma grade. Recorrência gera ocorrências no Flutter
 * (registros irmãos com o mesmo serie_id).
 */
migrate(
  (app) => {
    const COFRE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';
    const LER =
      COFRE +
      ' || (@request.auth.role = "profissional" && profissional = @request.auth.id)';

    function tryFind(nameOrId) {
      try {
        return app.findCollectionByNameOrId(nameOrId);
      } catch (_) {
        return null;
      }
    }

    if (tryFind("agenda_compromissos") || tryFind("agendacompromi01")) return;

    const users = app.findCollectionByNameOrId("users");
    const col = new Collection({
      type: "base",
      name: "agenda_compromissos",
      id: "agendacompromi01",
      listRule: LER,
      viewRule: LER,
      createRule: COFRE,
      updateRule: COFRE,
      deleteRule: COFRE,
    });
    col.fields.add(new TextField({ name: "titulo", required: true, max: 160 }));
    col.fields.add(new TextField({ name: "descricao", required: false, max: 800 }));
    col.fields.add(
      new RelationField({
        name: "profissional",
        required: true,
        maxSelect: 1,
        minSelect: 0,
        collectionId: users.id,
        cascadeDelete: false,
      }),
    );
    col.fields.add(new TextField({ name: "data_hora", required: true, max: 40 }));
    col.fields.add(
      new NumberField({ name: "duracao_min", required: true, min: 15, max: 24 * 60 }),
    );
    col.fields.add(
      new SelectField({
        name: "recorrencia",
        required: false,
        maxSelect: 1,
        values: ["nenhuma", "semanal", "mensal"],
      }),
    );
    col.fields.add(new TextField({ name: "serie_id", required: false, max: 40 }));
    col.fields.add(
      new SelectField({
        name: "status",
        required: false,
        maxSelect: 1,
        values: ["pendente", "concluida"],
      }),
    );
    app.save(col);
  },
  (app) => {
    // no destructive down
  },
);
