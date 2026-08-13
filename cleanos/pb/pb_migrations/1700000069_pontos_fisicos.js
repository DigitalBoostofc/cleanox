/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Pontos físicos (endereços da empresa) + vínculo na OS.
 *
 * - Coleção `pontos_fisicos` (CRUD admin/gerente)
 * - OS.local_tipo: cliente | ponto_fisico
 * - OS.ponto_fisico: relation → pontos_fisicos
 *
 * Quando local_tipo=ponto_fisico, hooks usam o endereço do ponto
 * (bairro denorm + endereco_liberado), não o do cliente.
 */
migrate(
  (app) => {
    const COFRE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';

    function tryFind(nameOrId) {
      try {
        return app.findCollectionByNameOrId(nameOrId);
      } catch (_) {
        return null;
      }
    }

    // ── pontos_fisicos ──────────────────────────────────────────────────────
    let pontos = tryFind("pontos_fisicos") || tryFind("pontosfisicos0001");
    if (!pontos) {
      pontos = new Collection({
        type: "base",
        name: "pontos_fisicos",
        id: "pontosfisicos0001",
        listRule: COFRE,
        viewRule: COFRE,
        createRule: COFRE,
        updateRule: COFRE,
        deleteRule: COFRE,
      });
      pontos.fields.add(new TextField({ name: "nome", required: true, max: 120 }));
      pontos.fields.add(
        new TextField({ name: "endereco_cep", required: false, max: 16 }),
      );
      pontos.fields.add(
        new TextField({ name: "endereco_rua", required: false, max: 200 }),
      );
      pontos.fields.add(
        new TextField({ name: "endereco_numero", required: false, max: 40 }),
      );
      pontos.fields.add(
        new TextField({ name: "endereco_complemento", required: false, max: 120 }),
      );
      pontos.fields.add(
        new TextField({ name: "endereco_bairro", required: false, max: 120 }),
      );
      pontos.fields.add(
        new TextField({ name: "endereco_cidade", required: false, max: 120 }),
      );
      pontos.fields.add(
        new TextField({ name: "endereco_estado", required: false, max: 2 }),
      );
      pontos.fields.add(new BoolField({ name: "ativo", required: false }));
      pontos.fields.add(
        new TextField({ name: "observacoes", required: false, max: 400 }),
      );
      app.save(pontos);
    }

    // ── ordens_servico ──────────────────────────────────────────────────────
    const os = app.findCollectionByNameOrId("ordens_servico");
    let mudou = false;

    if (!os.fields.getByName("local_tipo")) {
      os.fields.add(
        new SelectField({
          name: "local_tipo",
          required: false,
          maxSelect: 1,
          values: ["cliente", "ponto_fisico"],
        }),
      );
      mudou = true;
    }

    if (!os.fields.getByName("ponto_fisico")) {
      os.fields.add(
        new RelationField({
          name: "ponto_fisico",
          required: false,
          maxSelect: 1,
          minSelect: 0,
          collectionId: pontos.id,
          cascadeDelete: false,
        }),
      );
      mudou = true;
    }

    if (mudou) app.save(os);

    // Backfill local_tipo = cliente
    try {
      const list = app.findRecordsByFilter("ordens_servico", "", "", 500, 0);
      for (let i = 0; i < (list || []).length; i++) {
        const r = list[i];
        const t = r.get("local_tipo");
        if (t == null || t === "") {
          r.set("local_tipo", "cliente");
          app.save(r);
        }
      }
    } catch (_) {}
  },
  (app) => {
    // no destructive down
  },
);
