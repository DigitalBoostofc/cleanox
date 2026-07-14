/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Duração própria da Ordem de Serviço (agenda estilo Google).
 *
 * Adiciona `ordens_servico.duracao_min` (number, opcional, min 15): a duração do
 * atendimento em minutos. Fim do evento = `data_hora` + `duracao_min`.
 *
 * Antes disso a duração era GLOBAL por profissional (`disponibilidade.duracao_min`);
 * agora cada OS pode ter a sua. Sem migração de dados: OS antiga fica sem valor e o
 * render cai no fallback `duracaoEfetivaMin` (OS > profissional > 60).
 *
 * ⚠️ NumberField opcional volta como **0** quando vazio (nunca null) — variante
 * numérica da regra R2 do CLAUDE.md. O Flutter normaliza `<= 0 → null` no
 * `fromRecord` (ver core/models/ordem_servico.dart).
 *
 * IDEMPOTENTE (checa o campo antes de criar). DOWN remove o campo.
 */

migrate(
  (app) => {
    const ordens = app.findCollectionByNameOrId("ordserv00000001");
    if (!ordens.fields.getByName("duracao_min")) {
      ordens.fields.add(
        new NumberField({
          name: "duracao_min",
          required: false,
          onlyInt: true,
          min: 15,
        }),
      );
      app.save(ordens);
    }
  },
  (app) => {
    try {
      const ordens = app.findCollectionByNameOrId("ordserv00000001");
      const f = ordens.fields.getByName("duracao_min");
      if (f) ordens.fields.removeById(f.id);
      app.save(ordens);
    } catch (_) {}
  },
);
