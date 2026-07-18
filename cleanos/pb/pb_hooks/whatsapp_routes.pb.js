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

  // Se o token antigo for de outro host uazapi (ex.: migração de conta),
  // /instance/status falha e precisamos recriar a instância nesta conta.
  if (instanceToken) {
    try {
      uazapi.instanceStatus(instanceToken);
    } catch (probeErr) {
      console.error("[whatsapp/connect] token inválido neste UAZAPI, recriando: " + probeErr);
      instanceToken = "";
      cfg.set("whatsapp_instance_token", "");
      cfg.set("whatsapp_instance_name", "");
      cfg.set("whatsapp_status", "disconnected");
      $app.save(cfg);
    }
  }

  if (!instanceToken) {
    // Nome único por conta (evita colisão se "cleanox" já existir)
    const instName = "cleanox-ops";
    const created = uazapi.createInstance(instName);
    instanceToken = created.token || (created.instance && created.instance.token) || "";
    if (!instanceToken) {
      throw new BadRequestError("UAZAPI não retornou token da instância na criação.");
    }
    cfg.set("whatsapp_instance_name", created.name || instName);
    cfg.set("whatsapp_instance_token", instanceToken);
    cfg.set("whatsapp_status", "disconnected");
    $app.save(cfg);
  }

  let connRes;
  try {
    connRes = uazapi.connectInstance(instanceToken);
  } catch (connErr) {
    console.error("[whatsapp/connect] Erro UAZAPI connect: " + connErr);
    throw new BadRequestError("Falha ao conectar WhatsApp: " + String(connErr));
  }
  const inst    = h.extractInstance(connRes);
  const status  = inst.status || connRes.status || "connecting";

  cfg.set("whatsapp_status", status);
  $app.save(cfg);

  // QR pode vir em instance.qrcode ou no topo da resposta
  let qrcode = inst.qrcode || connRes.qrcode || null;
  if (qrcode && typeof qrcode === "string" && qrcode.indexOf("data:") !== 0 && qrcode.indexOf("http") !== 0) {
    qrcode = "data:image/png;base64," + qrcode;
  }

  const payload = { status: status, qrcode: qrcode };
  const pair = inst.paircode || connRes.paircode;
  if (pair) payload.paircode = pair;
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
  // F-502: OS sem cliente associado → 400 explícito (espelha o guard de /relatorio).
  // Sem isso, clienteId vazio levaria findRecordById a um 404/500 cru.
  const clienteId     = lib.relId(os.get("cliente"));
  if (!clienteId) {
    throw new BadRequestError("Esta OS não possui cliente associado.");
  }
  const cliente       = $app.findRecordById("clientes", clienteId);
  const telefoneBruto = cliente.getString("telefone");
  const numero        = uazapi.normalizePhone(telefoneBruto);

  // F-502: telefone ausente/inválido → normalizePhone devolve "". Aborta com erro
  // de negócio em vez de seguir para o sendText com número vazio.
  if (!numero) {
    throw new BadRequestError("O cliente desta OS não possui telefone válido para o aviso.");
  }

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

  // 10b) doc 09 §3 — rastreamento: RESETA os carimbos de aviso desta viagem para
  //      que o cron possa reenviar Msg2/Msg3 (idempotência por viagem), e
  //      geocodifica o destino se ainda não tiver dest_lat/lng. A degradação é
  //      graciosa: sem GOOGLE_MAPS_API_KEY o destino fica nulo e o cron
  //      simplesmente não avança (Cheguei manual continua funcionando).
  os.set("aviso_5min_em", null);
  os.set("aviso_1min_em", null);
  os.set("cheguei_em", null);

  const temDestino = !isNaN(Number(os.get("dest_lat"))) && Number(os.get("dest_lat")) !== 0 &&
                     !isNaN(Number(os.get("dest_lng"))) && Number(os.get("dest_lng")) !== 0;
  if (!temDestino) {
    try {
      const maps = require(`${__hooks}/maps.js`);
      const coord = maps.geocode(lib.buildEndereco(cliente));
      if (coord) {
        os.set("dest_lat", coord.lat);
        os.set("dest_lng", coord.lng);
      }
    } catch (errGeo) {
      console.error("[a-caminho] geocode do destino falhou (ignorado): " + errGeo);
    }
  }

  $app.save(os);

  // NUNCA retorna número, texto com número, nem telefone.
  return e.json(200, { ok: true, sentAt });
}, $apis.requireAuth());

// ── GET /api/cleanos/os/{id}/contato-cliente ─────────────────────────────────
// Pedido do dono (2026-07-18): profissional dono da OS abre WhatsApp do CLIENTE
// (wa.me) para combinar horário/chegada ANTES ou DEPOIS de Iniciar.
//
// - só profissional dono da OS;
// - só em `atribuida` ou `em_andamento` (não em concluída/cancelada/agendada);
// - telefone lido do COFRE `clientes` na hora — NÃO grava na OS;
// - resposta: { ok, waUrl } (o app abre externo). O número vai na URL do wa.me
//   (inevitável para deep-link); não devolvemos o telefone cru em outro campo.
routerAdd("GET", "/api/cleanos/os/{id}/contato-cliente", (e) => {
  const uazapi = require(`${__hooks}/uazapi.js`);
  const lib = require(`${__hooks}/os_logic.js`);

  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  if (String(e.auth.get("role")) !== "profissional") {
    throw new ForbiddenError("Rota exclusiva para o papel profissional.");
  }

  const osId = e.request.pathValue("id");
  const os = $app.findRecordById("ordens_servico", osId);

  const profId = lib.relId(os.get("profissional"));
  if (profId !== String(e.auth.id)) {
    throw new ForbiddenError("Você não está atribuído a esta OS.");
  }

  const status = os.getString("status");
  if (status !== "atribuida" && status !== "em_andamento") {
    throw new BadRequestError(
      "Contato com o cliente só está disponível em OS atribuída ou em andamento."
    );
  }

  const clienteId = lib.relId(os.get("cliente"));
  if (!clienteId) {
    throw new BadRequestError("Esta OS não possui cliente associado.");
  }
  const cliente = $app.findRecordById("clientes", clienteId);
  const numero = uazapi.normalizePhone(cliente.getString("telefone"));
  if (!numero) {
    throw new BadRequestError(
      "O cliente desta OS não possui telefone válido para WhatsApp."
    );
  }

  // Prefill curto, sem PII extra; o profissional completa a conversa.
  const nome = os.getString("nome_curto") || "cliente";
  const texto = encodeURIComponent(
    "Olá, " + nome + "! Aqui é o profissional da Cleanox."
  );
  const waUrl = "https://wa.me/" + numero + "?text=" + texto;

  return e.json(200, { ok: true, waUrl: waUrl });
}, $apis.requireAuth());

// ── POST /api/cleanos/os/{id}/relatorio ──────────────────────────────────────
// Envia o RELATÓRIO FINAL da OS ao cliente por WhatsApp (uazapi) e grava
// relatorio_enviado_em na OS. A mensagem é montada server-side a partir dos
// dados REAIS da OS (service_snapshot, checklist_exec, adicionais, observacoes_prof).
// Mesma infra do /a-caminho: 409 quando o WhatsApp da empresa não está conectado.
routerAdd("POST", "/api/cleanos/os/{id}/relatorio", (e) => {
  // RATE-LIMIT por OS (throttle): cada POST dispara uma mensagem WhatsApp ao
  // cliente; sem limite, um duplo-clique/retry/abuso spamma o cliente. Como a v0.39
  // deste binário não expõe $apis.rateLimit e o estado em memória não é confiável
  // entre as VMs isoladas dos handlers, o throttle é PERSISTENTE e por-recurso:
  // usa o carimbo `relatorio_enviado_em` (já gravado ao final do envio) como
  // cooldown. Um novo envio dentro de RELATORIO_COOLDOWN_SEG após o último → 429.
  // Reenvio legítimo (relatório corrigido) continua possível após o cooldown.
  const RELATORIO_COOLDOWN_SEG = 60;
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

    // Resumo financeiro (espelha calcTotalOS do frontend: principal + adicionais − descontos)
    const descontos = Math.max(0, Number(os.get("descontos") || 0));
    const total = Math.max(0, valorPrincipal + valorAdicionais - descontos);
    lines.push("💰 *Resumo financeiro:*");
    lines.push("   Serviço: " + brl(valorPrincipal));
    if (valorAdicionais > 0) lines.push("   Adicionais: " + brl(valorAdicionais));
    if (descontos > 0) lines.push("   Descontos: -" + brl(descontos));
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

  // 4b) RATE-LIMIT por OS: bloqueia reenvio dentro do cooldown desde o último
  //     `relatorio_enviado_em`. Antes de qualquer chamada externa (UAZAPI/send).
  const ultimoEnvio = os.getString("relatorio_enviado_em"); // "" se nunca enviado
  if (ultimoEnvio) {
    const ultimoMs = new Date(ultimoEnvio).getTime();
    if (!isNaN(ultimoMs)) {
      const decorridoSeg = (Date.now() - ultimoMs) / 1000;
      if (decorridoSeg >= 0 && decorridoSeg < RELATORIO_COOLDOWN_SEG) {
        const faltamSeg = Math.ceil(RELATORIO_COOLDOWN_SEG - decorridoSeg);
        return e.json(429, {
          error: "Relatório já enviado há pouco. Aguarde " + faltamSeg +
            "s para reenviar.",
          retryAfter: faltamSeg,
        });
      }
    }
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

  // Telefone ausente/inválido → normalizePhone devolve "". Aborta com erro de
  // negócio em vez de mandar sendText a um número vazio (espelha /a-caminho).
  if (!numero) {
    throw new BadRequestError("O cliente desta OS não possui telefone válido para o relatório.");
  }

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

  // 10) Grava relatorio_enviado_em ANTES do envio (check-and-set: requisições
  //     concorrentes que passarem no cooldown acima verão o carimbo persistido
  //     e serão bloqueadas em 429; não espera o envio externo para gravar).
  const sentAt = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
  os.set("relatorio_enviado_em", sentAt);
  $app.save(os);

  // 11) Envia a mensagem.
  uazapi.sendText(instanceToken, numero, texto);

  // NUNCA retorna número, texto com número, nem telefone.
  return e.json(200, { ok: true, sentAt });
}, $apis.requireAuth());

// ── POST /api/cleanos/os/{id}/posicao ────────────────────────────────────────
// doc 09 §3 — grava a posição GPS atual do profissional (enviada pelo app, mesmo
// em background). Na 1ª posição, geocodifica o endereço do cofre → dest_lat/lng.
// Espelha /a-caminho: auth profissional dono + OS em_andamento; escrita server-side
// (bypass do guard de campo). NUNCA expõe telefone/endereço do cliente na resposta.
routerAdd("POST", "/api/cleanos/os/{id}/posicao", (e) => {
  const lib  = require(`${__hooks}/os_logic.js`);
  const maps = require(`${__hooks}/maps.js`);

  // 1) Auth: profissional autenticado.
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  if (String(e.auth.get("role")) !== "profissional") {
    throw new ForbiddenError("Rota exclusiva para o papel profissional.");
  }

  // 2) Carrega a OS (404 automático se não existir).
  const osId = e.request.pathValue("id");
  const os   = $app.findRecordById("ordens_servico", osId);

  // 3) Dono.
  if (lib.relId(os.get("profissional")) !== String(e.auth.id)) {
    throw new ForbiddenError("Você não está atribuído a esta OS.");
  }

  // 4) Status.
  if (os.getString("status") !== "em_andamento") {
    throw new BadRequestError("A OS precisa estar em_andamento para enviar posição.");
  }

  // 5) Body {lat, lng} — valida números plausíveis.
  const data = e.requestInfo().body || {};
  const lat  = Number(data.lat);
  const lng  = Number(data.lng);
  if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw new BadRequestError("Coordenadas inválidas (lat/lng).");
  }

  // 6) Grava posição server-side.
  const nowStr = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
  os.set("prof_lat", lat);
  os.set("prof_lng", lng);
  os.set("prof_pos_em", nowStr);

  // 7) 1ª posição: geocodifica o destino a partir do cofre (server-side).
  //    Degradação graciosa: sem chave/erro → dest fica nulo, cron não avança.
  const temDestino = !isNaN(Number(os.get("dest_lat"))) && Number(os.get("dest_lat")) !== 0 &&
                     !isNaN(Number(os.get("dest_lng"))) && Number(os.get("dest_lng")) !== 0;
  if (!temDestino) {
    try {
      const cid = lib.relId(os.get("cliente"));
      if (cid) {
        const cliente = $app.findRecordById("clientes", cid);
        const coord   = maps.geocode(lib.buildEndereco(cliente));
        if (coord) {
          os.set("dest_lat", coord.lat);
          os.set("dest_lng", coord.lng);
        }
      }
    } catch (errGeo) {
      console.error("[posicao] geocode do destino falhou (ignorado): " + errGeo);
    }
  }

  $app.save(os);

  // NUNCA retorna endereço/telefone. Só confirma o recebimento.
  return e.json(200, { ok: true });
}, $apis.requireAuth());

// ── POST /api/cleanos/os/{id}/cheguei ────────────────────────────────────────
// doc 09 §3 — o profissional chegou ao local: envia aviso_cheguei_texto ao cliente
// (best-effort), grava cheguei_em e ENCERRA o rastreamento (o cron para de mandar
// avisos). Espelha /a-caminho na auth; a gravação de cheguei_em acontece SEMPRE
// (mesmo com WhatsApp fora), para o rastreamento sempre encerrar de forma confiável.
routerAdd("POST", "/api/cleanos/os/{id}/cheguei", (e) => {
  const h      = require(`${__hooks}/whatsapp_helpers.js`);
  const uazapi = require(`${__hooks}/uazapi.js`);
  const lib    = require(`${__hooks}/os_logic.js`);

  // 1) Auth: profissional dono.
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  if (String(e.auth.get("role")) !== "profissional") {
    throw new ForbiddenError("Rota exclusiva para o papel profissional.");
  }
  const osId = e.request.pathValue("id");
  const os   = $app.findRecordById("ordens_servico", osId);
  if (lib.relId(os.get("profissional")) !== String(e.auth.id)) {
    throw new ForbiddenError("Você não está atribuído a esta OS.");
  }
  if (os.getString("status") !== "em_andamento") {
    throw new BadRequestError("A OS precisa estar em_andamento para registrar a chegada.");
  }

  // 2) Tenta avisar o cliente (best-effort). Telefone lido do cofre server-side.
  let avisoEnviado = false;
  try {
    const cfg           = h.getAppConfig($app);
    const instanceToken = cfg.getString("whatsapp_instance_token");
    if (instanceToken) {
      let wStatus = "disconnected";
      try {
        const inst = h.extractInstance(uazapi.instanceStatus(instanceToken));
        wStatus = inst.status || "disconnected";
        cfg.set("whatsapp_status", wStatus);
        $app.save(cfg);
      } catch (errSt) {
        wStatus = cfg.getString("whatsapp_status") || "disconnected";
        console.error("[cheguei] Erro ao verificar status UAZAPI: " + errSt);
      }

      if (wStatus === "connected") {
        const cid = lib.relId(os.get("cliente"));
        if (cid) {
          const cliente = $app.findRecordById("clientes", cid);
          const numero  = uazapi.normalizePhone(cliente.getString("telefone"));
          if (numero) {
            const template = cfg.getString("aviso_cheguei_texto") ||
              "Nosso profissional da Cleanox chegou ao local para o serviço de {servico}. 🚪";
            const texto = template
              .replace(/{nome}/g, os.getString("nome_curto") || "Cliente")
              .replace(/{servico}/g, os.getString("tipo_servico_nome") || "serviço");
            uazapi.sendText(instanceToken, numero, texto);
            avisoEnviado = true;
          }
        }
      }
    }
  } catch (errMsg) {
    // Falha no aviso NUNCA impede o encerramento do rastreamento.
    console.error("[cheguei] Falha ao enviar aviso de chegada (ignorado): " + errMsg);
  }

  // 3) Grava cheguei_em SEMPRE (server-side) → encerra o rastreamento (cron para).
  const sentAt = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
  os.set("cheguei_em", sentAt);
  $app.save(os);

  // NUNCA retorna número/telefone. avisoEnviado indica se o WhatsApp saiu.
  return e.json(200, { ok: true, sentAt, avisoEnviado });
}, $apis.requireAuth());

// ── POST /api/cleanos/push/register ──────────────────────────────────────────
// doc 09 §3 — o app registra/atualiza o token FCM do dispositivo do profissional.
// Upsert por (usuario, plataforma): 1 token por plataforma por profissional.
// Escrita server-side ($app.save, bypass de regra) mas SEMPRE escopada ao próprio
// usuário autenticado — nunca grava token em nome de outro.
routerAdd("POST", "/api/cleanos/push/register", (e) => {
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");

  const data       = e.requestInfo().body || {};
  const token      = String(data.token || "").trim();
  let   plataforma = String(data.plataforma || "").trim().toLowerCase();
  if (!token) {
    throw new BadRequestError("token é obrigatório.");
  }
  const PLATS = ["android", "ios", "web"];
  if (PLATS.indexOf(plataforma) === -1) plataforma = "android"; // default seguro

  const userId = String(e.auth.id);

  // Upsert por (usuario, plataforma).
  let rec = null;
  try {
    rec = $app.findFirstRecordByFilter(
      "push_tokens",
      "usuario = {:u} && plataforma = {:p}",
      { u: userId, p: plataforma }
    );
  } catch (_) {
    rec = null; // não existe ainda
  }

  if (rec) {
    rec.set("token", token);
    $app.save(rec);
  } else {
    try {
      const col = $app.findCollectionByNameOrId("push_tokens");
      rec = new Record(col);
      rec.set("usuario", userId);
      rec.set("token", token);
      rec.set("plataforma", plataforma);
      $app.save(rec);
    } catch (errCreate) {
      // Corrida: outro POST concorrente criou o registro entre o find e o create,
      // violando o índice único (usuario, plataforma). Refaz find+update em vez de
      // devolver 500. NUNCA vaza dado sensível — só (re)grava o token do próprio user.
      const again = $app.findFirstRecordByFilter(
        "push_tokens",
        "usuario = {:u} && plataforma = {:p}",
        { u: userId, p: plataforma }
      );
      again.set("token", token);
      $app.save(again);
    }
  }

  return e.json(200, { ok: true, plataforma });
}, $apis.requireAuth());
