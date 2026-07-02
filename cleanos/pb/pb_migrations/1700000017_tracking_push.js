/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 17: rastreamento "estou a caminho" (GPS ao vivo) + push nativo.
 *
 * ADITIVA — não altera nada do comportamento existente. Serve ao app Flutter do
 * profissional (doc 09 §3). Todas as adições são inertes até que o app comece a
 * chamar as rotas dedicadas e as chaves de ambiente sejam providas.
 *
 * Adiciona:
 *   - `ordens_servico`: coords efêmeras do profissional + destino + carimbos de
 *      aviso idempotentes. TODOS gravados SOMENTE server-side (rotas dedicadas /
 *      cron). O guard em os_logic.js os inclui na denylist do profissional.
 *   - `app_config`: 3 templates novos (aviso_5min/1min/cheguei), editáveis pelo
 *      admin via POST /api/cleanos/whatsapp/config.
 *   - Coleção `push_tokens`: 1 registro por (profissional, plataforma) com o token
 *      FCM. Profissional cria/atualiza o próprio; admin lê.
 *
 * NOTA DE API (PocketBase v0.39 / JSVM): campos via `collection.fields.add(...)`,
 * regras por propriedade (`col.listRule = ...`). Ver migration 1.
 */

migrate(
  (app) => {
    const ADMIN_ONLY = '@request.auth.role = "admin"';
    const OWNER      = 'usuario = @request.auth.id';

    // =========================================================================
    // 1) ordens_servico — coords efêmeras + carimbos de aviso.
    //    Gravados SOMENTE server-side (rotas /posicao, /cheguei, /a-caminho e o
    //    cron trackingAvisos). O guardOrdemUpdateRequest em os_logic.js já bloqueia
    //    o profissional de escrever direto (denylist `locked`).
    // =========================================================================
    const ordens = app.findCollectionByNameOrId("ordserv00000001");

    // Posição atual do profissional (última leitura de GPS enviada pelo app).
    ordens.fields.add(new NumberField({ name: "prof_lat",   required: false }));
    ordens.fields.add(new NumberField({ name: "prof_lng",   required: false }));
    ordens.fields.add(new DateField  ({ name: "prof_pos_em", required: false }));
    // Destino (geocodificado a partir do endereço do cofre na 1ª posição / a-caminho).
    ordens.fields.add(new NumberField({ name: "dest_lat", required: false }));
    ordens.fields.add(new NumberField({ name: "dest_lng", required: false }));
    // Carimbos idempotentes dos avisos ao cliente (impedem reenvio pelo cron).
    ordens.fields.add(new DateField({ name: "aviso_5min_em", required: false }));
    ordens.fields.add(new DateField({ name: "aviso_1min_em", required: false }));
    ordens.fields.add(new DateField({ name: "cheguei_em",    required: false }));

    app.save(ordens);

    // =========================================================================
    // 2) app_config — templates editáveis dos avisos de rastreamento.
    //    A coleção continua superuser-only no acesso direto; a edição é pelo
    //    endpoint POST /api/cleanos/whatsapp/config (admin).
    // =========================================================================
    const cfg = app.findCollectionByNameOrId("appconfigwh0001");
    cfg.fields.add(new TextField({ name: "aviso_5min_texto",    required: false, max: 500 }));
    cfg.fields.add(new TextField({ name: "aviso_1min_texto",    required: false, max: 500 }));
    cfg.fields.add(new TextField({ name: "aviso_cheguei_texto", required: false, max: 500 }));
    app.save(cfg);

    // Defaults (textos do doc 09 §1). {nome}/{servico} são substituídos server-side.
    const cfgRecord = app.findFirstRecordByFilter("app_config", "id != ''");
    cfgRecord.set("aviso_5min_texto",    "+5 minutos para o profissional chegar.");
    cfgRecord.set("aviso_1min_texto",    "Está quase chegando, falta menos de 1 min. Por favor fique atento.");
    cfgRecord.set("aviso_cheguei_texto", "Nosso profissional da Cleanox chegou ao local para o serviço de {servico}. 🚪");
    app.save(cfgRecord);

    // =========================================================================
    // 3) push_tokens — 1 token FCM por (profissional, plataforma).
    //    Profissional cria/atualiza o PRÓPRIO; admin lê (para diagnóstico).
    //    O envio de push é sempre server-side (hook/rotas usam $app, bypass de regra).
    // =========================================================================
    const usersId = app.findCollectionByNameOrId("users").id;

    const pt = new Collection({
      type: "base",
      name: "push_tokens",
      id:   "pushtokens00001",
    });
    pt.fields.add(
      new RelationField({
        name:          "usuario",
        required:      true,
        maxSelect:     1,
        minSelect:     1,
        collectionId:  usersId,
        cascadeDelete: true, // remover o user limpa seus tokens
      })
    );
    pt.fields.add(new TextField({ name: "token", required: true, max: 500 }));
    pt.fields.add(
      new SelectField({
        name:      "plataforma",
        required:  false,
        maxSelect: 1,
        values:    ["android", "ios", "web"],
      })
    );
    pt.fields.add(new AutodateField({ name: "created", onCreate: true,  onUpdate: false }));
    pt.fields.add(new AutodateField({ name: "updated", onCreate: true,  onUpdate: true  }));

    // 1 token por (profissional, plataforma) — o app faz upsert por essa chave.
    pt.indexes = [
      "CREATE UNIQUE INDEX idx_push_tokens_user_plat ON push_tokens (usuario, plataforma)",
    ];

    // Isolamento por profissional: admin lê tudo; cada um só enxerga/edita o seu.
    pt.listRule   = ADMIN_ONLY + " || " + OWNER;
    pt.viewRule   = ADMIN_ONLY + " || " + OWNER;
    pt.createRule = '@request.auth.id != "" && ' + OWNER;
    pt.updateRule = '@request.auth.id != "" && ' + OWNER;
    pt.deleteRule = ADMIN_ONLY + " || " + OWNER;
    app.save(pt);
  },

  // ── DOWN ──────────────────────────────────────────────────────────────────
  (app) => {
    try { app.delete(app.findCollectionByNameOrId("pushtokens00001")); } catch (_) {}

    try {
      const cfg = app.findCollectionByNameOrId("appconfigwh0001");
      const campos = ["aviso_5min_texto", "aviso_1min_texto", "aviso_cheguei_texto"];
      for (let i = 0; i < campos.length; i++) {
        const f = cfg.fields.getByName(campos[i]);
        if (f) cfg.fields.removeById(f.id);
      }
      app.save(cfg);
    } catch (_) {}

    try {
      const ordens = app.findCollectionByNameOrId("ordserv00000001");
      const campos = [
        "prof_lat", "prof_lng", "prof_pos_em",
        "dest_lat", "dest_lng",
        "aviso_5min_em", "aviso_1min_em", "cheguei_em",
      ];
      for (let i = 0; i < campos.length; i++) {
        const f = ordens.fields.getByName(campos[i]);
        if (f) ordens.fields.removeById(f.id);
      }
      app.save(ordens);
    } catch (_) {}
  }
);
