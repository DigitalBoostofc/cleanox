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
 * FIX D2-002: antes de criar o índice, o UP deduplica quaisquer linhas com
 * padrao=true existentes — mantém a mais recente (por `updated`) e zera as
 * demais — para que a criação do índice nunca falhe por dados inconsistentes.
 * Safe quando há 0 ou 1 linha padrão (o loop não executa).
 *
 * IDEMPOTENTE (checa se o índice já existe) / REVERSÍVEL (o DOWN remove o índice;
 * o campo `padrao` continua — ele pertence à migration 16).
 */
migrate(
  (app) => {
    let contas = null;
    try { contas = app.findCollectionByNameOrId("fincontas000001"); } catch (_) { contas = null; }
    if (!contas) return; // base sem a coleção financeira — nada a fazer

    // ── DEDUPE (D2-002): ≤1 padrao=true antes de criar o índice ─────────────
    // Ordena pela mais recente; mantém a [0] e zera as demais.
    // Não executa quando há 0 ou 1 linha (idempotente).
    const padraoRows = app.findRecordsByFilter(
      "fin_contas", "padrao = true", "-updated", 0, 0, {}
    );
    for (let i = 1; i < padraoRows.length; i++) {
      padraoRows[i].set("padrao", false);
      app.save(padraoRows[i]);
    }

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
