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
function syncDenormalized(app, record) {
  const cid = relId(record.get("cliente"));
  if (cid) {
    const c = app.findRecordById("clientes", cid);
    record.set("nome_curto", shortName(c.get("nome"), c.get("sobrenome")));
    record.set("bairro", c.get("endereco_bairro"));
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

// libera/limpa o endereço efêmero conforme o status.
// SOMENTE `em_andamento` tem endereço. Telefone NUNCA é tocado aqui.
function manageEndereco(app, record) {
  if (record.get("status") === "em_andamento") {
    const cid = relId(record.get("cliente"));
    // F-01: guard — cid vazio não deve crashar (espelha o if(cid) em syncDenormalized)
    if (!cid) {
      record.set("endereco_liberado", "");
      return;
    }
    const c = app.findRecordById("clientes", cid);
    record.set("endereco_liberado", buildEndereco(c));
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

function changed(orig, rec, field) {
  return String(orig.get(field)) !== String(rec.get(field));
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
    "endereco_liberado",     // só o hook de modelo escreve
    "aviso_a_caminho_em",    // só a rota /a-caminho escreve (server-side)
    "repasse_status",
    "repasse_valor",
    "observacoes",
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
    }
  }
}

module.exports = {
  shortName,
  relId,
  buildEndereco,
  syncDenormalized,
  manageEndereco,
  assertPaymentIfConcluida,
  assertServiceIsToday,
  guardOrdemUpdateRequest,
};
