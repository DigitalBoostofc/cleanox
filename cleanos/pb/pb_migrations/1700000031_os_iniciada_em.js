/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — carimbo server-side de início da OS.
 *
 * Adiciona `ordens_servico.iniciada_em` (date, opcional): quando o serviço de
 * fato COMEÇOU (transição para `em_andamento`). Escrito só pelo hook
 * `stampIniciadaEm` (os_logic.js) — o profissional é barrado pela denylist.
 *
 * Motivação: a regra de Iniciar mudou para "dia do serviço OU depois" (OS que
 * ficou de ontem sem registro no app). Com isso, `data_hora` deixou de indicar
 * quando a OS entrou em execução, e o cron `cleanStaleEndereco` passa a cortar
 * por `iniciada_em` (fallback `data_hora` para OS legadas sem o carimbo).
 *
 * ⚠️ DateField opcional volta como **""** quando vazio (nunca null) — regra R2
 * do CLAUDE.md. Comparar com `!= ""`.
 *
 * IDEMPOTENTE (checa o campo antes de criar). DOWN remove o campo.
 */

migrate(
  (app) => {
    const ordens = app.findCollectionByNameOrId("ordserv00000001");
    if (!ordens.fields.getByName("iniciada_em")) {
      ordens.fields.add(
        new DateField({
          name: "iniciada_em",
          required: false,
        }),
      );
      app.save(ordens);
    }
  },
  (app) => {
    try {
      const ordens = app.findCollectionByNameOrId("ordserv00000001");
      const f = ordens.fields.getByName("iniciada_em");
      if (f) ordens.fields.removeById(f.id);
      app.save(ordens);
    } catch (_) {}
  },
);
