/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — helper de mapas (módulo CommonJS).
 *
 * Geocode:
 *   1) Google Geocoding se GOOGLE_MAPS_API_KEY estiver no ambiente
 *   2) Fallback Nominatim (OpenStreetMap) — gratuito, volume baixo do CleanOS
 *
 * ETA (etaMinutes) continua só com Google Distance Matrix (precisa da chave).
 *
 * DEGRADAÇÃO GRACIOSA: se tudo falhar, retorna null — nunca lança.
 * Carregar via require() DENTRO do handler (R9).
 *
 * Funções exportadas:
 *   geocode(endereco)                 → { lat, lng } | null
 *   etaMinutes(oLat,oLng,dLat,dLng)   → number (minutos, inteiro) | null
 */

var GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json";
var NOMINATIM_URL = "https://nominatim.openstreetmap.org/search";
var DM_URL      = "https://maps.googleapis.com/maps/api/distancematrix/json";

function apiKey() {
  return $os.getenv("GOOGLE_MAPS_API_KEY") || "";
}

function buildUrl(base, params) {
  var parts = [];
  for (var k in params) {
    if (Object.prototype.hasOwnProperty.call(params, k)) {
      parts.push(encodeURIComponent(k) + "=" + encodeURIComponent(String(params[k])));
    }
  }
  return base + "?" + parts.join("&");
}

/**
 * Variantes do endereço para geocode (do mais preciso ao bairro/cidade).
 * Remove "AP 05", CEP etc. que confundem o Nominatim.
 */
function geocodeQueries(endereco) {
  var raw = String(endereco || "").trim();
  if (!raw) return [];
  var q = [];
  function push(s) {
    s = String(s || "").replace(/\s+/g, " ").trim();
    if (!s) return;
    for (var i = 0; i < q.length; i++) if (q[i] === s) return;
    q.push(s);
  }
  push(raw);
  // "Rua X, 123 - Bairro - Cidade" → unifica separadores
  var uni = raw.replace(/\s*[-–—]\s*/g, ", ").replace(/\s*,\s*/g, ", ");
  push(uni);
  // tira apt/bloco/casa que atrapalham
  var semApt = uni
    .replace(/\b(AP|APT|APTO|APARTAMENTO|BL|BLOCO|CASA|SALA)\s*\.?\s*\w+\b/gi, "")
    .replace(/,\s*,/g, ",")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/^,\s*|,\s*$/g, "");
  push(semApt);
  // últimos 2–3 segmentos (bairro + cidade)
  var parts = uni.split(",").map(function (p) { return p.trim(); }).filter(Boolean);
  if (parts.length >= 2) {
    push(parts.slice(-2).join(", ") + ", Brasil");
  }
  if (parts.length >= 3) {
    push(parts.slice(-3).join(", ") + ", Brasil");
  }
  return q;
}

function geocodeGoogle(addr) {
  var key = apiKey();
  if (!key) return null;
  try {
    var url = buildUrl(GEOCODE_URL, {
      address:  addr,
      key:      key,
      region:   "br",
      language: "pt-BR",
    });
    var res = $http.send({ method: "GET", url: url, timeout: 8 });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      console.error("[maps] google geocode HTTP " + res.statusCode);
      return null;
    }
    var data = res.json || {};
    if (data.status !== "OK" || !data.results || !data.results.length) {
      console.error("[maps] google geocode status=" + (data.status || "?"));
      return null;
    }
    var loc = data.results[0].geometry && data.results[0].geometry.location;
    if (!loc || typeof loc.lat === "undefined" || typeof loc.lng === "undefined") {
      return null;
    }
    return { lat: Number(loc.lat), lng: Number(loc.lng) };
  } catch (err) {
    console.error("[maps] google geocode falhou: " + err);
    return null;
  }
}

/**
 * Nominatim (OSM). Política: User-Agent identificável; volume baixo ok.
 * https://operations.osmfoundation.org/policies/nominatim/
 */
function geocodeNominatim(addr) {
  try {
    var url = buildUrl(NOMINATIM_URL, {
      q: addr,
      format: "json",
      limit: "1",
      countrycodes: "br",
      addressdetails: "0",
    });
    var res = $http.send({
      method: "GET",
      url: url,
      timeout: 10,
      headers: {
        "User-Agent": "CleanOS/1.2 (mapa-dia; https://app.cleanox.com.br)",
        Accept: "application/json",
      },
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      console.error("[maps] nominatim HTTP " + res.statusCode);
      return null;
    }
    var data = res.json;
    if (!data) {
      try {
        data = JSON.parse(String(res.raw || "[]"));
      } catch (_) {
        data = [];
      }
    }
    if (!Array.isArray(data) || !data.length) return null;
    var lat = Number(data[0].lat);
    var lng = Number(data[0].lon);
    if (!lat || !lng || isNaN(lat) || isNaN(lng)) return null;
    return { lat: lat, lng: lng };
  } catch (err) {
    console.error("[maps] nominatim falhou: " + err);
    return null;
  }
}

/**
 * Geocodifica um endereço em texto livre → { lat, lng }.
 * Google (se chave) → Nominatim; tenta variantes do texto.
 * @param {string} endereco  ex.: "Rua X, 123 - Bairro - Cidade - CEP 01000-000"
 */
function geocode(endereco) {
  var queries = geocodeQueries(endereco);
  if (!queries.length) {
    console.log("[maps] geocode chamado com endereço vazio; pulado.");
    return null;
  }
  // Google com o texto original (melhor qualidade quando há chave)
  if (apiKey()) {
    var g = geocodeGoogle(queries[0]);
    if (g) return g;
  } else {
    console.log("[maps] GOOGLE_MAPS_API_KEY ausente; usando Nominatim (OSM).");
  }
  for (var i = 0; i < queries.length; i++) {
    var n = geocodeNominatim(queries[i]);
    if (n) {
      console.log("[maps] nominatim ok q=" + queries[i].slice(0, 60));
      return n;
    }
  }
  console.error("[maps] geocode sem resultado para: " + queries[0].slice(0, 80));
  return null;
}

/**
 * ETA em minutos (inteiro, arredondado p/ cima) da origem ao destino, com
 * trânsito atual (Distance Matrix, departure_time=now). Retorna null se a chave
 * faltar, as coords forem inválidas, ou a API falhar/não achar rota.
 */
function etaMinutes(oLat, oLng, dLat, dLng) {
  var key = apiKey();
  if (!key) {
    console.log("[maps] GOOGLE_MAPS_API_KEY ausente; etaMinutes pulado (degradação graciosa).");
    return null;
  }
  var nums = [oLat, oLng, dLat, dLng].map(Number);
  for (var i = 0; i < nums.length; i++) {
    if (isNaN(nums[i])) {
      console.log("[maps] etaMinutes com coordenada inválida; pulado.");
      return null;
    }
  }
  try {
    var url = buildUrl(DM_URL, {
      origins:        nums[0] + "," + nums[1],
      destinations:   nums[2] + "," + nums[3],
      key:            key,
      mode:           "driving",
      departure_time: "now",        // habilita duration_in_traffic
      language:       "pt-BR",
      region:         "br",
    });
    var res = $http.send({ method: "GET", url: url, timeout: 8 });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      console.error("[maps] distancematrix HTTP " + res.statusCode + ": " +
        (res.raw ? String(res.raw).slice(0, 200) : "(sem corpo)"));
      return null;
    }
    var data = res.json || {};
    if (data.status !== "OK" || !data.rows || !data.rows.length) {
      console.error("[maps] distancematrix status=" + (data.status || "?") +
        " (" + (data.error_message || "sem linhas") + ")");
      return null;
    }
    var el = data.rows[0].elements && data.rows[0].elements[0];
    if (!el || el.status !== "OK") {
      console.error("[maps] distancematrix element status=" + (el ? el.status : "?"));
      return null;
    }
    // Prefere duration_in_traffic (com trânsito); cai p/ duration se ausente.
    var dur = el.duration_in_traffic || el.duration;
    if (!dur || typeof dur.value === "undefined") {
      console.error("[maps] distancematrix sem duration.");
      return null;
    }
    var minutes = Math.ceil(Number(dur.value) / 60); // value em segundos
    return isNaN(minutes) ? null : minutes;
  } catch (err) {
    console.error("[maps] etaMinutes falhou (ignorado): " + err);
    return null;
  }
}

module.exports = { geocode, etaMinutes };
