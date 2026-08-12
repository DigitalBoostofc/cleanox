/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Vitrine autoagendamento (sem orçamento / sem atribuição automática).
 *
 * ADITIVA e REVERSÍVEL:
 *  1) ordens_servico.vitrine_idempotency_key + índice único parcial
 *  2) vitrine_config: capacidade/horários da grade pública
 *  3) data update de copy legado SOMENTE quando o valor é exatamente o default antigo
 *     (preserva customizações do CMS)
 *
 * NÃO toca produção sozinha — precisa migrate up autorizado.
 */

migrate(
  (app) => {
    // ── 1) Idempotência em OS ───────────────────────────────────────────────
    let ordens = null;
    try {
      ordens = app.findCollectionByNameOrId("ordens_servico");
    } catch (_) {
      ordens = null;
    }
    if (ordens) {
      if (!ordens.fields.getByName("vitrine_idempotency_key")) {
        ordens.fields.add(
          new TextField({
            name: "vitrine_idempotency_key",
            required: false,
            max: 100,
          }),
        );
      }
      const IDX = "idx_os_vitrine_idem";
      const hasIdx = (ordens.indexes || []).some(function (s) {
        return String(s).indexOf(IDX) !== -1;
      });
      if (!hasIdx) {
        ordens.indexes = (ordens.indexes || []).concat([
          "CREATE UNIQUE INDEX `" +
            IDX +
            "` ON `ordens_servico` (`vitrine_idempotency_key`) WHERE `vitrine_idempotency_key` != ''",
        ]);
      }
      app.save(ordens);
    }

    // ── 2) Capacidade / grade em vitrine_config ─────────────────────────────
    let cfgCol = null;
    try {
      cfgCol = app.findCollectionByNameOrId("vitrine_config");
    } catch (_) {
      try {
        cfgCol = app.findCollectionByNameOrId("vitrineconfig0001");
      } catch (__) {
        cfgCol = null;
      }
    }
    if (cfgCol) {
      function ensureNum(name, min) {
        if (!cfgCol.fields.getByName(name)) {
          cfgCol.fields.add(
            new NumberField({ name: name, required: false, min: min }),
          );
        }
      }
      function ensureText(name, max) {
        if (!cfgCol.fields.getByName(name)) {
          cfgCol.fields.add(
            new TextField({ name: name, required: false, max: max }),
          );
        }
      }
      ensureNum("capacidade_simultanea", 0);
      ensureText("horario_inicio", 8);
      ensureText("horario_fim", 8);
      ensureNum("passo_min", 15);
      ensureNum("antecedencia_minutos", 0);
      ensureNum("horizonte_dias", 1);
      app.save(cfgCol);

      // Defaults numéricos só se ainda vazios / null (não sobrescreve CMS)
      try {
        const list = app.findRecordsByFilter("vitrine_config", "", "", 10, 0);
        for (let i = 0; i < (list || []).length; i++) {
          const r = list[i];
          let ch = false;
          if (r.get("capacidade_simultanea") == null) {
            r.set("capacidade_simultanea", 0);
            ch = true;
          }
          if (!String(r.get("horario_inicio") || "").trim()) {
            r.set("horario_inicio", "08:00");
            ch = true;
          }
          if (!String(r.get("horario_fim") || "").trim()) {
            r.set("horario_fim", "18:00");
            ch = true;
          }
          if (r.get("passo_min") == null || Number(r.get("passo_min")) <= 0) {
            r.set("passo_min", 30);
            ch = true;
          }
          if (r.get("antecedencia_minutos") == null) {
            r.set("antecedencia_minutos", 60);
            ch = true;
          }
          if (r.get("horizonte_dias") == null || Number(r.get("horizonte_dias")) <= 0) {
            r.set("horizonte_dias", 14);
            ch = true;
          }

          // ── 3) Copy legado → autoagendamento (match exato only) ─────────
          // Defaults antigos (mig 0045 / defaultConfig pré-autoagendamento)
          const OLD_TITULO = "Orçamento em 1 minuto";
          const OLD_CTA = "Montar orçamento";
          const OLD_COMO =
            "1) Selecione os serviços\n2) Informe contato e endereço\n3) Veja o orçamento e ofertas\n4) Escolha data e horário\n5) Confirmamos no WhatsApp";
          const NEW_TITULO = "Agende seu serviço";
          const NEW_SUB =
            "Escolha o que precisa limpar e marque data e horário";
          const NEW_CTA = "Agendar agora";
          const NEW_COMO =
            "1) Selecione os serviços\n2) Escolha data e horário\n3) Informe contato e endereço\n4) Revise e confirme\n5) OS criada — a Cleanox atribui a equipe";
          const OLD_SUB =
            "Escolha o que precisa limpar e agende no horário ideal";

          if (String(r.get("hero_titulo") || "") === OLD_TITULO) {
            r.set("hero_titulo", NEW_TITULO);
            ch = true;
          }
          if (String(r.get("hero_cta") || "") === OLD_CTA) {
            r.set("hero_cta", NEW_CTA);
            ch = true;
          }
          if (String(r.get("hero_subtitulo") || "") === OLD_SUB) {
            r.set("hero_subtitulo", NEW_SUB);
            ch = true;
          }
          if (String(r.get("como_funciona") || "") === OLD_COMO) {
            r.set("como_funciona", NEW_COMO);
            ch = true;
          }
          // preserva qualquer copy customizada do CMS (não-igual aos defaults antigos)
          if (ch) app.save(r);
        }
      } catch (_) {
        /* best-effort */
      }
    }
  },

  // ── DOWN ────────────────────────────────────────────────────────────────
  (app) => {
    let ordens = null;
    try {
      ordens = app.findCollectionByNameOrId("ordens_servico");
    } catch (_) {
      ordens = null;
    }
    if (ordens) {
      ordens.indexes = (ordens.indexes || []).filter(function (s) {
        return String(s).indexOf("idx_os_vitrine_idem") === -1;
      });
      const f = ordens.fields.getByName("vitrine_idempotency_key");
      if (f) ordens.fields.removeById(f.id);
      app.save(ordens);
    }

    let cfgCol = null;
    try {
      cfgCol = app.findCollectionByNameOrId("vitrine_config");
    } catch (_) {
      try {
        cfgCol = app.findCollectionByNameOrId("vitrineconfig0001");
      } catch (__) {
        cfgCol = null;
      }
    }
    if (cfgCol) {
      // Reverte copy SOMENTE se ainda for o default novo (não apaga customização)
      try {
        const list = app.findRecordsByFilter("vitrine_config", "", "", 10, 0);
        for (let i = 0; i < (list || []).length; i++) {
          const r = list[i];
          let ch = false;
          if (String(r.get("hero_titulo") || "") === "Agende seu serviço") {
            r.set("hero_titulo", "Orçamento em 1 minuto");
            ch = true;
          }
          if (String(r.get("hero_cta") || "") === "Agendar agora") {
            r.set("hero_cta", "Montar orçamento");
            ch = true;
          }
          if (
            String(r.get("hero_subtitulo") || "") ===
            "Escolha o que precisa limpar e marque data e horário"
          ) {
            r.set(
              "hero_subtitulo",
              "Escolha o que precisa limpar e agende no horário ideal",
            );
            ch = true;
          }
          if (
            String(r.get("como_funciona") || "") ===
            "1) Selecione os serviços\n2) Escolha data e horário\n3) Informe contato e endereço\n4) Revise e confirme\n5) OS criada — a Cleanox atribui a equipe"
          ) {
            r.set(
              "como_funciona",
              "1) Selecione os serviços\n2) Informe contato e endereço\n3) Veja o orçamento e ofertas\n4) Escolha data e horário\n5) Confirmamos no WhatsApp",
            );
            ch = true;
          }
          if (ch) app.save(r);
        }
      } catch (_) {}

      const drop = [
        "capacidade_simultanea",
        "horario_inicio",
        "horario_fim",
        "passo_min",
        "antecedencia_minutos",
        "horizonte_dias",
      ];
      for (let d = 0; d < drop.length; d++) {
        const field = cfgCol.fields.getByName(drop[d]);
        if (field) cfgCol.fields.removeById(field.id);
      }
      app.save(cfgCol);
    }
  },
);
