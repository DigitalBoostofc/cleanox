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
 *   - Rota /relatorio exige admin/gerente OU o profissional dono da OS.
 *   - O token da instância NUNCA é retornado ao frontend.
 *   - O telefone do cliente NUNCA aparece na resposta.
 *
 * ROTAS:
 *   GET  /api/cleanos/whatsapp/status      → { configured, status, instanceName, profileName? }
 *   POST /api/cleanos/whatsapp/connect     → { status, qrcode, paircode? }
 *   POST /api/cleanos/whatsapp/disconnect  → { status }
 *   POST /api/cleanos/os/{id}/a-caminho   → { ok, sentAt }  (ou 409 se desconectado)
 *   POST /api/cleanos/os/{id}/relatorio   → { ok, sentAt }  (ou 409 se desconectado)
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

// ── POST /api/cleanos/os/{id}/relatorio ──────────────────────────────────────
// Envia o RELATÓRIO FINAL da OS ao cliente por WhatsApp (uazapi) e grava
// relatorio_enviado_em na OS. A mensagem é montada server-side a partir dos
// dados REAIS da OS (service_snapshot, checklist_exec, adicionais, observacoes_prof).
// Mesma infra do /a-caminho: 409 quando o WhatsApp da empresa não está conectado.
routerAdd("POST", "/api/cleanos/os/{id}/relatorio", (e) => {
  // TODO rate-limit: hoje o reenvio do relatório é ilimitado (cada POST dispara
  // uma nova mensagem ao cliente). Adicionar um throttle por OS/usuário.
  const h      = require(`${__hooks}/whatsapp_helpers.js`);
  const uazapi = require(`${__hooks}/uazapi.js`);
  const lib    = require(`${__hooks}/os_logic.js`);

  // ── Helpers locais (a VM do handler não enxerga o escopo do arquivo) ──

  // Campos JSON do PB voltam como types.JSONRaw; getString() devolve o TEXTO JSON
  // (UTF-8 correto), então JSON.parse(getString) é o caminho confiável.
  function readJSON(rec, field, fallback) {
    const s = rec.getString(field);
    if (!s) return fallback;
    try {
      const v = JSON.parse(s);
      return (v === null || v === undefined) ? fallback : v;
    } catch (_) {
      return fallback;
    }
  }

  // Formata valor em BRL sem depender de Intl: "1234.5" → "R$ 1.234,50".
  function brl(n) {
    const v = Number(n);
    const safe = isNaN(v) ? 0 : v;
    const neg = safe < 0;
    const fixed = Math.abs(safe).toFixed(2);
    const parts = fixed.split(".");
    const intPart = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ".");
    return (neg ? "-R$ " : "R$ ") + intPart + "," + parts[1];
  }

  // data_hora vem em UTC ("2026-06-25 14:00:00.000Z"); exibe em BRT (UTC-3).
  function fmtDataBRT(raw) {
    if (!raw) return "";
    const d = new Date(raw);
    if (isNaN(d.getTime())) return String(raw);
    const b = new Date(d.getTime() - 3 * 3600 * 1000);
    const p2 = function (x) { return String(x).padStart(2, "0"); };
    return p2(b.getUTCDate()) + "/" + p2(b.getUTCMonth() + 1) + "/" + b.getUTCFullYear() +
           " " + p2(b.getUTCHours()) + ":" + p2(b.getUTCMinutes());
  }

  function aprovacaoLabel(a) {
    switch (a) {
      case "nao_requer": return "Não precisa aprovar";
      case "aguardando": return "Aguardando aprovação do cliente";
      case "aprovado":   return "Aprovado";
      case "recusado":   return "Recusado";
      default:           return "";
    }
  }

  function isCobravel(a) {
    return a && (a.aprovacao === "aprovado" || a.aprovacao === "nao_requer");
  }

  // Monta o texto do relatório (espelha buildWhatsAppMessage do frontend, sem
  // o link placeholder de avaliação — o fluxo de avaliação é tratado pelo n8n).
  function buildRelatorioTexto(os, snapshot, checklist, adicionais, observacoes, profNome) {
    const lines = [];
    const numero = "#" + String(os.id).slice(-6).toUpperCase();
    lines.push("🧼 *Cleanox — Relatório de Serviço Nº " + numero + "*");
    lines.push("");
    lines.push("Olá, " + (os.getString("nome_curto") || "cliente") + "! Seu serviço foi concluído. ✅");
    lines.push("Segue o resumo do que foi executado:");
    lines.push("");

    // Serviço principal
    const servNome = (snapshot && snapshot.nome) || os.getString("tipo_servico_nome") || "Serviço";
    lines.push("🛠️ *Serviço:* " + servNome);
    const tempo = snapshot && snapshot.tempoMedioLabel ? String(snapshot.tempoMedioLabel).trim() : "";
    if (tempo) lines.push("⏱️ Tempo médio: " + tempo);
    const data = fmtDataBRT(os.getString("data_hora"));
    if (data) lines.push("📅 Data: " + data);
    if (profNome) lines.push("👤 Profissional: " + profNome);
    lines.push("");

    // Valores
    const valorPrincipal = snapshot && snapshot.valorBase != null
      ? Number(snapshot.valorBase)
      : Number(os.get("valor_servico") || 0);

    const cobraveis = (adicionais || []).filter(isCobravel);
    let valorAdicionais = 0;
    if (cobraveis.length > 0) {
      lines.push("➕ *Serviços adicionais:*");
      for (let i = 0; i < cobraveis.length; i++) {
        const a = cobraveis[i];
        const qtd = Number(a.quantidade) || 1;
        const subtotal = (Number(a.valor) || 0) * qtd;
        valorAdicionais += subtotal;
        const qtdTxt = qtd > 1 ? " (x" + qtd + ")" : "";
        lines.push("   • " + (a.nome || "Adicional") + qtdTxt + " — " + brl(subtotal) +
                   " · " + aprovacaoLabel(a.aprovacao));
      }
      lines.push("");
    }

    // Resumo financeiro
    const total = Math.max(0, valorPrincipal + valorAdicionais);
    lines.push("💰 *Resumo financeiro:*");
    lines.push("   Serviço: " + brl(valorPrincipal));
    if (valorAdicionais > 0) lines.push("   Adicionais: " + brl(valorAdicionais));
    lines.push("   *Total: " + brl(total) + "*");
    lines.push("");

    // Checklist
    const cl = checklist || [];
    if (cl.length > 0) {
      const concluidos = cl.filter(function (c) { return c.status === "concluido"; });
      lines.push("📋 *Checklist executado* (" + concluidos.length + "/" + cl.length + "):");
      for (let i = 0; i < cl.length; i++) {
        const item = cl[i];
        const mark = item.status === "concluido" ? "✓" : "◻️";
        const sufixo = item.status === "concluido" ? "" : " (pendente)";
        lines.push("   " + mark + " " + (item.titulo || "Item") + sufixo);
      }
      lines.push("");
    }

    // Observações visíveis ao cliente
    const visiveis = (observacoes || []).filter(function (o) { return o && o.visivelCliente === true; });
    if (visiveis.length > 0) {
      lines.push("📝 *Observações:*");
      for (let i = 0; i < visiveis.length; i++) {
        if (visiveis[i].texto) lines.push("   • " + visiveis[i].texto);
      }
      lines.push("");
    }

    // Orientações pós-serviço
    const orient = snapshot && snapshot.orientacoesPosServico
      ? String(snapshot.orientacoesPosServico).trim() : "";
    if (orient) {
      lines.push("🧴 *Orientações pós-serviço:*");
      lines.push("   " + orient);
      lines.push("");
    }

    // Prazo de intercorrência (espelha RELATORIO_PRAZO_DIAS = 3 do frontend)
    lines.push("⏳ Você tem até *3 dias* para relatar qualquer falha ou intercorrência. " +
               "Conte com a gente!");
    lines.push("");
    lines.push("Obrigado por escolher a Cleanox! 💙");

    return lines.join("\n");
  }

  // 1) Auth: precisa estar autenticado.
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  const role = String(e.auth.get("role"));

  // 2) Carrega a OS (lança 404 automaticamente se não existir).
  const osId = e.request.pathValue("id");
  const os   = $app.findRecordById("ordens_servico", osId);

  // 3) Permissão: admin/gerente sempre; profissional só a OS dele.
  if (role === "admin" || role === "gerente") {
    /* ok */
  } else if (role === "profissional") {
    const profId = lib.relId(os.get("profissional"));
    if (profId !== String(e.auth.id)) {
      throw new ForbiddenError("Você não está atribuído a esta OS.");
    }
  } else {
    throw new ForbiddenError("Sem permissão para enviar o relatório desta OS.");
  }

  // 4) Status: o relatório final só faz sentido com a OS em andamento ou concluída.
  const status = os.getString("status");
  if (status !== "em_andamento" && status !== "concluida") {
    throw new BadRequestError(
      "O relatório só pode ser enviado para uma OS em andamento ou concluída."
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
    console.error("[relatorio] Erro ao verificar status UAZAPI: " + err);
  }

  if (wStatus !== "connected") {
    return e.json(409, {
      error: "WhatsApp não está conectado (status: " + wStatus + "). Peça ao admin para reconectar.",
    });
  }

  // 7) Lê telefone do COFRE server-side — NUNCA expõe na resposta.
  // F-03: OS sem cliente associado → 400 explícito (sem isso, relId vazio levaria
  // findRecordById a um 404/500 cru ao montar o número).
  const clienteId = lib.relId(os.get("cliente"));
  if (!clienteId) {
    throw new BadRequestError("Esta OS não possui cliente associado.");
  }
  const cliente   = $app.findRecordById("clientes", clienteId);
  const numero    = uazapi.normalizePhone(cliente.getString("telefone"));

  // 8) Nome do profissional (best-effort; não bloqueia se ausente).
  let profNome = "";
  try {
    const pid = lib.relId(os.get("profissional"));
    if (pid) {
      const prof = $app.findRecordById("users", pid);
      profNome = prof.getString("nome") || prof.getString("name") || "";
    }
  } catch (_) { /* profissional ausente — segue sem nome */ }

  // 9) Monta a mensagem a partir dos dados ricos da OS.
  const snapshot    = readJSON(os, "service_snapshot", null);
  const checklist   = readJSON(os, "checklist_exec", []);
  const adicionais  = readJSON(os, "adicionais", []);
  const observacoes = readJSON(os, "observacoes_prof", []);
  const texto = buildRelatorioTexto(os, snapshot, checklist, adicionais, observacoes, profNome);

  // 10) Envia a mensagem.
  uazapi.sendText(instanceToken, numero, texto);

  // 11) Grava relatorio_enviado_em server-side (bypass do guard de request).
  const sentAt = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
  os.set("relatorio_enviado_em", sentAt);
  $app.save(os);

  // NUNCA retorna número, texto com número, nem telefone.
  return e.json(200, { ok: true, sentAt });
}, $apis.requireAuth());
