/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS → Cleanox Ads CAPI
 *
 * Eventos:
 *   - Schedule: OS → agendada
 *   - Purchase: OS → concluida com valor_pago > 0
 *   - Lead:     OS → cancelada após ter entrado no funil de agenda
 *               (agendada | atribuida | em_andamento → cancelada)
 *               Público de remarketing: interessou/agendou e desmarcou.
 *               Quem reagendar gera novo Schedule — exclua Schedule no público.
 *
 * Config (app_config):
 *   meta_capi_enabled  = "true"
 *   meta_capi_url      = "https://ads.cleanox.com.br/api/webhooks/cleanos/purchase"
 *   meta_capi_secret   = mesmo CLEANOS_WEBHOOK_SECRET do cleanox-ads
 *
 * Best-effort: NUNCA lança. Idempotência: eventId estável por OS + tipo.
 */

function relId(v) {
  if (Array.isArray(v)) return v.length ? String(v[0]) : "";
  return v ? String(v) : "";
}

function normalizePhone(raw) {
  var digits = String(raw || "").replace(/\D/g, "");
  if (digits.length >= 12) return digits;
  if (digits.length >= 10) return "55" + digits;
  return digits;
}

function getMetaCapiConfig(app) {
  try {
    var cfg = app.findFirstRecordByFilter("app_config", "id != ''");
    return {
      enabled: String(cfg.getString("meta_capi_enabled") || "").toLowerCase() === "true",
      url: String(cfg.getString("meta_capi_url") || "").trim(),
      secret: String(cfg.getString("meta_capi_secret") || "").trim(),
    };
  } catch (err) {
    // Campos/migration ausentes — tenta env do processo PocketBase
    try {
      var enabled = String($os.getenv("META_CAPI_ENABLED") || "").toLowerCase() === "true";
      var url = String($os.getenv("META_CAPI_URL") || "").trim();
      var secret = String($os.getenv("META_CAPI_SECRET") || "").trim();
      return { enabled: enabled, url: url, secret: secret };
    } catch (_) {
      return null;
    }
  }
}

/**
 * @param {core.App} app
 * @param {core.Record} record  OS
 * @param {string|null} origStatus  status ANTES do e.next() (null em CREATE)
 */
function resolveCliente(app, record) {
  var phone = "";
  var name = String(record.get("nome_curto") || "");
  var city = "";
  var state = "";
  var zip = "";
  var street = "";
  var neighborhood = "";
  var externalId = "";
  var email = "";

  var cid = relId(record.get("cliente"));
  if (cid) {
    externalId = cid;
    try {
      var c = app.findRecordById("clientes", cid);
      phone = normalizePhone(c.get("telefone") || c.get("whatsapp") || c.get("phone") || "");
      email = String(c.get("email") || "").trim();
      var n = String(c.get("nome") || "").trim();
      var s = String(c.get("sobrenome") || "").trim();
      if (n) name = s ? n + " " + s : n;
      city = String(c.get("endereco_cidade") || "").trim();
      state = String(c.get("endereco_estado") || c.get("endereco_uf") || "").trim();
      zip = String(c.get("endereco_cep") || "").replace(/\D/g, "");
      // CEP não é coletado no agendamento — o ads resolve via ViaCEP com rua+bairro
      street = String(c.get("endereco_rua") || "").trim();
      neighborhood = String(c.get("endereco_bairro") || "").trim();
    } catch (errCliente) {
      console.log("[meta-capi] cliente não encontrado: " + cid);
    }
  }
  return {
    phone: phone,
    name: name,
    city: city,
    state: state,
    zip: zip,
    street: street,
    neighborhood: neighborhood,
    externalId: externalId,
    email: email,
  };
}

function postCapi(cfg, body, label) {
  var res = $http.send({
    url: cfg.url,
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer " + cfg.secret,
    },
    body: JSON.stringify(body),
    timeout: 8,
  });
  var statusCode = res.statusCode || res.status || 0;
  if (statusCode >= 200 && statusCode < 300) {
    console.log("[meta-capi] " + label + " OK HTTP " + statusCode);
  } else {
    var bodyText = "";
    try {
      bodyText = typeof res.body === "string" ? res.body : JSON.stringify(res.body || res.json);
    } catch (_) {}
    console.error("[meta-capi] " + label + " FALHOU HTTP " + statusCode + " " + String(bodyText).slice(0, 200));
  }
}

function prevStatusOf(record, origStatus) {
  if (arguments.length >= 2 && origStatus !== undefined) {
    return String(origStatus || "");
  }
  var orig = record.original ? record.original() : null;
  return orig ? String(orig.get("status") || "") : "";
}

/**
 * Purchase: OS → concluida com valor_pago > 0
 */
function emitPurchaseCapi(app, record, origStatus) {
  try {
    var newStatus = String(record.get("status") || "");
    if (newStatus !== "concluida") return;
    var prevStatus = prevStatusOf(record, origStatus);
    if (prevStatus === "concluida") return;

    var valorPago = Number(record.get("valor_pago") || 0);
    if (!(valorPago > 0)) {
      console.log("[meta-capi] OS sem valor_pago > 0; skip Purchase.");
      return;
    }

    var cfg = getMetaCapiConfig(app);
    if (!cfg || !cfg.enabled || !cfg.url) {
      console.log("[meta-capi] desabilitado ou URL vazia; skip.");
      return;
    }
    if (!cfg.secret) {
      console.log("[meta-capi] meta_capi_secret vazio; skip.");
      return;
    }

    var osId = record.id;
    var cli = resolveCliente(app, record);
    if (!cli.phone) {
      console.log("[meta-capi] Purchase sem telefone do cliente; skip OS " + osId);
      return;
    }

    postCapi(
      cfg,
      {
        eventName: "Purchase",
        eventId: "purchase_os_" + osId,
        osId: osId,
        value: valorPago,
        currency: "BRL",
        phone: cli.phone,
        email: cli.email || null,
        name: cli.name || null,
        externalId: cli.externalId || null,
        city: cli.city || null,
        state: cli.state || null,
        zip: cli.zip || null,
        street: cli.street || null,
        neighborhood: cli.neighborhood || null,
        country: "br",
        eventTime: Math.floor(Date.now() / 1000),
      },
      "Purchase OS " + osId + " R$ " + valorPago
    );
  } catch (err) {
    console.error("[meta-capi] Purchase erro (ignorado): " + err);
  }
}

/**
 * Schedule: transição para agendada (ou create já agendada)
 */
function emitScheduleCapi(app, record, origStatus) {
  try {
    var newStatus = String(record.get("status") || "");
    if (newStatus !== "agendada") return;
    var prevStatus = prevStatusOf(record, origStatus);
    if (prevStatus === "agendada") return;

    var cfg = getMetaCapiConfig(app);
    if (!cfg || !cfg.enabled || !cfg.url || !cfg.secret) return;

    var osId = record.id;
    var cli = resolveCliente(app, record);
    if (!cli.phone) {
      console.log("[meta-capi] Schedule sem telefone; skip OS " + osId);
      return;
    }

    postCapi(
      cfg,
      {
        eventName: "Schedule",
        eventId: "schedule_os_" + osId,
        osId: osId,
        phone: cli.phone,
        email: cli.email || null,
        name: cli.name || null,
        externalId: cli.externalId || null,
        city: cli.city || null,
        state: cli.state || null,
        zip: cli.zip || null,
        street: cli.street || null,
        neighborhood: cli.neighborhood || null,
        country: "br",
        eventTime: Math.floor(Date.now() / 1000),
      },
      "Schedule OS " + osId
    );
  } catch (err) {
    console.error("[meta-capi] Schedule erro (ignorado): " + err);
  }
}

/**
 * Lead (remarketing): agendou e cancelou (não reagendou ainda).
 *
 * Dispara na transição → cancelada se o status anterior era do funil de agenda:
 *   agendada | atribuida | em_andamento
 *
 * Não dispara se cancelar algo que nunca entrou na agenda (ex.: rascunho raro).
 * Se o cliente reagendar depois, CleanOS emite Schedule de novo — no Meta,
 * o público de remarketing deve excluir quem teve Schedule recente.
 */
function emitLeadCancelCapi(app, record, origStatus) {
  try {
    var newStatus = String(record.get("status") || "");
    if (newStatus !== "cancelada") return;

    var prevStatus = prevStatusOf(record, origStatus);
    if (prevStatus === "cancelada") return;

    // Só quem já estava no funil de agenda
    var booked = { agendada: 1, atribuida: 1, em_andamento: 1 };
    if (!booked[prevStatus]) {
      console.log(
        "[meta-capi] Cancelamento sem agenda prévia (prev=" + prevStatus + "); skip Lead."
      );
      return;
    }

    var cfg = getMetaCapiConfig(app);
    if (!cfg || !cfg.enabled || !cfg.url || !cfg.secret) return;

    var osId = record.id;
    var cli = resolveCliente(app, record);
    if (!cli.phone) {
      console.log("[meta-capi] Lead cancel sem telefone; skip OS " + osId);
      return;
    }

    // Idempotente por OS: um cancelamento = um Lead de remarketing
    postCapi(
      cfg,
      {
        eventName: "Lead",
        eventId: "lead_cancel_os_" + osId,
        osId: osId,
        phone: cli.phone,
        email: cli.email || null,
        name: cli.name || null,
        externalId: cli.externalId || null,
        city: cli.city || null,
        state: cli.state || null,
        zip: cli.zip || null,
        street: cli.street || null,
        neighborhood: cli.neighborhood || null,
        country: "br",
        eventTime: Math.floor(Date.now() / 1000),
        // metadado livre no summary do ads (body aceita campos extras)
        source: "cleanos_cancel",
      },
      "Lead cancel OS " + osId + " (prev=" + prevStatus + ")"
    );
  } catch (err) {
    console.error("[meta-capi] Lead cancel erro (ignorado): " + err);
  }
}

/** Emite os eventos CAPI relevantes para a transição de status da OS. */
function emitOsCapi(app, record, origStatus) {
  emitScheduleCapi(app, record, origStatus);
  emitPurchaseCapi(app, record, origStatus);
  emitLeadCancelCapi(app, record, origStatus);
}

module.exports = {
  emitPurchaseCapi: emitPurchaseCapi,
  emitScheduleCapi: emitScheduleCapi,
  emitLeadCancelCapi: emitLeadCancelCapi,
  emitOsCapi: emitOsCapi,
};
