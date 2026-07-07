/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — helpers compartilhados para as rotas WhatsApp (módulo CommonJS).
 *
 * Deve ser carregado via require() DENTRO de cada handler de routerAdd,
 * nunca no escopo externo do arquivo .pb.js.
 * $app, ForbiddenError, UnauthorizedError são globais PocketBase disponíveis
 * no contexto de execução dos handlers.
 */

/**
 * Verifica que o usuário autenticado tem papel admin ou gerente.
 * Lança ForbiddenError/UnauthorizedError caso contrário.
 */
function requireAdminOrGerente(e) {
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  const role = String(e.auth.get("role"));
  if (role !== "admin" && role !== "gerente") {
    throw new ForbiddenError("Rota restrita a admin/gerente.");
  }
}

/**
 * Retorna o registro singleton de app_config.
 * @param {any} app  instância de $app passada pelo caller (global do handler)
 */
function getAppConfig(app) {
  return app.findFirstRecordByFilter("app_config", "id != ''");
}

/**
 * Extrai o objeto `instance` de respostas UAZAPI que podem vir com ou sem wrapper.
 */
function extractInstance(res) {
  return res.instance || res;
}

/**
 * Formata um instante UTC (ISO do `data_hora`) para o relógio de parede BRT
 * (UTC-3), no formato "DD/MM às HH:MM". String vazia se ilegível.
 */
function fmtBrt(iso) {
  try {
    const t = new Date(iso).getTime();
    if (isNaN(t)) return "";
    const d = new Date(t - 3 * 3600 * 1000); // desloca p/ BRT e lê em UTC
    const p2 = (n) => (n < 10 ? "0" + n : "" + n);
    return `${p2(d.getUTCDate())}/${p2(d.getUTCMonth() + 1)} às ${p2(d.getUTCHours())}:${p2(d.getUTCMinutes())}`;
  } catch (_) {
    return "";
  }
}

/**
 * Notifica o PROFISSIONAL, por WhatsApp, que uma nova OS foi atribuída a ele —
 * com um deep-link (App Link) que abre o app direto na tela da OS.
 *
 * Anti-desvio: a mensagem usa SÓ os campos que o profissional já enxerga no app
 * (nome_curto "Carlos S.", bairro, tipo_servico_nome, data_hora). NUNCA telefone,
 * e-mail, nome completo ou endereço completo do cliente.
 *
 * Best-effort (espelha push.js/sendAviso): chave/instância/numero ausentes ou
 * WhatsApp fora → LOGA e retorna { skipped }, nunca lança. É chamada DEPOIS do
 * e.next() no hook, então jamais bloqueia o create/update da OS.
 *
 * @param {any} app     instância de $app (global do handler)
 * @param {string} userId  id do profissional destinatário
 * @param {any} os      registro da OS (para o resumo + id do deep-link)
 * @returns {{ok:boolean, skipped?:boolean, reason?:string}}
 */
function notifyProfNovaOS(app, userId, os) {
  if (!userId || !os) return { ok: false, skipped: true, reason: "args" };

  const uazapi = require(`${__hooks}/uazapi.js`);

  // 1. Config/instância. Sem instância → pula (estado normal em dev).
  let cfg;
  try {
    cfg = getAppConfig(app);
  } catch (_) {
    return { ok: false, skipped: true, reason: "no_config" };
  }
  const instanceToken = cfg.getString("whatsapp_instance_token");
  if (!instanceToken) return { ok: false, skipped: true, reason: "no_instance" };

  // Status é atualizado a cada minuto pelo cron trackingAvisos — barato e fresco
  // o bastante. Sem conexão, não tenta (evita um envio fadado ao erro).
  if (cfg.getString("whatsapp_status") !== "connected") {
    return { ok: false, skipped: true, reason: "wpp_disconnected" };
  }

  // 2. Número do PRÓPRIO profissional (contato dele, não é PII de cliente).
  let numero = "";
  try {
    const prof = app.findRecordById("users", String(userId));
    numero = uazapi.normalizePhone(prof.getString("whatsapp"));
  } catch (_) {
    return { ok: false, skipped: true, reason: "no_user" };
  }
  if (!numero) {
    console.log(`[notifyProf] Profissional ${userId} sem whatsapp cadastrado; aviso pulado.`);
    return { ok: false, skipped: true, reason: "no_number" };
  }

  // 3. Mensagem — só campos seguros (os que o profissional já vê) + deep-link.
  const base = ($os.getenv("APP_PUBLIC_URL") || "https://app.cleanox.com.br").replace(/\/+$/, "");
  const link = `${base}/app/os/${String(os.id)}`;
  const quando = fmtBrt(os.getString("data_hora"));
  const linhas = [
    "🔔 *Nova OS atribuída a você*",
    "",
    `📍 ${os.getString("nome_curto") || "Cliente"} — ${os.getString("bairro") || "—"}`,
    `🧹 ${os.getString("tipo_servico_nome") || "Serviço"}`,
  ];
  if (quando) linhas.push(`📅 ${quando}`);
  linhas.push("", "👉 Toque para abrir no app:", link);
  const texto = linhas.join("\n");

  // 4. Envio best-effort — nunca lança.
  try {
    uazapi.sendText(instanceToken, numero, texto);
    return { ok: true };
  } catch (err) {
    console.error(`[notifyProf] Falha ao notificar nova OS ${os.id} (ignorado): ${err}`);
    return { ok: false, skipped: true, reason: "send_failed" };
  }
}

module.exports = {
  requireAdminOrGerente,
  getAppConfig,
  extractInstance,
  fmtBrt,
  notifyProfNovaOS,
};
