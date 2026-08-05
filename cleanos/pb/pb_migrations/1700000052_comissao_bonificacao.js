/// 1700000052_comissao_bonificacao.js
///
/// Bonificação manual em prof_comissoes e categoria Equipe por profissional.
/// A configuração automática continua em users.comissao_tipo.

migrate(
  (app) => {
    const com = app.findCollectionByNameOrId("prof_comissoes");
    const tipo = com.fields.getByName("tipo_aplicado");
    if (tipo && Array.isArray(tipo.values) && tipo.values.indexOf("bonificacao") === -1) {
      tipo.values = tipo.values.concat(["bonificacao"]);
    }
    const os = com.fields.getByName("os");
    if (os) os.required = false;
    app.save(com);

    // Comissão automática continua única por OS/profissional; bonificação
    // vinculada à mesma OS não pode colidir com ela.
    try {
      app.db().newQuery("DROP INDEX IF EXISTS idx_prof_comissoes_os_prof").execute();
      app.db().newQuery(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_prof_comissoes_os_prof " +
          "ON prof_comissoes (os, profissional) " +
          "WHERE os != '' AND profissional != '' AND tipo_aplicado != 'bonificacao'",
      ).execute();
    } catch (e) {
      console.log("[mig 52] índice de comissões: " + e);
    }
  },
  (app) => {
    const com = app.findCollectionByNameOrId("prof_comissoes");
    try {
      const bonus = app.findFirstRecordByFilter(
        "prof_comissoes",
        "tipo_aplicado = 'bonificacao'",
      );
      if (bonus) throw new Error("não é possível reverter: existem bonificações gravadas");
    } catch (e) {
      if (String(e).indexOf("existem bonificações gravadas") >= 0) throw e;
    }
    const tipo = com.fields.getByName("tipo_aplicado");
    if (tipo && Array.isArray(tipo.values)) {
      tipo.values = tipo.values.filter((v) => v !== "bonificacao");
    }
    app.save(com);
    try {
      app.db().newQuery("DROP INDEX IF EXISTS idx_prof_comissoes_os_prof").execute();
      app.db().newQuery(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_prof_comissoes_os_prof " +
          "ON prof_comissoes (os, profissional) WHERE os != '' AND profissional != ''",
      ).execute();
    } catch (_) {}
  },
);
