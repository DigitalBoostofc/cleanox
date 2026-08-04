/**
 * CleanOS — atividade da OS (comentários + log de alterações + menções).
 *
 * CommonJS. Carregar com require() DENTRO de cada handler.
 *
 * Regras de produto:
 *   1) Feed INTERNO — só admin/gerente (regras de coleção).
 *   2) Log de TUDO que muda na OS (campos de negócio; ignora GPS efêmero).
 *   3) @menção de admin/gerente → notificação in-app.
 */

/** Campos que NÃO entram no log (ruído / server-only efêmero). */
var SKIP_FIELDS = {
  id: true,
  created: true,
  updated: true,
  collectionId: true,
  collectionName: true,
  // tracking GPS efêmero
  prof_lat: true,
  prof_lng: true,
  prof_pos_em: true,
  dest_lat: true,
  dest_lng: true,
  aviso_5min_em: true,
  aviso_1min_em: true,
  cheguei_em: true,
  aviso_a_caminho_em: true,
  // denorm que mudam junto (já logamos a relation fonte)
  // mantemos cliente_nome / bairro se mudarem de propósito
};

/** Rótulos pt-BR para o feed. */
var FIELD_LABELS = {
  status: "Status",
  profissional: "Profissional",
  cliente: "Cliente",
  servico: "Serviço",
  tipo_servico_nome: "Tipo de serviço",
  data_hora: "Data/hora",
  duracao_min: "Duração (min)",
  bairro: "Bairro",
  observacoes: "Observações",
  observacoes_prof: "Obs. do profissional",
  valor_servico: "Valor do serviço",
  valor_pago: "Valor pago",
  forma_pagamento: "Forma de pagamento",
  descontos: "Descontos",
  adicionais: "Adicionais",
  checklist_exec: "Checklist",
  repasse_status: "Repasse (status)",
  repasse_valor: "Repasse (valor)",
  motivo_cancelamento: "Motivo do cancelamento",
  cancelado_por: "Cancelado por",
  cancelado_em: "Cancelado em",
  cancelado_por_nome: "Cancelado por (nome)",
  avaliacao_nota: "Avaliação (nota)",
  avaliacao_motivo: "Avaliação (motivo)",
  avaliacao_em: "Avaliação em",
  refazer: "Refazer",
  vitrine: "Vitrine",
  endereco_liberado: "Endereço liberado",
  service_snapshot: "Snapshot do serviço",
  cliente_nome: "Nome do cliente (denorm)",
  iniciada_em: "Iniciada em",
  concluida_em: "Concluída em",
};

function relId(v) {
  if (v == null || v === "") return "";
  if (typeof v === "string") return v;
  if (typeof v === "object") {
    if (v.id) return String(v.id);
    if (typeof v.get === "function") {
      try {
        return String(v.get("id") || v.id || "");
      } catch (_) {
        return "";
      }
    }
  }
  return String(v);
}

function fieldLabel(campo) {
  return FIELD_LABELS[campo] || campo;
}

/**
 * Serializa valor de campo para texto de log (truncado).
 * JSONField: usa getString se disponível no record.
 */
function serializeValue(rec, field) {
  if (!rec) return "—";
  try {
    // Prefer getString (estável p/ JSONField em goja)
    if (typeof rec.getString === "function") {
      var s = rec.getString(field);
      if (s !== undefined && s !== null && s !== "") {
        if (s.length > 500) return s.slice(0, 500) + "…";
        return s;
      }
    }
    var v = rec.get(field);
    if (v == null || v === "") return "—";
    // relation
    var rid = relId(v);
    if (rid && (typeof v === "string" || (typeof v === "object" && v.id))) {
      return rid;
    }
    if (typeof v === "boolean") return v ? "sim" : "não";
    if (typeof v === "number") return String(v);
    if (typeof v === "object") {
      try {
        var j = JSON.stringify(v);
        if (j.length > 500) return j.slice(0, 500) + "…";
        return j;
      } catch (_) {
        return String(v);
      }
    }
    var str = String(v);
    if (str.length > 500) return str.slice(0, 500) + "…";
    return str || "—";
  } catch (_) {
    return "—";
  }
}

function valuesEqual(a, b) {
  return String(a || "—") === String(b || "—");
}

function displayNameFromUser(u) {
  if (!u) return "Alguém";
  try {
    var nome = String(u.getString ? u.getString("nome") : u.get("nome") || "").trim();
    if (nome) return nome;
    var name = String(u.getString ? u.getString("name") : u.get("name") || "").trim();
    if (name) return name;
    var email = String(u.getString ? u.getString("email") : u.get("email") || "").trim();
    if (email) return email.split("@")[0];
  } catch (_) {}
  return "Alguém";
}

function authDisplayName(auth) {
  if (!auth) return "Sistema";
  return displayNameFromUser(auth);
}

/**
 * Resolve nome legível de relation (users/clientes/servicos) quando possível.
 */
function resolveRelationLabel(app, collection, id) {
  var rid = String(id || "");
  if (!rid || rid === "—") return "—";
  try {
    var rec = app.findRecordById(collection, rid);
    if (collection === "users") return displayNameFromUser(rec);
    if (collection === "clientes") {
      var n = String(rec.getString("nome") || "").trim();
      var sn = String(rec.getString("sobrenome") || "").trim();
      return (n + (sn ? " " + sn.charAt(0) + "." : "")).trim() || rid;
    }
    if (collection === "servicos") {
      return String(rec.getString("nome") || rid);
    }
  } catch (_) {}
  return rid;
}

function humanizeFieldValue(app, field, raw) {
  if (raw === "—" || raw === "") return "—";
  if (field === "profissional" || field === "cancelado_por") {
    return resolveRelationLabel(app, "users", raw);
  }
  if (field === "cliente") {
    return resolveRelationLabel(app, "clientes", raw);
  }
  if (field === "servico") {
    return resolveRelationLabel(app, "servicos", raw);
  }
  if (field === "status") {
    var map = {
      agendada: "Em agendamento",
      atribuida: "Atribuída",
      em_andamento: "Em andamento",
      concluida: "Concluída",
      cancelada: "Cancelada",
    };
    return map[raw] || raw;
  }
  if (field === "forma_pagamento") {
    var fp = {
      debito: "Débito",
      credito: "Crédito",
      pix_maquininha: "Pix maquininha",
      dinheiro: "Dinheiro",
      pix: "Pix",
    };
    return fp[raw] || raw;
  }
  return raw;
}

/**
 * Cria um registro em os_atividade (bypass de regras — $app.save).
 */
function createAtividade(app, data) {
  try {
    var col = app.findCollectionByNameOrId("os_atividade");
    var rec = new Record(col);
    rec.set("os", data.os);
    rec.set("tipo", data.tipo || "sistema");
    if (data.autor) rec.set("autor", data.autor);
    rec.set("texto", data.texto || "");
    if (data.campo) rec.set("campo", data.campo);
    if (data.valor_antes != null) rec.set("valor_antes", String(data.valor_antes));
    if (data.valor_depois != null) rec.set("valor_depois", String(data.valor_depois));
    if (data.mentions && data.mentions.length) {
      rec.set("mentions", data.mentions);
    }
    app.save(rec);
    return rec;
  } catch (err) {
    console.error("[os_atividade] falha ao gravar: " + err);
    return null;
  }
}

/**
 * Lista campos de negócio presentes no record (exceto SKIP).
 */
function businessFields(rec) {
  var out = [];
  // Campos canônicos conhecidos + qualquer outro que não esteja no SKIP.
  var known = Object.keys(FIELD_LABELS);
  var seen = {};
  for (var i = 0; i < known.length; i++) {
    seen[known[i]] = true;
    if (!SKIP_FIELDS[known[i]]) out.push(known[i]);
  }
  // Campos extras do schema (se o record expuser)
  try {
    var col = rec.collection && rec.collection();
    if (col && col.fields) {
      var fields = col.fields;
      // PocketBase JSVM: fields pode ser iterável via getByName / length
      if (typeof fields.length === "number") {
        for (var j = 0; j < fields.length; j++) {
          var f = fields[j];
          var name = f && (f.name || (f.get && f.get("name")));
          name = String(name || "");
          if (!name || SKIP_FIELDS[name] || seen[name]) continue;
          // ignora system
          if (name === "id") continue;
          out.push(name);
          seen[name] = true;
        }
      }
    }
  } catch (_) {}
  return out;
}

/**
 * Loga todas as mudanças entre original e record (pós e.next, best-effort).
 */
function logOsUpdate(app, record, original, auth) {
  if (!record || !original) return;
  var osId = String(record.id || "");
  if (!osId) return;

  var autorId = auth ? String(auth.id || "") : "";
  var autorNome = authDisplayName(auth);
  var fields = businessFields(record);

  for (var i = 0; i < fields.length; i++) {
    var campo = fields[i];
    var antes = serializeValue(original, campo);
    var depois = serializeValue(record, campo);
    if (valuesEqual(antes, depois)) continue;

    var hAntes = humanizeFieldValue(app, campo, antes);
    var hDepois = humanizeFieldValue(app, campo, depois);
    var label = fieldLabel(campo);
    var texto =
      autorNome +
      " alterou " +
      label +
      " de «" +
      hAntes +
      "» para «" +
      hDepois +
      "»";

    createAtividade(app, {
      os: osId,
      tipo: "alteracao",
      autor: autorId || "",
      texto: texto,
      campo: campo,
      valor_antes: hAntes,
      valor_depois: hDepois,
    });
  }
}

/**
 * Log de criação de OS.
 */
function logOsCreate(app, record, auth) {
  if (!record) return;
  var osId = String(record.id || "");
  if (!osId) return;
  var autorId = auth ? String(auth.id || "") : "";
  var autorNome = authDisplayName(auth);
  createAtividade(app, {
    os: osId,
    tipo: "sistema",
    autor: autorId || "",
    texto: autorNome + " criou a OS",
  });
}

/**
 * Lista admin/gerente ativos (para match de @menção).
 * Prefer findRecordsByFilter (string); fallback findAllRecords + filter em JS
 * (útil em testes unitários com app mock).
 */
function listAdminGerente(app) {
  var out = [];
  try {
    var recs = null;
    if (typeof app.findRecordsByFilter === "function") {
      try {
        recs = app.findRecordsByFilter(
          "users",
          'role = "admin" || role = "gerente"',
          "nome",
          200,
          0,
        );
      } catch (_) {
        recs = null;
      }
    }
    if (!recs && typeof app.findAllRecords === "function") {
      recs = app.findAllRecords("users");
    }
    if (!recs) return out;
    for (var i = 0; i < recs.length; i++) {
      var r = recs[i];
      var role = "";
      try {
        role = String(
          r.getString ? r.getString("role") : r.get("role") || "",
        );
      } catch (_) {
        role = "";
      }
      if (role === "admin" || role === "gerente") out.push(r);
    }
  } catch (err) {
    console.error("[os_atividade] listAdminGerente: " + err);
  }
  return out;
}

/**
 * Resolve menções a partir do array explícito (ids) e/ou parse de @Nome no texto.
 * Só aceita admin/gerente.
 */
function resolveMentions(app, texto, explicitIds) {
  var staff = listAdminGerente(app);
  var byId = {};
  for (var i = 0; i < staff.length; i++) {
    byId[String(staff[i].id)] = staff[i];
  }

  var found = {};

  // 1) ids explícitos do client
  var ids = explicitIds || [];
  if (!Array.isArray(ids)) {
    if (typeof ids === "string" && ids) ids = [ids];
    else ids = [];
  }
  for (var j = 0; j < ids.length; j++) {
    var id = String(ids[j] || "");
    if (id && byId[id]) found[id] = true;
  }

  // 2) parse @Nome no texto (case-insensitive, nome completo ou primeiro nome)
  var body = String(texto || "");
  for (var k = 0; k < staff.length; k++) {
    var u = staff[k];
    var dn = displayNameFromUser(u);
    if (!dn || dn === "Alguém") continue;
    // escape regex simples
    var esc = dn.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    var reFull = new RegExp("@" + esc + "(?=\\s|$|[.,;:!?])", "i");
    if (reFull.test(body)) {
      found[String(u.id)] = true;
      continue;
    }
    var first = dn.split(/\s+/)[0];
    if (first && first.length >= 2) {
      var escF = first.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      var reFirst = new RegExp("@" + escF + "(?=\\s|$|[.,;:!?])", "i");
      if (reFirst.test(body)) found[String(u.id)] = true;
    }
  }

  return Object.keys(found);
}

/**
 * Cria notificações in-app para cada mencionado (exceto o autor).
 */
function notifyMentions(app, opts) {
  var destIds = opts.destIds || [];
  var autorId = String(opts.autorId || "");
  var osId = String(opts.osId || "");
  var atividadeId = String(opts.atividadeId || "");
  var autorNome = String(opts.autorNome || "Alguém");
  var trecho = String(opts.texto || "").slice(0, 200);

  for (var i = 0; i < destIds.length; i++) {
    var dest = String(destIds[i] || "");
    if (!dest || dest === autorId) continue;
    try {
      var col = app.findCollectionByNameOrId("notificacoes");
      var rec = new Record(col);
      rec.set("destinatario", dest);
      rec.set("tipo", "mencao_os");
      rec.set("titulo", autorNome + " mencionou você");
      rec.set("corpo", trecho);
      if (osId) rec.set("os", osId);
      if (atividadeId) rec.set("atividade", atividadeId);
      rec.set("lida", false);
      app.save(rec);
    } catch (err) {
      console.error("[notificacoes] falha ao criar menção: " + err);
    }
  }
}

/**
 * Guard de create via API: só comentário, força autor, resolve mentions.
 * Roda em onRecordCreateRequest (antes do save).
 */
function guardComentarioCreate(e) {
  var auth = e.auth;
  if (!auth) throw new UnauthorizedError("Autenticação necessária.");
  var role = String(auth.get("role") || "");
  if (role !== "admin" && role !== "gerente") {
    throw new ForbiddenError("Atividade da OS é restrita a admin/gerente.");
  }

  var rec = e.record;
  // Client só pode criar comentário.
  rec.set("tipo", "comentario");
  rec.set("autor", String(auth.id));

  var texto = String(rec.getString("texto") || "").trim();
  if (!texto) throw new BadRequestError("Comentário vazio.");
  if (texto.length > 4000) throw new BadRequestError("Comentário muito longo.");

  var osId = relId(rec.get("os"));
  if (!osId) throw new BadRequestError("OS obrigatória.");

  // Confirma que a OS existe (404 se não).
  try {
    e.app.findRecordById("ordens_servico", osId);
  } catch (_) {
    throw new BadRequestError("OS não encontrada.");
  }

  // Mentions: aceita o que o client mandou + parse do texto.
  var rawMentions = rec.get("mentions");
  var explicit = [];
  if (Array.isArray(rawMentions)) {
    for (var i = 0; i < rawMentions.length; i++) {
      explicit.push(relId(rawMentions[i]));
    }
  } else if (rawMentions) {
    explicit.push(relId(rawMentions));
  }
  var resolved = resolveMentions(e.app, texto, explicit);
  rec.set("mentions", resolved);

  // Limpa campos de alteração (client não grava log).
  rec.set("campo", "");
  rec.set("valor_antes", "");
  rec.set("valor_depois", "");
}

/**
 * Pós-create de comentário: gera notificações (best-effort, após e.next).
 */
function afterComentarioCreate(app, record, auth) {
  if (!record) return;
  var tipo = String(record.getString("tipo") || "");
  if (tipo !== "comentario") return;

  var mentions = record.get("mentions") || [];
  var ids = [];
  if (Array.isArray(mentions)) {
    for (var i = 0; i < mentions.length; i++) ids.push(relId(mentions[i]));
  } else if (mentions) {
    ids.push(relId(mentions));
  }
  if (!ids.length) return;

  var autorId = auth ? String(auth.id) : relId(record.get("autor"));
  notifyMentions(app, {
    destIds: ids,
    autorId: autorId,
    osId: relId(record.get("os")),
    atividadeId: String(record.id || ""),
    autorNome: auth ? authDisplayName(auth) : "Alguém",
    texto: record.getString("texto") || "",
  });
}

module.exports = {
  logOsUpdate: logOsUpdate,
  logOsCreate: logOsCreate,
  createAtividade: createAtividade,
  guardComentarioCreate: guardComentarioCreate,
  afterComentarioCreate: afterComentarioCreate,
  resolveMentions: resolveMentions,
  serializeValue: serializeValue,
  fieldLabel: fieldLabel,
  SKIP_FIELDS: SKIP_FIELDS,
};
