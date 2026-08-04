/**
 * Unit tests — os_atividade_lib (parse de menções + labels + skip fields).
 * Roda sem PocketBase vivo (só o lib CommonJS).
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const lib = require(
  join(__dirname, "../../pb/pb_hooks/os_atividade_lib.js"),
);

describe("os_atividade_lib field labels", () => {
  it("label de status e profissional", () => {
    assert.equal(lib.fieldLabel("status"), "Status");
    assert.equal(lib.fieldLabel("profissional"), "Profissional");
    assert.equal(lib.fieldLabel("campo_desconhecido"), "campo_desconhecido");
  });

  it("SKIP_FIELDS cobre GPS efêmero", () => {
    assert.equal(lib.SKIP_FIELDS.prof_lat, true);
    assert.equal(lib.SKIP_FIELDS.aviso_5min_em, true);
    assert.equal(lib.SKIP_FIELDS.status, undefined);
  });
});

describe("os_atividade_lib serializeValue", () => {
  it("trata record mock com getString", () => {
    const rec = {
      getString(k) {
        if (k === "status") return "concluida";
        return "";
      },
      get(k) {
        return this.getString(k);
      },
    };
    assert.equal(lib.serializeValue(rec, "status"), "concluida");
    assert.equal(lib.serializeValue(rec, "vazio"), "—");
  });
});

describe("os_atividade_lib resolveMentions (com app mock)", () => {
  function makeUser(id, nome, role) {
    return {
      id,
      get(k) {
        if (k === "nome") return nome;
        if (k === "role") return role;
        if (k === "name") return "";
        if (k === "email") return "";
        return "";
      },
      getString(k) {
        return String(this.get(k) || "");
      },
    };
  }

  it("aceita ids explícitos de admin/gerente e ignora profissional", () => {
    const admin = makeUser("a1", "Leo Admin", "admin");
    const ger = makeUser("g1", "Maria Gerente", "gerente");
    const prof = makeUser("p1", "João Prof", "profissional");
    const app = {
      findAllRecords() {
        return [admin, ger];
      },
    };
    // explicit tem prof (deve filtrar) + admin
    const ids = lib.resolveMentions(app, "oi", ["a1", "p1", "g1"]);
    assert.deepEqual(ids.sort(), ["a1", "g1"].sort());
    // prof não está em staff
    assert.ok(!ids.includes("p1"));
  });

  it("parseia @Nome completo e @primeiro no texto", () => {
    const admin = makeUser("a1", "Leo Admin", "admin");
    const ger = makeUser("g1", "Maria Silva", "gerente");
    const app = {
      findAllRecords() {
        return [admin, ger];
      },
    };
    const ids1 = lib.resolveMentions(app, "Fala @Leo Admin, confere?", []);
    assert.deepEqual(ids1, ["a1"]);
    const ids2 = lib.resolveMentions(app, "Oi @Maria, blz?", []);
    assert.deepEqual(ids2, ["g1"]);
  });
});
