/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 7: área de atuação e disponibilidade por profissional.
 *
 * Adiciona:
 *   - Campo `endereco_estado` (UF) em `clientes` — para autofill de CEP e
 *     pré-seleção pela área de atuação.
 *   - Coleção `config_atuacao` (singleton) — estado e cidades/bairros de cobertura.
 *   - Coleção `disponibilidade` — grade de horários por profissional.
 *
 * Regras de acesso (ambas as coleções):
 *   list/view/create/update = admin ou gerente; delete = somente admin.
 *   Profissional: totalmente negado (não é config operacional dele).
 *
 * Unicidade de disponibilidade por profissional é garantida por UNIQUE INDEX.
 * O app deve sempre fazer upsert (buscar por profissional antes de criar).
 */

migrate(
  (app) => {
    const ADMIN_GERENTE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';
    const ADMIN_ONLY = '@request.auth.role = "admin"';

    // =========================================================================
    // 1) clientes — campo `endereco_estado` (UF, 2 letras, opcional)
    //    Usado para autofill quando o frontend consulta o CEP e para pré-filtrar
    //    clientes pela área de atuação configurada em config_atuacao.
    // =========================================================================
    const clientes = app.findCollectionByNameOrId("clientes0000001");
    clientes.fields.add(
      new TextField({ name: "endereco_estado", required: false, max: 2 })
    );
    app.save(clientes);

    // =========================================================================
    // 2) config_atuacao (base, singleton) — área geográfica de cobertura.
    //    Cria 1 registro vazio agora; o app edita via PATCH.
    //    Profissional não lê — é dado administrativo.
    // =========================================================================
    const atuacao = new Collection({
      type: "base",
      name: "config_atuacao",
      id:   "config_atuaca01",
    });
    // `estado`: UF em que a empresa opera (ex.: "SP")
    atuacao.fields.add(
      new TextField({ name: "estado", required: false, max: 2 })
    );
    // `cidades`: array de objetos { nome: string, principal: boolean, bairros: string[] }
    atuacao.fields.add(
      new JSONField({ name: "cidades", required: false })
    );
    atuacao.fields.add(new AutodateField({ name: "created", onCreate: true,  onUpdate: false }));
    atuacao.fields.add(new AutodateField({ name: "updated", onCreate: true,  onUpdate: true  }));

    atuacao.listRule   = ADMIN_GERENTE;
    atuacao.viewRule   = ADMIN_GERENTE;
    atuacao.createRule = ADMIN_GERENTE;
    atuacao.updateRule = ADMIN_GERENTE;
    atuacao.deleteRule = ADMIN_ONLY;
    app.save(atuacao);

    // Registro singleton vazio — frontend atualiza via PATCH /records/:id
    const atuacaoRecord = new Record(atuacao);
    atuacaoRecord.set("estado",  "");
    atuacaoRecord.set("cidades", []);
    app.save(atuacaoRecord);

    // =========================================================================
    // 3) disponibilidade (base) — grade de horários por profissional.
    //    Um registro por profissional (garantido por UNIQUE INDEX).
    //    O app sempre faz upsert: busca por `profissional`, cria se não existir.
    // =========================================================================
    const usersId = app.findCollectionByNameOrId("users").id;

    const disp = new Collection({
      type: "base",
      name: "disponibilidade",
      id:   "disponibilid001",
    });
    disp.fields.add(
      new RelationField({
        name:          "profissional",
        required:      true,
        maxSelect:     1,
        minSelect:     1,
        collectionId:  usersId,
        cascadeDelete: false,
      })
    );
    // Duração padrão de um serviço em minutos (default: 60).
    // O app deve gravar 60 na criação se o usuário não informar outro valor.
    disp.fields.add(
      new NumberField({ name: "duracao_min", required: false, min: 1 })
    );
    // `dias`: config por dia da semana 0..6 (0=domingo).
    // Shape: array de 7 objetos { ativo: boolean, inicio: "HH:MM", fim: "HH:MM" }
    // indexado pela posição (0=dom, 1=seg, …, 6=sáb).
    disp.fields.add(
      new JSONField({ name: "dias", required: false })
    );
    disp.fields.add(new AutodateField({ name: "created", onCreate: true,  onUpdate: false }));
    disp.fields.add(new AutodateField({ name: "updated", onCreate: true,  onUpdate: true  }));

    // Garante 1 registro por profissional a nível de banco.
    disp.indexes = [
      "CREATE UNIQUE INDEX idx_disp_profissional ON disponibilidade (profissional)",
    ];

    disp.listRule   = ADMIN_GERENTE;
    disp.viewRule   = ADMIN_GERENTE;
    disp.createRule = ADMIN_GERENTE;
    disp.updateRule = ADMIN_GERENTE;
    disp.deleteRule = ADMIN_ONLY;
    app.save(disp);
  },

  // ── DOWN ────────────────────────────────────────────────────────────────────
  (app) => {
    // Remove disponibilidade e config_atuacao (dependências entre si não há)
    try { app.delete(app.findCollectionByNameOrId("disponibilid001")); } catch (_) {}
    try { app.delete(app.findCollectionByNameOrId("config_atuaca01")); } catch (_) {}

    // Remove endereco_estado de clientes
    try {
      const clientes = app.findCollectionByNameOrId("clientes0000001");
      const f = clientes.fields.getByName("endereco_estado");
      if (f) clientes.fields.removeById(f.id);
      app.save(clientes);
    } catch (_) {}
  }
);
