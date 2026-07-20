/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — reabrir OS concluída.
 *
 *   POST /api/cleanos/os/{id}/reabrir
 *
 * Admin/gerente. Volta para status `agendada` com etiqueta `refazer=true`,
 * zera valores de pagamento/serviço, remove profissional, estorna receita
 * via_os (inclusive paga) e comissão. Mesma OS (mesmo id).
 */
routerAdd(
  "POST",
  "/api/cleanos/os/{id}/reabrir",
  (e) => {
    const delLib = require(`${__hooks}/os_delete_lib.js`);
    const comLib = require(`${__hooks}/prof_comissao_lib.js`);

    if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
    const role = String(e.auth.get("role") || "");
    if (role !== "admin" && role !== "gerente") {
      throw new ForbiddenError("Só admin ou gerente podem reabrir OS.");
    }

    const osId = String(e.request.pathValue("id") || "");
    if (!osId) throw new BadRequestError("OS inválida.");

    let os;
    try {
      os = $app.findRecordById("ordens_servico", osId);
    } catch (_) {
      throw new NotFoundError("OS não encontrada.");
    }

    if (String(os.get("status") || "") !== "concluida") {
      throw new BadRequestError(
        "Só é possível reabrir OS concluída.",
      );
    }

    // Estorna financeiro da conclusão (receita + comissão).
    delLib.apagarReceitasDaOs($app, osId);
    comLib.removerComissoesDaOs($app, osId);

    // Volta para "Em agendamento" (wire: agendada), mesma OS.
    os.set("status", "agendada");
    os.set("profissional", "");
    os.set("refazer", true);
    os.set("valor_pago", 0);
    os.set("forma_pagamento", "");
    os.set("forma_pagamento_outro", "");
    os.set("valor_servico", 0);
    os.set("descontos", 0);
    os.set("endereco_liberado", "");
    os.set("repasse_status", "");
    os.set("repasse_valor", 0);
    // Carimbos de execução — limpa para novo ciclo.
    try {
      os.set("concluida_em", "");
    } catch (_) {}
    try {
      os.set("iniciada_em", "");
    } catch (_) {}
    try {
      os.set("cheguei_em", "");
    } catch (_) {}
    try {
      os.set("aviso_a_caminho_em", "");
    } catch (_) {}
    try {
      os.set("aviso_5min_em", "");
    } catch (_) {}
    try {
      os.set("aviso_1min_em", "");
    } catch (_) {}
    // Coords de tracking.
    try {
      os.set("prof_lat", null);
      os.set("prof_lng", null);
      os.set("prof_pos_em", "");
      os.set("dest_lat", null);
      os.set("dest_lng", null);
    } catch (_) {}

    $app.save(os);

    return e.json(200, {
      ok: true,
      osId: String(os.id),
      status: "agendada",
      refazer: true,
    });
  },
  $apis.requireAuth(),
);
