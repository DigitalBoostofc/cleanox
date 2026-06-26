/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — cliente UAZAPI (módulo CommonJS).
 *
 * Lê BASE_URL e ADMIN_TOKEN de variáveis de ambiente — NUNCA hardcode de valores.
 * Em produção, declare-os em /opt/cleanos/cleanos.env (EnvironmentFile no systemd).
 *
 * Funções exportadas:
 *   createInstance(name)               → res com `token` (da instância)
 *   connectInstance(instanceToken)     → res com `instance.qrcode`, `instance.status`
 *   instanceStatus(instanceToken)      → res com `instance.status`, etc.
 *   disconnectInstance(instanceToken)  → res com `instance.status`
 *   sendText(instanceToken, number, text) → res de envio
 *   normalizePhone(raw)                → "5511999990001"
 *
 * Erro: lança Error("UAZAPI <endpoint> HTTP <status>: <trecho>") em respostas não-2xx.
 */

function baseUrl() {
  const v = $os.getenv("UAZAPI_BASE_URL");
  if (!v) throw new Error("Variável de ambiente UAZAPI_BASE_URL não definida.");
  return v.replace(/\/$/, "");
}

function adminToken() {
  const v = $os.getenv("UAZAPI_ADMIN_TOKEN");
  if (!v) throw new Error("Variável de ambiente UAZAPI_ADMIN_TOKEN não definida.");
  return v;
}

function httpSend(method, endpoint, headersObj, bodyObj) {
  const req = {
    method,
    url: baseUrl() + endpoint,
    headers: Object.assign({ "Accept": "application/json" }, headersObj),
  };
  if (bodyObj !== undefined) {
    req.body = JSON.stringify(bodyObj);
    req.headers["Content-Type"] = "application/json";
  }
  const res = $http.send(req);
  const status = res.statusCode;
  if (status < 200 || status >= 300) {
    const detail = res.raw ? String(res.raw).slice(0, 300) : "(sem corpo)";
    throw new Error("UAZAPI " + endpoint + " HTTP " + status + ": " + detail);
  }
  return res.json || {};
}

/**
 * Cria uma nova instância no UAZAPI (usa admintoken).
 * Retorna `{ token, name, instance, ... }` — o `token` é o token da instância.
 */
function createInstance(name) {
  return httpSend("POST", "/instance/create", { admintoken: adminToken() }, { name });
}

/**
 * Inicia processo de conexão (QR code / pair code).
 * @param {string} instanceToken  token salvo em app_config
 */
function connectInstance(instanceToken) {
  return httpSend("POST", "/instance/connect", { token: instanceToken }, {});
}

/**
 * Retorna status atual da instância.
 * @param {string} instanceToken
 */
function instanceStatus(instanceToken) {
  return httpSend("GET", "/instance/status", { token: instanceToken });
}

/**
 * Desconecta a instância do WhatsApp.
 * @param {string} instanceToken
 */
function disconnectInstance(instanceToken) {
  return httpSend("POST", "/instance/disconnect", { token: instanceToken }, {});
}

/**
 * Envia mensagem de texto via WhatsApp.
 * @param {string} instanceToken
 * @param {string} number  ex.: "5511999990001"
 * @param {string} text    conteúdo da mensagem
 */
function sendText(instanceToken, number, text) {
  return httpSend("POST", "/send/text", { token: instanceToken }, { number, text });
}

/**
 * Normaliza um telefone para o formato UAZAPI (só dígitos, com DDI 55 se ausente).
 * "11 99999-0001" → "5511999990001"
 * "(11)99999-0001" → "5511999990001"
 * "11999990001"  → "5511999990001"
 * "5511999990001" → "5511999990001" (já ok)
 */
function normalizePhone(raw) {
  const digits = String(raw || "").replace(/\D/g, "");
  if (digits.length >= 12) return digits; // já tem DDI
  if (digits.length >= 10) return "55" + digits; // 10-11 dígitos BR sem DDI
  return digits; // tamanho inesperado — devolve como está, UAZAPI valida
}

module.exports = {
  createInstance,
  connectInstance,
  instanceStatus,
  disconnectInstance,
  sendText,
  normalizePhone,
};
