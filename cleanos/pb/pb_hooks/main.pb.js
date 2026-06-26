/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — registro dos hooks.
 *
 * Separação de responsabilidades:
 *   - Hooks de MODELO (onRecordCreate/onRecordUpdate): denormalização dos campos
 *     seguros, gestão do `endereco_liberado` e invariante de pagamento. Rodam em
 *     QUALQUER caminho de gravação (API, seed, admin UI) → garantia consistente.
 *   - Hooks de REQUEST (onRecord*Request): autorização a nível de campo que
 *     depende do usuário autenticado (travas do profissional, repasse só-admin,
 *     proteção de role/email em users).
 *
 * A proteção anti-desvio principal vive nas REGRAS DE COLEÇÃO (migration):
 * o papel `profissional` simplesmente não consegue ler a coleção `clientes`.
 */

// ----------------------------------------------------------------------------
// ORDENS DE SERVIÇO — modelo (sempre roda)
// ----------------------------------------------------------------------------
onRecordCreate((e) => {
  const lib = require(`${__hooks}/os_logic.js`);
  lib.syncDenormalized(e.app, e.record);
  lib.manageEndereco(e.app, e.record); // limpa/define endereço conforme status
  lib.assertPaymentIfConcluida(e.record);
  e.next();
}, "ordens_servico");

onRecordUpdate((e) => {
  const lib = require(`${__hooks}/os_logic.js`);
  lib.syncDenormalized(e.app, e.record);
  lib.manageEndereco(e.app, e.record);
  lib.assertPaymentIfConcluida(e.record);
  lib.triggerRatingWebhookIfConcluida(e.app, e.record);
  e.next();
}, "ordens_servico");

// ----------------------------------------------------------------------------
// ORDENS DE SERVIÇO — request (autorização fina por papel)
// ----------------------------------------------------------------------------

// F1 — guard anti-oráculo relacional: bloqueia filter/sort que atravessam a
// relação cliente→cofre quando o caller é profissional.
// Mesmo que a versão atual do PocketBase bloqueie nativamente o data-oracle,
// este guard é defesa em profundidade e fecha o schema-oracle de sort.
onRecordsListRequest((e) => {
  const auth = e.auth;
  if (!auth || String(auth.get("role")) !== "profissional") {
    return e.next();
  }
  const info   = e.requestInfo();
  const filter = String(info.query["filter"] || "");
  const sort   = String(info.query["sort"]   || "");
  // Rejeita qualquer referência a campos relacionais do cofre de clientes
  const BLOCKED = /cliente\.|@collection/i;
  if (BLOCKED.test(filter) || BLOCKED.test(sort)) {
    throw new BadRequestError(
      "Filtros ou ordenação por campos relacionais não são permitidos para o papel profissional."
    );
  }
  e.next();
}, "ordens_servico");

// F1 — mesmo guard para o caminho realtime (subscribe com options.filter).
onRealtimeSubscribeRequest((e) => {
  const auth = e.auth;
  if (!auth || String(auth.get("role")) !== "profissional") {
    return e.next();
  }
  const BLOCKED = /cliente\.|@collection/i;
  const subs = e.subscriptions || [];
  for (let i = 0; i < subs.length; i++) {
    const sub = String(subs[i]);
    // Apenas assinaturas em ordens_servico são relevantes aqui
    if (/^ordens_servico/.test(sub)) {
      let decoded = sub;
      try { decoded = decodeURIComponent(sub); } catch (_) {}
      if (BLOCKED.test(decoded)) {
        throw new ForbiddenError(
          "Assinatura realtime com filtro relacional não é permitida para o papel profissional."
        );
      }
    }
  }
  e.next();
});

onRecordUpdateRequest((e) => {
  const lib = require(`${__hooks}/os_logic.js`);
  lib.guardOrdemUpdateRequest(e); // lança erro se a alteração for proibida
  e.next();
}, "ordens_servico");

// ----------------------------------------------------------------------------
// USERS — request: impede escalonamento de privilégio / troca de e-mail por
// não-admin no self-update (a updateRule libera o próprio registro).
// ----------------------------------------------------------------------------
onRecordUpdateRequest((e) => {
  const auth = e.auth;
  const role = auth ? String(auth.get("role")) : "";
  if (role !== "admin" && role !== "gerente") {
    const orig = e.record.original();
    if (String(orig.get("role")) !== String(e.record.get("role"))) {
      throw new ForbiddenError("Você não pode alterar seu próprio papel (role).");
    }
    if (String(orig.get("email")) !== String(e.record.get("email"))) {
      throw new ForbiddenError("Alteração de e-mail requer admin/gerente.");
    }
  }
  e.next();
}, "users");

// F6 — bloqueia o fluxo dedicado de email-change para não-admin/gerente.
// O hook acima cobre o update comum; este cobre o endpoint /request-email-change.
onRecordRequestEmailChangeRequest((e) => {
  const auth = e.auth;
  const role = auth ? String(auth.get("role")) : "";
  if (role !== "admin" && role !== "gerente") {
    throw new ForbiddenError("Alteração de e-mail requer admin/gerente.");
  }
  e.next();
}, "users");

// ----------------------------------------------------------------------------
// F3 — CRON: limpa endereco_liberado de OS eternamente em_andamento.
// Roda 03:05 UTC (= 00:05 BRT, UTC-3 fixo). Idempotente.
// ----------------------------------------------------------------------------
cronAdd("cleanStaleEndereco", "5 3 * * *", () => {
  try {
    const nowBRT   = new Date(Date.now() - 3 * 3600 * 1000);
    const todayBRT = nowBRT.toISOString().slice(0, 10);

    const records = $app.findAllRecords(
      "ordens_servico",
      $dbx.hashExp({ status: "em_andamento" })
    );

    let cleaned = 0;
    for (const rec of records) {
      const raw = rec.getString("data_hora");
      if (!raw) continue;
      // Converte data_hora (UTC) para BRT e pega o dia
      const dataBRT = new Date(new Date(raw).getTime() - 3 * 3600 * 1000);
      const diaBRT  = dataBRT.toISOString().slice(0, 10);
      if (diaBRT < todayBRT) {
        rec.set("endereco_liberado", "");
        $app.save(rec);
        cleaned++;
      }
    }

    if (cleaned > 0) {
      console.log(
        `[cleanStaleEndereco] Limpou endereco_liberado de ${cleaned} OS(s) expiradas (dia BRT < ${todayBRT}).`
      );
    }
  } catch (err) {
    console.error(`[cleanStaleEndereco] Erro ao limpar OS expiradas: ${err}`);
  }
});
