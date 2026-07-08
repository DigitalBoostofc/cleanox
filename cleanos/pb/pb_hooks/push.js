/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — envio de push nativo via FCM HTTP v1 (módulo CommonJS).
 *
 * MIGRAÇÃO (doc 09 §3): a Legacy HTTP API do FCM (`/fcm/send` com
 * `Authorization: key=<FCM_SERVER_KEY>`) foi DESCONTINUADA pelo Google. Este
 * helper usa agora a **FCM HTTP v1**:
 *   POST https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send
 *   Authorization: Bearer <OAuth2 access token do service account>
 * O payload v1 é por-destinatário ({ message: { token, ... } }) — não há mais o
 * lote `registration_ids` da Legacy —, então enviamos um request por token.
 *
 * DEGRADAÇÃO GRACIOSA (igual à Legacy): se FALTAR projeto/token de acesso, OU o
 * usuário não tiver tokens de device, OU a API falhar, o helper LOGA e retorna
 * SEM lançar — o fluxo que dispara o push (ex.: atribuição de OS) nunca quebra.
 * Assim o módulo fica INERTE enquanto as credenciais não existirem.
 *
 * COMO O TOKEN DE ACESSO É OBTIDO (importante):
 *   A HTTP v1 exige um OAuth2 access token do service account, obtido trocando
 *   uma asserção JWT assinada em **RS256** no endpoint de token do Google. A VM
 *   JS do PocketBase (goja) só sabe assinar **HS256** (`$security.createJWT`) —
 *   NÃO há RS256 aqui —, logo a asserção do service account NÃO pode ser gerada
 *   dentro deste hook. Por isso o access token é PROVIDO por um refresher
 *   externo (systemd timer / n8n rodando `google-auth` ou
 *   `gcloud auth application-default print-access-token`), que o mantém fresco
 *   (~55 min) e o expõe em `FCM_ACCESS_TOKEN`. Este helper apenas o consome.
 *
 * ENV VARS (nunca hardcode; declaradas em /opt/cleanos/cleanos.env):
 *   FCM_PROJECT_ID    → id do projeto Firebase (compõe a URL v1).
 *   FCM_ACCESS_TOKEN  → OAuth2 access token do service account (scope
 *                       https://www.googleapis.com/auth/firebase.messaging),
 *                       renovado por processo externo. Vazio ⇒ push pulado.
 *
 * Deve ser carregado via require() DENTRO de cada handler/hook. $app, $http, $os,
 * $dbx são globais PocketBase disponíveis no contexto de execução.
 *
 * Funções exportadas (assinaturas preservadas — o hook que chama não muda):
 *   tokensForUser(app, userId)                    → string[]
 *   sendToTokens(tokens, title, body, data?)      → { ok, skipped?, reason?, sent?, failed? }
 *   notifyUserNovaOS(app, userId, osId?)          → dispara "Nova OS" (best-effort)
 */

function projectId() {
  return $os.getenv("FCM_PROJECT_ID") || "";
}

/**
 * OAuth2 access token do service account (HTTP v1). Provido/renovado por um
 * refresher externo (ver cabeçalho) — a JSVM não consegue assiná-lo (RS256).
 * Vazio ⇒ push inerte (degradação graciosa).
 */
function accessToken() {
  return $os.getenv("FCM_ACCESS_TOKEN") || "";
}

function v1Url(project) {
  return "https://fcm.googleapis.com/v1/projects/" + project + "/messages:send";
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
 * A HTTP v1 exige que `data` seja um mapa string→string. Coage todos os valores
 * para string (a Legacy aceitava tipos arbitrários). Retorna null se vazio.
 */
function stringifyData(data) {
  if (!data) return null;
  var out = {};
  var any = false;
  for (var k in data) {
    if (Object.prototype.hasOwnProperty.call(data, k)) {
      out[k] = String(data[k]);
      any = true;
    }
  }
  return any ? out : null;
}

/**
 * Envia UMA notificação para um ÚNICO token via HTTP v1. Retorna
 * { ok:true } no 2xx, senão { ok:false, reason }. Best-effort: nunca lança.
 */
function sendToOne(url, bearer, token, title, body, dataMap) {
  try {
    var message = {
      token: token,
      notification: { title: String(title || ""), body: String(body || "") },
      // Prioridade alta no Android (equivalente ao priority:"high" da Legacy).
      android: { priority: "high" },
    };
    if (dataMap) message.data = dataMap;

    var res = $http.send({
      method:  "POST",
      url:     url,
      headers: { "Authorization": "Bearer " + bearer, "Content-Type": "application/json" },
      body:    JSON.stringify({ message: message }),
      timeout: 8,
    });

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return { ok: true };
    }
    // 401 = access token expirado/inválido (refresher externo atrasado);
    // 404 / UNREGISTERED = token de device obsoleto. Só loga (best-effort).
    console.error("[fcm] v1 send HTTP " + res.statusCode + ": " +
      (res.raw ? String(res.raw).slice(0, 200) : "(sem corpo)"));
    return { ok: false, reason: "http_" + res.statusCode };
  } catch (err) {
    console.error("[fcm] v1 send falhou (ignorado): " + err);
    return { ok: false, reason: "exception" };
  }
}

/**
 * Envia uma notificação para uma lista de tokens FCM (um request v1 por token).
 * Degrada graciosamente: projeto/token de acesso ausente ou lista vazia →
 * { skipped: true }. Retorna também a contagem { sent, failed }.
 */
function sendToTokens(tokens, title, body, data) {
  var project = projectId();
  var bearer  = accessToken();
  if (!project || !bearer) {
    console.log("[fcm] FCM_PROJECT_ID/FCM_ACCESS_TOKEN ausente; push pulado (degradação graciosa).");
    return { ok: false, skipped: true, reason: !project ? "no_project" : "no_token" };
  }
  if (!tokens || !tokens.length) {
    console.log("[fcm] Nenhum token para o destinatário; push pulado.");
    return { ok: false, skipped: true, reason: "no_tokens" };
  }

  var url     = v1Url(project);
  var dataMap = stringifyData(data);
  var sent = 0, failed = 0;
  for (var i = 0; i < tokens.length; i++) {
    var r = sendToOne(url, bearer, tokens[i], title, body, dataMap);
    if (r.ok) sent++; else failed++;
  }
  return { ok: sent > 0, sent: sent, failed: failed };
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
