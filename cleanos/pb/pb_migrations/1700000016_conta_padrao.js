/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 16: conta PADRÃO para receita de OS (F-223).
 *
 * Antes, o hook OS→Financeiro (os_financeiro_lib.js) creditava a receita de toda
 * OS concluída SEMPRE na "primeira conta ativa por nome asc". Criar uma 2ª conta
 * cujo nome ordene antes redirecionava TODA a receita silenciosamente, sem
 * configuração — atribuição arbitrária/frágil do destino.
 *
 * Esta migration adiciona a flag booleana `padrao` em `fin_contas` e marca a conta
 * que HOJE recebe a receita (1ª ativa por nome asc) como `padrao=true`, tornando o
 * destino EXPLÍCITO e ESTÁVEL: a partir daqui o hook prefere a conta `padrao=true`
 * (com fallback à 1ª ativa), então uma nova conta de nome anterior não sequestra
 * mais a receita. O admin pode reatribuir o padrão marcando outra conta.
 *
 * IDEMPOTENTE: só adiciona o campo se ainda não existir; só marca um padrão se
 * nenhuma conta já for `padrao=true`.
 * REVERSÍVEL: o DOWN remove o campo.
 */
migrate(
  (app) => {
    const contas = app.findCollectionByNameOrId("fincontas000001");
    if (!contas.fields.getByName("padrao")) {
      contas.fields.add(new BoolField({ name: "padrao" }));
      app.save(contas);
    }

    // Pinar o destino atual: se nenhuma conta já é padrão, marca a 1ª ativa por
    // nome asc (exatamente a que o hook escolhia antes) como padrao=true — preserva
    // o comportamento vigente de forma explícita, sem redirecionar receita existente.
    let jaTemPadrao = false;
    try {
      app.findFirstRecordByFilter("fin_contas", "padrao = true");
      jaTemPadrao = true;
    } catch (_) { /* nenhuma marcada → segue */ }

    if (!jaTemPadrao) {
      try {
        const ativas = app.findRecordsByFilter("fin_contas", "ativo = true", "nome", 1, 0, {});
        if (ativas && ativas.length > 0) {
          ativas[0].set("padrao", true);
          app.save(ativas[0]);
        }
      } catch (_) { /* sem contas ativas → nada a pinar */ }
    }
  },

  (app) => {
    try {
      const contas = app.findCollectionByNameOrId("fincontas000001");
      const f = contas.fields.getByName("padrao");
      if (f) {
        contas.fields.removeById(f.id);
        app.save(contas);
      }
    } catch (_) {}
  }
);
