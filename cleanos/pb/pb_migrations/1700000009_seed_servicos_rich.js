/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 9: SEED do catálogo RICO de serviços (32 itens).
 *
 * Fonte de verdade: cleanos/web/src/lib/servicos/seed.ts (SERVICOS_SEED).
 * Transcreve 15 veiculares + 17 residenciais com taxonomia, valores, tempo
 * médio, checklist padrão, orientações e adicionais relacionados.
 *
 * UPSERT idempotente:
 *   1) casa por `slug` (referência estável) → UPDATE;
 *   2) senão, casa por `nome` (inclui os aliases dos 7 placeholders já seedados
 *      pela Migration 2 `catalog_prod`) → UPDATE preenchendo os campos ricos,
 *      em vez de duplicar;
 *   3) senão, CREATE.
 *
 * Back-compat: grava `preco_base = valor_base` e `ativo = (status === 'ativo')`.
 * `tempo_medio_min` é DERIVADO de `tempo_medio_label` (limite superior) por
 * parseTempoMedio — rótulo e minutos nunca divergem (mesma regra do frontend).
 *
 * DOWN: reverte. Os 7 placeholders são restaurados ao estado da Migration 2;
 * os 25 itens criados por esta migration são removidos — EXCETO se uma OS os
 * referenciar (nesse caso só limpamos os campos ricos, preservando o registro).
 */

migrate(
  (app) => {
    const servicosCol = app.findCollectionByNameOrId("servicos");

    // ---- parseTempoMedio (espelho de web/src/lib/servicos/labels.ts) ----
    // Usa sempre o LIMITE SUPERIOR; "Variável"/"" → 0 (sem tempo determinável).
    function parseTempoMedio(label) {
      if (!label) return 0;
      const normalized = String(label).toLowerCase();
      if (normalized.indexOf("vari") !== -1) return 0;
      const re = /(\d+)\s*h\s*(\d+)?|(\d+)\s*min/g;
      let max = 0;
      let m;
      while ((m = re.exec(normalized)) !== null) {
        let minutos;
        if (m[1] !== undefined) {
          minutos = parseInt(m[1], 10) * 60 + (m[2] ? parseInt(m[2], 10) : 0);
        } else {
          minutos = parseInt(m[3], 10);
        }
        if (minutos > max) max = minutos;
      }
      return max;
    }

    // ---- mkChecklist: ids estáveis derivados do slug (= seed.ts) ----
    function mkChecklist(slug, titulos) {
      return (titulos || []).map(function (titulo, i) {
        return { id: "chk_" + slug + "_" + (i + 1), titulo: titulo, ordem: i + 1 };
      });
    }

    // ---- Orientações reaproveitadas (transcritas de seed.ts) ----
    const ORIENT_PRE_PREMIUM =
      "Garantir ponto de energia e ponto de água no local. Remover objetos pessoais do " +
      "veículo para melhor execução do serviço.";
    const ORIENT_POS_PREMIUM =
      "Tempo de secagem de 2 a 6 horas, dependendo do clima e do nível da higienização " +
      "realizada. Prazo de até 3 dias para relatar qualquer intercorrência.";
    const ORIENT_POS_VEICULAR =
      "Tempo de secagem de 2 a 6 horas, dependendo do clima e do nível da higienização. " +
      "Prazo de até 3 dias para relatar qualquer intercorrência.";
    const ORIENT_POS_RESIDENCIAL =
      "Tempo de secagem de 4 a 8 horas. Evite o uso da peça antes da secagem completa. " +
      "Prazo de até 3 dias para relatar qualquer intercorrência.";

    // ---- Títulos de checklist (transcritos de seed.ts) ----
    const TIT_ESSENCIAL = [
      "Fotos de antes", "Conferência inicial do veículo", "Aspiração inicial",
      "Higienização dos bancos", "Aspiração do carpete, porta-malas e tapetes",
      "Conferência final", "Fotos de depois",
    ];
    const TIT_COMPLETO = [
      "Fotos de antes", "Conferência inicial do veículo",
      "Proteção e organização da área de trabalho", "Aspiração inicial",
      "Higienização dos bancos", "Higienização do teto", "Higienização do quebra-sol",
      "Higienização dos cintos", "Higienização dos forros das portas",
      "Aspiração do carpete, porta-malas e tapetes", "Conferência final", "Fotos de depois",
    ];
    const TIT_PREMIUM = [
      "Fotos de antes", "Conferência inicial do veículo",
      "Proteção e organização da área de trabalho", "Aspiração inicial completa",
      "Higienização dos bancos frente e trás", "Higienização do teto",
      "Higienização dos quebra-sóis", "Higienização dos cintos de segurança",
      "Higienização dos forros de porta", "Higienização do carpete",
      "Higienização do porta-malas", "Higienização dos tapetes",
      "Revitalização de painel e partes plásticas", "Conferência final",
      "Fotos de depois", "Validação com o cliente",
    ];
    const TIT_AVULSO_VEICULAR = [
      "Fotos de antes", "Higienização do item contratado", "Conferência final", "Fotos de depois",
    ];
    const TIT_RESIDENCIAL = [
      "Fotos de antes", "Conferência inicial da peça", "Pré-tratamento de manchas",
      "Higienização e extração", "Conferência final", "Fotos de depois",
    ];

    // monta um serviço completo a partir do mínimo, preenchendo defaults.
    function svc(input) {
      return {
        slug: input.slug,
        categoria: input.categoria,
        grupo: input.grupo,
        nome: input.nome,
        valorBase: input.valorBase,
        valorBaseMax: input.valorBaseMax,
        tipoValor: input.tipoValor,
        tempoMedioMin: parseTempoMedio(input.tempoMedioLabel),
        tempoMedioLabel: input.tempoMedioLabel,
        status: input.status || "ativo",
        observacao: input.observacao || "",
        checklistPadrao: mkChecklist(input.slug, input.checklistTitulos),
        orientacoesPre: input.orientacoesPre || "",
        orientacoesPos: input.orientacoesPos || "",
        adicionaisRelacionados: input.adicionaisRelacionados || [],
      };
    }

    const SEED = [
      // ---- VEICULAR (15) ----
      svc({ slug: "svc_veic_essencial", categoria: "veicular", grupo: "plano", nome: "Cleanox Essencial", valorBase: 150, tipoValor: "fixo", tempoMedioLabel: "1h30 a 2h", observacao: "Pacote de entrada, focado em bancos + aspiração.", checklistTitulos: TIT_ESSENCIAL, orientacoesPos: ORIENT_POS_VEICULAR, adicionaisRelacionados: ["svc_veic_muito_sujo", "svc_veic_deslocamento", "svc_veic_teto", "svc_veic_carpete_higien"] }),
      svc({ slug: "svc_veic_completo", categoria: "veicular", grupo: "plano", nome: "Cleanox Completo", valorBase: 220, tipoValor: "fixo", tempoMedioLabel: "1h30 a 2h30", observacao: "Inclui bancos, teto, quebra-sol, cintos, forros das portas e aspiração.", checklistTitulos: TIT_COMPLETO, orientacoesPos: ORIENT_POS_VEICULAR, adicionaisRelacionados: ["svc_veic_muito_sujo", "svc_veic_deslocamento", "svc_veic_painel", "svc_veic_carpete_higien"] }),
      svc({ slug: "svc_veic_premium", categoria: "veicular", grupo: "plano", nome: "Cleanox Premium", valorBase: 300, tipoValor: "fixo", tempoMedioLabel: "3h a 4h", observacao: "Serviço mais detalhado, adicionando higienização do carpete e revitalização das partes plásticas ao pacote completo.", checklistTitulos: TIT_PREMIUM, orientacoesPre: ORIENT_PRE_PREMIUM, orientacoesPos: ORIENT_POS_PREMIUM, adicionaisRelacionados: ["svc_veic_muito_sujo", "svc_veic_deslocamento"] }),
      svc({ slug: "svc_veic_completo_promo", categoria: "veicular", grupo: "promocao", nome: "Cleanox Completo - Promoção", valorBase: 200, tipoValor: "fixo", tempoMedioLabel: "2h", observacao: "Versão promocional do Cleanox Completo.", checklistTitulos: TIT_COMPLETO, orientacoesPos: ORIENT_POS_VEICULAR, adicionaisRelacionados: ["svc_veic_muito_sujo", "svc_veic_deslocamento"] }),
      svc({ slug: "svc_veic_premium_promo", categoria: "veicular", grupo: "promocao", nome: "Cleanox Premium - Promoção", valorBase: 250, tipoValor: "fixo", tempoMedioLabel: "2h a 3h", observacao: "Versão promocional do Cleanox Premium.", checklistTitulos: TIT_PREMIUM, orientacoesPre: ORIENT_PRE_PREMIUM, orientacoesPos: ORIENT_POS_PREMIUM, adicionaisRelacionados: ["svc_veic_muito_sujo", "svc_veic_deslocamento"] }),
      svc({ slug: "svc_veic_muito_sujo", categoria: "veicular", grupo: "adicional", nome: "Veículo muito sujo", valorBase: 50, tipoValor: "variavel", tempoMedioLabel: "Variável", observacao: "Cobrado adicionalmente caso o veículo apresente excesso de sujeira, exigindo maior esforço, tempo e produtos." }),
      svc({ slug: "svc_veic_deslocamento", categoria: "veicular", grupo: "adicional", nome: "Taxa de deslocamento", valorBase: 30, tipoValor: "variavel", tempoMedioLabel: "Variável", observacao: "Taxa calculada com base na distância e tempo de deslocamento até o local do cliente." }),
      svc({ slug: "svc_veic_bancos_frente_tras", categoria: "veicular", grupo: "avulsos", nome: "Higienização de bancos frente e trás", valorBase: 130, tipoValor: "fixo", tempoMedioLabel: "1h a 1h30", checklistTitulos: TIT_AVULSO_VEICULAR }),
      svc({ slug: "svc_veic_bancos_meio", categoria: "veicular", grupo: "avulsos", nome: "Higienização de bancos somente frente ou somente trás", valorBase: 100, tipoValor: "fixo", tempoMedioLabel: "1h", checklistTitulos: TIT_AVULSO_VEICULAR }),
      svc({ slug: "svc_veic_teto", categoria: "veicular", grupo: "avulsos", nome: "Higienização de teto", valorBase: 70, tipoValor: "fixo", tempoMedioLabel: "40min a 1h", checklistTitulos: TIT_AVULSO_VEICULAR }),
      svc({ slug: "svc_veic_cintos", categoria: "veicular", grupo: "avulsos", nome: "Higienização dos cintos", valorBase: 50, tipoValor: "fixo", tempoMedioLabel: "20min a 40min", checklistTitulos: TIT_AVULSO_VEICULAR }),
      svc({ slug: "svc_veic_forros_porta", categoria: "veicular", grupo: "avulsos", nome: "Higienização dos forros de porta", valorBase: 50, tipoValor: "fixo", tempoMedioLabel: "30min a 1h", checklistTitulos: TIT_AVULSO_VEICULAR }),
      svc({ slug: "svc_veic_painel", categoria: "veicular", grupo: "avulsos", nome: "Revitalização de painel / partes plásticas", valorBase: 50, tipoValor: "fixo", tempoMedioLabel: "30min a 1h", checklistTitulos: TIT_AVULSO_VEICULAR }),
      svc({ slug: "svc_veic_carpete_higien", categoria: "veicular", grupo: "avulsos", nome: "Higienização do carpete, porta-malas e tapetes", valorBase: 100, tipoValor: "fixo", tempoMedioLabel: "1h", checklistTitulos: TIT_AVULSO_VEICULAR }),
      svc({ slug: "svc_veic_carpete_asp", categoria: "veicular", grupo: "avulsos", nome: "Aspiração do carpete, porta-malas e tapetes", valorBase: 50, tipoValor: "fixo", tempoMedioLabel: "30min a 1h", checklistTitulos: TIT_AVULSO_VEICULAR }),

      // ---- RESIDENCIAL (17) ----
      svc({ slug: "svc_resid_sofa2", categoria: "residencial", grupo: "sofa", nome: "Sofá 2 lugares", valorBase: 150, tipoValor: "fixo", tempoMedioLabel: "1h a 1h30", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_sofa3", categoria: "residencial", grupo: "sofa", nome: "Sofá 3 lugares", valorBase: 180, tipoValor: "fixo", tempoMedioLabel: "1h30 a 2h", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_sofa_retratil", categoria: "residencial", grupo: "sofa", nome: "Sofá retrátil 2/3 lugares", valorBase: 200, tipoValor: "fixo", tempoMedioLabel: "2h a 2h30", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_sofa4", categoria: "residencial", grupo: "sofa", nome: "Sofá 4 lugares", valorBase: 230, tipoValor: "variavel", tempoMedioLabel: "2h a 3h", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_sofa56", categoria: "residencial", grupo: "sofa", nome: "Sofá 5/6 lugares", valorBase: 250, tipoValor: "variavel", tempoMedioLabel: "3h+", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_colchao_solteiro", categoria: "residencial", grupo: "colchao", nome: "Colchão solteiro", valorBase: 120, tipoValor: "fixo", tempoMedioLabel: "1h", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_colchao_casal", categoria: "residencial", grupo: "colchao", nome: "Colchão casal", valorBase: 150, tipoValor: "fixo", tempoMedioLabel: "1h a 1h30", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_colchao_queen", categoria: "residencial", grupo: "colchao", nome: "Colchão queen", valorBase: 170, tipoValor: "fixo", tempoMedioLabel: "1h30 a 2h", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_colchao_king", categoria: "residencial", grupo: "colchao", nome: "Colchão king", valorBase: 190, tipoValor: "fixo", tempoMedioLabel: "2h", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_box_solteiro", categoria: "residencial", grupo: "colchao", nome: "Cama box solteiro", valorBase: 120, tipoValor: "fixo", tempoMedioLabel: "1h", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_box_casal", categoria: "residencial", grupo: "colchao", nome: "Cama box casal", valorBase: 150, tipoValor: "fixo", tempoMedioLabel: "1h a 1h30", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_poltrona", categoria: "residencial", grupo: "outros", nome: "Poltrona", valorBase: 50, valorBaseMax: 80, tipoValor: "faixa", tempoMedioLabel: "30min a 1h", checklistTitulos: TIT_RESIDENCIAL, orientacoesPos: ORIENT_POS_RESIDENCIAL }),
      svc({ slug: "svc_resid_cadeira_assento", categoria: "residencial", grupo: "outros", nome: "Cadeira apenas assento", valorBase: 20, tipoValor: "fixo", tempoMedioLabel: "10min a 20min", checklistTitulos: TIT_RESIDENCIAL }),
      svc({ slug: "svc_resid_cadeira_assento_encosto", categoria: "residencial", grupo: "outros", nome: "Cadeira assento + encosto", valorBase: 30, tipoValor: "fixo", tempoMedioLabel: "15min a 25min", checklistTitulos: TIT_RESIDENCIAL }),
      svc({ slug: "svc_resid_puff", categoria: "residencial", grupo: "outros", nome: "Puff", valorBase: 30, tipoValor: "fixo", tempoMedioLabel: "15min a 30min", checklistTitulos: TIT_RESIDENCIAL }),
      svc({ slug: "svc_resid_tapete_pequeno", categoria: "residencial", grupo: "outros", nome: "Tapete pequeno", valorBase: 60, tipoValor: "variavel", tempoMedioLabel: "Variável", checklistTitulos: TIT_RESIDENCIAL }),
      svc({ slug: "svc_resid_tapete_grande", categoria: "residencial", grupo: "outros", nome: "Tapete médio/grande", valorBase: 120, tipoValor: "variavel", tempoMedioLabel: "Variável", checklistTitulos: TIT_RESIDENCIAL }),
    ];

    // nomes legados (placeholders da Migration 2) que casam num slug rico.
    // Os 5 restantes ("Sofá 2 lugares", "Sofá 3 lugares", "Poltrona",
    // "Colchão solteiro", "Colchão casal") casam pelo próprio nome.
    const SLUG_LEGACY_NOMES = {
      "svc_resid_cadeira_assento_encosto": ["Cadeira"],
      "svc_resid_tapete_pequeno": ["Tapete"],
    };

    function applyRich(rec, s) {
      rec.set("slug", s.slug);
      rec.set("nome", s.nome);
      rec.set("categoria", s.categoria);
      rec.set("grupo", s.grupo);
      rec.set("valor_base", s.valorBase);
      rec.set("valor_base_max", (s.valorBaseMax === undefined || s.valorBaseMax === null) ? 0 : s.valorBaseMax);
      rec.set("tipo_valor", s.tipoValor);
      rec.set("tempo_medio_min", s.tempoMedioMin || 0);
      rec.set("tempo_medio_label", s.tempoMedioLabel || "");
      rec.set("status", s.status);
      rec.set("observacao", s.observacao || "");
      rec.set("checklist_padrao", s.checklistPadrao || []);
      rec.set("orientacoes_pre", s.orientacoesPre || "");
      rec.set("orientacoes_pos", s.orientacoesPos || "");
      rec.set("adicionais_relacionados", s.adicionaisRelacionados || []);
      // back-compat (legado): preco_base = valor_base; ativo = status ativo.
      rec.set("preco_base", s.valorBase);
      rec.set("ativo", s.status === "ativo");
    }

    for (let i = 0; i < SEED.length; i++) {
      const s = SEED[i];

      // 1) casa por slug
      let rec = null;
      try { rec = app.findFirstRecordByData("servicos", "slug", s.slug); } catch (_) { rec = null; }

      // 2) senão, casa por nome (próprio + aliases legados)
      if (!rec) {
        const nomes = [s.nome].concat(SLUG_LEGACY_NOMES[s.slug] || []);
        for (let j = 0; j < nomes.length; j++) {
          try { rec = app.findFirstRecordByData("servicos", "nome", nomes[j]); break; }
          catch (_) { /* não achou esse nome — tenta o próximo */ }
        }
      }

      // 3) senão, cria
      if (!rec) rec = new Record(servicosCol);

      applyRich(rec, s);
      app.save(rec);
    }
  },

  // ----------------------------- DOWN -----------------------------
  (app) => {
    // Restauração dos 7 placeholders ao estado da Migration 2 (catalog_prod).
    const PLACEHOLDER_RESTORE = {
      "svc_resid_sofa2": { nome: "Sofá 2 lugares", descricao: "Higienização de sofá de 2 lugares", preco: 180 },
      "svc_resid_sofa3": { nome: "Sofá 3 lugares", descricao: "Higienização de sofá de 3 lugares", preco: 240 },
      "svc_resid_poltrona": { nome: "Poltrona", descricao: "Higienização de poltrona", preco: 90 },
      "svc_resid_colchao_solteiro": { nome: "Colchão solteiro", descricao: "Higienização de colchão de solteiro", preco: 120 },
      "svc_resid_colchao_casal": { nome: "Colchão casal", descricao: "Higienização de colchão de casal", preco: 160 },
      "svc_resid_cadeira_assento_encosto": { nome: "Cadeira", descricao: "Higienização de cadeira estofada", preco: 40 },
      "svc_resid_tapete_pequeno": { nome: "Tapete", descricao: "Higienização de tapete (m²)", preco: 70 },
    };

    // todos os slugs criados/enriquecidos por esta migration.
    const SLUGS = [
      "svc_veic_essencial", "svc_veic_completo", "svc_veic_premium",
      "svc_veic_completo_promo", "svc_veic_premium_promo", "svc_veic_muito_sujo",
      "svc_veic_deslocamento", "svc_veic_bancos_frente_tras", "svc_veic_bancos_meio",
      "svc_veic_teto", "svc_veic_cintos", "svc_veic_forros_porta", "svc_veic_painel",
      "svc_veic_carpete_higien", "svc_veic_carpete_asp",
      "svc_resid_sofa2", "svc_resid_sofa3", "svc_resid_sofa_retratil",
      "svc_resid_sofa4", "svc_resid_sofa56", "svc_resid_colchao_solteiro",
      "svc_resid_colchao_casal", "svc_resid_colchao_queen", "svc_resid_colchao_king",
      "svc_resid_box_solteiro", "svc_resid_box_casal", "svc_resid_poltrona",
      "svc_resid_cadeira_assento", "svc_resid_cadeira_assento_encosto",
      "svc_resid_puff", "svc_resid_tapete_pequeno", "svc_resid_tapete_grande",
    ];

    // alguma OS referencia este serviço?
    function isReferenced(servicoId) {
      try {
        const refs = app.findRecordsByFilter(
          "ordens_servico", "servico = {:sid}", "", 1, 0, { sid: servicoId }
        );
        return refs && refs.length > 0;
      } catch (_) { return false; }
    }

    // limpa os campos ricos de um registro (preserva nome/preco_base/ativo).
    function clearRich(rec) {
      rec.set("slug", "");
      rec.set("categoria", "");
      rec.set("grupo", "");
      rec.set("valor_base", 0);
      rec.set("valor_base_max", 0);
      rec.set("tipo_valor", "");
      rec.set("tempo_medio_min", 0);
      rec.set("tempo_medio_label", "");
      rec.set("status", "");
      rec.set("observacao", "");
      rec.set("checklist_padrao", null);
      rec.set("orientacoes_pre", "");
      rec.set("orientacoes_pos", "");
      rec.set("adicionais_relacionados", null);
    }

    for (let i = 0; i < SLUGS.length; i++) {
      const slug = SLUGS[i];
      let rec = null;
      try { rec = app.findFirstRecordByData("servicos", "slug", slug); } catch (_) { rec = null; }
      if (!rec) continue;

      const restore = PLACEHOLDER_RESTORE[slug];
      if (restore) {
        // placeholder pré-existente → restaura ao estado da Migration 2.
        clearRich(rec);
        rec.set("nome", restore.nome);
        rec.set("descricao", restore.descricao);
        rec.set("preco_base", restore.preco);
        rec.set("ativo", true);
        app.save(rec);
      } else if (isReferenced(rec.id)) {
        // criado por esta migration, mas há OS apontando → preserva o registro,
        // só limpa os campos ricos.
        clearRich(rec);
        app.save(rec);
      } else {
        // criado por esta migration e sem referência → remove.
        app.delete(rec);
      }
    }
  }
);
