/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — lógica da vitrine pública (catálogo, slots, agendar).
 *
 * Sem auth de usuário. Proteções: rate-limit simples em memória, honeypot,
 * token HMAC de slot. Usa $app com privilégio de hook (bypass de rules).
 */

var slotsLib = null;
function slots() {
  if (!slotsLib) slotsLib = require(`${__hooks}/vitrine_slots_lib.js`);
  return slotsLib;
}

var bumpsLib = null;
function bumps() {
  if (!bumpsLib) bumpsLib = require(`${__hooks}/vitrine_bumps_lib.js`);
  return bumpsLib;
}

/** admin | gerente only (vitrine CMS) */
function assertVitrineAdmin(e) {
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  const role = String(e.auth.get("role") || "");
  if (role !== "admin" && role !== "gerente") {
    throw new ForbiddenError(
      "Acesso restrito a admin/gerente. Profissionais não entram no admin da vitrine.",
    );
  }
  return e.auth;
}

/** Rate limit in-process: ip → { n, reset } */
var _rl = {};

function clientIp(e) {
  try {
    const info = e.requestInfo() || {};
    const h = info.headers || {};
    const xff = String(h["x_forwarded_for"] || h["x-forwarded-for"] || "");
    if (xff) return xff.split(",")[0].trim();
    return String(info.remoteAddr || e.realIP || "0.0.0.0");
  } catch (_) {
    return "0.0.0.0";
  }
}

/**
 * @returns {string|null} mensagem de erro se bloqueado
 */
function rateLimit(ip, maxPerMin) {
  const key = String(ip || "x");
  const now = Date.now();
  const win = 60 * 1000;
  const max = maxPerMin || 30;
  var bucket = _rl[key];
  if (!bucket || now > bucket.reset) {
    _rl[key] = { n: 1, reset: now + win };
    return null;
  }
  bucket.n += 1;
  if (bucket.n > max) return "Muitas tentativas. Aguarde um minuto.";
  return null;
}

function hmacSecret() {
  return (
    String($os.getenv("VITRINE_SLOT_SECRET") || "") ||
    String($os.getenv("CLEANOS_SERVICE_SECRET") || "") ||
    "cleanos-vitrine-dev-only"
  );
}

/** Token simples: base64url(payload).sig  — sig = sha256 hex do secret+payload */
function signSlot(payloadObj) {
  const payload = JSON.stringify(payloadObj);
  // btoa pode não existir no JSVM — monta base64 manual via $security se houver
  var b64;
  try {
    if (typeof $security !== "undefined" && $security.md5) {
      /* prefer encode */
    }
  } catch (_) {}
  try {
    b64 = String(
      typeof Buffer !== "undefined"
        ? Buffer.from(payload, "utf8").toString("base64")
        : encodeURIComponent(payload),
    );
  } catch (_) {
    b64 = encodeURIComponent(payload);
  }
  const sig = hashHex(hmacSecret() + "|" + b64);
  return b64 + "." + sig;
}

function verifySlot(token) {
  const t = String(token || "");
  const i = t.lastIndexOf(".");
  if (i < 1) return null;
  const b64 = t.slice(0, i);
  const sig = t.slice(i + 1);
  if (hashHex(hmacSecret() + "|" + b64) !== sig) return null;
  try {
    var json;
    try {
      json =
        typeof Buffer !== "undefined"
          ? Buffer.from(b64, "base64").toString("utf8")
          : decodeURIComponent(b64);
    } catch (_) {
      json = decodeURIComponent(b64);
    }
    return JSON.parse(json);
  } catch (_) {
    return null;
  }
}

function hashHex(s) {
  // Prefer $security se existir; senão djb2-ish estável (dev only — prod usa secret).
  try {
    if (typeof $security !== "undefined" && $security.hs256) {
      return String($security.hs256(s, hmacSecret()));
    }
  } catch (_) {}
  try {
    if (typeof $security !== "undefined" && $security.md5) {
      return String($security.md5(s));
    }
  } catch (_) {}
  var h = 5381;
  const str = String(s);
  for (var i = 0; i < str.length; i++) {
    h = (h * 33) ^ str.charCodeAt(i);
  }
  return (h >>> 0).toString(16);
}

function servicoPublico(rec) {
  if (!rec) return null;
  const ativo = !!rec.get("ativo");
  const status = String(rec.get("status") || "").toLowerCase();
  if (!ativo && status !== "ativo") return null;
  // Flag vitrine: some do site se explicitamente desmarcado (false/0/"")
  try {
    const v = rec.get("vitrine");
    if (v === false || v === 0 || v === "0" || v === "false") return null;
  } catch (_) {}
  return {
    id: rec.id,
    nome: String(rec.get("nome") || ""),
    descricao: String(rec.get("descricao") || ""),
    categoria: String(rec.get("categoria") || ""),
    grupo: String(rec.get("grupo") || ""),
    valor_base: Number(rec.get("valor_base") || rec.get("preco_base") || 0),
    valor_base_max: Number(rec.get("valor_base_max") || 0),
    tipo_valor: String(rec.get("tipo_valor") || ""),
    tempo_medio_min: Number(rec.get("tempo_medio_min") || 0),
    tempo_medio_label: String(rec.get("tempo_medio_label") || ""),
    orientacoes_pre: String(rec.get("orientacoes_pre") || ""),
    vitrine_destaque: !!rec.get("vitrine_destaque"),
  };
}

function listarServicosPublicos(app) {
  let list = [];
  try {
    list = app.findRecordsByFilter(
      "servicos",
      "ativo = true",
      "nome",
      200,
      0,
    );
  } catch (_) {
    try {
      list = app.findRecordsByFilter("servicos", "", "nome", 200, 0);
    } catch (__) {
      list = [];
    }
  }
  const out = [];
  for (var i = 0; i < (list || []).length; i++) {
    const p = servicoPublico(list[i]);
    if (p && p.nome) out.push(p);
  }
  // Destaques primeiro
  out.sort(function (a, b) {
    return (b.vitrine_destaque ? 1 : 0) - (a.vitrine_destaque ? 1 : 0);
  });
  return out;
}

function defaultConfig() {
  return {
    hero_titulo: "Orçamento em 1 minuto",
    hero_subtitulo:
      "Escolha o que precisa limpar e agende no horário ideal",
    hero_cta: "Montar orçamento",
    whatsapp_exibido: "",
    rodape_msg: "Pagamento só no local · maquininha Cleanox",
    cidades_texto: "",
    como_funciona:
      "1) Selecione os serviços\n2) Informe contato e endereço\n3) Veja o orçamento e ofertas\n4) Escolha data e horário\n5) Confirmamos no WhatsApp",
  };
}

function getConfig(app) {
  const base = defaultConfig();
  try {
    const list = app.findRecordsByFilter("vitrine_config", "", "", 1, 0);
    if (list && list.length) {
      const r = list[0];
      return {
        id: r.id,
        hero_titulo: String(r.get("hero_titulo") || base.hero_titulo),
        hero_subtitulo: String(r.get("hero_subtitulo") || base.hero_subtitulo),
        hero_cta: String(r.get("hero_cta") || base.hero_cta),
        whatsapp_exibido: String(r.get("whatsapp_exibido") || ""),
        rodape_msg: String(r.get("rodape_msg") || base.rodape_msg),
        cidades_texto: String(r.get("cidades_texto") || ""),
        como_funciona: String(r.get("como_funciona") || base.como_funciona),
      };
    }
  } catch (_) {}
  return base;
}

function saveConfig(app, body) {
  let rec = null;
  try {
    const list = app.findRecordsByFilter("vitrine_config", "", "", 1, 0);
    if (list && list.length) rec = list[0];
  } catch (_) {}
  if (!rec) {
    const col = app.findCollectionByNameOrId("vitrine_config");
    rec = new Record(col);
  }
  const keys = [
    "hero_titulo",
    "hero_subtitulo",
    "hero_cta",
    "whatsapp_exibido",
    "rodape_msg",
    "cidades_texto",
    "como_funciona",
  ];
  for (var i = 0; i < keys.length; i++) {
    const k = keys[i];
    if (body[k] != null) rec.set(k, String(body[k]));
  }
  app.save(rec);
  return getConfig(app);
}

function parseJsonArr(v) {
  return bumps().toStrArray(v);
}

/**
 * Monta URL pública de arquivo PB.
 * @param {string} [baseUrl] ex. https://agendar.cleanox.com.br
 */
function filePublicUrl(baseUrl, collection, recordId, filename) {
  const f = String(filename || "").trim();
  if (!f || f === "null") return "";
  const base = String(baseUrl || "https://app.cleanox.com.br").replace(
    /\/$/,
    "",
  );
  return (
    base +
    "/api/files/" +
    encodeURIComponent(collection) +
    "/" +
    encodeURIComponent(recordId) +
    "/" +
    encodeURIComponent(f)
  );
}

/** Base URL a partir do request (Traefik X-Forwarded-*). */
function requestBaseUrl(e) {
  try {
    const info = e.requestInfo() || {};
    const h = info.headers || {};
    const host = String(
      h["x_forwarded_host"] || h["x-forwarded-host"] || h["host"] || "",
    )
      .split(",")[0]
      .trim();
    if (!host) return "https://app.cleanox.com.br";
    var proto = String(
      h["x_forwarded_proto"] || h["x-forwarded-proto"] || "https",
    )
      .split(",")[0]
      .trim();
    if (proto !== "http" && proto !== "https") proto = "https";
    return proto + "://" + host;
  } catch (_) {
    return "https://app.cleanox.com.br";
  }
}

function bumpPublico(rec, baseUrl) {
  if (!rec) return null;
  var oferta = rec.get("servico_oferta");
  if (oferta && typeof oferta === "object" && oferta.id) oferta = oferta.id;
  const foto = String(rec.get("foto") || "");
  return {
    id: rec.id,
    titulo: String(rec.get("titulo") || ""),
    descricao: String(rec.get("descricao") || ""),
    badge: String(rec.get("badge") || ""),
    servico_oferta: String(oferta || ""),
    preco_cheio: Number(rec.get("preco_cheio") || 0),
    preco_promo: Number(rec.get("preco_promo") || 0),
    gatilho_tipo: String(rec.get("gatilho_tipo") || "qualquer_grupo"),
    gatilho_valores: parseJsonArr(rec.get("gatilho_valores")),
    excluir_se: parseJsonArr(rec.get("excluir_se")),
    prioridade: Number(rec.get("prioridade") || 0),
    ativo: rec.get("ativo") !== false,
    foto: foto,
    foto_url: filePublicUrl(
      baseUrl,
      "vitrine_order_bumps",
      rec.id,
      foto,
    ),
  };
}

function listarBumpsRaw(app, soAtivos, baseUrl) {
  let list = [];
  var errMsg = "";
  try {
    if (typeof app.findAllRecords === "function") {
      list = app.findAllRecords("vitrine_order_bumps");
    }
  } catch (e1) {
    errMsg = String(e1);
    list = [];
  }
  if (!list || !list.length) {
    try {
      list = app.findRecordsByFilter(
        "vitrine_order_bumps",
        "",
        "titulo",
        200,
        0,
      );
    } catch (e2) {
      errMsg = (errMsg ? errMsg + " | " : "") + String(e2);
      list = [];
    }
  }
  if (errMsg) console.error("[vitrine] listarBumpsRaw: " + errMsg);
  const out = [];
  for (var i = 0; i < (list || []).length; i++) {
    const p = bumpPublico(list[i], baseUrl);
    if (!p || !p.titulo) continue;
    if (soAtivos && p.ativo === false) continue;
    out.push(p);
  }
  out.sort(function (a, b) {
    return Number(b.prioridade || 0) - Number(a.prioridade || 0);
  });
  return out;
}

/**
 * @param {string[]} servicoIds  ids no carrinho
 * @param {string} [baseUrl]
 */
function orderBumpsParaCarrinho(app, servicoIds, baseUrl) {
  const ids = Array.isArray(servicoIds) ? servicoIds : [];
  const cart = [];
  for (var i = 0; i < ids.length; i++) {
    const sid = String(ids[i] || "").trim();
    if (!sid) continue;
    const pub = getServicoPublico(app, sid);
    if (pub) {
      cart.push({ id: pub.id, grupo: pub.grupo });
    } else {
      cart.push({ id: sid, grupo: "" });
    }
  }
  const all = listarBumpsRaw(app, true, baseUrl);
  const matched = bumps().matchOrderBumps(cart, all);
  for (var m = 0; m < matched.length; m++) {
    try {
      const rec = app.findRecordById(
        "servicos",
        matched[m].servico_oferta,
      );
      matched[m].servico_nome = String(rec.get("nome") || "");
      if (!(matched[m].preco_cheio > 0)) {
        matched[m].preco_cheio = Number(
          rec.get("valor_base") || rec.get("preco_base") || 0,
        );
      }
    } catch (_) {}
  }
  return matched;
}

function listarMidiaPublica(app, baseUrl, soAtivos) {
  let list = [];
  try {
    if (typeof app.findAllRecords === "function") {
      list = app.findAllRecords("vitrine_midia");
    }
  } catch (_) {
    list = [];
  }
  if (!list || !list.length) {
    try {
      list = app.findRecordsByFilter("vitrine_midia", "", "ordem", 100, 0);
    } catch (__) {
      list = [];
    }
  }
  const out = [];
  for (var i = 0; i < (list || []).length; i++) {
    const r = list[i];
    if (soAtivos !== false && r.get("ativo") === false) continue;
    const arquivo = String(r.get("arquivo") || "");
    const urlExterna = String(r.get("url_externa") || "");
    const fileUrl = filePublicUrl(baseUrl, "vitrine_midia", r.id, arquivo);
    out.push({
      id: r.id,
      chave: String(r.get("chave") || ""),
      titulo: String(r.get("titulo") || ""),
      url_externa: urlExterna,
      ordem: Number(r.get("ordem") || 0),
      arquivo: arquivo,
      url: urlExterna || fileUrl || "",
      ativo: r.get("ativo") !== false,
    });
  }
  out.sort(function (a, b) {
    return Number(a.ordem || 0) - Number(b.ordem || 0);
  });
  return out;
}

/** Pacote único para boot da vitrine (config + mídia + destaques). */
function bootstrapPublico(app, baseUrl) {
  return {
    config: getConfig(app),
    midia: listarMidiaPublica(app, baseUrl, true),
    atuacao: getAtuacao(app),
  };
}

/** Admin: lista serviços com flags vitrine (inclui fora da vitrine). */
function listarServicosAdmin(app) {
  let list = [];
  try {
    list = app.findRecordsByFilter("servicos", "", "nome", 300, 0);
  } catch (_) {
    list = [];
  }
  const out = [];
  for (var i = 0; i < (list || []).length; i++) {
    const r = list[i];
    out.push({
      id: r.id,
      nome: String(r.get("nome") || ""),
      grupo: String(r.get("grupo") || ""),
      categoria: String(r.get("categoria") || ""),
      valor_base: Number(r.get("valor_base") || r.get("preco_base") || 0),
      ativo: !!r.get("ativo") || String(r.get("status") || "") === "ativo",
      vitrine: r.get("vitrine") !== false,
      vitrine_destaque: !!r.get("vitrine_destaque"),
    });
  }
  return out;
}

function setServicoVitrineFlags(app, id, flags) {
  const r = app.findRecordById("servicos", id);
  if (flags.vitrine != null) r.set("vitrine", !!flags.vitrine);
  if (flags.vitrine_destaque != null) {
    r.set("vitrine_destaque", !!flags.vitrine_destaque);
  }
  app.save(r);
  return {
    id: r.id,
    vitrine: r.get("vitrine") !== false,
    vitrine_destaque: !!r.get("vitrine_destaque"),
  };
}

function upsertBump(app, body, existingId) {
  const col = app.findCollectionByNameOrId("vitrine_order_bumps");
  var rec;
  if (existingId) {
    rec = app.findRecordById("vitrine_order_bumps", existingId);
  } else {
    rec = new Record(col);
  }
  if (body.titulo != null) rec.set("titulo", String(body.titulo).trim());
  if (body.descricao != null) rec.set("descricao", String(body.descricao));
  if (body.badge != null) rec.set("badge", String(body.badge));
  if (body.servico_oferta != null) {
    rec.set("servico_oferta", String(body.servico_oferta));
  }
  if (body.preco_cheio != null) rec.set("preco_cheio", Number(body.preco_cheio));
  if (body.preco_promo != null) rec.set("preco_promo", Number(body.preco_promo));
  if (body.gatilho_tipo != null) {
    rec.set("gatilho_tipo", String(body.gatilho_tipo));
  }
  if (body.gatilho_valores != null) {
    rec.set(
      "gatilho_valores",
      Array.isArray(body.gatilho_valores)
        ? body.gatilho_valores
        : parseJsonArr(body.gatilho_valores),
    );
  }
  if (body.excluir_se != null) {
    rec.set(
      "excluir_se",
      Array.isArray(body.excluir_se)
        ? body.excluir_se
        : parseJsonArr(body.excluir_se),
    );
  }
  if (body.prioridade != null) rec.set("prioridade", Number(body.prioridade));
  if (body.ativo != null) rec.set("ativo", !!body.ativo);
  if (!existingId && body.ativo == null) rec.set("ativo", true);
  if (!String(rec.get("titulo") || "").trim()) {
    throw new Error("Título obrigatório");
  }
  if (!String(rec.get("servico_oferta") || "").trim()) {
    throw new Error("servico_oferta obrigatório");
  }
  app.save(rec);
  return bumpPublico(rec);
}

function deleteBump(app, id) {
  const rec = app.findRecordById("vitrine_order_bumps", id);
  app.delete(rec);
  return { ok: true, id: id };
}

function listarAgendamentosVitrine(app, limit) {
  const n = Math.min(Number(limit) || 30, 100);
  let list = [];
  try {
    list = app.findRecordsByFilter(
      "ordens_servico",
      'canal_origem = "vitrine"',
      "-created",
      n,
      0,
    );
  } catch (_) {
    list = [];
  }
  const out = [];
  for (var i = 0; i < (list || []).length; i++) {
    const r = list[i];
    out.push({
      id: r.id,
      os_ref: String(r.id).slice(-6).toUpperCase(),
      nome_curto: String(r.get("nome_curto") || ""),
      tipo_servico_nome: String(r.get("tipo_servico_nome") || ""),
      data_hora: String(r.get("data_hora") || ""),
      valor_servico: Number(r.get("valor_servico") || 0),
      status: String(r.get("status") || ""),
      bairro: String(r.get("bairro") || ""),
    });
  }
  return out;
}

function getServicoPublico(app, id) {
  try {
    return servicoPublico(app.findRecordById("servicos", id));
  } catch (_) {
    return null;
  }
}

/** Normaliza item de config_atuacao.cidades: string | {nome} → nome */
function nomeCidadeItem(it) {
  if (it == null) return "";
  if (typeof it === "string") return it.trim();
  if (typeof it === "object" && it.nome != null) return String(it.nome).trim();
  return "";
}

function parseJsonField(rec, name) {
  var v = null;
  try {
    if (rec.getString) {
      const s = String(rec.getString(name) || "");
      if (s && s !== "null") {
        try {
          v = JSON.parse(s);
        } catch (_) {
          v = null;
        }
      }
    }
  } catch (_) {}
  if (v == null) {
    try {
      v = rec.get(name);
    } catch (_) {
      v = null;
    }
  }
  if (typeof v === "string") {
    try {
      v = JSON.parse(v);
    } catch (_) {
      v = [];
    }
  }
  return v;
}

function getAtuacao(app) {
  try {
    const list = app.findRecordsByFilter("config_atuacao", "", "", 1, 0);
    if (list && list.length) {
      const r = list[0];
      var cidades = parseJsonField(r, "cidades");
      const nomes = [];
      if (Array.isArray(cidades)) {
        for (var i = 0; i < cidades.length; i++) {
          const n = nomeCidadeItem(cidades[i]);
          if (n) nomes.push(n);
        }
      }
      return {
        estado: String(r.get("estado") || ""),
        cidades: nomes,
      };
    }
  } catch (_) {}
  return { estado: "", cidades: [] };
}

function cidadeCoberta(app, cidade) {
  const a = getAtuacao(app);
  const c = String(cidade || "")
    .trim()
    .toLowerCase();
  if (!c) return false;
  if (!a.cidades || !a.cidades.length) return true; // sem config = não bloqueia
  for (var i = 0; i < a.cidades.length; i++) {
    if (String(a.cidades[i] || "").trim().toLowerCase() === c) return true;
  }
  // match parcial
  for (var j = 0; j < a.cidades.length; j++) {
    const x = String(a.cidades[j] || "").trim().toLowerCase();
    if (x && (c.indexOf(x) >= 0 || x.indexOf(c) >= 0)) return true;
  }
  return false;
}

function listarDisponibilidades(app) {
  let disps = [];
  try {
    disps = app.findRecordsByFilter(
      "disponibilidade",
      "id != ''",
      "",
      100,
      0,
    );
  } catch (_) {
    try {
      disps = app.findRecordsByFilter("disponibilidade", "", "", 100, 0);
    } catch (__) {
      disps = [];
    }
  }
  const out = [];
  for (var i = 0; i < (disps || []).length; i++) {
    const r = disps[i];
    var dias = parseJsonField(r, "dias");
    var prof = r.get("profissional");
    // relation pode vir como string ou objeto
    if (prof && typeof prof === "object" && prof.id) prof = prof.id;
    out.push({
      profissional: String(prof || ""),
      dias: Array.isArray(dias) ? dias : [],
      duracao_min: Number(r.get("duracao_min") || 0),
    });
  }
  return out;
}

function listarOsOcupadasNoDia(app, ymd) {
  // Janela UTC cobrindo o dia BRT ymd (00:00–24:00 BRT = 03:00–03:00 UTC next)
  const sl = slots();
  const startUtc = sl.brtSlotToUtcPb(ymd, "00:00");
  // fim: próximo dia 00:00 BRT
  const p = String(ymd).split("-");
  const next = new Date(
    Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2]) + 1),
  );
  const nextYmd =
    next.getUTCFullYear() +
    "-" +
    String(next.getUTCMonth() + 1).padStart(2, "0") +
    "-" +
    String(next.getUTCDate()).padStart(2, "0");
  const endUtc = sl.brtSlotToUtcPb(nextYmd, "00:00");

  let list = [];
  try {
    list = app.findRecordsByFilter(
      "ordens_servico",
      'status != "cancelada" && status != "concluida" && data_hora >= "' +
        startUtc +
        '" && data_hora < "' +
        endUtc +
        '"',
      "data_hora",
      500,
      0,
    );
  } catch (_) {
    list = [];
  }
  const out = [];
  for (var i = 0; i < (list || []).length; i++) {
    const r = list[i];
    out.push({
      profissional: String(r.get("profissional") || ""),
      data_hora: String(r.get("data_hora") || ""),
      duracao_min: Number(r.get("duracao_min") || 0),
    });
  }
  return out;
}

/**
 * @param {string} [servicoId]  principal (opcional se duracaoMin forçado)
 * @param {string} ymd
 * @param {number} [duracaoMin] duração total do pacote (soma dos itens)
 */
function slotsDoDia(app, servicoId, ymd, duracaoMin) {
  var dur = Number(duracaoMin) || 0;
  var serv = null;
  if (servicoId) {
    serv = getServicoPublico(app, servicoId);
    if (!serv && !dur) return { error: "Serviço não encontrado", status: 404 };
  }
  if (!(dur > 0)) {
    dur = serv && serv.tempo_medio_min > 0 ? serv.tempo_medio_min : 60;
  }
  dur = Math.max(30, Math.round(dur));
  const disps = listarDisponibilidades(app);
  const osOcupadas = listarOsOcupadasNoDia(app, ymd);
  const livres = slots().calcularSlotsLivres({
    ymd: ymd,
    servicoDurMin: dur,
    stepMin: 30,
    disponibilidades: disps,
    osOcupadas: osOcupadas,
  });

  const exp = Date.now() + 15 * 60 * 1000;
  const sid = servicoId || (serv && serv.id) || "";
  const out = [];
  for (var i = 0; i < livres.length; i++) {
    const s = livres[i];
    const token = signSlot({
      s: sid,
      d: ymd,
      h: s.hora,
      p: s.profissionais,
      e: exp,
      dur: dur,
    });
    out.push({ hora: s.hora, token: token });
  }
  return { servico: serv, data: ymd, duracao_min: dur, slots: out };
}

function normalizarTelefone(t) {
  return String(t || "").replace(/\D/g, "");
}

function upsertCliente(app, body) {
  const tel = normalizarTelefone(body.telefone);
  if (tel.length < 10) throw new Error("Telefone inválido");
  const nome = String(body.nome || "").trim();
  if (!nome) throw new Error("Nome obrigatório");

  let existente = null;
  try {
    existente = app.findFirstRecordByFilter(
      "clientes",
      'telefone = "' + tel.replace(/"/g, '\\"') + '"',
    );
  } catch (_) {
    existente = null;
  }

  const fields = {
    nome: nome,
    sobrenome: String(body.sobrenome || "").trim(),
    telefone: tel,
    email: String(body.email || "").trim(),
    endereco_cep: String(body.cep || "").trim(),
    endereco_rua: String(body.rua || "").trim(),
    endereco_numero: String(body.numero || "").trim(),
    endereco_bairro: String(body.bairro || "").trim(),
    endereco_cidade: String(body.cidade || "").trim(),
    endereco_estado: String(body.estado || "").trim(),
    endereco_complemento: String(body.complemento || "").trim(),
    origem: "vitrine",
    ativo: true,
  };

  if (existente) {
    const keys = Object.keys(fields);
    for (var i = 0; i < keys.length; i++) {
      const k = keys[i];
      if (k === "origem") continue; // não sobrescreve origem antiga
      if (fields[k] !== "" && fields[k] != null) existente.set(k, fields[k]);
    }
    app.save(existente);
    return existente;
  }

  const col = app.findCollectionByNameOrId("clientes");
  const rec = new Record(col);
  const keys2 = Object.keys(fields);
  for (var j = 0; j < keys2.length; j++) {
    rec.set(keys2[j], fields[keys2[j]]);
  }
  app.save(rec);
  return rec;
}

function contagemOsPorProfNoDia(osOcupadas) {
  const m = {};
  for (var i = 0; i < (osOcupadas || []).length; i++) {
    const p = String(osOcupadas[i].profissional || "");
    if (!p) continue;
    m[p] = (m[p] || 0) + 1;
  }
  return m;
}

/**
 * Agenda: valida token, revalida slot, cria cliente+OS.
 * Body pode trazer `itens: [{id, nome, valor}]` (orçamento multi-serviço).
 */
function agendar(app, body) {
  const honeypot = String(body.website || body.honeypot || "");
  if (honeypot) throw new Error("Rejeitado");

  const token = String(body.slot_token || body.token || "");
  const payload = verifySlot(token);
  if (!payload) throw new Error("Horário inválido ou expirado. Escolha de novo.");
  if (Number(payload.e) < Date.now()) {
    throw new Error("Horário expirado. Escolha de novo.");
  }

  const ymd = String(payload.d || "");
  const hora = String(payload.h || "");
  const profsToken = payload.p || [];
  const durToken = Number(payload.dur) || 0;

  // Itens do orçamento (multi-select da vitrine)
  var itens = Array.isArray(body.itens) ? body.itens : [];
  var valorTotal = 0;
  var nomes = [];
  var durSoma = 0;
  var primaryId = String(payload.s || body.servico_id || "");
  for (var ii = 0; ii < itens.length; ii++) {
    const it = itens[ii] || {};
    const sid = String(it.id || it.servico_id || "");
    const pub = sid ? getServicoPublico(app, sid) : null;
    const nome = String(it.nome || (pub && pub.nome) || "").trim();
    const val = Number(
      it.valor != null
        ? it.valor
        : pub
          ? pub.valor_base
          : 0,
    );
    if (nome) nomes.push(nome);
    if (val > 0) valorTotal += val;
    if (pub && pub.tempo_medio_min > 0) durSoma += pub.tempo_medio_min;
    if (!primaryId && sid) primaryId = sid;
  }
  // Fallback: 1 serviço do token
  var serv = primaryId ? getServicoPublico(app, primaryId) : null;
  if (!serv && !nomes.length) throw new Error("Serviço não encontrado");
  if (!nomes.length && serv) {
    nomes = [serv.nome];
    valorTotal = serv.valor_base;
    durSoma = serv.tempo_medio_min || 60;
  }
  if (!(valorTotal > 0) && serv) valorTotal = serv.valor_base;
  var dur = durToken > 0 ? durToken : durSoma > 0 ? durSoma : 60;
  dur = Math.max(30, Math.round(dur));
  if (!primaryId && serv) primaryId = serv.id;

  // Endereço: aceita "endereco" único (landing) ou campos separados
  var enderecoLivre = String(body.endereco || "").trim();
  if (enderecoLivre && !String(body.bairro || "").trim()) {
    // tenta extrair bairro grosseiro
    body.bairro = enderecoLivre;
  }
  if (!String(body.cidade || "").trim() && enderecoLivre) {
    // default cidade da atuação se não veio
    const at = getAtuacao(app);
    if (at.cidades && at.cidades.length) body.cidade = at.cidades[0];
  }
  // telefone alias whatsapp
  if (!body.telefone && body.whatsapp) body.telefone = body.whatsapp;

  const cidade = String(body.cidade || "").trim();
  if (cidade && !cidadeCoberta(app, cidade)) {
    throw new Error("Ainda não atendemos essa cidade.");
  }

  // Revalida slot com a mesma duração
  const again = slotsDoDia(app, primaryId, ymd, dur);
  if (again.error) throw new Error(again.error);
  var still = null;
  for (var i = 0; i < (again.slots || []).length; i++) {
    if (again.slots[i].hora === hora) {
      still = again.slots[i];
      break;
    }
  }
  if (!still) throw new Error("Esse horário acabou de ser preenchido. Escolha outro.");

  const revalPayload = verifySlot(still.token);
  const profsNow = (revalPayload && revalPayload.p) || [];
  const cand = [];
  for (var j = 0; j < profsToken.length; j++) {
    if (profsNow.indexOf(profsToken[j]) >= 0) cand.push(profsToken[j]);
  }
  if (!cand.length) {
    for (var k = 0; k < profsNow.length; k++) cand.push(profsNow[k]);
  }
  if (!cand.length) throw new Error("Sem profissional disponível nesse horário.");

  const osOcup = listarOsOcupadasNoDia(app, ymd);
  const contagem = contagemOsPorProfNoDia(osOcup);
  const profId = slots().escolherProfissional(cand, contagem);

  const cliente = upsertCliente(app, body);
  const dataHora = slots().brtSlotToUtcPb(ymd, hora);

  const titulo = nomes.join(" + ").slice(0, 180);
  var obsUser = String(body.observacoes || "").trim();
  if (body.veiculo) {
    obsUser = ("Veículo: " + String(body.veiculo).trim() +
      (obsUser ? "\n" + obsUser : "")).trim();
  }
  const obsItens =
    "Orçamento vitrine:\n" +
    nomes
      .map(function (n, idx) {
        const it = itens[idx] || {};
        const v = Number(it.valor || 0);
        return "- " + n + (v > 0 ? " · R$ " + v.toFixed(2) : "");
      })
      .join("\n") +
    "\nTotal: R$ " +
    Number(valorTotal).toFixed(2) +
    (obsUser ? "\n\n" + obsUser : "");

  const col = app.findCollectionByNameOrId("ordens_servico");
  const os = new Record(col);
  os.set("cliente", cliente.id);
  if (primaryId) os.set("servico", primaryId);
  os.set("profissional", profId);
  os.set("status", "atribuida");
  os.set("data_hora", dataHora);
  os.set("duracao_min", dur);
  os.set("valor_servico", Math.round(valorTotal * 100) / 100);
  os.set("nome_curto", String(cliente.get("nome") || body.nome || ""));
  os.set("bairro", String(body.bairro || cliente.get("endereco_bairro") || ""));
  os.set("tipo_servico_nome", titulo || (serv && serv.nome) || "Serviço");
  os.set("canal_origem", "vitrine");
  os.set("observacoes", obsItens.slice(0, 2000));
  app.save(os);

  return {
    ok: true,
    os_id: os.id,
    os_ref: String(os.id).slice(-6).toUpperCase(),
    data: ymd,
    hora: hora,
    data_hora: dataHora,
    servico: titulo || (serv && serv.nome) || "",
    valor: Math.round(valorTotal * 100) / 100,
    bairro: String(body.bairro || ""),
    mensagem:
      "Agendamento confirmado! Nossa equipe entrará em contato se precisar de algo. No dia do serviço o pagamento é na maquininha da Cleanox.",
  };
}

/** Mapeia erro de admin CMS → { status, error } */
function adminHttpError(err) {
  const msg = String(err && err.message ? err.message : err);
  if (/Autenticação|Unauthorized/i.test(msg)) {
    return { status: 401, error: msg };
  }
  if (/restrito|Forbidden|Profissionais/i.test(msg)) {
    return { status: 403, error: msg };
  }
  if (/obrigat|inválid|não encontr/i.test(msg)) {
    return { status: 400, error: msg };
  }
  return { status: 500, error: msg || "Erro no admin da vitrine" };
}

module.exports = {
  clientIp,
  rateLimit,
  assertVitrineAdmin,
  adminHttpError,
  listarServicosPublicos,
  getServicoPublico,
  getAtuacao,
  cidadeCoberta,
  slotsDoDia,
  agendar,
  signSlot,
  verifySlot,
  normalizarTelefone,
  getConfig,
  saveConfig,
  defaultConfig,
  orderBumpsParaCarrinho,
  listarBumpsRaw,
  listarMidiaPublica,
  bootstrapPublico,
  requestBaseUrl,
  filePublicUrl,
  listarServicosAdmin,
  setServicoVitrineFlags,
  upsertBump,
  deleteBump,
  listarAgendamentosVitrine,
  bumpPublico,
};
