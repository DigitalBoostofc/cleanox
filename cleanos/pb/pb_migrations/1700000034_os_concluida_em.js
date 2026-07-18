/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — carimbo server-side de CONCLUSÃO da OS.
 *
 * Adiciona `ordens_servico.concluida_em` (date, opcional): quando o profissional
 * (ou o painel) FINALIZOU o serviço (transição para `concluida`). Escrito só
 * pelo hook `stampConcluidaEm` — denylist no profissional.
 *
 * Motivação: a aba Concluída da lista precisa ordenar por "quem concluiu
 * primeiro / mais recente", não por `data_hora` (agenda do serviço).
 *
 * Backfill: OS já `concluida` sem carimbo recebem `updated` como aproximação
 * (melhor que vazio para o sort `-concluida_em`).
 *
 * ⚠️ DateField opcional → "" quando vazio (R2). IDEMPOTENTE.
 */
migrate(
  (app) => {
    const ordens = app.findCollectionByNameOrId("ordserv00000001");
    if (!ordens.fields.getByName("concluida_em")) {
      ordens.fields.add(
        new DateField({
          name: "concluida_em",
          required: false,
        }),
      );
      app.save(ordens);
    }

    // Backfill best-effort das já concluídas.
    try {
      const rows = app.findRecordsByFilter(
        "ordens_servico",
        'status = "concluida"',
        "-updated",
        500,
        0,
      );
      for (const r of rows) {
        const atual = String(r.get("concluida_em") || "").trim();
        if (atual) continue;
        const upd = String(r.get("updated") || "").trim();
        if (!upd) continue;
        r.set("concluida_em", upd);
        app.save(r);
      }
    } catch (_) {
      /* seed / vazio */
    }
  },
  (app) => {
    try {
      const ordens = app.findCollectionByNameOrId("ordserv00000001");
      const f = ordens.fields.getByName("concluida_em");
      if (f) {
        ordens.fields.removeById(f.id);
        app.save(ordens);
      }
    } catch (_) {}
  },
);
