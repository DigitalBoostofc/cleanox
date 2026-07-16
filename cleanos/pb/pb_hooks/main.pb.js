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
  lib.stampIniciadaEm(e.record); // carimbo de início (create direto em em_andamento)
  lib.assertPaymentIfConcluida(e.record);
  lib.setRepasseIfConcluida(e.record); // F-002: cobre create-as-concluida (OS nascendo concluida)

  // doc 09 §3: OS nascendo já atribuída a um profissional → push "Nova OS".
  const novoProf = lib.relId(e.record.get("profissional"));

  e.next();

  // Aviso "Nova OS" pelo WhatsApp do profissional (best-effort, nunca bloqueia o
  // create). Traz um deep-link que abre o app direto na OS. Ver notifyProfNovaOS.
  if (novoProf) {
    try {
      require(`${__hooks}/whatsapp_helpers.js`).notifyProfNovaOS(e.app, novoProf, e.record);
    } catch (err) {
      console.error("[notifyProf] Falha ao notificar nova OS (create, ignorado): " + err);
    }
  }
}, "ordens_servico");

onRecordUpdate((e) => {
  const lib = require(`${__hooks}/os_logic.js`);

  // Detecta ATRIBUIÇÃO (mudança de profissional) ANTES do save, comparando com o
  // estado original — para disparar o push "Nova OS" só quando de fato muda.
  const orig     = e.record.original ? e.record.original() : null;
  const antesProf = orig ? lib.relId(orig.get("profissional")) : "";
  const novoProf  = lib.relId(e.record.get("profissional"));
  const atribuiu  = !!novoProf && novoProf !== antesProf;

  lib.syncDenormalized(e.app, e.record);
  lib.manageEndereco(e.app, e.record);
  lib.stampIniciadaEm(e.record); // carimbo de início na transição → em_andamento
  lib.assertPaymentIfConcluida(e.record);
  lib.setRepasseIfConcluida(e.record); // F-002: pendente na transição → concluida
  lib.triggerRatingWebhookIfConcluida(e.app, e.record);

  e.next();

  // Aviso "Nova OS" pelo WhatsApp do profissional (best-effort, nunca bloqueia o
  // update). Só na transição de atribuição real. Deep-link abre o app na OS.
  if (atribuiu) {
    try {
      require(`${__hooks}/whatsapp_helpers.js`).notifyProfNovaOS(e.app, novoProf, e.record);
    } catch (err) {
      console.error("[notifyProf] Falha ao notificar nova OS (update, ignorado): " + err);
    }
  }
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

// F-403: gerente/profissional não pode definir repasse ao CRIAR uma OS.
// Espelha a trava que já existe no onRecordUpdateRequest.
onRecordCreateRequest((e) => {
  const auth = e.auth;
  const role = auth ? String(auth.get("role")) : "";
  if (role !== "admin") {
    const rs = String(e.record.get("repasse_status") || "");
    const rv = Number(e.record.get("repasse_valor") || 0);
    if (rs || rv > 0) {
      throw new ForbiddenError("Apenas o admin pode definir o repasse ao criar uma OS.");
    }
  }
  e.next();
}, "ordens_servico");

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

// F-005: garante emailVisibility=true para qualquer user criado via API/Admin UI.
// (O migrate CLI não garante hooks, por isso o seed também seta diretamente.)
onRecordCreate((e) => {
  e.record.set("emailVisibility", true);
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
//
// F-401 (nota secundária do fuso): a expressão cron roda no fuso LOCAL do
// processo PocketBase, que depende do TZ da VPS (UTC numa Ubuntu "crua", mas
// não garantido). Para tornar o alvo "00:05 BRT" CORRETO independentemente do
// TZ da VPS, roda DE HORA EM HORA (minuto :05): assim a virada do dia BRT é
// sempre coberta dentro de ~1h, qualquer que seja o fuso do processo. O corte é
// por DIA BRT (`diaBRT < todayBRT`) e o save é idempotente, então rodadas extras
// não limpam OS do dia corrente nem têm efeito colateral.
// ----------------------------------------------------------------------------
cronAdd("cleanStaleEndereco", "5 * * * *", () => {
  try {
    const lib      = require(`${__hooks}/os_logic.js`);
    const nowBRT   = new Date(Date.now() - 3 * 3600 * 1000);
    const todayBRT = nowBRT.toISOString().slice(0, 10);

    const records = $app.findAllRecords(
      "ordens_servico",
      $dbx.hashExp({ status: "em_andamento" })
    );

    let cleaned = 0;
    for (const rec of records) {
      // "Stale" = o serviço COMEÇOU (iniciada_em; fallback data_hora p/ OS
      // legadas) num dia BRT anterior. O corte NÃO usa mais data_hora direto:
      // uma OS de ontem iniciada HOJE (regra "dia do serviço ou depois")
      // não pode ter o endereço varrido no meio do atendimento.
      if (lib.isStaleEmAndamento(rec, todayBRT)) {
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

// ----------------------------------------------------------------------------
// doc 09 §3 — CRON: avisos de proximidade "estou a caminho" (GPS ao vivo).
//
// A cada minuto varre as OS em_andamento que:
//   - têm `aviso_a_caminho_em` setado (Msg1 já enviada — a viagem começou);
//   - NÃO têm `cheguei_em` (rastreamento ainda ativo);
//   - têm `prof_pos_em` RECENTE (o app está enviando GPS de verdade);
//   - têm `dest_lat/dest_lng` (destino geocodificado);
//   - a viagem começou há menos de MAX_TRIP_MIN (janela máx — evita OS zumbis).
// Calcula o ETA com trânsito e dispara, de forma IDEMPOTENTE (carimbos
// aviso_5min_em / aviso_1min_em), a Msg2 (≤5min) e a Msg3 (≤1min).
//
// Degradação graciosa: sem GOOGLE_MAPS_API_KEY o ETA vem null e nada é enviado
// (o botão "Cheguei ao local" manual continua funcionando). Sem WhatsApp
// conectado, apenas loga e pula. NUNCA lança — best-effort como cleanStaleEndereco.
// ----------------------------------------------------------------------------
cronAdd("trackingAvisos", "* * * * *", () => {
  // Thresholds e janelas (constantes — doc 09 §3).
  const ETA_5MIN_MIN  = 5;                 // Msg2: ETA ≤ 5 min
  const ETA_1MIN_MIN  = 1;                 // Msg3: ETA ≤ 1 min
  const POS_FRESH_MS  = 3 * 60 * 1000;     // posição do prof considerada "recente" (3 min)
  const MAX_TRIP_MS   = 2 * 60 * 60 * 1000;// janela máx da viagem (2 h) após a-caminho

  try {
    const uazapi = require(`${__hooks}/uazapi.js`);
    const maps   = require(`${__hooks}/maps.js`);
    const lib    = require(`${__hooks}/os_logic.js`);
    const h      = require(`${__hooks}/whatsapp_helpers.js`);

    // OS candidatas: em_andamento.
    const records = $app.findAllRecords(
      "ordens_servico",
      $dbx.hashExp({ status: "em_andamento" })
    );
    if (!records.length) return;

    // Config WhatsApp — resolve UMA vez por rodada. Sem instância/conexão, pula tudo.
    const cfg           = h.getAppConfig($app);
    const instanceToken = cfg.getString("whatsapp_instance_token");
    if (!instanceToken) {
      // Sem instância configurada — nada a fazer (silencioso: é estado normal em dev).
      return;
    }
    const msg5Template      = cfg.getString("aviso_5min_texto")    || "+5 minutos para o profissional chegar.";
    const msg1Template      = cfg.getString("aviso_1min_texto")    || "Está quase chegando, falta menos de 1 min. Por favor fique atento.";

    // QUOTA GUARD (Google Maps): resolve o status da instância UMA vez por rodada.
    // Se o WhatsApp não estiver `connected`, os avisos jamais seriam enviados —
    // então PULA o loop inteiro ANTES de chamar maps.etaMinutes por OS (cada
    // etaMinutes é uma chamada HTTP paga ao Google). Sem esta trava, o cron
    // queimaria quota do Maps a cada minuto com o WhatsApp fora. Degradação
    // graciosa: se a checagem de status falhar, cai no whatsapp_status salvo.
    let wStatus = "disconnected";
    try {
      const inst = h.extractInstance(uazapi.instanceStatus(instanceToken));
      wStatus = inst.status || "disconnected";
      cfg.set("whatsapp_status", wStatus);
      $app.save(cfg);
    } catch (errSt) {
      wStatus = cfg.getString("whatsapp_status") || "disconnected";
      console.error(`[trackingAvisos] Erro ao verificar status UAZAPI (ignorado): ${errSt}`);
    }
    if (wStatus !== "connected") return; // WhatsApp fora → não queima quota do Maps

    const now = Date.now();

    for (const os of records) {
      try {
        // Gates de elegibilidade (baratos primeiro).
        if (!os.getString("aviso_a_caminho_em")) continue; // viagem não começou
        if (os.getString("cheguei_em")) continue;          // já chegou

        // Janela máx: a-caminho recente o suficiente.
        const aCaminho = new Date(os.getString("aviso_a_caminho_em")).getTime();
        if (isNaN(aCaminho) || (now - aCaminho) > MAX_TRIP_MS) continue;

        // Posição do profissional recente.
        const posEmStr = os.getString("prof_pos_em");
        if (!posEmStr) continue;
        const posEm = new Date(posEmStr).getTime();
        if (isNaN(posEm) || (now - posEm) > POS_FRESH_MS) continue;

        // Coordenadas presentes.
        const oLat = Number(os.get("prof_lat"));
        const oLng = Number(os.get("prof_lng"));
        const dLat = Number(os.get("dest_lat"));
        const dLng = Number(os.get("dest_lng"));
        if ([oLat, oLng, dLat, dLng].some((n) => isNaN(n) || n === 0)) continue;

        // Se ambos os avisos já foram enviados, nada a fazer (evita chamar a API à toa).
        const has5 = !!os.getString("aviso_5min_em");
        const has1 = !!os.getString("aviso_1min_em");
        if (has5 && has1) continue;

        // ETA com trânsito (degrada p/ null se a chave faltar ou a API falhar).
        const eta = maps.etaMinutes(oLat, oLng, dLat, dLng);
        if (eta === null) continue;

        // Decide qual mensagem enviar. Idempotente por carimbo. Se o ETA já caiu
        // direto para ≤1 sem termos mandado a de 5, mandamos só a de 1 (a mais
        // relevante) e marcamos ambas para não reenviar depois.
        let sentAny = false;

        if (eta <= ETA_1MIN_MIN && !has1) {
          if (sendAviso(os, uazapi, lib, instanceToken, msg1Template)) {
            const stamp = nowStamp();
            os.set("aviso_1min_em", stamp);
            if (!has5) os.set("aviso_5min_em", stamp); // pulou a de 5 → marca p/ não reenviar
            sentAny = true;
          }
        } else if (eta <= ETA_5MIN_MIN && !has5) {
          if (sendAviso(os, uazapi, lib, instanceToken, msg5Template)) {
            os.set("aviso_5min_em", nowStamp());
            sentAny = true;
          }
        }

        if (sentAny) $app.save(os);
      } catch (errOne) {
        console.error(`[trackingAvisos] Erro na OS ${os.id} (ignorado): ${errOne}`);
      }
    }
  } catch (err) {
    console.error(`[trackingAvisos] Erro geral (ignorado): ${err}`);
  }

  // ── helpers locais do cron ──
  function nowStamp() {
    return new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
  }

  // Envia um aviso ao cliente da OS (telefone lido do cofre server-side, NUNCA
  // exposto). Substitui {nome}/{servico}. Retorna true se enviou, false se pulou.
  function sendAviso(os, uazapi, lib, instanceToken, template) {
    const cid = lib.relId(os.get("cliente"));
    if (!cid) return false;
    let numero = "";
    try {
      const cliente = $app.findRecordById("clientes", cid);
      numero = uazapi.normalizePhone(cliente.getString("telefone"));
    } catch (_) {
      return false;
    }
    if (!numero) return false;

    const texto = String(template || "")
      .replace(/{nome}/g, os.getString("nome_curto") || "Cliente")
      .replace(/{servico}/g, os.getString("tipo_servico_nome") || "serviço");

    try {
      uazapi.sendText(instanceToken, numero, texto);
      return true;
    } catch (errSend) {
      // WhatsApp desconectado / erro de envio — loga e não marca o carimbo
      // (tentará de novo na próxima rodada). NUNCA vaza o número.
      console.error(`[trackingAvisos] Falha ao enviar aviso da OS ${os.id} (ignorado): ${errSend}`);
      return false;
    }
  }
});
