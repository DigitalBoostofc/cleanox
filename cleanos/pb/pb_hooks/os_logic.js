/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — lógica de negócio das Ordens de Serviço (módulo CommonJS).
 *
 * É carregado via require() de dentro dos handlers em main.pb.js. Cada handler
 * do PocketBase roda numa VM isolada e NÃO enxerga o escopo do arquivo, por isso
 * a lógica compartilhada precisa morar aqui e ser importada dentro de cada hook.
 *
 * REGRA INEGOCIÁVEL (anti-desvio):
 *   - telefone/e-mail do cliente NUNCA são copiados para a OS (em nenhum estado);
 *   - endereço só é escrito em `endereco_liberado` durante `em_andamento`;
 *   - é limpo em `concluida`/`cancelada`/`agendada`/`atribuida`.
 */

// "Carlos", "Silva" -> "Carlos S."  (nunca expõe o sobrenome inteiro)
function shortName(nome, sobrenome) {
  const n = String(nome || "").trim();
  const s = String(sobrenome || "").trim();
  return s ? `${n} ${s.charAt(0).toUpperCase()}.` : n;
}

// normaliza um valor de campo relation (single) para o id string
function relId(v) {
  if (Array.isArray(v)) return v.length ? String(v[0]) : "";
  return v ? String(v) : "";
}

// Lê um JSONField de um record como valor JS JÁ PARSEADO.
//
// IMPORTANTE (goja/PocketBase): record.get() num campo JSON devolve um
// types.JSONRaw exposto pelo JSVM como ARRAY DE BYTES — iterá-lo dá lixo.
// getString() faz o cast []byte→string (o TEXTO JSON, preservando UTF-8);
// então é seguro JSON.parse(). Defensivo: devolve null se vazio/ilegível.
function readJsonField(rec, key) {
  let raw = "";
  try { raw = rec.getString(key); } catch (_) { raw = ""; }
  raw = String(raw == null ? "" : raw).trim();
  if (!raw || raw === "null") return null;
  try { return JSON.parse(raw); } catch (_) { return null; }
}

// normaliza telefone para só dígitos, prefixando '55' (DDI BR) se necessário.
// "11 99999-0001" → "5511999990001"   "5511999990001" → "5511999990001"
function normalizePhone(raw) {
  const digits = String(raw || "").replace(/\D/g, "");
  if (digits.length >= 12) return digits; // já tem DDI
  if (digits.length >= 10) return "55" + digits; // 10-11 dígitos sem DDI
  return digits; // tamanho inesperado — devolve como está
}

// Compara dois telefones de forma tolerante a:
//   - prefixo DDI 55 presente ou ausente
//   - 9º dígito do celular presente ou ausente
// Reduz ambos ao canônico (só dígitos, sem DDI 55) e compara:
//   1. Formas canônicas iguais → true
//   2. Um tem 11 dígitos (com 9º) e outro 10 (sem 9º): mesmo DDD e mesmos 8 dígitos finais → true
function phonesMatch(a, b) {
  const canon = function(s) {
    var d = String(s || "").replace(/\D/g, "");
    if (d.startsWith("55") && d.length >= 12) d = d.slice(2);
    return d;
  };
  var ca = canon(a);
  var cb = canon(b);
  if (ca === cb) return true;
  var longer  = ca.length >= cb.length ? ca : cb;
  var shorter = ca.length <  cb.length ? ca : cb;
  if (longer.length === 11 && shorter.length === 10) {
    return longer.slice(0, 2) === shorter.slice(0, 2) &&
           longer.slice(-8) === shorter.slice(-8);
  }
  return false;
}

// monta o endereço completo a partir do cliente — SEM telefone/e-mail.
function buildEndereco(cliente) {
  const parts = [];
  const rua = cliente.get("endereco_rua");
  const num = cliente.get("endereco_numero");
  if (rua) parts.push(num ? `${rua}, ${num}` : rua);
  const comp = cliente.get("endereco_complemento");
  if (comp) parts.push(comp);
  const bairro = cliente.get("endereco_bairro");
  if (bairro) parts.push(bairro);
  const cidade = cliente.get("endereco_cidade");
  if (cidade) parts.push(cidade);
  const cep = cliente.get("endereco_cep");
  if (cep) parts.push("CEP " + cep);
  return parts.join(" - ");
}

// denormaliza os campos SEGUROS na OS (nome curto, bairro, nome do serviço).
// Lê do cofre `clientes` mas só escreve dados não-sensíveis na OS.
// F-402: cliente órfão não trava o save — degrada silenciosamente como já faz para servico.
function syncDenormalized(app, record) {
  const cid = relId(record.get("cliente"));
  if (cid) {
    try {
      const c = app.findRecordById("clientes", cid);
      record.set("nome_curto", shortName(c.get("nome"), c.get("sobrenome")));
      record.set("bairro", c.get("endereco_bairro"));
    } catch (_) {
      /* cliente pode ter sido removido — mantém campos denormalizados como estão */
    }
  }
  const sid = relId(record.get("servico"));
  if (sid) {
    try {
      const s = app.findRecordById("servicos", sid);
      record.set("tipo_servico_nome", s.get("nome"));
    } catch (_) {
      /* serviço pode ter sido removido — ignora snapshot */
    }
  }
}

// RISCO #2 (defesa em profundidade): preenche, no SERVIDOR, o snapshot imutável
// do serviço dentro da OS — espelha buildSnapshot() do frontend
// (web/src/lib/servicos/store.ts). Garante que, mesmo que a UI não envie o
// snapshot (ou que um cliente malicioso o omita), a OS congele os dados do
// serviço a partir do registro `servicos` correspondente.
//
// Invariantes:
//   - só age quando `servico` (relation) está setado;
//   - NUNCA sobrescreve um snapshot já existente (imutabilidade) — detecta via
//     presença de `serviceId`;
//   - serviço removido/órfão NÃO trava o save (degrada como syncDenormalized);
//   - as CHAVES do JSON são camelCase, idênticas ao ServiceSnapshot do frontend,
//     pois é a UI/relatório que consome este objeto.
function fillServiceSnapshot(app, record) {
  try {
    const sid = relId(record.get("servico"));
    if (!sid) return; // sem serviço de origem — nada a congelar

    // imutabilidade: se já há snapshot real, não toca.
    const existing = readJsonField(record, "service_snapshot");
    if (existing && existing.serviceId) return;

    let s;
    try {
      s = app.findRecordById("servicos", sid);
    } catch (_) {
      return; // serviço removido — ignora (igual ao snapshot de nome em syncDenormalized)
    }

    const rawChecklist = readJsonField(s, "checklist_padrao");
    const checklistPadrao = Array.isArray(rawChecklist)
      ? rawChecklist.map(function (it) {
          it = it || {};
          return {
            id: String(it.id || ""),
            titulo: String(it.titulo || ""),
            ordem: Number(it.ordem || 0),
            obrigatorio: Boolean(it.obrigatorio || false),
          };
        })
      : [];

    const snapshot = {
      serviceId: s.id,
      nome: s.getString("nome"),
      categoria: s.getString("categoria"),
      grupo: s.getString("grupo"),
      valorBase: s.getFloat("valor_base"),
      valorBaseMax: s.getFloat("valor_base_max"),
      tipoValor: s.getString("tipo_valor"),
      tempoMedioMin: s.getFloat("tempo_medio_min"),
      tempoMedioLabel: s.getString("tempo_medio_label"),
      observacaoTecnica: s.getString("observacao"),
      checklistPadrao: checklistPadrao,
      orientacoesPreServico: s.getString("orientacoes_pre"),
      orientacoesPosServico: s.getString("orientacoes_pos"),
      capturedAt: new Date().toISOString(),
    };

    record.set("service_snapshot", snapshot);

    // F-010: materializa o checklist de EXECUÇÃO já na criação da OS, espelhando
    // snapshotToChecklistExec() do frontend (web/src/lib/servicos/store.ts).
    // Antes, uma OS criada pelo modal "Nova OS" (que só envia o relation `servico`,
    // sem snapshot/checklist) chegava na tela de Execução com checklist VAZIO — os
    // itens só apareciam ao RE-selecionar o serviço no dropdown. Como este bloco só
    // roda quando ACABAMOS de congelar o snapshot (snapshot vazio antes), e ainda
    // assim só preenche se checklist_exec estiver vazio, nunca clobbera um checklist
    // em progresso nem o checklist já derivado pela UI (que envia snapshot+checklist
    // juntos, caso em que retornamos antes na guarda de imutabilidade).
    const existingExec = readJsonField(record, "checklist_exec");
    if (!Array.isArray(existingExec) || existingExec.length === 0) {
      const ordered = checklistPadrao.slice().sort(function (a, b) {
        return a.ordem - b.ordem;
      });
      if (ordered.length > 0) {
        const exec = ordered.map(function (it, i) {
          return {
            id: "cke_" + Date.now().toString(36) + i.toString(36) +
                Math.floor(Math.random() * 1e9).toString(36),
            titulo: it.titulo,
            status: "pendente",
            obrigatorio: Boolean(it.obrigatorio || false),
          };
        });
        record.set("checklist_exec", exec);
      }
    }
  } catch (err) {
    // best-effort: loga mas nunca bloqueia a gravação da OS.
    console.error("[snapshot] Falha ao preencher service_snapshot (ignorado): " + err);
  }
}

// libera/limpa o endereço efêmero conforme o status.
// SOMENTE `em_andamento` tem endereço. Telefone NUNCA é tocado aqui.
//
// F-401: só PREENCHE na TRANSIÇÃO para em_andamento (status anterior !== 'em_andamento').
// Se a OS já estava em_andamento e continua (ex.: save do cron, update de pagamento),
// não mexe — a limpeza do cron passa a "colar".
// F-402: cliente órfão não trava o save.
function manageEndereco(app, record) {
  const newStatus = String(record.get("status") || "");
  const orig      = record.original ? record.original() : null;
  const oldStatus = orig ? String(orig.get("status") || "") : null;

  if (newStatus === "em_andamento") {
    // Se já estava em_andamento e permanece (sem transição) → não mexe no campo
    if (oldStatus === "em_andamento") return;

    // Transição para em_andamento (ou CREATE direto com em_andamento) → preenche
    const cid = relId(record.get("cliente"));
    if (!cid) {
      record.set("endereco_liberado", "");
      return;
    }
    try {
      const c = app.findRecordById("clientes", cid);
      record.set("endereco_liberado", buildEndereco(c));
    } catch (_) {
      /* cliente não encontrado — mantém endereco_liberado como está */
    }
  } else {
    record.set("endereco_liberado", "");
  }
}

// invariante: não conclui sem pagamento registrado.
function assertPaymentIfConcluida(record) {
  if (record.get("status") === "concluida") {
    const valor = Number(record.get("valor_pago") || 0);
    const forma = String(record.get("forma_pagamento") || "");
    if (valor <= 0 || !forma) {
      throw new BadRequestError(
        "Não é possível concluir a OS sem registrar o pagamento (valor_pago > 0 e forma_pagamento)."
      );
    }
  }
}

// F-02: compara via getString() em vez de String(get()). Para JSONField, get()
// devolve um JSONRaw (array de bytes em goja) e String(...) produz lixo instável,
// fazendo a trava de campo passar batido. getString() devolve o TEXTO JSON
// (cast []byte→string), comparável de forma estável. Para Text/Number/Select/Date
// o getString() é equivalente — drop-in seguro.
function changed(orig, rec, field) {
  return orig.getString(field) !== rec.getString(field);
}

// data_hora precisa ser HOJE (dia do serviço, em BRT = UTC-3) para iniciar.
// F-04: compara em BRT para não bloquear serviços noturnos (ex.: 23h BRT = 02h UTC+1d).
function assertServiceIsToday(record) {
  const raw = record.getString("data_hora"); // "2026-06-25 14:00:00.000Z" (UTC)
  const nowBRT  = new Date(Date.now() - 3 * 3600 * 1000);
  const hoje    = nowBRT.toISOString().slice(0, 10);              // dia atual em BRT
  const dataBRT = new Date(new Date(raw).getTime() - 3 * 3600 * 1000);
  const dia     = dataBRT.toISOString().slice(0, 10);             // dia do serviço em BRT
  if (dia !== hoje) {
    throw new BadRequestError(
      `Só é possível Iniciar a OS no dia do serviço (data BRT: ${dia}, hoje BRT: ${hoje}).`
    );
  }
}

/**
 * Trava de autorização a NÍVEL DE CAMPO no update via API.
 * As regras de coleção do PocketBase são por registro; esta função impõe o
 * controle fino que falta:
 *   - profissional: só avança status em transições válidas e grava pagamento;
 *   - gerente/admin: só admin mexe em repasse.
 */
function guardOrdemUpdateRequest(e) {
  const auth = e.auth;
  const role = auth ? String(auth.get("role")) : "";

  // admin/gerente: única restrição extra é repasse ser exclusivo de admin.
  if (role === "admin" || role === "gerente") {
    if (role !== "admin") {
      const orig = e.record.original();
      if (
        changed(orig, e.record, "repasse_status") ||
        changed(orig, e.record, "repasse_valor")
      ) {
        throw new ForbiddenError("Apenas o admin pode marcar/alterar o repasse.");
      }
    }
    return;
  }

  // qualquer outro papel sem ser profissional não tem update aqui.
  if (role !== "profissional") {
    throw new ForbiddenError("Sem permissão para alterar ordens de serviço.");
  }

  // ---------------- PROFISSIONAL ----------------
  const orig = e.record.original();

  // 1) precisa ser o profissional atribuído (no estado ORIGINAL).
  if (relId(orig.get("profissional")) !== String(auth.id)) {
    throw new ForbiddenError("Você não está atribuído a esta OS.");
  }

  // 2) só pode agir enquanto atribuida ou em_andamento.
  const from = String(orig.get("status"));
  if (from !== "atribuida" && from !== "em_andamento") {
    throw new ForbiddenError(
      "Esta OS não está num estado editável pelo profissional."
    );
  }

  // 3) trava de campos: profissional só toca status, valor_pago, forma_pagamento.
  // F-08: campos relation (cliente, servico, profissional) comparados via relId()
  //       para evitar falsos positivos com String() em valores null/undefined.
  const relLocked = ["cliente", "servico", "profissional"];
  for (let i = 0; i < relLocked.length; i++) {
    const f = relLocked[i];
    if (relId(orig.get(f)) !== relId(e.record.get(f))) {
      throw new ForbiddenError("Profissional não pode alterar o campo: " + f);
    }
  }
  const locked = [
    "nome_curto",
    "bairro",
    "tipo_servico_nome",
    "data_hora",
    "valor_servico",
    "endereco_liberado",        // só o hook de modelo escreve
    "aviso_a_caminho_em",       // só a rota /a-caminho escreve (server-side)
    "avaliacao_nota",           // só o n8n via endpoint de serviço
    "avaliacao_motivo",         // só o n8n via endpoint de serviço
    "avaliacao_em",             // só o n8n via endpoint de serviço
    "avaliacao_solicitada_em",  // só o trigger de conclusão (server-side)
    "repasse_status",
    "repasse_valor",
    "observacoes",
    // RISCO #2: snapshot imutável do serviço — só o servidor escreve (hook
    // fillServiceSnapshot). O profissional NUNCA pode forjar/alterar valores
    // congelados (valorBase, checklist padrão, etc.).
    "service_snapshot",
    // marcado pelo fluxo server-side de envio do relatório ao cliente.
    "relatorio_enviado_em",
    // NB: checklist_exec, adicionais e observacoes_prof ficam de FORA da denylist
    //     de propósito — são o TRABALHO do profissional na OS (campos editáveis).
  ];
  for (let i = 0; i < locked.length; i++) {
    if (changed(orig, e.record, locked[i])) {
      throw new ForbiddenError(
        "Profissional não pode alterar o campo: " + locked[i]
      );
    }
  }

  // 4) transição de status válida.
  const to = String(e.record.get("status"));
  if (from !== to) {
    const ok =
      (from === "atribuida" && to === "em_andamento") ||
      (from === "em_andamento" && to === "concluida");
    if (!ok) {
      throw new ForbiddenError(`Transição de status inválida: ${from} -> ${to}`);
    }
    // ao Iniciar: precisa ser o dia do serviço.
    if (to === "em_andamento") {
      assertServiceIsToday(e.record);
    }
    // ao Concluir: o pagamento já tem que estar gravado.
    if (to === "concluida") {
      assertPaymentIfConcluida(e.record);
      // itens obrigatórios pendentes bloqueiam a conclusão (server-side mirror do frontend).
      const checklistExec = readJsonField(e.record, "checklist_exec");
      if (Array.isArray(checklistExec)) {
        for (let i = 0; i < checklistExec.length; i++) {
          const it = checklistExec[i];
          if (Boolean(it.obrigatorio) && String(it.status) !== "concluido") {
            throw new BadRequestError(
              "Conclua os itens obrigatórios do checklist antes de finalizar a OS."
            );
          }
        }
      }
    }
  }
}

/**
 * F-002: inicializa o repasse quando a OS passa a `concluida` COM pagamento.
 * Vale para os DOIS caminhos (chamado tanto em onRecordCreate quanto onRecordUpdate):
 *   - update-to-concluida: detecta a TRANSIÇÃO x → concluida (orig.status !== concluida);
 *   - create-as-concluida: OS nascendo já concluida (sem original()) — ex.: admin/gerente
 *     lançando uma OS já finalizada, ou import. Sem este ramo a OS jamais entraria na
 *     fila "A repassar" do Financeiro (que filtra repasse_status === 'pendente').
 * Só preenche se `repasse_status` estiver VAZIO — NUNCA sobrescreve 'pago' (admin já
 * repassou) nem 'pendente' já definido manualmente.
 */
function setRepasseIfConcluida(record) {
  if (String(record.get("status")) !== "concluida") return; // não está concluida

  const orig = record.original ? record.original() : null;
  // update: só age na TRANSIÇÃO; se já estava concluida, não reage a saves seguintes.
  // create: orig === null → segue (OS nascendo concluida).
  if (orig && String(orig.get("status")) === "concluida") return;

  // só com pagamento registrado (espelha assertPaymentIfConcluida, que roda antes).
  const valorPago = Number(record.get("valor_pago") || 0);
  if (!(valorPago > 0)) return;

  if (!record.get("repasse_status")) {
    record.set("repasse_status", "pendente");
  }
  const rv = Number(record.get("repasse_valor") || 0);
  if (!(rv > 0)) {
    record.set("repasse_valor", valorPago);
  }
}

/**
 * Dispara, de forma best-effort (try/catch), o webhook do n8n quando uma OS
 * transiciona para `concluida`. Também seta `avaliacao_solicitada_em = now`.
 *
 * Deve ser chamado APENAS em onRecordUpdate (não no create):
 *   - detecta a transição comparando original().status vs status atual
 *   - se N8N_RATING_WEBHOOK_URL não estiver configurada, apenas loga e pula
 *   - nunca bloqueia a conclusão em caso de falha de rede
 */
function triggerRatingWebhookIfConcluida(app, record) {
  // Só roda em update (onRecordCreate não tem original())
  const orig = record.original ? record.original() : null;
  if (!orig) return;

  // Só dispara na transição x → concluida (não em saves subsequentes)
  if (String(orig.get("status")) === "concluida") return;
  if (String(record.get("status")) !== "concluida") return;

  // Marca quando a avaliação foi solicitada (server-side, não editável pelo profissional)
  const nowStr = new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";
  record.set("avaliacao_solicitada_em", nowStr);

  try {
    const url = $os.getenv("N8N_RATING_WEBHOOK_URL") || "";
    if (!url) {
      console.log("[ratings] N8N_RATING_WEBHOOK_URL não configurada; gatilho de avaliação pulado.");
      return;
    }
    const secret = $os.getenv("CLEANOS_SERVICE_SECRET") || "";
    const cid = relId(record.get("cliente"));
    if (!cid) {
      console.log("[ratings] OS sem cliente; gatilho de avaliação pulado.");
      return;
    }
    const cliente = app.findRecordById("clientes", cid);
    const phone   = normalizePhone(cliente.getString("telefone"));
    const servico = record.getString("tipo_servico_nome") || "";
    const nome    = record.getString("nome_curto") || "";

    $http.send({
      method:  "POST",
      url:     url,
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ os_id: record.id, phone, servico, nome, secret }),
      timeout: 5,
    });
  } catch (err) {
    // Best-effort: loga mas nunca bloqueia a conclusão da OS
    console.error("[ratings] Erro ao notificar n8n (ignorado): " + err);
  }
}

module.exports = {
  shortName,
  relId,
  readJsonField,
  normalizePhone,
  phonesMatch,
  buildEndereco,
  syncDenormalized,
  fillServiceSnapshot,
  manageEndereco,
  assertPaymentIfConcluida,
  setRepasseIfConcluida,
  assertServiceIsToday,
  guardOrdemUpdateRequest,
  triggerRatingWebhookIfConcluida,
};
