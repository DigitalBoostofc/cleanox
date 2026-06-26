/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — rotas custom WhatsApp / UAZAPI.
 *
 * IMPORTANTE: cada handler de routerAdd roda numa VM isolada do PocketBase.
 * Por isso, todo helper compartilhado é carregado via require() DENTRO de
 * cada handler — funções definidas no escopo do arquivo NÃO estão disponíveis.
 *
 * SEGURANÇA:
 *   - Rotas /whatsapp/* exigem papel admin ou gerente.
 *   - Rota /a-caminho exige papel profissional E ser o dono da OS.
 *   - O token da instância NUNCA é retornado ao frontend.
 *   - O telefone do cliente NUNCA aparece na resposta.
 *
 * ROTAS:
 *   GET  /api/cleanos/whatsapp/status      → { configured, status, instanceName, profileName? }
 *   POST /api/cleanos/whatsapp/connect     → { status, qrcode, paircode? }
 *   POST /api/cleanos/whatsapp/disconnect  → { status }
 *   POST /api/cleanos/os/{id}/a-caminho   → { ok, sentAt }  (ou 409 se desconectado)
 */

// ── GET /api/cleanos/whatsapp/status ─────────────────────────────────────────
routerAdd("GET", "/api/cleanos/whatsapp/status", (e) => {
  const h      = require(`${__hooks}/whatsapp_helpers.js`);
  const uazapi = require(`${__hooks}/uazapi.js`);

  h.requireAdminOrGerente(e);

  const cfg           = h.getAppConfig($app);
  const instanceName  = cfg.getString("whatsapp_instance_name");
  const instanceToken = cfg.getString("whatsapp_instance_token");

  if (!instanceToken) {
    return e.json(200, { configured: false, status: "disconnected", instanceName: "" });
  }

  let status      = cfg.getString("whatsapp_status") || "disconnected";
  let profileName = "";

  try {
    const res  = uazapi.instanceStatus(instanceToken);
    const inst = h.extractInstance(res);
    status      = inst.status      || status;
    profileName = inst.profileName || "";
    cfg.set("whatsapp_status", status);
    $app.save(cfg);
  } catch (err) {
    console.error("[whatsapp/status] Erro ao consultar UAZAPI: " + err);
  }

  const payload = { configured: true, status, instanceName };
  if (profileName) payload.profileName = profileName;
  return e.json(200, payload);
}, $apis.requireAuth());

// ── POST /api/cleanos/whatsapp/connect ───────────────────────────────────────
routerAdd("POST", "/api/cleanos/whatsapp/connect", (e) => {
  const h      = require(`${__hooks}/whatsapp_helpers.js`);
  const uazapi = require(`${__hooks}/uazapi.js`);

  h.requireAdminOrGerente(e);

  const cfg = h.getAppConfig($app);
  let instanceToken = cfg.getString("whatsapp_instance_token");

  if (!instanceToken) {
    const created = uazapi.createInstance("cleanox");
    instanceToken = created.token;
    if (!instanceToken) {
      throw new BadRequestError("UAZAPI não retornou token da instância na criação.");
    }
    cfg.set("whatsapp_instance_name", created.name || "cleanox");
    cfg.set("whatsapp_instance_token", instanceToken);
    cfg.set("whatsapp_status", "disconnected");
    $app.save(cfg);
  }

  const connRes = uazapi.connectInstance(instanceToken);
  const inst    = h.extractInstance(connRes);
  const status  = inst.status || "connecting";

  cfg.set("whatsapp_status", status);
  $app.save(cfg);

  const payload = { status, qrcode: inst.qrcode || null };
  if (inst.paircode) payload.paircode = inst.paircode;
  return e.json(200, payload);
}, $apis.requireAuth());

// ── POST /api/cleanos/whatsapp/disconnect ────────────────────────────────────
routerAdd("POST", "/api/cleanos/whatsapp/disconnect", (e) => {
  const h      = require(`${__hooks}/whatsapp_helpers.js`);
  const uazapi = require(`${__hooks}/uazapi.js`);

  h.requireAdminOrGerente(e);

  const cfg           = h.getAppConfig($app);
  const instanceToken = cfg.getString("whatsapp_instance_token");

  if (!instanceToken) {
    return e.json(200, { status: "disconnected" });
  }

  try {
    uazapi.disconnectInstance(instanceToken);
  } catch (err) {
    console.error("[whatsapp/disconnect] Erro: " + err);
  }

  cfg.set("whatsapp_status", "disconnected");
  $app.save(cfg);

  return e.json(200, { status: "disconnected" });
}, $apis.requireAuth());

// ── POST /api/cleanos/os/{id}/a-caminho ──────────────────────────────────────
routerAdd("POST", "/api/cleanos/os/{id}/a-caminho", (e) => {
  const h      = require(`${__hooks}/whatsapp_helpers.js`);
  const uazapi = require(`${__hooks}/uazapi.js`);
  const lib    = require(`${__hooks}/os_logic.js`);

  // 1) Auth: exige profissional autenticado.
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  const role = String(e.auth.get("role"));
  if (role !== "profissional") {
    throw new ForbiddenError("Rota exclusiva para o papel profissional.");
  }

  // 2) Carrega a OS (lança 404 automaticamente se não existir).
  const osId = e.request.pathValue("id");
  const os   = $app.findRecordById("ordens_servico", osId);

  // 3) Verifica que é o profissional dono.
  const profId = lib.relId(os.get("profissional"));
  if (profId !== String(e.auth.id)) {
    throw new ForbiddenError("Você não está atribuído a esta OS.");
  }

  // 4) Verifica status.
  if (os.getString("status") !== "em_andamento") {
    throw new BadRequestError(
      "A OS precisa estar em_andamento para disparar o aviso a caminho."
    );
  }

  // 5) Verificar configuração WhatsApp.
  const cfg           = h.getAppConfig($app);
  const instanceToken = cfg.getString("whatsapp_instance_token");

  if (!instanceToken) {
    return e.json(409, {
      error: "WhatsApp não configurado. Peça ao admin para conectar a instância.",
    });
  }

  // 6) Verificar status real da instância.
  let wStatus = "disconnected";
  try {
    const res  = uazapi.instanceStatus(instanceToken);
    const inst = h.extractInstance(res);
    wStatus    = inst.status || "disconnected";
    cfg.set("whatsapp_status", wStatus);
    $app.save(cfg);
  } catch (err) {
    wStatus = cfg.getString("whatsapp_status") || "disconnected";
    console.error("[a-caminho] Erro ao verificar status UAZAPI: " + err);
  }

  if (wStatus !== "connected") {
    return e.json(409, {
      error: "WhatsApp não está conectado (status: " + wStatus + "). Peça ao admin para reconectar.",
    });
  }

  // 7) Lê telefone do COFRE server-side — NUNCA expõe na resposta.
  const clienteId     = lib.relId(os.get("cliente"));
  const cliente       = $app.findRecordById("clientes", clienteId);
  const telefoneBruto = cliente.getString("telefone");
  const numero        = uazapi.normalizePhone(telefoneBruto);

  // 8) Monta o texto com placeholders simples.
  const nomeCurto = os.getString("nome_curto") || "Cliente";
  const servico   = os.getString("tipo_servico_nome") || "serviço";
  const template  = cfg.getString("aviso_template") ||
    "Olá {nome}! Aqui é da Cleanox. Nosso profissional está a caminho para o serviço de {servico}. Qualquer dúvida, fale com a gente por aqui. 🚐";
  const texto = template
    .replace(/{nome}/g, nomeCurto)
    .replace(/{servico}/g, servico);

  // 9) Envia a mensagem.
  uazapi.sendText(instanceToken, numero, texto);

  // 10) Grava aviso_a_caminho_em server-side (bypass do guard de request).
  const sentAt = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
  os.set("aviso_a_caminho_em", sentAt);
  $app.save(os);

  // NUNCA retorna número, texto com número, nem telefone.
  return e.json(200, { ok: true, sentAt });
}, $apis.requireAuth());
