/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — helper Google Maps (módulo CommonJS).
 *
 * Lê GOOGLE_MAPS_API_KEY do ambiente (padrão $http.send, igual uazapi.js).
 * NUNCA hardcode da chave. Em produção declare em /opt/cleanos/cleanos.env.
 *
 * DEGRADAÇÃO GRACIOSA (regra do doc 09 §3): se a chave faltar OU a API falhar,
 * as funções LOGAM e retornam null — nunca lançam. O rastreamento simplesmente
 * não avança (o botão "Cheguei ao local" manual continua funcionando), sem
 * quebrar nenhum fluxo existente.
 *
 * Deve ser carregado via require() DENTRO de cada handler/cron. $http, $os são
 * globais PocketBase disponíveis no contexto de execução.
 *
 * Funções exportadas:
 *   geocode(endereco)                 → { lat, lng } | null
 *   etaMinutes(oLat,oLng,dLat,dLng)   → number (minutos, inteiro) | null
 */

var GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json";
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
 * Geocodifica um endereço em texto livre → { lat, lng }.
 * Retorna null (com log) se a chave faltar, o endereço for vazio, ou a API falhar.
 * @param {string} endereco  ex.: "Rua X, 123 - Bairro - Cidade - CEP 01000-000"
 */
function geocode(endereco) {
  var key = apiKey();
  if (!key) {
    console.log("[maps] GOOGLE_MAPS_API_KEY ausente; geocode pulado (degradação graciosa).");
    return null;
  }
  var addr = String(endereco || "").trim();
  if (!addr) {
    console.log("[maps] geocode chamado com endereço vazio; pulado.");
    return null;
  }
  try {
    var url = buildUrl(GEOCODE_URL, {
      address:  addr,
      key:      key,
      region:   "br",
      language: "pt-BR",
    });
    var res = $http.send({ method: "GET", url: url, timeout: 8 });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      console.error("[maps] geocode HTTP " + res.statusCode + ": " +
        (res.raw ? String(res.raw).slice(0, 200) : "(sem corpo)"));
      return null;
    }
    var data = res.json || {};
    if (data.status !== "OK" || !data.results || !data.results.length) {
      console.error("[maps] geocode status=" + (data.status || "?") +
        " (" + (data.error_message || "sem resultados") + ")");
      return null;
    }
    var loc = data.results[0].geometry && data.results[0].geometry.location;
    if (!loc || typeof loc.lat === "undefined" || typeof loc.lng === "undefined") {
      console.error("[maps] geocode sem geometry.location.");
      return null;
    }
    return { lat: Number(loc.lat), lng: Number(loc.lng) };
  } catch (err) {
    console.error("[maps] geocode falhou (ignorado): " + err);
    return null;
  }
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
