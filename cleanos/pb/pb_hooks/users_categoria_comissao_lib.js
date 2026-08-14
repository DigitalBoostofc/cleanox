/**
 * Categoria financeira automática do profissional: Equipe → nome.
 *
 * Uma única subcategoria classifica comissão automática e bonificação.
 * CommonJS: require() no hook e em prof_comissao_pago_lib.js (R9).
 */

var EQUIPE_CANONICAL_ID = "catdequipe00001";

function fail(msg) {
  if (typeof BadRequestError === "function") {
    throw new BadRequestError(msg);
  }
  var err = new Error(msg);
  err.name = "BadRequestError";
  throw err;
}

function asRoleList(value) {
  if (Array.isArray(value)) return value.map(String);
  if (typeof value === "string" && value) {
    try {
      var parsed = JSON.parse(value);
      if (Array.isArray(parsed)) return parsed.map(String);
    } catch (_) {}
    return [value];
  }
  return [];
}

function papeisDoUsuario(record) {
  var role = String(record.get("role") || "").trim();
  var roles = asRoleList(record.get("roles"));
  if (roles.length === 0) roles = [role || "profissional"];
  return roles;
}

function temPapelProfissional(record) {
  var papeis = papeisDoUsuario(record);
  for (var i = 0; i < papeis.length; i++) {
    if (papeis[i] === "profissional") return true;
  }
  return false;
}

function nomeDoUsuario(record) {
  var nome = String(record.get("nome") || "").trim();
  if (nome) return nome;
  return String(record.get("name") || "").trim();
}

function ehRaizDespesa(rec) {
  if (!rec) return false;
  if (String(rec.get("tipo") || "") !== "despesa") return false;
  return !String(rec.get("parent_id") || "").trim();
}

function resolverRaizEquipe(app) {
  try {
    var equipe = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && nome = 'Equipe' && (parent_id = '' || parent_id = null)",
    );
    if (equipe && ehRaizDespesa(equipe)) return equipe;
  } catch (_) {}
  try {
    var canon = app.findRecordById("fin_categorias", EQUIPE_CANONICAL_ID);
    if (ehRaizDespesa(canon)) return canon;
  } catch (_) {}
  fail(
    'Categoria raiz de despesa "Equipe" não encontrada. Crie Equipe (ou restaure catdequipe00001) antes de cadastrar profissional.',
  );
}

function acharSubcategoria(app, equipeId, nome) {
  var safeNome = String(nome).replace(/'/g, "\\'");
  try {
    var sub = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && parent_id = '" +
        equipeId +
        "' && nome = '" +
        safeNome +
        "'",
    );
    if (sub) return sub;
  } catch (_) {}
  return null;
}

function criarSubcategoria(app, equipeId, nome) {
  var col = app.findCollectionByNameOrId("fin_categorias");
  var sub = new Record(col);
  sub.set("nome", nome);
  sub.set("tipo", "despesa");
  sub.set("parent_id", equipeId);
  sub.set("icone", "");
  sub.set("cor", "");
  sub.set("arquivada", false);
  app.save(sub);
  return sub;
}

function garantirSubcategoriaEquipe(app, profNome) {
  var equipe = resolverRaizEquipe(app);
  var nome = String(profNome || "").trim();
  if (!nome) {
    fail(
      "Nome do profissional é obrigatório para configurar a categoria financeira Equipe.",
    );
  }
  var existente = acharSubcategoria(app, equipe.id, nome);
  if (existente) {
    return { equipeId: equipe.id, subId: existente.id, created: false };
  }
  var criada = criarSubcategoria(app, equipe.id, nome);
  return { equipeId: equipe.id, subId: criada.id, created: true };
}

function categoriaDespesaValida(app, categoriaId) {
  var id = String(categoriaId || "").trim();
  if (!id) return null;
  try {
    var selected = app.findRecordById("fin_categorias", id);
    if (String(selected.get("tipo") || "") !== "despesa") return null;
    var parentId = String(selected.get("parent_id") || "").trim();
    if (!parentId) return { categoriaId: selected.id, subcategoriaId: null };
    return { categoriaId: parentId, subcategoriaId: selected.id };
  } catch (_) {
    return null;
  }
}

function resolverCategoriaConfigurada(app, profId) {
  var id = String(profId || "").trim();
  if (!id) return null;
  try {
    var user = app.findRecordById("users", id);
    return categoriaDespesaValida(app, user.get("categoria_comissao"));
  } catch (_) {
    return null;
  }
}

function aplicarCategoriaNoCreate(app, record) {
  if (!temPapelProfissional(record)) {
    record.set("categoria_comissao", "");
    return { created: false, subId: "", equipeId: "" };
  }
  var nome = nomeDoUsuario(record);
  if (!nome) {
    fail(
      "Nome do profissional é obrigatório para configurar a categoria financeira Equipe.",
    );
  }
  var out = garantirSubcategoriaEquipe(app, nome);
  record.set("categoria_comissao", out.subId);
  return out;
}

function aplicarCategoriaNoUpdate(app, record) {
  var orig = record.original ? record.original() : null;
  var origCat = orig ? String(orig.get("categoria_comissao") || "").trim() : "";
  var origValida = origCat ? categoriaDespesaValida(app, origCat) : null;

  if (!temPapelProfissional(record)) {
    if (origCat) record.set("categoria_comissao", origCat);
    else record.set("categoria_comissao", "");
    return { created: false, subId: origCat, equipeId: "" };
  }

  if (origValida) {
    record.set("categoria_comissao", origCat);
    return { created: false, subId: origCat, equipeId: origValida.categoriaId };
  }

  var nome = nomeDoUsuario(record);
  if (!nome) {
    fail(
      "Nome do profissional é obrigatório para configurar a categoria financeira Equipe.",
    );
  }
  var out = garantirSubcategoriaEquipe(app, nome);
  record.set("categoria_comissao", out.subId);
  return out;
}

function _aindaReferenciada(app, collection, filter, params) {
  try {
    var list = app.findRecordsByFilter(collection, filter, "", 1, 0, params);
    return !!(list && list.length);
  } catch (_) {
    return false;
  }
}

function backfillUsersCategoriaComissao(app) {
  var equipe = resolverRaizEquipe(app);
  var users = [];
  try {
    users = app.findRecordsByFilter("users", "", "", 500, 0) || [];
  } catch (_) {
    users = [];
  }
  var alterados = 0;
  for (var i = 0; i < users.length; i++) {
    var user = users[i];
    if (!temPapelProfissional(user)) continue;
    var atual = String(user.get("categoria_comissao") || "").trim();
    if (atual && categoriaDespesaValida(app, atual)) continue;
    var nome = nomeDoUsuario(user);
    if (!nome) {
      throw new Error(
        "[mig 76] profissional " +
          String(user.id || "") +
          " sem nome e sem categoria de despesa válida; abortando backfill.",
      );
    }
    var out = garantirSubcategoriaEquipe(app, nome);
    user.set("categoria_comissao", out.subId);
    app.save(user);
    alterados++;
  }
  return { equipeId: equipe.id, alterados: alterados };
}

function compensarSubcategoriaOrfa(app, result) {
  // Só a sub CRIADA nesta tentativa. created:false = reutilizada: não apagar.
  if (!result || result.created !== true) return;
  var subId = String(result.subId || "").trim();
  if (!subId) return;
  if (
    _aindaReferenciada(app, "users", "categoria_comissao = {:id}", { id: subId })
  ) {
    return;
  }
  if (
    _aindaReferenciada(app, "fin_lancamentos", "subcategoria_id = {:id}", {
      id: subId,
    })
  ) {
    return;
  }
  try {
    var rec = app.findRecordById("fin_categorias", subId);
    app.delete(rec);
  } catch (_) {}
}

module.exports = {
  EQUIPE_CANONICAL_ID: EQUIPE_CANONICAL_ID,
  temPapelProfissional: temPapelProfissional,
  nomeDoUsuario: nomeDoUsuario,
  ehRaizDespesa: ehRaizDespesa,
  resolverRaizEquipe: resolverRaizEquipe,
  garantirSubcategoriaEquipe: garantirSubcategoriaEquipe,
  categoriaDespesaValida: categoriaDespesaValida,
  resolverCategoriaConfigurada: resolverCategoriaConfigurada,
  aplicarCategoriaNoCreate: aplicarCategoriaNoCreate,
  aplicarCategoriaNoUpdate: aplicarCategoriaNoUpdate,
  backfillUsersCategoriaComissao: backfillUsersCategoriaComissao,
  compensarSubcategoriaOrfa: compensarSubcategoriaOrfa,
};
