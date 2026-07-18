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
 * Rota OSRM (público) → { distanceM, durationS } | null.
 * Fallback quando não há Google Distance Matrix.
 */
function osrmRoute(oLat, oLng, dLat, dLng) {
  try {
    var url =
      "https://router.project-osrm.org/route/v1/driving/" +
      oLng +
      "," +
      oLat +
      ";" +
      dLng +
      "," +
      dLat +
      "?overview=false";
    var res = $http.send({ method: "GET", url: url, timeout: 10 });
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    var data = res.json || {};
    if (!data.routes || !data.routes.length) return null;
    var r0 = data.routes[0];
    var dist = Number(r0.distance || 0);
    var dur = Number(r0.duration || 0);
    if (!(dist > 0) || !(dur > 0)) return null;
    return { distanceM: dist, durationS: dur };
  } catch (err) {
    console.error("[maps] osrm falhou: " + err);
    return null;
  }
}

/**
 * ETA em minutos (inteiro, arredondado p/ cima) da origem ao destino.
 * 1) Google Distance Matrix (trânsito) se houver chave
 * 2) OSRM (sem trânsito) como fallback gratuito
 */
function etaMinutes(oLat, oLng, dLat, dLng) {
  var nums = [oLat, oLng, dLat, dLng].map(Number);
  for (var i = 0; i < nums.length; i++) {
    if (isNaN(nums[i]) || nums[i] === 0) {
      console.log("[maps] etaMinutes com coordenada inválida; pulado.");
      return null;
    }
  }
  var key = apiKey();
  if (key) {
    try {
      var url = buildUrl(DM_URL, {
        origins:        nums[0] + "," + nums[1],
        destinations:   nums[2] + "," + nums[3],
        key:            key,
        mode:           "driving",
        departure_time: "now",
        language:       "pt-BR",
        region:         "br",
      });
      var res = $http.send({ method: "GET", url: url, timeout: 8 });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        var data = res.json || {};
        if (data.status === "OK" && data.rows && data.rows.length) {
          var el = data.rows[0].elements && data.rows[0].elements[0];
          if (el && el.status === "OK") {
            var dur = el.duration_in_traffic || el.duration;
            if (dur && typeof dur.value !== "undefined") {
              var minutes = Math.ceil(Number(dur.value) / 60);
              if (!isNaN(minutes)) return minutes;
            }
          }
        }
      }
    } catch (err) {
      console.error("[maps] etaMinutes Google falhou: " + err);
    }
  }
  var osrm = osrmRoute(nums[0], nums[1], nums[2], nums[3]);
  if (osrm) {
    var m = Math.ceil(osrm.durationS / 60);
    console.log("[maps] etaMinutes via OSRM: " + m + " min");
    return m;
  }
  return null;
}

/**
 * Distância em linha reta (metros) — fallback se OSRM falhar.
 */
function haversineM(oLat, oLng, dLat, dLng) {
  var R = 6371000;
  var toRad = function (d) {
    return (Number(d) * Math.PI) / 180;
  };
  var lat1 = toRad(oLat);
  var lat2 = toRad(dLat);
  var dLatR = toRad(Number(dLat) - Number(oLat));
  var dLngR = toRad(Number(dLng) - Number(oLng));
  var a =
    Math.sin(dLatR / 2) * Math.sin(dLatR / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLngR / 2) * Math.sin(dLngR / 2);
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Circuito planejado: soma trechos consecutivos de `points` (lat/lng).
 * Preferência OSRM por trecho; haversine se falhar.
 * Retorna { metros, km, fonte: "osrm"|"haversine"|"misto" } | null.
 */
function routeCircuitKm(points) {
  if (!points || points.length < 2) return null;
  var total = 0;
  var usedOsrm = 0;
  var usedHav = 0;
  for (var i = 0; i < points.length - 1; i++) {
    var a = points[i];
    var b = points[i + 1];
    if (!a || !b) continue;
    var oLat = Number(a.lat);
    var oLng = Number(a.lng);
    var dLat = Number(b.lat);
    var dLng = Number(b.lng);
    if (
      isNaN(oLat) ||
      isNaN(oLng) ||
      isNaN(dLat) ||
      isNaN(dLng) ||
      !oLat ||
      !oLng ||
      !dLat ||
      !dLng
    ) {
      continue;
    }
    var osrm = osrmRoute(oLat, oLng, dLat, dLng);
    if (osrm && osrm.distanceM > 0) {
      total += osrm.distanceM;
      usedOsrm += 1;
    } else {
      var h = haversineM(oLat, oLng, dLat, dLng);
      if (h > 0) {
        total += h;
        usedHav += 1;
      }
    }
  }
  if (!(total > 0)) return null;
  var fonte = "osrm";
  if (usedOsrm > 0 && usedHav > 0) fonte = "misto";
  else if (usedHav > 0 && usedOsrm === 0) fonte = "haversine";
  var km = Math.round((total / 1000) * 10) / 10;
  return { metros: Math.round(total), km: km, fonte: fonte };
}

module.exports = {
  geocode,
  etaMinutes,
  osrmRoute,
  haversineM,
  routeCircuitKm,
};
