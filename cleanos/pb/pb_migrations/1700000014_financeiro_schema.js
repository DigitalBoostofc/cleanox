/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 14: schema das coleções do módulo Financeiro.
 *
 * Cria 4 coleções: fin_contas, fin_categorias, fin_lancamentos, fin_limites.
 * IDEMPOTENTE: só cria se ainda não existir (guard try/findCollectionByNameOrId).
 * REVERSÍVEL: DOWN apaga em ordem inversa de FK.
 * COFRE_FIN: profissional nunca acessa fin_* (só admin/gerente).
 */

migrate(
  (app) => {
    const COFRE_FIN = '@request.auth.role = "admin" || @request.auth.role = "gerente"';

    function tryFind(id) {
      try { return app.findCollectionByNameOrId(id); } catch (_) { return null; }
    }

    // ── A) fin_contas (fincontas000001) ───────────────────────────────────────
    if (!tryFind("fincontas000001")) {
      const c = new Collection({ type: "base", name: "fin_contas", id: "fincontas000001" });
      c.fields.add(new TextField({ name: "nome", required: true, max: 100 }));
      c.fields.add(new SelectField({
        name: "tipo", required: true, maxSelect: 1,
        values: ["carteira", "banco", "cartao", "caixa"],
      }));
      c.fields.add(new NumberField({ name: "saldo_inicial", required: false }));
      c.fields.add(new NumberField({ name: "saldo_atual",   required: false }));
      c.fields.add(new BoolField({ name: "ativo" }));
      c.fields.add(new TextField({ name: "cor", required: false, max: 20 }));
      c.fields.add(new TextField({ name: "icone", required: false, max: 60 }));
      c.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));
      c.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));
      c.listRule   = COFRE_FIN;
      c.viewRule   = COFRE_FIN;
      c.createRule = COFRE_FIN;
      c.updateRule = COFRE_FIN;
      c.deleteRule = COFRE_FIN;
      app.save(c);
    }

    // ── B) fin_categorias (fincateg0000001) ───────────────────────────────────
    if (!tryFind("fincateg0000001")) {
      const c = new Collection({ type: "base", name: "fin_categorias", id: "fincateg0000001" });
      c.fields.add(new TextField({ name: "nome", required: true, max: 100 }));
      c.fields.add(new SelectField({
        name: "tipo", required: true, maxSelect: 1,
        values: ["receita", "despesa"],
      }));
      c.fields.add(new TextField({ name: "icone", required: false, max: 60 }));
      c.fields.add(new TextField({ name: "cor", required: false, max: 20 }));
      // TextField (não RelationField) para evitar FK circular em migração/seed
      c.fields.add(new TextField({ name: "parent_id", required: false, max: 50 }));
      c.fields.add(new BoolField({ name: "arquivada" }));
      c.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));
      c.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));
      c.listRule   = COFRE_FIN;
      c.viewRule   = COFRE_FIN;
      c.createRule = COFRE_FIN;
      c.updateRule = COFRE_FIN;
      c.deleteRule = COFRE_FIN;
      app.save(c);
    }

    // ── C) fin_lancamentos (finlancament001) ──────────────────────────────────
    if (!tryFind("finlancament001")) {
      const c = new Collection({ type: "base", name: "fin_lancamentos", id: "finlancament001" });
      c.fields.add(new SelectField({
        name: "tipo", required: true, maxSelect: 1,
        values: ["receita", "despesa"],
      }));
      c.fields.add(new TextField({ name: "descricao", required: true, max: 500 }));
      c.fields.add(new RelationField({
        name: "categoria_id", required: true, maxSelect: 1,
        collectionId: "fincateg0000001", cascadeDelete: false,
      }));
      c.fields.add(new RelationField({
        name: "subcategoria_id", required: false, maxSelect: 1,
        collectionId: "fincateg0000001", cascadeDelete: false,
      }));
      c.fields.add(new NumberField({ name: "valor", required: true, min: 0 }));
      c.fields.add(new RelationField({
        name: "conta_id", required: true, maxSelect: 1,
        collectionId: "fincontas000001", cascadeDelete: false,
      }));
      c.fields.add(new DateField({ name: "data", required: true }));
      c.fields.add(new DateField({ name: "vencimento", required: false }));
      c.fields.add(new SelectField({
        name: "status", required: true, maxSelect: 1,
        values: ["pago", "pendente", "previsto", "em_atraso"],
      }));
      c.fields.add(new SelectField({
        name: "recorrencia", required: true, maxSelect: 1,
        values: ["unica", "fixa", "recorrente", "parcelada"],
      }));
      c.fields.add(new NumberField({ name: "parcela_atual", required: false, min: 1 }));
      c.fields.add(new NumberField({ name: "parcelas_total", required: false, min: 1 }));
      c.fields.add(new SelectField({
        name: "origem", required: true, maxSelect: 1,
        values: ["manual", "via_os"],
      }));
      // Campos denormalizados da OS (TextField, não RelationField — evita cascade)
      c.fields.add(new TextField({ name: "os_id", required: false, max: 15 }));
      c.fields.add(new TextField({ name: "os_numero", required: false, max: 20 }));
      c.fields.add(new TextField({ name: "cliente_nome", required: false, max: 100 }));
      c.fields.add(new TextField({ name: "servico_nome", required: false, max: 200 }));
      c.fields.add(new TextField({ name: "forma_pagamento", required: false, max: 100 }));
      c.fields.add(new TextField({ name: "observacao", required: false, max: 1000 }));
      c.fields.add(new JSONField({ name: "tags", required: false }));
      c.fields.add(new JSONField({ name: "anexos", required: false }));
      c.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));
      c.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));
      c.indexes = [
        "CREATE INDEX idx_finlanc_data   ON fin_lancamentos (data)",
        "CREATE INDEX idx_finlanc_status ON fin_lancamentos (status)",
        "CREATE INDEX idx_finlanc_conta  ON fin_lancamentos (conta_id)",
        "CREATE INDEX idx_finlanc_os_id  ON fin_lancamentos (os_id)",
      ];
      c.listRule   = COFRE_FIN;
      c.viewRule   = COFRE_FIN;
      c.createRule = COFRE_FIN;
      c.updateRule = COFRE_FIN;
      c.deleteRule = COFRE_FIN;
      app.save(c);
    }

    // ── D) fin_limites (finlimites00001) ──────────────────────────────────────
    if (!tryFind("finlimites00001")) {
      const c = new Collection({ type: "base", name: "fin_limites", id: "finlimites00001" });
      c.fields.add(new RelationField({
        name: "categoria_id", required: true, maxSelect: 1,
        collectionId: "fincateg0000001", cascadeDelete: true,
      }));
      c.fields.add(new NumberField({ name: "limite", required: true, min: 0 }));
      c.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));
      c.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));
      c.listRule   = COFRE_FIN;
      c.viewRule   = COFRE_FIN;
      c.createRule = COFRE_FIN;
      c.updateRule = COFRE_FIN;
      c.deleteRule = COFRE_FIN;
      app.save(c);
    }
  },

  // ── DOWN — apaga em ordem inversa de FK ───────────────────────────────────
  (app) => {
    for (const id of ["finlimites00001", "finlancament001", "fincateg0000001", "fincontas000001"]) {
      try { app.delete(app.findCollectionByNameOrId(id)); } catch (_) {}
    }
  }
);
