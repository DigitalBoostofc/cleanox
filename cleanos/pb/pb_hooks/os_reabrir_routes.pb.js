/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — reabrir OS concluída = DUPLICAR para novo ciclo "Refazer".
 *
 *   POST /api/cleanos/os/{id}/reabrir
 *
 * Admin/gerente. A OS original (concluída) permanece intacta — histórico,
 * pagamento, receita e comissão não são tocados.
 *
 * Cria uma NOVA OS em status `agendada` (rótulo Em agendamento) com
 * `refazer=true`, mesmos cliente/serviço/agenda/obs, valor e pagamento zerados,
 * sem profissional. O hook de create preenche snapshot + checklist padrão.
 */
routerAdd(
  "POST",
  "/api/cleanos/os/{id}/reabrir",
  (e) => {
    const lib = require(`${__hooks}/os_logic.js`);

    if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
    const role = String(e.auth.get("role") || "");
    if (role !== "admin" && role !== "gerente") {
      throw new ForbiddenError("Só admin ou gerente podem reabrir OS.");
    }

    const osId = String(e.request.pathValue("id") || "");
    if (!osId) throw new BadRequestError("OS inválida.");

    let orig;
    try {
      orig = $app.findRecordById("ordens_servico", osId);
    } catch (_) {
      throw new NotFoundError("OS não encontrada.");
    }

    if (String(orig.get("status") || "") !== "concluida") {
      throw new BadRequestError("Só é possível reabrir OS concluída.");
    }

    const col = $app.findCollectionByNameOrId("ordens_servico");
    const nova = new Record(col);

    // Copia dados de negócio (não financeiros / não de execução).
    const cliente = lib.relId(orig.get("cliente"));
    const servico = lib.relId(orig.get("servico"));
    if (cliente) nova.set("cliente", cliente);
    if (servico) nova.set("servico", servico);

    nova.set("nome_curto", String(orig.get("nome_curto") || ""));
    nova.set("bairro", String(orig.get("bairro") || ""));
    nova.set("tipo_servico_nome", String(orig.get("tipo_servico_nome") || ""));
    nova.set("data_hora", orig.get("data_hora"));
    try {
      const dur = Number(orig.get("duracao_min") || 0);
      if (dur > 0) nova.set("duracao_min", dur);
    } catch (_) {}
    nova.set("observacoes", String(orig.get("observacoes") || ""));

    // Novo ciclo operacional.
    nova.set("status", "agendada");
    nova.set("profissional", "");
    nova.set("refazer", true);
    nova.set("valor_servico", 0);
    nova.set("valor_pago", 0);
    nova.set("forma_pagamento", "");
    nova.set("forma_pagamento_outro", "");
    nova.set("descontos", 0);
    nova.set("endereco_liberado", "");
    nova.set("repasse_status", "");
    nova.set("repasse_valor", 0);
    nova.set("adicionais", []);
    nova.set("observacoes_prof", []);
    // checklist_exec / service_snapshot: hook fillServiceSnapshot no create
    // preenche a partir do catálogo (checklist limpo, pendente).

    // onRecordCreate: syncDenormalized, fillServiceSnapshot, manageEndereco…
    $app.save(nova);

    return e.json(200, {
      ok: true,
      osId: String(nova.id),
      origemOsId: String(orig.id),
      status: "agendada",
      refazer: true,
      duplicada: true,
    });
  },
  $apis.requireAuth(),
);
