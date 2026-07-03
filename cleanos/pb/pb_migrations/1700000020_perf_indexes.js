/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 20: índices de performance em `ordens_servico`.
 *
 * ADITIVA — só cria índices; nenhum campo, regra ou dado muda. Motivada pelo
 * diagnóstico de otimização de banco (senior-backend + pocketbase-cleanos):
 * mapeamento dos filtros reais usados pelo Flutter (`painel_filters.dart`,
 * `prof_filters.dart`, `avaliacoes_controller.dart`) cruzado com
 * `EXPLAIN QUERY PLAN` na cópia de produção (17 OS hoje — dataset pequeno,
 * mas os planos já mostram os índices atuais (`idx_os_status`,
 * `idx_os_profissional`, `idx_os_data`, todos de coluna única) não cobrindo
 * as combinações reais de filtro, forçando SCAN completo ou uso de só um dos
 * três índices com o resto filtrado linha a linha. Índices adicionados agora,
 * antes do volume crescer, evitam re-migração sob carga depois.
 *
 * 1) `idx_os_prof_data` (profissional, data_hora) — cobre o padrão mais quente
 *    do app: profissional + intervalo de data. Beneficia:
 *      - `profOrdensHojeFilter` / `profOrdensProximasFilter` /
 *        `profOrdensAtrasadasAbertasFilter` (prof_filters.dart) — carregados a
 *        cada abertura de "Meus Serviços" pelo profissional;
 *      - `ordensOcupamAgendaFilter` + `disponibilidadeDoProfissionalFilter`
 *        (painel_filters.dart) — checados a cada seleção de horário na Nova OS
 *        e a cada dia visto na Agenda;
 *      - `ordensFilter` (painel_filters.dart) quando o admin filtra OS por
 *        profissional + período.
 *    `EXPLAIN QUERY PLAN` ANTES (prod): `SEARCH ordens_servico USING INDEX
 *    idx_os_data (data_hora>? AND data_hora<?)` — o filtro `profissional=?` é
 *    aplicado depois, linha a linha, escaneando OS de TODOS os profissionais
 *    no intervalo. Com o índice composto o SEARCH passa a ser direto por
 *    profissional, sem examinar OS de outros profissionais.
 *
 * 2) `idx_os_avaliacao_em` (avaliacao_em) WHERE avaliacao_nota >= 1 — índice
 *    PARCIAL (só entra o subconjunto de OS já avaliadas). Beneficia
 *    `avaliacoesFilter()` (avaliacoes_controller.dart), a query agregada da
 *    tela admin Avaliações (`perPage: 1000`, roda a cada abertura da tela).
 *    ANTES: `SCAN ordens_servico` + `USE TEMP B-TREE FOR ORDER BY` (tabela
 *    inteira). Como o predicado do índice (`avaliacao_nota >= 1`) é IDÊNTICO
 *    ao da query, o SQLite passa a resolver filtro + ordenação num único
 *    SEARCH pelo índice, sem sort separado.
 *
 * 3) `idx_os_prof_avaliacao_em` (profissional, avaliacao_em) WHERE
 *    avaliacao_nota >= 1 — mesma ideia, mas para a busca por profissional
 *    específico: `profissional = ? && avaliacao_nota >= 1 ORDER BY
 *    avaliacao_em DESC` (accordion da tela Avaliações, `_loadReviews`) e o
 *    filtro do Perfil do profissional (`profAvaliadasFilter`, perfil_screen).
 *    ANTES: mesmo `SCAN` + sort completo da tabela.
 *
 * `fin_lancamentos` NÃO recebeu índice novo: `EXPLAIN QUERY PLAN` confirmou
 * que `idx_finlanc_data` já é usado corretamente pelo filtro de período (o
 * filtro mais comum e mais seletivo em toda tela do Financeiro); não há
 * evidência de combinação não coberta.
 *
 * IDEMPOTENTE / REVERSÍVEL: checa existência antes de criar; o DOWN remove só
 * estes três índices.
 */
migrate(
  (app) => {
    let ordens = null;
    try { ordens = app.findCollectionByNameOrId("ordserv00000001"); } catch (_) { ordens = null; }
    if (!ordens) return; // base muito antiga sem a coleção — nada a fazer

    const hasIdx = function (name) {
      return (ordens.indexes || []).some(function (s) {
        return String(s).indexOf(name) !== -1;
      });
    };

    const toAdd = [];

    if (!hasIdx("idx_os_prof_data")) {
      toAdd.push(
        "CREATE INDEX `idx_os_prof_data` ON `ordens_servico` (`profissional`, `data_hora`)"
      );
    }

    if (!hasIdx("idx_os_avaliacao_em")) {
      toAdd.push(
        "CREATE INDEX `idx_os_avaliacao_em` ON `ordens_servico` (`avaliacao_em`) WHERE `avaliacao_nota` >= 1"
      );
    }

    if (!hasIdx("idx_os_prof_avaliacao_em")) {
      toAdd.push(
        "CREATE INDEX `idx_os_prof_avaliacao_em` ON `ordens_servico` (`profissional`, `avaliacao_em`) WHERE `avaliacao_nota` >= 1"
      );
    }

    if (toAdd.length) {
      ordens.indexes = (ordens.indexes || []).concat(toAdd);
      app.save(ordens);
    }
  },

  // ── DOWN ──────────────────────────────────────────────────────────────────
  (app) => {
    let ordens = null;
    try { ordens = app.findCollectionByNameOrId("ordserv00000001"); } catch (_) { ordens = null; }
    if (!ordens) return;

    const REMOVE = ["idx_os_prof_data", "idx_os_avaliacao_em", "idx_os_prof_avaliacao_em"];
    ordens.indexes = (ordens.indexes || []).filter(function (s) {
      return !REMOVE.some(function (name) { return String(s).indexOf(name) !== -1; });
    });

    app.save(ordens);
  }
);
