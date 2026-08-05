/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — bonificação manual em Financeiro → Comissões.
 *
 * - prof_comissoes.tipo_aplicado aceita `bonificacao`;
 * - prof_comissoes.os deixa de ser obrigatório para permitir bonificação avulsa.
 *
 * A bonificação continua na mesma coleção para aproveitar status pendente/paga e
 * o hook de repasse/despesa já existente. Hooks de comissão automática ignoram
 * `bonificacao` para não recalcular/apagar decisão manual.
 */
migrate(
  (app) => {
    const col = app.findCollectionByNameOrId("prof_comissoes");

    const tipo = col.fields.getByName("tipo_aplicado");
    if (tipo && tipo.values && tipo.values.indexOf("bonificacao") === -1) {
      tipo.values = tipo.values.concat(["bonificacao"]);
    }

    const os = col.fields.getByName("os");
    if (os && os.required) {
      os.required = false;
    }

    app.save(col);
  },
  (app) => {
    const col = app.findCollectionByNameOrId("prof_comissoes");
    try {
      app.findFirstRecordByFilter(
        "prof_comissoes",
        "tipo_aplicado = 'bonificacao'",
      );
      throw new Error(
        "rollback bloqueado: existem prof_comissoes.tipo_aplicado=bonificacao",
      );
    } catch (err) {
      if (
        err &&
        String(err.message || err).indexOf("rollback bloqueado") !== -1
      ) {
        throw err;
      }
      // Sem bonificações: seguro remover o valor do enum.
    }
    const tipo = col.fields.getByName("tipo_aplicado");
    if (tipo && tipo.values) {
      tipo.values = tipo.values.filter((v) => v !== "bonificacao");
    }
    // DOWN não volta `os.required=true`: podem existir bonificações avulsas.
    app.save(col);
  },
);
