/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — envio de push nativo via FCM (módulo CommonJS).
 *
 * Lê FCM_SERVER_KEY do ambiente (padrão $http.send, igual uazapi.js). NUNCA
 * hardcode da chave. Em produção declare em /opt/cleanos/cleanos.env.
 *
 * DEGRADAÇÃO GRACIOSA (doc 09 §3): se a chave faltar OU o usuário não tiver
 * tokens OU a API falhar, LOGA e retorna sem lançar — o fluxo que dispara o push
 * (ex.: atribuição de OS) nunca é bloqueado.
 *
 * Usa a FCM Legacy HTTP API (Authorization: key=<server key>), que é o contrato
 * do doc (FCM_SERVER_KEY). Quando o app Flutter migrar para HTTP v1 (OAuth), este
 * helper é o único ponto a trocar; o hook que o chama permanece igual.
 *
 * Deve ser carregado via require() DENTRO de cada handler/hook. $app, $http, $os
 * são globais PocketBase disponíveis no contexto de execução.
 *
 * Funções exportadas:
 *   tokensForUser(app, userId)                    → string[]
 *   sendToTokens(tokens, title, body, data?)      → { ok, skipped?, reason? }
 *   notifyUserNovaOS(app, userId, osId?)          → dispara "Nova OS" (best-effort)
 */

var FCM_URL = "https://fcm.googleapis.com/fcm/send";

function serverKey() {
  return $os.getenv("FCM_SERVER_KEY") || "";
}

/**
 * Coleta os tokens FCM ativos de um usuário (todas as plataformas).
 * @returns {string[]}  lista (possivelmente vazia) de tokens.
 */
function tokensForUser(app, userId) {
  var uid = String(userId || "");
  if (!uid) return [];
  var out = [];
  try {
    var recs = app.findAllRecords("push_tokens", $dbx.hashExp({ usuario: uid }));
    for (var i = 0; i < recs.length; i++) {
      var t = recs[i].getString("token");
      if (t) out.push(t);
    }
  } catch (err) {
    console.error("[fcm] Falha ao ler push_tokens (ignorado): " + err);
  }
  return out;
}

/**
 * Envia uma notificação para uma lista de tokens FCM.
 * Degrada graciosamente: chave ausente / lista vazia → { skipped: true }.
 */
function sendToTokens(tokens, title, body, data) {
  var key = serverKey();
  if (!key) {
    console.log("[fcm] FCM_SERVER_KEY ausente; push pulado (degradação graciosa).");
    return { ok: false, skipped: true, reason: "no_key" };
  }
  if (!tokens || !tokens.length) {
    console.log("[fcm] Nenhum token para o destinatário; push pulado.");
    return { ok: false, skipped: true, reason: "no_tokens" };
  }
  try {
    var payload = {
      registration_ids: tokens,
      notification: { title: String(title || ""), body: String(body || "") },
      priority: "high",
    };
    if (data) payload.data = data;

    var res = $http.send({
      method:  "POST",
      url:     FCM_URL,
      headers: { "Authorization": "key=" + key, "Content-Type": "application/json" },
      body:    JSON.stringify(payload),
      timeout: 8,
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      console.error("[fcm] send HTTP " + res.statusCode + ": " +
        (res.raw ? String(res.raw).slice(0, 200) : "(sem corpo)"));
      return { ok: false, reason: "http_" + res.statusCode };
    }
    return { ok: true };
  } catch (err) {
    console.error("[fcm] send falhou (ignorado): " + err);
    return { ok: false, reason: "exception" };
  }
}

/**
 * Notifica um profissional de que uma nova OS foi atribuída a ele. Best-effort.
 * @param {string} userId  id do profissional
 * @param {string} [osId]  id da OS (vai no data payload para deep-link no app)
 */
function notifyUserNovaOS(app, userId, osId) {
  var tokens = tokensForUser(app, userId);
  if (!tokens.length) {
    // Sem log de erro: profissional pode simplesmente não ter o app instalado.
    return { ok: false, skipped: true, reason: "no_tokens" };
  }
  var data = { tipo: "nova_os" };
  if (osId) data.os_id = String(osId);
  return sendToTokens(
    tokens,
    "Nova OS atribuída",
    "Você recebeu uma nova ordem de serviço. Toque para ver os detalhes.",
    data
  );
}

module.exports = { tokensForUser, sendToTokens, notifyUserNovaOS };
