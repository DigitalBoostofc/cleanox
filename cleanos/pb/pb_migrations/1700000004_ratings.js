/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 4: sistema de avaliação do prestador (orquestrado por n8n).
 *
 * Adiciona:
 *   - Campos de avaliação em `ordens_servico`:
 *       avaliacao_nota, avaliacao_motivo, avaliacao_em, avaliacao_solicitada_em
 *   - Campos de template editáveis em `app_config`:
 *       avaliacao_poll_texto, avaliacao_motivo_texto, avaliacao_agradecimento
 */

migrate(
  (app) => {
    // =========================================================================
    // 1) ordens_servico — campos de avaliação
    //    Gravados SOMENTE pelo n8n via endpoint de serviço ou pelo trigger server-side.
    //    O guard existente em os_logic.js bloqueia o profissional de escrever nesses campos.
    // =========================================================================
    const ordens = app.findCollectionByNameOrId("ordserv00000001");
    ordens.fields.add(new NumberField({ name: "avaliacao_nota",         required: false }));
    ordens.fields.add(new TextField ({  name: "avaliacao_motivo",       required: false }));
    ordens.fields.add(new DateField  ({ name: "avaliacao_em",           required: false }));
    ordens.fields.add(new DateField  ({ name: "avaliacao_solicitada_em", required: false }));
    app.save(ordens);

    // =========================================================================
    // 2) app_config — templates de avaliação editáveis pelo admin/gerente
    //    via POST /api/cleanos/whatsapp/config.
    //    A coleção continua superuser-only no acesso direto (/api/collections/app_config).
    // =========================================================================
    const cfg = app.findCollectionByNameOrId("appconfigwh0001");
    cfg.fields.add(new TextField({ name: "avaliacao_poll_texto",    required: false, max: 500 }));
    cfg.fields.add(new TextField({ name: "avaliacao_motivo_texto",  required: false, max: 500 }));
    cfg.fields.add(new TextField({ name: "avaliacao_agradecimento", required: false, max: 500 }));
    app.save(cfg);

    // =========================================================================
    // 3) Preenche defaults no registro singleton
    // =========================================================================
    const cfgRecord = app.findFirstRecordByFilter("app_config", "id != ''");
    cfgRecord.set("avaliacao_poll_texto",    "Como foi o serviço de {servico}? Toque pra avaliar 👇");
    cfgRecord.set("avaliacao_motivo_texto",  "Poxa, queremos melhorar! Conta pra gente: o que não foi bom no atendimento? 🙏");
    cfgRecord.set("avaliacao_agradecimento", "Muito obrigado pela sua avaliação! 💙 Conte sempre com a Cleanox.");
    app.save(cfgRecord);
  },

  // ── DOWN ──────────────────────────────────────────────────────────────────
  (app) => {
    try {
      const ordens = app.findCollectionByNameOrId("ordserv00000001");
      const campos = ["avaliacao_nota", "avaliacao_motivo", "avaliacao_em", "avaliacao_solicitada_em"];
      for (let i = 0; i < campos.length; i++) {
        const f = ordens.fields.getByName(campos[i]);
        if (f) ordens.fields.removeById(f.id);
      }
      app.save(ordens);
    } catch (_) {}

    try {
      const cfg = app.findCollectionByNameOrId("appconfigwh0001");
      const campos = ["avaliacao_poll_texto", "avaliacao_motivo_texto", "avaliacao_agradecimento"];
      for (let i = 0; i < campos.length; i++) {
        const f = cfg.fields.getByName(campos[i]);
        if (f) cfg.fields.removeById(f.id);
      }
      app.save(cfg);
    } catch (_) {}
  }
);
