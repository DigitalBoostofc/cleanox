"use strict";

function parsePayload(body) {
  const source = body && typeof body === "object" ? body : {};
  const kind = String(source.kind || "");
  if (kind !== "taxonomia" && kind !== "servicos") {
    throw new Error("Tipo de catálogo inválido.");
  }
  if (!Array.isArray(source.ids) || source.ids.length < 1 || source.ids.length > 500) {
    throw new Error("A sequência deve conter entre 1 e 500 itens.");
  }
  const ids = source.ids.map((id) => String(id || "").trim());
  if (ids.some((id) => !id)) throw new Error("A sequência contém um item inválido.");
  if (new Set(ids).size !== ids.length) {
    throw new Error("A sequência não pode conter itens duplicados.");
  }
  return { kind, ids };
}

function hasExactIds(ids, records) {
  if (!Array.isArray(records) || records.length !== ids.length) return false;
  const expected = new Set(ids);
  for (const record of records) {
    if (!record || !expected.delete(String(record.id || ""))) return false;
  }
  return expected.size === 0;
}

function orderAt(index) {
  return (Number(index) + 1) * 10;
}

function scopeFilter(kind, first) {
  if (kind === "servicos") {
    return {
      categoria: first.getString("categoria"),
      grupo: first.getString("grupo"),
    };
  }
  return {
    tipo: first.getString("tipo"),
    parent: first.getString("parent"),
    ativo: true,
  };
}

module.exports = { parsePayload, hasExactIds, orderAt, scopeFilter };
