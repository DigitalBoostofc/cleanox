/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 21: garante UMA ÚNICA conta padrão (fin_contas).
 *
 * A migration 16 adicionou a flag `padrao` (BoolField) e marcou a conta que
 * recebe a receita de OS. Mas nada IMPEDIA marcar duas contas como `padrao=true`
 * — aí o hook OS→Financeiro (os_financeiro_lib.js) escolheria a "primeira" de
 * forma arbitrária, reintroduzindo exatamente a fragilidade que a flag resolveu.
 *
 * Esta migration cria um ÍNDICE ÚNICO PARCIAL que só entra nas linhas com
 * `padrao = TRUE`, tornando essa condição no máximo UMA linha a nível de banco
 * (backstop contra corrida/erro de UI, mesma técnica do idx_evid_idem, mig 18).
 *
 * SEMÂNTICA DE Bool NO SQLITE (verificada na base real): o BoolField vira a
 * coluna `padrao BOOLEAN DEFAULT FALSE NOT NULL`, armazenada como INTEIRO 0/1
 * (nunca NULL). Logo `WHERE padrao = TRUE` (TRUE⇒1 no SQLite ≥3.23) indexa só as
 * contas marcadas; as `padrao=0` ficam de FORA do índice e não colidem entre si.
 * Respeita a regra do projeto (bool nunca é null; comparo pelo valor, não == null).
 *
 * PRÉ-CONDIÇÃO: hoje existe no máximo uma conta com `padrao=true` (a mig 16 marca
 * exatamente uma e o app não expõe marcar duas). Se por acaso houvesse duas, o
 * CREATE UNIQUE INDEX falharia no `up` — o que é o comportamento correto: expõe
 * um dado inconsistente em vez de mascará-lo.
 *
 * IDEMPOTENTE (checa se o índice já existe) / REVERSÍVEL (o DOWN remove o índice;
 * o campo `padrao` continua — ele pertence à migration 16).
 */
migrate(
  (app) => {
    let contas = null;
    try { contas = app.findCollectionByNameOrId("fincontas000001"); } catch (_) { contas = null; }
    if (!contas) return; // base sem a coleção financeira — nada a fazer

    const IDX = "idx_fin_contas_padrao_unica";
    const hasIdx = (contas.indexes || []).some(function (s) {
      return String(s).indexOf(IDX) !== -1;
    });
    if (!hasIdx) {
      contas.indexes = (contas.indexes || []).concat([
        "CREATE UNIQUE INDEX `" + IDX + "` ON `fin_contas` (`padrao`) WHERE `padrao` = TRUE",
      ]);
      app.save(contas);
    }
  },

  // ── DOWN ──────────────────────────────────────────────────────────────────
  (app) => {
    let contas = null;
    try { contas = app.findCollectionByNameOrId("fincontas000001"); } catch (_) { contas = null; }
    if (!contas) return;

    contas.indexes = (contas.indexes || []).filter(function (s) {
      return String(s).indexOf("idx_fin_contas_padrao_unica") === -1;
    });
    app.save(contas);
  }
);
