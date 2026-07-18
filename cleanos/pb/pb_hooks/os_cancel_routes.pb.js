/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — cancelamento de OS com motivo e auditoria.
 *
 *   POST /api/cleanos/os/{id}/cancelar
 *   Body: { motivo: string }
 *
 * Quem pode: admin, gerente, ou profissional dono da OS (atribuida|em_andamento).
 * Grava server-side: status=cancelada, motivo, cancelado_por, cancelado_por_nome,
 * cancelado_em. Não devolve PII de cliente.
 */
routerAdd(
  "POST",
  "/api/cleanos/os/{id}/cancelar",
  (e) => {
    const lib = require(`${__hooks}/os_logic.js`);

    if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
    const role = String(e.auth.get("role") || "");
    const authId = String(e.auth.id);

    const osId = String(e.request.pathValue("id") || "");
    if (!osId) throw new BadRequestError("OS inválida.");

    let os;
    try {
      os = $app.findRecordById("ordens_servico", osId);
    } catch (_) {
      throw new NotFoundError("OS não encontrada.");
    }

    const status = String(os.get("status") || "");
    if (status === "cancelada") {
      throw new BadRequestError("Esta OS já está cancelada.");
    }
    if (status === "concluida") {
      throw new BadRequestError("Não é possível cancelar uma OS concluída.");
    }

    if (role === "profissional") {
      const profId = lib.relId(os.get("profissional"));
      if (profId !== authId) {
        throw new ForbiddenError("Você não está atribuído a esta OS.");
      }
      if (status !== "atribuida" && status !== "em_andamento") {
        throw new ForbiddenError(
          "Profissional só cancela OS atribuída ou em andamento."
        );
      }
    } else if (role !== "admin" && role !== "gerente") {
      throw new ForbiddenError("Sem permissão para cancelar OS.");
    }

    const body = e.requestInfo().body || {};
    const motivo = String(body.motivo || "").trim();
    if (!motivo) {
      throw new BadRequestError("Informe o motivo do cancelamento.");
    }
    if (motivo.length > 1000) {
      throw new BadRequestError("Motivo muito longo (máx. 1000 caracteres).");
    }

    let nomeCancelador = "";
    try {
      const u = $app.findRecordById("users", authId);
      nomeCancelador =
        String(u.get("nome") || "").trim() ||
        String(u.get("name") || "").trim() ||
        String(u.get("email") || "").trim() ||
        authId;
    } catch (_) {
      nomeCancelador = authId;
    }

    const now =
      new Date().toISOString().replace("T", " ").slice(0, 23) + "Z";

    os.set("status", "cancelada");
    os.set("motivo_cancelamento", motivo);
    os.set("cancelado_por", authId);
    os.set("cancelado_por_nome", nomeCancelador);
    os.set("cancelado_em", now);

    // Limpa endereço liberado (anti-desvio) — manageEndereco no hook de modelo
    // também age; reforço explícito.
    try {
      os.set("endereco_liberado", "");
    } catch (_) {}

    $app.save(os);

    return e.json(200, {
      ok: true,
      osId: String(os.id),
      canceladoEm: now,
      canceladoPorNome: nomeCancelador,
      motivo: motivo,
    });
  },
  $apis.requireAuth(),
);
