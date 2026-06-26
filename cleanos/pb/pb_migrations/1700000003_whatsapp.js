/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 3: integração WhatsApp (UAZAPI).
 *
 * Adiciona:
 *   - Coleção `app_config` (singleton, só superuser via API — dados sensíveis)
 *   - Campo `aviso_a_caminho_em` em `ordens_servico`
 *   - Registro vazio em `app_config` com template padrão
 */

migrate(
  (app) => {
    // =========================================================================
    // 1) app_config — configurações globais (instância WhatsApp, etc.)
    //    SOMENTE superuser acessa via API (token da instância é dado sensível).
    // =========================================================================
    const cfg = new Collection({
      type: "base",
      name: "app_config",
      id: "appconfigwh0001",
    });
    cfg.fields.add(new TextField({ name: "whatsapp_instance_name", required: false, max: 120 }));
    // token sensível — nunca retornado ao frontend; lido só server-side via hook
    cfg.fields.add(new TextField({ name: "whatsapp_instance_token", required: false, max: 500 }));
    cfg.fields.add(new TextField({ name: "whatsapp_status", required: false, max: 50 }));
    cfg.fields.add(
      new TextField({
        name: "aviso_template",
        required: false,
        max: 1000,
      })
    );
    cfg.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));
    cfg.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));

    // SOMENTE superuser — nenhum papel de negócio lê/escreve via API.
    // Deixar null implica "somente superuser" no PocketBase (regra mais restritiva).
    cfg.listRule   = null;
    cfg.viewRule   = null;
    cfg.createRule = null;
    cfg.updateRule = null;
    cfg.deleteRule = null;
    app.save(cfg);

    // Registro singleton com template padrão
    const DEFAULT_TEMPLATE =
      "Olá {nome}! Aqui é da Cleanox. Nosso profissional está a caminho para o serviço de {servico}. Qualquer dúvida, fale com a gente por aqui. 🚐";

    const record = new Record(cfg);
    record.set("whatsapp_instance_name", "");
    record.set("whatsapp_instance_token", "");
    record.set("whatsapp_status", "");
    record.set("aviso_template", DEFAULT_TEMPLATE);
    app.save(record);

    // =========================================================================
    // 2) ordens_servico — campo `aviso_a_caminho_em` (date, opcional)
    //    Gravado SOMENTE server-side pelo hook da rota /a-caminho.
    //    O guard existente em os_logic.js já bloqueia campos fora da lista
    //    permitida ao profissional, então nenhum profissional pode gravar direto.
    // =========================================================================
    const ordens = app.findCollectionByNameOrId("ordserv00000001");
    ordens.fields.add(
      new DateField({ name: "aviso_a_caminho_em", required: false })
    );
    app.save(ordens);
  },

  // ── DOWN ──────────────────────────────────────────────────────────────────
  (app) => {
    try {
      const ordens = app.findCollectionByNameOrId("ordserv00000001");
      const f = ordens.fields.getByName("aviso_a_caminho_em");
      if (f) ordens.fields.removeById(f.id);
      app.save(ordens);
    } catch (_) {}

    try {
      app.delete(app.findCollectionByNameOrId("appconfigwh0001"));
    } catch (_) {}
  }
);
