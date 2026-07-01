/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 15: SEED idempotente do módulo Financeiro.
 *
 * Fonte de verdade: cleanos/web/src/lib/financeiro/seed.ts
 * Cria 5 contas, 34 categorias (mães → filhas), 20 lançamentos e 6 limites,
 * todos com IDs estáveis. Mês de referência: Junho/2026.
 *
 * Resumo de conferência (Jun/2026, status=pago):
 *   entradas = R$ 2.230,00  (lanc_seed_01+02+03+05)
 *   saídas   = R$ 7.223,74  (lanc_seed_07..17)
 *
 * APPROACH B — IDs nativos PocketBase (15 chars [a-z0-9]):
 * PocketBase 0.39.4 exige id: mínimo 15 chars, padrão [a-zA-Z0-9].
 * Nomes semânticos preservados no campo `nome` de cada registro.
 *
 * Mapa de IDs (semântico → ID PB):
 *   conta_carteira            → fincarteira0001
 *   conta_inter               → fininterbank001
 *   conta_nubank              → finnubank000001
 *   conta_cartao              → fincartao000001
 *   conta_caixa               → fincaixa0000001
 *   cat_produtos              → catdprodutos001
 *   cat_produtos_quimicos     → catdprodquim001
 *   cat_produtos_insumos      → catdprodins0001
 *   cat_equipamentos          → catdequipm00001
 *   cat_equipamentos_maquinas → catdequipmaq001
 *   cat_equipamentos_acessorios→catdequipacc001
 *   cat_equipe                → catdequipe00001
 *   cat_equipe_profissionais  → catdequipeprof1
 *   cat_equipe_comissoes      → catdequipecomi1
 *   cat_socios                → catdsocios00001
 *   cat_socios_dennis         → catdsociodenn01
 *   cat_socios_diego          → catdsociodieg01
 *   cat_impostos              → catdimpost00001
 *   cat_marketing             → catdmarket00001
 *   cat_marketing_google      → catdmarketgoog1
 *   cat_marketing_meta        → catdmarketmeta1
 *   cat_marketing_criativos   → catdmarketcria1
 *   cat_transporte            → catdtransp00001
 *   cat_transporte_combustivel→ catdtranscomb01
 *   cat_transporte_manutencao → catdtransmant01
 *   cat_transporte_uber       → catdtransuber01
 *   cat_compras               → catdcompras0001
 *   cat_assinaturas           → catdassinas0001
 *   cat_alimentacao           → catdaliment0001
 *   cat_aluguel               → catdaluguel0001
 *   cat_contabilidade         → catdcontab00001
 *   cat_taxas_bancarias       → catdtaxabanc001
 *   cat_outros                → catdoutros00001
 *   cat_servico_automotivo    → catrautomot0001   ← categoria receita padrão do hook
 *   cat_servico_residencial   → catrresid000001   ← categoria receita residencial do hook
 *   cat_aporte_socios         → catreaporte0001
 *   cat_emprestimos           → catreemprest001
 *   cat_reembolsos            → catrreembol0001
 *   cat_outras_receitas       → catrotrarecei01
 *   lim_marketing_google      → finlimmktggoog1
 *   lim_marketing_meta        → finlimmktgmeta1
 *   lim_produtos              → finlimprodut001
 *   lim_equipamentos          → finlimequip0001
 *   lim_combustivel           → finlimcombust01
 *   lim_equipe                → finlimequipe001
 *   lanc_seed_NN              → finlancseedNNNN
 *
 * NOTA: o hook os_financeiro_lib.js hardcoda os IDs semânticos antigos
 * ('cat_servico_automotivo', 'conta_carteira') mas tem fallback dinâmico
 * (primeira categoria receita / primeira conta ativa) — funciona corretamente.
 *
 * UPSERT idempotente por ID:
 *   findRecordById → se existir, atualiza; senão cria com rec.id = <id fixo>.
 *
 * DOWN: apaga pelos mesmos IDs em ordem inversa (limites → lancs → cats → contas).
 */

migrate(
  // ─────────────────────────── UP ───────────────────────────
  function (app) {

    function upsert(col, id, applyFn) {
      var rec = null;
      try { rec = app.findRecordById(col.name, id); } catch (_) { rec = null; }
      if (!rec) {
        rec = new Record(col);
        rec.id = id;
      }
      applyFn(rec);
      app.save(rec);
      return rec;
    }

    // ── 1. fin_contas (5) ────────────────────────────────────
    var contasCol = app.findCollectionByNameOrId("fin_contas");

    var CONTAS = [
      { id: "fincarteira0001", nome: "Carteira",            tipo: "carteira", saldo_inicial: 500,  saldo_atual:  306.16, ativo: true, cor: "#10B981", icone: "wallet"      },
      { id: "fininterbank001", nome: "Banco Inter",         tipo: "banco",    saldo_inicial: 8000, saldo_atual: 6450,    ativo: true, cor: "#FF7A00", icone: "landmark"    },
      { id: "finnubank000001", nome: "Nubank",              tipo: "banco",    saldo_inicial: 3000, saldo_atual: 3250,    ativo: true, cor: "#820AD1", icone: "landmark"    },
      { id: "fincartao000001", nome: "Cartão Empresarial",  tipo: "cartao",   saldo_inicial: 0,    saldo_atual: -1179.9, ativo: true, cor: "#1F2937", icone: "credit-card" },
      { id: "fincaixa0000001", nome: "Caixa físico",        tipo: "caixa",    saldo_inicial: 300,  saldo_atual:  300,    ativo: true, cor: "#64748B", icone: "banknote"    },
    ];

    for (var i = 0; i < CONTAS.length; i++) {
      (function (c) {
        upsert(contasCol, c.id, function (rec) {
          rec.set("nome",          c.nome);
          rec.set("tipo",          c.tipo);
          rec.set("saldo_inicial", c.saldo_inicial);
          rec.set("saldo_atual",   c.saldo_atual);
          rec.set("ativo",         c.ativo);
          rec.set("cor",           c.cor);
          rec.set("icone",         c.icone);
        });
      })(CONTAS[i]);
    }

    // ── 2. fin_categorias (34) — mães ANTES das filhas ───────
    var catsCol = app.findCollectionByNameOrId("fin_categorias");

    var CATEGORIAS = [
      // Despesas — Produtos
      { id: "catdprodutos001", nome: "Produtos",              tipo: "despesa", icone: "spray-can",     cor: "#0E9F9C", parent_id: "",                arquivada: false },
      { id: "catdprodquim001", nome: "Produtos químicos",     tipo: "despesa", icone: "flask-conical", cor: "#0E9F9C", parent_id: "catdprodutos001",  arquivada: false },
      { id: "catdprodins0001", nome: "Insumos",               tipo: "despesa", icone: "package",       cor: "#14B8A6", parent_id: "catdprodutos001",  arquivada: false },
      // Despesas — Equipamentos
      { id: "catdequipm00001", nome: "Equipamentos",          tipo: "despesa", icone: "wrench",        cor: "#6366F1", parent_id: "",                     arquivada: false },
      { id: "catdequipmaq001", nome: "Máquinas",              tipo: "despesa", icone: "cog",           cor: "#6366F1", parent_id: "catdequipm00001",      arquivada: false },
      { id: "catdequipacc001", nome: "Acessórios",            tipo: "despesa", icone: "plug",          cor: "#818CF8", parent_id: "catdequipm00001",      arquivada: false },
      // Despesas — Equipe
      { id: "catdequipe00001", nome: "Equipe",                tipo: "despesa", icone: "users",         cor: "#F59E0B", parent_id: "",              arquivada: false },
      { id: "catdequipeprof1", nome: "Profissionais",         tipo: "despesa", icone: "user-check",   cor: "#F59E0B", parent_id: "catdequipe00001", arquivada: false },
      { id: "catdequipecomi1", nome: "Comissões",             tipo: "despesa", icone: "hand-coins",   cor: "#FBBF24", parent_id: "catdequipe00001", arquivada: false },
      // Despesas — Sócios
      { id: "catdsocios00001", nome: "Sócios / Retiradas",    tipo: "despesa", icone: "briefcase",    cor: "#8B5CF6", parent_id: "",               arquivada: false },
      { id: "catdsociodenn01", nome: "Dennis",                tipo: "despesa", icone: "user",         cor: "#8B5CF6", parent_id: "catdsocios00001", arquivada: false },
      { id: "catdsociodieg01", nome: "Diego",                 tipo: "despesa", icone: "user",         cor: "#A78BFA", parent_id: "catdsocios00001", arquivada: false },
      // Despesas — Impostos
      { id: "catdimpost00001", nome: "Impostos e Taxas",      tipo: "despesa", icone: "landmark",     cor: "#64748B", parent_id: "", arquivada: false },
      // Despesas — Marketing
      { id: "catdmarket00001", nome: "Marketing",             tipo: "despesa", icone: "megaphone",    cor: "#EC4899", parent_id: "",               arquivada: false },
      { id: "catdmarketgoog1", nome: "Tráfego Pago Google",   tipo: "despesa", icone: "search",       cor: "#EA4335", parent_id: "catdmarket00001", arquivada: false },
      { id: "catdmarketmeta1", nome: "Tráfego Pago Meta",     tipo: "despesa", icone: "thumbs-up",    cor: "#1877F2", parent_id: "catdmarket00001", arquivada: false },
      { id: "catdmarketcria1", nome: "Materiais criativos",   tipo: "despesa", icone: "palette",      cor: "#F472B6", parent_id: "catdmarket00001", arquivada: false },
      // Despesas — Transporte
      { id: "catdtransp00001", nome: "Transporte",            tipo: "despesa", icone: "truck",        cor: "#0EA5E9", parent_id: "",                   arquivada: false },
      { id: "catdtranscomb01", nome: "Combustível",           tipo: "despesa", icone: "fuel",         cor: "#F97316", parent_id: "catdtransp00001",    arquivada: false },
      { id: "catdtransmant01", nome: "Manutenção",            tipo: "despesa", icone: "wrench",       cor: "#0EA5E9", parent_id: "catdtransp00001",    arquivada: false },
      { id: "catdtransuber01", nome: "Uber",                  tipo: "despesa", icone: "car",          cor: "#111827", parent_id: "catdtransp00001",    arquivada: false },
      // Despesas — Avulsas
      { id: "catdcompras0001", nome: "Compras",               tipo: "despesa", icone: "shopping-cart",cor: "#22C55E", parent_id: "", arquivada: false },
      { id: "catdassinas0001", nome: "Assinaturas e sistemas",tipo: "despesa", icone: "monitor",      cor: "#3B82F6", parent_id: "", arquivada: false },
      { id: "catdaliment0001", nome: "Alimentação",           tipo: "despesa", icone: "utensils",     cor: "#EF4444", parent_id: "", arquivada: false },
      { id: "catdaluguel0001", nome: "Aluguel",               tipo: "despesa", icone: "home",         cor: "#10B981", parent_id: "", arquivada: false },
      { id: "catdcontab00001", nome: "Contabilidade",         tipo: "despesa", icone: "calculator",   cor: "#64748B", parent_id: "", arquivada: false },
      { id: "catdtaxabanc001", nome: "Taxas bancárias",       tipo: "despesa", icone: "banknote",     cor: "#94A3B8", parent_id: "", arquivada: false },
      { id: "catdoutros00001", nome: "Outros",                tipo: "despesa", icone: "circle-dashed",cor: "#9CA3AF", parent_id: "", arquivada: false },
      // Receitas
      { id: "catrautomot0001", nome: "Serviço Automotivo",    tipo: "receita", icone: "car",          cor: "#0EA5A4", parent_id: "", arquivada: false },
      { id: "catrresid000001", nome: "Serviço Residencial",   tipo: "receita", icone: "home",         cor: "#10B981", parent_id: "", arquivada: false },
      { id: "catreaporte0001", nome: "Aporte dos Sócios",     tipo: "receita", icone: "piggy-bank",   cor: "#14B8A6", parent_id: "", arquivada: false },
      { id: "catreemprest001", nome: "Empréstimos",           tipo: "receita", icone: "hand-coins",   cor: "#22C55E", parent_id: "", arquivada: false },
      { id: "catrreembol0001", nome: "Reembolsos",            tipo: "receita", icone: "rotate-ccw",   cor: "#34D399", parent_id: "", arquivada: false },
      { id: "catrotrarecei01", nome: "Outras receitas",       tipo: "receita", icone: "plus-circle",  cor: "#2DD4BF", parent_id: "", arquivada: false },
    ];

    for (var j = 0; j < CATEGORIAS.length; j++) {
      (function (cat) {
        upsert(catsCol, cat.id, function (rec) {
          rec.set("nome",      cat.nome);
          rec.set("tipo",      cat.tipo);
          rec.set("icone",     cat.icone);
          rec.set("cor",       cat.cor);
          rec.set("parent_id", cat.parent_id);
          rec.set("arquivada", cat.arquivada);
        });
      })(CATEGORIAS[j]);
    }

    // ── 3. fin_lancamentos (20) ──────────────────────────────
    var lancsCol = app.findCollectionByNameOrId("fin_lancamentos");

    var LANCAMENTOS = [
      // ---- Receitas via OS ----
      {
        id: "finlancseed0001", tipo: "receita", descricao: "OS #000245 - Cleanox Premium",
        categoria_id: "catrautomot0001", subcategoria_id: "",
        valor: 300, conta_id: "fininterbank001",
        data: "2026-06-03T14:30:00.000Z", vencimento: "",
        status: "pago", recorrencia: "unica",
        origem: "via_os", os_id: "os_000245", os_numero: "000245",
        cliente_nome: "Carlos S.", servico_nome: "Cleanox Premium",
        forma_pagamento: "Pix", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0002", tipo: "receita", descricao: "OS #000251 - Sofá 3 lugares",
        categoria_id: "catrresid000001", subcategoria_id: "",
        valor: 180, conta_id: "fininterbank001",
        data: "2026-06-07T10:00:00.000Z", vencimento: "",
        status: "pago", recorrencia: "unica",
        origem: "via_os", os_id: "os_000251", os_numero: "000251",
        cliente_nome: "Marina L.", servico_nome: "Higienização Sofá 3 lugares",
        forma_pagamento: "Crédito", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0003", tipo: "receita", descricao: "OS #000260 - Cleanox Plus",
        categoria_id: "catrautomot0001", subcategoria_id: "",
        valor: 250, conta_id: "finnubank000001",
        data: "2026-06-15T16:45:00.000Z", vencimento: "",
        status: "pago", recorrencia: "unica",
        origem: "via_os", os_id: "os_000260", os_numero: "000260",
        cliente_nome: "Rafael T.", servico_nome: "Cleanox Plus",
        forma_pagamento: "Débito", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0004", tipo: "receita", descricao: "OS #000259 - Colchão casal",
        categoria_id: "catrresid000001", subcategoria_id: "",
        valor: 160, conta_id: "fininterbank001",
        data: "2026-06-28T09:00:00.000Z", vencimento: "2026-06-28",
        status: "previsto", recorrencia: "unica",
        origem: "via_os", os_id: "os_000259", os_numero: "000259",
        cliente_nome: "João P.", servico_nome: "Higienização Colchão casal",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
      // ---- Receitas manuais ----
      {
        id: "finlancseed0005", tipo: "receita", descricao: "Aporte dos sócios",
        categoria_id: "catreaporte0001", subcategoria_id: "",
        valor: 1500, conta_id: "fininterbank001",
        data: "2026-06-01T12:00:00.000Z", vencimento: "",
        status: "pago", recorrencia: "unica",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "Aporte para capital de giro", tags: [], anexos: [],
      },
      {
        id: "finlancseed0006", tipo: "receita", descricao: "Reembolso de material",
        categoria_id: "catrreembol0001", subcategoria_id: "",
        valor: 120, conta_id: "fininterbank001",
        data: "2026-06-20T11:00:00.000Z", vencimento: "2026-06-20",
        status: "pendente", recorrencia: "unica",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
      // ---- Despesas pagas ----
      {
        id: "finlancseed0007", tipo: "despesa", descricao: "Google Ads",
        categoria_id: "catdmarket00001", subcategoria_id: "catdmarketgoog1",
        valor: 450, conta_id: "fincartao000001",
        data: "2026-06-05T08:00:00.000Z", vencimento: "",
        status: "pago", recorrencia: "recorrente",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "Crédito", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0008", tipo: "despesa", descricao: "Meta Ads",
        categoria_id: "catdmarket00001", subcategoria_id: "catdmarketmeta1",
        valor: 350, conta_id: "fincartao000001",
        data: "2026-06-05T08:05:00.000Z", vencimento: "",
        status: "pago", recorrencia: "recorrente",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "Crédito", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0009", tipo: "despesa", descricao: "Fornecedor CleanTech",
        categoria_id: "catdprodutos001", subcategoria_id: "catdprodquim001",
        valor: 980, conta_id: "fininterbank001",
        data: "2026-06-08T15:20:00.000Z", vencimento: "",
        status: "pago", recorrencia: "unica",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "Produtos de limpeza profissionais", tags: [], anexos: [],
      },
      {
        id: "finlancseed0010", tipo: "despesa", descricao: "Combustível",
        categoria_id: "catdtransp00001", subcategoria_id: "catdtranscomb01",
        valor: 155.34, conta_id: "fincarteira0001",
        data: "2026-06-10T07:30:00.000Z", vencimento: "",
        status: "pago", recorrencia: "unica",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "Débito", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0011", tipo: "despesa", descricao: "Folha da equipe",
        categoria_id: "catdequipe00001", subcategoria_id: "catdequipeprof1",
        valor: 3250, conta_id: "fininterbank001",
        data: "2026-06-05T18:00:00.000Z", vencimento: "",
        status: "pago", recorrencia: "fixa",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0012", tipo: "despesa", descricao: "Taxa bancária",
        categoria_id: "catdtaxabanc001", subcategoria_id: "",
        valor: 20, conta_id: "fininterbank001",
        data: "2026-06-02T03:00:00.000Z", vencimento: "",
        status: "pago", recorrencia: "recorrente",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0013", tipo: "despesa", descricao: "Uber para atendimento",
        categoria_id: "catdtransp00001", subcategoria_id: "catdtransuber01",
        valor: 38.5, conta_id: "fincarteira0001",
        data: "2026-06-12T13:10:00.000Z", vencimento: "",
        status: "pago", recorrencia: "unica",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0014", tipo: "despesa", descricao: "Assinatura sistema (hospedagem)",
        categoria_id: "catdassinas0001", subcategoria_id: "",
        valor: 99.9, conta_id: "fincartao000001",
        data: "2026-06-04T06:00:00.000Z", vencimento: "",
        status: "pago", recorrencia: "recorrente",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "Crédito", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0015", tipo: "despesa", descricao: "Retirada - Dennis",
        categoria_id: "catdsocios00001", subcategoria_id: "catdsociodenn01",
        valor: 800, conta_id: "fininterbank001",
        data: "2026-06-20T17:00:00.000Z", vencimento: "",
        status: "pago", recorrencia: "unica",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0016", tipo: "despesa", descricao: "Retirada - Diego",
        categoria_id: "catdsocios00001", subcategoria_id: "catdsociodieg01",
        valor: 800, conta_id: "fininterbank001",
        data: "2026-06-20T17:05:00.000Z", vencimento: "",
        status: "pago", recorrencia: "unica",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0017", tipo: "despesa", descricao: "Máquina extratora (parcela 1/10)",
        categoria_id: "catdequipm00001", subcategoria_id: "catdequipmaq001",
        valor: 280, conta_id: "fincartao000001",
        data: "2026-06-01T10:00:00.000Z", vencimento: "",
        status: "pago", recorrencia: "parcelada", parcela_atual: 1, parcelas_total: 10,
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "Crédito", observacao: "", tags: [], anexos: [],
      },
      // ---- Despesas em aberto ----
      {
        id: "finlancseed0018", tipo: "despesa", descricao: "Aluguel",
        categoria_id: "catdaluguel0001", subcategoria_id: "",
        valor: 1200, conta_id: "fininterbank001",
        data: "2026-07-05T00:00:00.000Z", vencimento: "2026-07-05",
        status: "pendente", recorrencia: "fixa",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0019", tipo: "despesa", descricao: "Manutenção do extrator",
        categoria_id: "catdequipm00001", subcategoria_id: "catdequipmaq001",
        valor: 320, conta_id: "fininterbank001",
        data: "2026-06-18T00:00:00.000Z", vencimento: "2026-06-18",
        status: "em_atraso", recorrencia: "unica",
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
      {
        id: "finlancseed0020", tipo: "despesa", descricao: "Parcela do equipamento (2/10)",
        categoria_id: "catdequipm00001", subcategoria_id: "catdequipmaq001",
        valor: 280, conta_id: "fincartao000001",
        data: "2026-06-25T00:00:00.000Z", vencimento: "2026-06-25",
        status: "previsto", recorrencia: "parcelada", parcela_atual: 2, parcelas_total: 10,
        origem: "manual", os_id: "", os_numero: "", cliente_nome: "", servico_nome: "",
        forma_pagamento: "", observacao: "", tags: [], anexos: [],
      },
    ];

    for (var k = 0; k < LANCAMENTOS.length; k++) {
      (function (l) {
        upsert(lancsCol, l.id, function (rec) {
          rec.set("tipo",           l.tipo);
          rec.set("descricao",      l.descricao);
          rec.set("categoria_id",   l.categoria_id);
          rec.set("subcategoria_id",l.subcategoria_id);
          rec.set("valor",          l.valor);
          rec.set("conta_id",       l.conta_id);
          rec.set("data",           l.data);
          rec.set("vencimento",     l.vencimento);
          rec.set("status",         l.status);
          rec.set("recorrencia",    l.recorrencia);
          if (l.recorrencia === "parcelada") {
            rec.set("parcela_atual",  l.parcela_atual);
            rec.set("parcelas_total", l.parcelas_total);
          } else {
            rec.set("parcela_atual",  null);
            rec.set("parcelas_total", null);
          }
          rec.set("origem",         l.origem);
          rec.set("os_id",          l.os_id);
          rec.set("os_numero",      l.os_numero);
          rec.set("cliente_nome",   l.cliente_nome);
          rec.set("servico_nome",   l.servico_nome);
          rec.set("forma_pagamento",l.forma_pagamento);
          rec.set("observacao",     l.observacao);
          rec.set("tags",           l.tags);
          rec.set("anexos",         l.anexos);
        });
      })(LANCAMENTOS[k]);
    }

    // ── 4. fin_limites (6) ───────────────────────────────────
    var limitesCol = app.findCollectionByNameOrId("fin_limites");

    var LIMITES = [
      { id: "finlimmktggoog1", categoria_id: "catdmarketgoog1", limite: 600  },
      { id: "finlimmktgmeta1", categoria_id: "catdmarketmeta1", limite: 500  },
      { id: "finlimprodut001", categoria_id: "catdprodutos001", limite: 1500 },
      { id: "finlimequip0001", categoria_id: "catdequipm00001", limite: 1000 },
      { id: "finlimcombust01", categoria_id: "catdtranscomb01", limite: 400  },
      { id: "finlimequipe001", categoria_id: "catdequipe00001", limite: 4000 },
    ];

    for (var m = 0; m < LIMITES.length; m++) {
      (function (lim) {
        upsert(limitesCol, lim.id, function (rec) {
          rec.set("categoria_id", lim.categoria_id);
          rec.set("limite",       lim.limite);
        });
      })(LIMITES[m]);
    }
  },

  // ─────────────────────────── DOWN ─────────────────────────
  function (app) {

    function tryDelete(colName, id) {
      try { app.delete(app.findRecordById(colName, id)); } catch (_) {}
    }

    var LIMITE_IDS = [
      "finlimmktggoog1", "finlimmktgmeta1", "finlimprodut001",
      "finlimequip0001", "finlimcombust01", "finlimequipe001",
    ];
    for (var i = 0; i < LIMITE_IDS.length; i++) tryDelete("fin_limites", LIMITE_IDS[i]);

    var LANC_IDS = [
      "finlancseed0001", "finlancseed0002", "finlancseed0003", "finlancseed0004",
      "finlancseed0005", "finlancseed0006", "finlancseed0007", "finlancseed0008",
      "finlancseed0009", "finlancseed0010", "finlancseed0011", "finlancseed0012",
      "finlancseed0013", "finlancseed0014", "finlancseed0015", "finlancseed0016",
      "finlancseed0017", "finlancseed0018", "finlancseed0019", "finlancseed0020",
    ];
    for (var j = 0; j < LANC_IDS.length; j++) tryDelete("fin_lancamentos", LANC_IDS[j]);

    // filhas primeiro, depois mães
    var CAT_IDS = [
      "catdprodquim001",  "catdprodins0001",
      "catdequipmaq001",  "catdequipacc001",
      "catdequipeprof1",  "catdequipecomi1",
      "catdsociodenn01",  "catdsociodieg01",
      "catdmarketgoog1",  "catdmarketmeta1",  "catdmarketcria1",
      "catdtranscomb01",  "catdtransmant01",  "catdtransuber01",
      // mães e avulsas
      "catdprodutos001",  "catdequipm00001",  "catdequipe00001",  "catdsocios00001",
      "catdimpost00001",  "catdmarket00001",  "catdtransp00001",
      "catdcompras0001",  "catdassinas0001",  "catdaliment0001",  "catdaluguel0001",
      "catdcontab00001",  "catdtaxabanc001",  "catdoutros00001",
      // receitas
      "catrautomot0001",  "catrresid000001",  "catreaporte0001",
      "catreemprest001",  "catrreembol0001",  "catrotrarecei01",
    ];
    for (var k = 0; k < CAT_IDS.length; k++) tryDelete("fin_categorias", CAT_IDS[k]);

    var CONTA_IDS = [
      "fincarteira0001", "fininterbank001", "finnubank000001", "fincartao000001", "fincaixa0000001",
    ];
    for (var m = 0; m < CONTA_IDS.length; m++) tryDelete("fin_contas", CONTA_IDS[m]);
  }
);
