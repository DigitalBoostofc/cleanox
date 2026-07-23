/**
 * CleanOS — matching de order bumps (puro, testável fora do PB).
 *
 * Um bump é elegível se:
 *  1) ativo
 *  2) carrinho NÃO contém nenhum id em excluir_se
 *  3) gatilho bate:
 *     - qualquer_grupo: algum item do carrinho tem grupo ∈ gatilho_valores
 *     - qualquer_servico: algum id do carrinho ∈ gatilho_valores
 */

/**
 * @param {Array<{id:string, grupo?:string}>} cartItems
 * @param {Array<{
 *   id:string,
 *   ativo?:boolean,
 *   gatilho_tipo:string,
 *   gatilho_valores?:any,
 *   excluir_se?:any,
 *   prioridade?:number,
 *   servico_oferta?:string,
 * }>} bumps
 * @returns {Array} bumps elegíveis ordenados por prioridade desc
 */
function matchOrderBumps(cartItems, bumps) {
  const cart = Array.isArray(cartItems) ? cartItems : [];
  const cartIds = {};
  const cartGrupos = {};
  for (var i = 0; i < cart.length; i++) {
    const it = cart[i] || {};
    const id = String(it.id || "").trim();
    if (id) cartIds[id] = true;
    const g = String(it.grupo || "")
      .trim()
      .toLowerCase();
    if (g) cartGrupos[g] = true;
  }

  const out = [];
  const list = Array.isArray(bumps) ? bumps : [];
  for (var b = 0; b < list.length; b++) {
    const bump = list[b] || {};
    if (bump.ativo === false) continue;

    const excl = toStrArray(bump.excluir_se);
    var blocked = false;
    for (var e = 0; e < excl.length; e++) {
      if (cartIds[excl[e]]) {
        blocked = true;
        break;
      }
    }
    // Também bloqueia se o próprio serviço da oferta já está no carrinho
    const oferta = String(bump.servico_oferta || bump.servico_id || "").trim();
    if (oferta && cartIds[oferta]) blocked = true;
    if (blocked) continue;

    const tipo = String(bump.gatilho_tipo || "qualquer_grupo");
    const vals = toStrArray(bump.gatilho_valores).map(function (v) {
      return String(v).trim().toLowerCase();
    });
    if (!vals.length) continue;

    var ok = false;
    if (tipo === "qualquer_servico") {
      for (var s = 0; s < vals.length; s++) {
        if (cartIds[vals[s]] || cartIds[String(bump.gatilho_valores[s])]) {
          ok = true;
          break;
        }
      }
      // match case-sensitive ids too
      if (!ok) {
        const raw = toStrArray(bump.gatilho_valores);
        for (var r = 0; r < raw.length; r++) {
          if (cartIds[raw[r]]) {
            ok = true;
            break;
          }
        }
      }
    } else {
      // qualquer_grupo (default)
      for (var g = 0; g < vals.length; g++) {
        if (cartGrupos[vals[g]]) {
          ok = true;
          break;
        }
      }
    }
    if (!ok) continue;
    out.push(bump);
  }

  out.sort(function (a, b) {
    return Number(b.prioridade || 0) - Number(a.prioridade || 0);
  });
  return out;
}

function toStrArray(v) {
  if (v == null || v === "") return [];
  // PB JSVM às vezes devolve JSONField (gravado via SQL) como array de
  // *bytes* (números 0–255) em vez de parsear o JSON.
  if (Array.isArray(v) && v.length && typeof v[0] === "number") {
    try {
      var asStr = String.fromCharCode.apply(null, v);
      return toStrArray(asStr);
    } catch (_) {
      /* cai no map genérico */
    }
  }
  if (Array.isArray(v)) {
    // Array de char-codes em string ("91","93") — mesmo caso de bytes
    if (
      v.length &&
      typeof v[0] === "string" &&
      v.every(function (x) {
        return /^\d{1,3}$/.test(String(x)) && Number(x) < 256;
      })
    ) {
      try {
        var codes = v.map(function (x) {
          return Number(x);
        });
        var s2 = String.fromCharCode.apply(null, codes);
        return toStrArray(s2);
      } catch (_) {}
    }
    return v
      .map(function (x) {
        if (x == null) return "";
        if (typeof x === "object" && x.id != null) return String(x.id);
        return String(x);
      })
      .filter(Boolean);
  }
  if (typeof v === "string") {
    var t = v.trim();
    if (!t) return [];
    try {
      const p = JSON.parse(t);
      return toStrArray(p);
    } catch (_) {
      return t
        .split(",")
        .map(function (s) {
          return s.trim();
        })
        .filter(Boolean);
    }
  }
  return [];
}

module.exports = {
  matchOrderBumps,
  toStrArray,
};
