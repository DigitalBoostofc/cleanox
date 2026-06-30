/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 8: épico Serviços/OS RICO (schema).
 *
 * Enriquece o catálogo `servicos` e as `ordens_servico` com a estrutura do novo
 * módulo de Serviços (taxonomia, checklist padrão, snapshot imutável na OS,
 * checklist de execução, adicionais, observações do profissional) e cria a
 * coleção `os_evidencias` (fotos antes/durante/depois) sob o MODELO COFRE.
 *
 * Princípios desta migration:
 *   - IDEMPOTENTE: só adiciona campo/índice/coleção se ainda não existir
 *     (checa col.fields.getByName / findCollectionByNameOrId).
 *   - REVERSÍVEL: o DOWN remove tudo que o UP adicionou.
 *   - NÃO remove/renomeia campos existentes. Mantém as regras de acesso atuais.
 *   - ANTI-DESVIO: `os_evidencias` segue o mesmo modelo de `ordens_servico` —
 *     o profissional só enxerga evidências de OS atribuídas a ele (regra de
 *     registro via relação `os.profissional = @request.auth.id`). Nada de
 *     telefone/endereço é gravado aqui.
 *
 * BACK-COMPAT (sincronia, garantida pela Migration 9 de seed e pela UI):
 *   - `preco_base` (legado) é mantido SINCRONIZADO = `valor_base`.
 *   - `ativo` (bool legado) é mantido SINCRONIZADO = (status === 'ativo').
 *   Esta migration só cria as COLUNAS; a sincronia de DADOS vive no seed/UI.
 */

migrate(
  (app) => {
    const ADMIN_GERENTE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';

    // Regra COFRE de os_evidencias: admin/gerente sempre; profissional SÓ as
    // evidências de OS atribuídas a ele (via relação os.profissional).
    const EVID_OWNER =
      '@request.auth.id != "" && (' +
      '@request.auth.role = "admin" || ' +
      '@request.auth.role = "gerente" || ' +
      'os.profissional = @request.auth.id)';

    // adiciona um campo só se ainda não existir (idempotência).
    function ensureField(col, field) {
      if (col.fields.getByName(field.name)) return false;
      col.fields.add(field);
      return true;
    }

    // garante um índice (por nome) na lista de índices da coleção (idempotente).
    function ensureIndex(col, indexName, sql) {
      const has = (col.indexes || []).some(function (s) {
        return String(s).indexOf(indexName) !== -1;
      });
      if (has) return false;
      col.indexes = (col.indexes || []).concat([sql]);
      return true;
    }

    // =====================================================================
    // A) servicos (servicos0000001) — catálogo RICO
    //    Leitura: qualquer autenticado · escrita: admin/gerente · delete: admin
    //    (regras existentes preservadas — não são tocadas aqui).
    // =====================================================================
    const servicos = app.findCollectionByNameOrId("servicos0000001");

    // referência estável (ex.: "svc_veic_essencial") — única via ÍNDICE PARCIAL.
    // required:false de propósito: (1) a unicidade real é o índice, não o "not null";
    // (2) back-compat — fluxos legados que criam `servicos` sem slug não quebram;
    // (3) permite o DOWN limpar o slug ("") sem violar validação. O seed (Migration 9)
    // e a UI do módulo Serviços SEMPRE preenchem o slug.
    ensureField(servicos, new TextField({ name: "slug", required: false, max: 80 }));
    ensureField(servicos, new SelectField({
      name: "categoria", required: false, maxSelect: 1,
      values: ["veicular", "residencial"],
    }));
    ensureField(servicos, new SelectField({
      name: "grupo", required: false, maxSelect: 1,
      values: ["plano", "promocao", "adicional", "avulsos", "sofa", "colchao", "outros"],
    }));
    // valor_base é a fonte canônica; preco_base (legado) é mantido = valor_base.
    ensureField(servicos, new NumberField({ name: "valor_base", required: false, min: 0 }));
    ensureField(servicos, new NumberField({ name: "valor_base_max", required: false, min: 0 }));
    ensureField(servicos, new SelectField({
      name: "tipo_valor", required: false, maxSelect: 1,
      values: ["fixo", "faixa", "variavel"],
    }));
    ensureField(servicos, new NumberField({ name: "tempo_medio_min", required: false, min: 0 }));
    ensureField(servicos, new TextField({ name: "tempo_medio_label", required: false, max: 60 }));
    // status é a fonte canônica; ativo (bool legado) é mantido = (status==='ativo').
    ensureField(servicos, new SelectField({
      name: "status", required: false, maxSelect: 1,
      values: ["ativo", "inativo"],
    }));
    ensureField(servicos, new TextField({ name: "observacao", required: false, max: 1000 }));
    // checklist_padrao: array de { id, titulo, ordem }
    ensureField(servicos, new JSONField({ name: "checklist_padrao", required: false }));
    ensureField(servicos, new TextField({ name: "orientacoes_pre", required: false, max: 1000 }));
    ensureField(servicos, new TextField({ name: "orientacoes_pos", required: false, max: 1000 }));
    // adicionais_relacionados: array de slugs (string[])
    ensureField(servicos, new JSONField({ name: "adicionais_relacionados", required: false }));

    // Unicidade do slug — ÍNDICE PARCIAL (ignora vazios) para conviver com os
    // placeholders já seedados (slug "" até a Migration 9 preenchê-los).
    ensureIndex(
      servicos,
      "idx_servicos_slug",
      "CREATE UNIQUE INDEX idx_servicos_slug ON servicos (slug) WHERE slug != ''"
    );
    app.save(servicos);

    // =====================================================================
    // B) ordens_servico (ordserv00000001) — campos ricos da OS
    //    Cofre preservado: nada de telefone/endereço aqui além do
    //    endereco_liberado efêmero já existente.
    // =====================================================================
    const ordens = app.findCollectionByNameOrId("ordserv00000001");
    // cópia IMUTÁVEL do serviço no instante da seleção (ServiceSnapshot)
    ensureField(ordens, new JSONField({ name: "service_snapshot", required: false }));
    // checklist executável (array de ChecklistExecItem)
    ensureField(ordens, new JSONField({ name: "checklist_exec", required: false }));
    // serviços extras na OS (array de ServicoAdicionalOS)
    ensureField(ordens, new JSONField({ name: "adicionais", required: false }));
    // observações técnicas do profissional (array de ObservacaoProfissional)
    // NÃO confundir com o campo texto `observacoes` já existente.
    ensureField(ordens, new JSONField({ name: "observacoes_prof", required: false }));
    // quando o relatório final foi enviado ao cliente
    ensureField(ordens, new DateField({ name: "relatorio_enviado_em", required: false }));
    app.save(ordens);

    // =====================================================================
    // C) os_evidencias (osevidenc000001) — fotos antes/durante/depois.
    //    MODELO COFRE: profissional só vê/edita evidências de OS dele.
    // =====================================================================
    const usersId = app.findCollectionByNameOrId("users").id;

    let evid = null;
    try { evid = app.findCollectionByNameOrId("osevidenc000001"); } catch (_) { evid = null; }
    if (!evid) {
      evid = new Collection({
        type: "base",
        name: "os_evidencias",
        id: "osevidenc000001",
      });
      // OS dona — cascadeDelete: apaga a evidência se a OS for apagada.
      evid.fields.add(new RelationField({
        name: "os",
        required: true,
        maxSelect: 1,
        minSelect: 1,
        collectionId: "ordserv00000001",
        cascadeDelete: true,
      }));
      // foto (1 imagem, até ~5MB).
      // SA-ALTO: protected:true — evidências NÃO são públicas. A URL só serve a
      // imagem acompanhada de um file token (gerado server-side p/ admin/dono),
      // espelhando o modelo COFRE da coleção. O frontend injeta o token na URL.
      evid.fields.add(new FileField({
        name: "foto",
        required: false,
        maxSelect: 1,
        maxSize: 5242880, // 5MB
        protected: true,
        mimeTypes: ["image/jpeg", "image/png", "image/webp", "image/gif", "image/heic", "image/heif"],
      }));
      evid.fields.add(new SelectField({
        name: "fase", required: false, maxSelect: 1,
        values: ["antes", "durante", "depois"],
      }));
      evid.fields.add(new TextField({ name: "legenda", required: false, max: 300 }));
      // vínculos OPCIONAIS a um item/observação/adicional da OS (ids livres).
      evid.fields.add(new TextField({ name: "checklist_item_id", required: false, max: 120 }));
      evid.fields.add(new TextField({ name: "observacao_id", required: false, max: 120 }));
      evid.fields.add(new TextField({ name: "adicional_id", required: false, max: 120 }));
      // quem enviou (profissional/admin) — opcional.
      evid.fields.add(new RelationField({
        name: "enviado_por",
        required: false,
        maxSelect: 1,
        minSelect: 0,
        collectionId: usersId,
        cascadeDelete: false,
      }));
      evid.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));
      evid.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));

      evid.indexes = [
        "CREATE INDEX idx_evid_os ON os_evidencias (os)",
      ];

      // ----- Regras COFRE (espelham ordens_servico) -----
      // list/view: admin/gerente OU o profissional dono da OS.
      evid.listRule = EVID_OWNER;
      evid.viewRule = EVID_OWNER;
      // create: profissional só cria evidência para uma OS dele (ou admin/gerente).
      evid.createRule = EVID_OWNER;
      // update/delete: dono (os.profissional) ou admin/gerente.
      evid.updateRule = EVID_OWNER;
      evid.deleteRule = EVID_OWNER;
      app.save(evid);
    } else {
      // Coleção já existe numa base (migrate up anterior, quando `foto` era pública):
      // ensureField não atualiza props de campo existente, então forçamos a flag
      // `protected` explicitamente p/ não deixar evidências públicas em produção.
      const fotoField = evid.fields.getByName("foto");
      if (fotoField && fotoField.protected !== true) {
        fotoField.protected = true;
        app.save(evid);
      }
    }
  },

  // ----------------------------- DOWN -----------------------------
  (app) => {
    // remove a lista de campos (por nome) de uma coleção, idempotente.
    function dropFields(collId, names) {
      try {
        const col = app.findCollectionByNameOrId(collId);
        for (let i = 0; i < names.length; i++) {
          const f = col.fields.getByName(names[i]);
          if (f) col.fields.removeById(f.id);
        }
        return col;
      } catch (_) { return null; }
    }

    // C) os_evidencias — apaga a coleção inteira.
    try { app.delete(app.findCollectionByNameOrId("osevidenc000001")); } catch (_) {}

    // B) ordens_servico — remove os campos ricos adicionados.
    const ordens = dropFields("ordserv00000001", [
      "service_snapshot", "checklist_exec", "adicionais",
      "observacoes_prof", "relatorio_enviado_em",
    ]);
    if (ordens) { try { app.save(ordens); } catch (_) {} }

    // A) servicos — remove o índice e os campos ricos adicionados.
    try {
      const servicos = app.findCollectionByNameOrId("servicos0000001");
      servicos.indexes = (servicos.indexes || []).filter(function (s) {
        return String(s).indexOf("idx_servicos_slug") === -1;
      });
      const names = [
        "slug", "categoria", "grupo", "valor_base", "valor_base_max",
        "tipo_valor", "tempo_medio_min", "tempo_medio_label", "status",
        "observacao", "checklist_padrao", "orientacoes_pre", "orientacoes_pos",
        "adicionais_relacionados",
      ];
      for (let i = 0; i < names.length; i++) {
        const f = servicos.fields.getByName(names[i]);
        if (f) servicos.fields.removeById(f.id);
      }
      app.save(servicos);
    } catch (_) {}
  }
);
