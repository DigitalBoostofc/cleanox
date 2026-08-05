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

    try {
      app
        .db()
        .newQuery("DROP INDEX IF EXISTS idx_prof_comissoes_os_prof")
        .execute();
    } catch (err) {
      console.log("[mig 56] drop idx_prof_comissoes_os_prof: " + err);
    }
    try {
      app
        .db()
        .newQuery(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_prof_comissoes_os_prof " +
            "ON prof_comissoes (os, profissional) " +
            "WHERE os != '' AND profissional != '' " +
            "AND tipo_aplicado != 'bonificacao'",
        )
        .execute();
    } catch (err) {
      console.log("[mig 56] idx_prof_comissoes_os_prof: " + err);
    }
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

    try {
      app
        .db()
        .newQuery("DROP INDEX IF EXISTS idx_prof_comissoes_os_prof")
        .execute();
    } catch (err) {
      console.log("[mig 56 down] drop idx_prof_comissoes_os_prof: " + err);
    }
    try {
      app
        .db()
        .newQuery(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_prof_comissoes_os_prof " +
            "ON prof_comissoes (os, profissional) " +
            "WHERE os != '' AND profissional != ''",
        )
        .execute();
    } catch (err) {
      console.log("[mig 56 down] restore idx_prof_comissoes_os_prof: " + err);
    }
  },
);
