/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Vitrine CMS + order bumps (aprovação mockup 2026-07-21).
 *
 *  - servicos.vitrine / vitrine_destaque (flags de exibição no site)
 *  - vitrine_config (singleton operacional: textos hero, WhatsApp, rodapé)
 *  - vitrine_midia (fotos da vitrine)
 *  - vitrine_order_bumps (ofertas condicionais no orçamento)
 *
 * COFRE: só admin/gerente via rules. Público lê por rotas custom (vitrine_routes).
 * IDEMPOTENTE.
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

    // ── servicos: flags vitrine ─────────────────────────────────────────────
    const servicos = app.findCollectionByNameOrId("servicos");
    let mudouServ = false;
    if (!servicos.fields.getByName("vitrine")) {
      servicos.fields.add(new BoolField({ name: "vitrine", required: false }));
      mudouServ = true;
    }
    if (!servicos.fields.getByName("vitrine_destaque")) {
      servicos.fields.add(
        new BoolField({ name: "vitrine_destaque", required: false }),
      );
      mudouServ = true;
    }
    if (mudouServ) app.save(servicos);

    // Backfill: serviços ativos entram na vitrine por padrão
    try {
      const list = app.findRecordsByFilter("servicos", "", "", 500, 0);
      for (let i = 0; i < (list || []).length; i++) {
        const r = list[i];
        let ch = false;
        if (r.get("vitrine") == null) {
          r.set("vitrine", true);
          ch = true;
        }
        if (r.get("vitrine_destaque") == null) {
          r.set("vitrine_destaque", false);
          ch = true;
        }
        if (ch) app.save(r);
      }
    } catch (_) {
      /* best-effort */
    }

    // ── vitrine_config ──────────────────────────────────────────────────────
    if (!tryFind("vitrineconfig0001") && !tryFind("vitrine_config")) {
      const c = new Collection({
        type: "base",
        name: "vitrine_config",
        id: "vitrineconfig0001",
      });
      c.fields.add(
        new TextField({ name: "hero_titulo", required: false, max: 200 }),
      );
      c.fields.add(
        new TextField({ name: "hero_subtitulo", required: false, max: 500 }),
      );
      c.fields.add(
        new TextField({ name: "hero_cta", required: false, max: 80 }),
      );
      c.fields.add(
        new TextField({ name: "whatsapp_exibido", required: false, max: 40 }),
      );
      c.fields.add(
        new TextField({ name: "rodape_msg", required: false, max: 300 }),
      );
      c.fields.add(
        new TextField({ name: "cidades_texto", required: false, max: 500 }),
      );
      c.fields.add(
        new TextField({ name: "como_funciona", required: false, max: 2000 }),
      );
      c.fields.add(
        new AutodateField({ name: "created", onCreate: true, onUpdate: false }),
      );
      c.fields.add(
        new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
      );
      c.listRule = COFRE;
      c.viewRule = COFRE;
      c.createRule = COFRE;
      c.updateRule = COFRE;
      c.deleteRule = COFRE;
      app.save(c);

      // Seed singleton
      try {
        const col = app.findCollectionByNameOrId("vitrineconfig0001");
        const rec = new Record(col);
        rec.set("hero_titulo", "Orçamento em 1 minuto");
        rec.set(
          "hero_subtitulo",
          "Escolha o que precisa limpar e agende no horário ideal",
        );
        rec.set("hero_cta", "Montar orçamento");
        rec.set(
          "rodape_msg",
          "Pagamento só no local · maquininha Cleanox",
        );
        rec.set(
          "como_funciona",
          "1) Selecione os serviços\n2) Informe contato e endereço\n3) Veja o orçamento e ofertas\n4) Escolha data e horário\n5) Confirmamos no WhatsApp",
        );
        app.save(rec);
      } catch (_) {}
    }

    // ── vitrine_midia ───────────────────────────────────────────────────────
    if (!tryFind("vitrinemidia00001") && !tryFind("vitrine_midia")) {
      const m = new Collection({
        type: "base",
        name: "vitrine_midia",
        id: "vitrinemidia00001",
      });
      m.fields.add(new TextField({ name: "chave", required: true, max: 80 }));
      m.fields.add(new TextField({ name: "titulo", required: false, max: 120 }));
      m.fields.add(
        new FileField({
          name: "arquivo",
          required: false,
          maxSelect: 1,
          maxSize: 5 * 1024 * 1024,
          mimeTypes: ["image/jpeg", "image/png", "image/webp"],
          thumbs: ["200x200", "800x0"],
        }),
      );
      m.fields.add(new TextField({ name: "url_externa", required: false, max: 500 }));
      m.fields.add(new NumberField({ name: "ordem", required: false, min: 0 }));
      m.fields.add(new BoolField({ name: "ativo", required: false }));
      m.fields.add(
        new AutodateField({ name: "created", onCreate: true, onUpdate: false }),
      );
      m.fields.add(
        new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
      );
      m.listRule = COFRE;
      m.viewRule = COFRE;
      m.createRule = COFRE;
      m.updateRule = COFRE;
      m.deleteRule = COFRE;
      app.save(m);
    }

    // ── vitrine_order_bumps ─────────────────────────────────────────────────
    if (!tryFind("vitrinebumps00001") && !tryFind("vitrine_order_bumps")) {
      const servicosId = app.findCollectionByNameOrId("servicos").id;
      const b = new Collection({
        type: "base",
        name: "vitrine_order_bumps",
        id: "vitrinebumps00001",
      });
      b.fields.add(new TextField({ name: "titulo", required: true, max: 160 }));
      b.fields.add(
        new TextField({ name: "descricao", required: false, max: 400 }),
      );
      b.fields.add(new TextField({ name: "badge", required: false, max: 40 }));
      b.fields.add(
        new RelationField({
          name: "servico_oferta",
          required: true,
          maxSelect: 1,
          minSelect: 0,
          collectionId: servicosId,
          cascadeDelete: false,
        }),
      );
      b.fields.add(new NumberField({ name: "preco_cheio", required: false, min: 0 }));
      b.fields.add(new NumberField({ name: "preco_promo", required: true, min: 0 }));
      // qualquer_grupo | qualquer_servico
      b.fields.add(
        new SelectField({
          name: "gatilho_tipo",
          required: true,
          maxSelect: 1,
          values: ["qualquer_grupo", "qualquer_servico"],
        }),
      );
      // JSON array: ["sofa","colchao"] ou ids de serviço
      b.fields.add(new JSONField({ name: "gatilho_valores", required: false }));
      // JSON array de ids de serviço: se carrinho já tem, não mostra
      b.fields.add(new JSONField({ name: "excluir_se", required: false }));
      b.fields.add(new NumberField({ name: "prioridade", required: false, min: 0 }));
      b.fields.add(new BoolField({ name: "ativo", required: false }));
      b.fields.add(
        new FileField({
          name: "foto",
          required: false,
          maxSelect: 1,
          maxSize: 3 * 1024 * 1024,
          mimeTypes: ["image/jpeg", "image/png", "image/webp"],
          thumbs: ["200x200"],
        }),
      );
      b.fields.add(
        new AutodateField({ name: "created", onCreate: true, onUpdate: false }),
      );
      b.fields.add(
        new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
      );
      b.listRule = COFRE;
      b.viewRule = COFRE;
      b.createRule = COFRE;
      b.updateRule = COFRE;
      b.deleteRule = COFRE;
      app.save(b);
    }
  },
  (app) => {
    try {
      app.delete(app.findCollectionByNameOrId("vitrinebumps00001"));
    } catch (_) {}
    try {
      app.delete(app.findCollectionByNameOrId("vitrinemidia00001"));
    } catch (_) {}
    try {
      app.delete(app.findCollectionByNameOrId("vitrineconfig0001"));
    } catch (_) {}
    try {
      const servicos = app.findCollectionByNameOrId("servicos");
      for (const n of ["vitrine", "vitrine_destaque"]) {
        const f = servicos.fields.getByName(n);
        if (f) servicos.fields.removeById(f.id);
      }
      app.save(servicos);
    } catch (_) {}
  },
);
