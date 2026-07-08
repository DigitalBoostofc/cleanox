/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — rotas de avaliação e configuração de templates.
 *
 * IMPORTANTE: cada handler de routerAdd roda numa VM isolada do PocketBase.
 * Helpers compartilhados são carregados via require() DENTRO de cada handler.
 * $app, $os, $http, $dbx e as classes de erro são globais PocketBase disponíveis
 * no contexto de execução de cada handler.
 *
 * ROTAS DE SERVIÇO (sem auth de usuário PocketBase; autenticadas por x-cleanos-secret):
 *   POST /api/cleanos/ratings/ingest
 *     Body:    { os_id: string, nota?: number(1-5), motivo?: string }
 *     Returns: { ok: true, nota: number|null, needsReason: boolean }
 *
 *   GET  /api/cleanos/ratings/pending?phone=<E164>
 *     Returns: { os_id: string, servico: string } | { os_id: null }
 *
 * ROTAS DE CONFIGURAÇÃO (auth de usuário PocketBase — admin/gerente):
 *   GET  /api/cleanos/whatsapp/config
 *     Returns: { aviso_template, avaliacao_poll_texto, avaliacao_motivo_texto, avaliacao_agradecimento }
 *
 *   POST /api/cleanos/whatsapp/config  (só admin)
 *     Body:    qualquer subconjunto dos 4 campos acima
 *     Returns: estado completo dos 4 campos após a atualização
 *
 * SEGURANÇA:
 *   - Endpoints de serviço: validam `x-cleanos-secret` == $CLEANOS_SERVICE_SECRET.
 *     Se a env var não estiver definida, TODOS os requests retornam 401.
 *   - Token da instância WhatsApp NUNCA é retornado em nenhuma resposta.
 *   - Telefone do cliente NUNCA é retornado (lido server-side apenas).
 */

// ── POST /api/cleanos/ratings/ingest ─────────────────────────────────────────
routerAdd("POST", "/api/cleanos/ratings/ingest", (e) => {
  // 1) Validação do segredo de serviço
  // PocketBase normaliza headers em requestInfo(): lowercase e hífens → underscores.
  // "X-Cleanos-Secret" vira "x_cleanos_secret".
  const secret = $os.getenv("CLEANOS_SERVICE_SECRET") || "";
  const hdrs   = e.requestInfo().headers || {};
  const clientSecret = String(hdrs["x_cleanos_secret"] || "");
  if (!secret || clientSecret !== secret) {
    return e.json(401, { error: "Unauthorized" });
  }

  // 2) Parse do body
  const data  = e.requestInfo().body || {};
  const osId  = String(data.os_id || "");
  if (!osId) {
    return e.json(400, { error: "os_id é obrigatório" });
  }

  const notaRaw = data.nota;
  const nota    = notaRaw != null ? Number(notaRaw) : null;
  const motivo  = data.motivo != null ? String(data.motivo) : null;

  if (nota !== null && (isNaN(nota) || !Number.isInteger(nota) || nota < 1 || nota > 5)) {
    return e.json(400, { error: "nota deve ser um inteiro entre 1 e 5" });
  }

  // 3) Carrega a OS
  let os;
  try {
    os = $app.findRecordById("ordens_servico", osId);
  } catch (_) {
    return e.json(404, { error: "OS não encontrada" });
  }

  if (os.getString("status") !== "concluida") {
    return e.json(400, { error: "OS não está concluida" });
  }

  // 4) Aplica campos (idempotente — cada campo só é tocado se enviado)
  if (nota !== null) {
    const nowStr = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
    os.set("avaliacao_nota", nota);
    os.set("avaliacao_em", nowStr);
  }

  if (motivo !== null && motivo.trim() !== "") {
    os.set("avaliacao_motivo", motivo.trim());
  }

  // 5) Persiste — dispara hooks de modelo (assertPaymentIfConcluida passa pois OS já tem pagamento;
  //    triggerRatingWebhookIfConcluida não dispara de novo pois status original == concluida)
  $app.save(os);

  // 6) Calcula needsReason a partir do estado final da OS
  const finalNotaRaw = os.get("avaliacao_nota");
  const finalNota    = (finalNotaRaw !== null && finalNotaRaw !== undefined && Number(finalNotaRaw) >= 1)
    ? Number(finalNotaRaw)
    : null;
  const finalMotivo  = String(os.get("avaliacao_motivo") || "").trim();
  const needsReason  = finalNota !== null && finalNota >= 1 && finalNota <= 3 && !finalMotivo;

  return e.json(200, { ok: true, nota: finalNota, needsReason });
});

// ── GET /api/cleanos/ratings/pending ─────────────────────────────────────────
routerAdd("GET", "/api/cleanos/ratings/pending", (e) => {
  // 1) Validação do segredo de serviço (header normalizado: X-Cleanos-Secret → x_cleanos_secret)
  const secret = $os.getenv("CLEANOS_SERVICE_SECRET") || "";
  const hdrs   = e.requestInfo().headers || {};
  const clientSecret = String(hdrs["x_cleanos_secret"] || "");
  if (!secret || clientSecret !== secret) {
    return e.json(401, { error: "Unauthorized" });
  }

  const lib = require(`${__hooks}/os_logic.js`);

  // 2) Valida o telefone buscado (normalização e match feitos por phonesMatch)
  const rawPhone = String(e.requestInfo().query["phone"] || "");
  if (!rawPhone) {
    return e.json(400, { error: "Parâmetro phone é obrigatório" });
  }

  // 3) Janela de 7 dias — o corte de data agora vai no WHERE do SQL (não em JS).
  const sevenDaysAgo = new Date(Date.now() - 7 * 86400000).toISOString().replace("T", " ").slice(0, 23) + "Z";

  // 4) Candidatas em SQL: WHERE + ORDER BY + LIMIT/OFFSET em nível de banco (via
  //    findRecordsByFilter). ANTES: findAllRecords carregava TODAS as concluídas
  //    e filtrava/ordenava em JS. AGORA o SQLite já devolve só o subconjunto
  //    elegível, ordenado, paginado — o único trabalho em JS é o match de
  //    telefone (precisa do cofre `clientes` + normalização de phonesMatch, que
  //    não dá pra expressar em filtro relacional).
  //    Predicados empurrados pro WHERE:
  //      status = "concluida"
  //      avaliacao_nota entre 1 e 3
  //      avaliacao_motivo = "" (vazio ⇒ ainda precisa de motivo; regra ""-never-null)
  //      avaliacao_solicitada_em >= janela de 7 dias
  //    Ordenado por -avaliacao_solicitada_em (mais recente primeiro).
  const FILTER =
    'status = "concluida" && avaliacao_nota >= 1 && avaliacao_nota <= 3 ' +
    '&& avaliacao_motivo = "" && avaliacao_solicitada_em >= {:since}';
  const SORT = "-avaliacao_solicitada_em";
  const PAGE = 200;

  for (let offset = 0; ; offset += PAGE) {
    let candidatas;
    try {
      candidatas = $app.findRecordsByFilter(
        "ordens_servico", FILTER, SORT, PAGE, offset, { since: sevenDaysAgo }
      );
    } catch (_) {
      break; // filtro/consulta falhou — trata como "nada pendente"
    }
    if (!candidatas || candidatas.length === 0) break;

    for (let i = 0; i < candidatas.length; i++) {
      const os = candidatas[i];
      // Verifica telefone do cliente server-side (NUNCA vaza na resposta).
      try {
        const cid = lib.relId(os.get("cliente"));
        if (!cid) continue;
        const cliente = $app.findRecordById("clientes", cid);
        if (lib.phonesMatch(cliente.getString("telefone"), rawPhone)) {
          return e.json(200, {
            os_id:   os.id,
            servico: os.getString("tipo_servico_nome") || "",
          });
        }
      } catch (_) {
        continue;
      }
    }

    if (candidatas.length < PAGE) break; // última página
  }

  return e.json(200, { os_id: null });
});

// ── GET /api/cleanos/whatsapp/dispatch-info ──────────────────────────────────
// Endpoint de serviço (consumido pelo n8n) para obter credenciais UAZAPI e
// templates de mensagem. É o ÚNICO endpoint que retorna o token da instância,
// e só o faz quando o caller apresenta o service secret correto.
routerAdd("GET", "/api/cleanos/whatsapp/dispatch-info", (e) => {
  const secret = $os.getenv("CLEANOS_SERVICE_SECRET") || "";
  const hdrs   = e.requestInfo().headers || {};
  const clientSecret = String(hdrs["x_cleanos_secret"] || "");
  if (!secret || clientSecret !== secret) {
    return e.json(401, { error: "Unauthorized" });
  }

  const h   = require(`${__hooks}/whatsapp_helpers.js`);
  const cfg = h.getAppConfig($app);

  return e.json(200, {
    uazapi_base:      $os.getenv("UAZAPI_BASE_URL") || "",
    uazapi_token:     cfg.getString("whatsapp_instance_token"),
    instance_status:  cfg.getString("whatsapp_status"),
    templates: {
      aviso_template:          cfg.getString("aviso_template"),
      avaliacao_poll_texto:    cfg.getString("avaliacao_poll_texto"),
      avaliacao_motivo_texto:  cfg.getString("avaliacao_motivo_texto"),
      avaliacao_agradecimento: cfg.getString("avaliacao_agradecimento"),
    },
  });
});

// ── GET /api/cleanos/whatsapp/config ─────────────────────────────────────────
routerAdd("GET", "/api/cleanos/whatsapp/config", (e) => {
  const h = require(`${__hooks}/whatsapp_helpers.js`);
  h.requireAdminOrGerente(e);

  const cfg = h.getAppConfig($app);
  return e.json(200, {
    aviso_template:          cfg.getString("aviso_template"),
    avaliacao_poll_texto:    cfg.getString("avaliacao_poll_texto"),
    avaliacao_motivo_texto:  cfg.getString("avaliacao_motivo_texto"),
    avaliacao_agradecimento: cfg.getString("avaliacao_agradecimento"),
    // doc 09 §3 — templates dos avisos de rastreamento "estou a caminho".
    aviso_5min_texto:        cfg.getString("aviso_5min_texto"),
    aviso_1min_texto:        cfg.getString("aviso_1min_texto"),
    aviso_cheguei_texto:     cfg.getString("aviso_cheguei_texto"),
  });
}, $apis.requireAuth());

// ── POST /api/cleanos/whatsapp/config ────────────────────────────────────────
routerAdd("POST", "/api/cleanos/whatsapp/config", (e) => {
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  const role = String(e.auth.get("role"));
  if (role !== "admin") {
    throw new ForbiddenError("Apenas admin pode alterar a configuração de templates.");
  }

  const h    = require(`${__hooks}/whatsapp_helpers.js`);
  const data = e.requestInfo().body || {};
  const cfg  = h.getAppConfig($app);

  const editableFields = [
    "aviso_template",
    "avaliacao_poll_texto",
    "avaliacao_motivo_texto",
    "avaliacao_agradecimento",
    // doc 09 §3 — templates dos avisos de rastreamento "estou a caminho".
    "aviso_5min_texto",
    "aviso_1min_texto",
    "aviso_cheguei_texto",
  ];
  for (let i = 0; i < editableFields.length; i++) {
    const field = editableFields[i];
    if (data[field] != null) {
      cfg.set(field, String(data[field]));
    }
  }

  $app.save(cfg);

  return e.json(200, {
    aviso_template:          cfg.getString("aviso_template"),
    avaliacao_poll_texto:    cfg.getString("avaliacao_poll_texto"),
    avaliacao_motivo_texto:  cfg.getString("avaliacao_motivo_texto"),
    avaliacao_agradecimento: cfg.getString("avaliacao_agradecimento"),
    aviso_5min_texto:        cfg.getString("aviso_5min_texto"),
    aviso_1min_texto:        cfg.getString("aviso_1min_texto"),
    aviso_cheguei_texto:     cfg.getString("aviso_cheguei_texto"),
  });
}, $apis.requireAuth());
