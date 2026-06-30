/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 11: persiste o DESCONTO da OS (F-501).
 *
 * Antes desta migration o desconto aplicado no "Resumo financeiro" da execução
 * (OSExecucaoPage) era estado PURAMENTE LOCAL: nunca era gravado no PB e o
 * backend que monta o relatório por WhatsApp (whatsapp_routes.pb.js
 * → buildRelatorioTexto) calculava o total SEM abatê-lo. Resultado: o cliente
 * recebia o total CHEIO, divergente do preview do operador.
 *
 * Esta migration adiciona a coluna `descontos` (NumberField, >= 0) em
 * `ordens_servico`. A UI passa a persistir o valor junto com o trio de rotina e o
 * relatório do backend subtrai esse desconto, alinhando preview e mensagem real.
 *
 * IDEMPOTENTE: só adiciona o campo se ainda não existir.
 * REVERSÍVEL: o DOWN remove o campo.
 */
migrate(
  (app) => {
    const ordens = app.findCollectionByNameOrId("ordserv00000001");
    if (!ordens.fields.getByName("descontos")) {
      ordens.fields.add(new NumberField({ name: "descontos", required: false, min: 0 }));
      app.save(ordens);
    }
  },

  (app) => {
    try {
      const ordens = app.findCollectionByNameOrId("ordserv00000001");
      const f = ordens.fields.getByName("descontos");
      if (f) {
        ordens.fields.removeById(f.id);
        app.save(ordens);
      }
    } catch (_) {}
  }
);
