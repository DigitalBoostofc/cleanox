/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 1: estrutura de coleções (schema).
 *
 * Cria de forma reprodutível o schema do backend. NÃO depende de cliques no
 * Admin UI. Rode com `./pocketbase migrate up`.
 *
 * NOTA DE API (PocketBase v0.39 / JSVM):
 *   - Os campos DEVEM ser adicionados via `collection.fields.add(...)`.
 *     O atalho `new Collection({ fields: [...] })` é silenciosamente ignorado
 *     nesta versão (a coleção nasce só com `id`).
 *   - As regras (listRule/viewRule/updateRule) também precisam ser atribuídas
 *     por propriedade após o construtor; passá-las no construtor não persiste.
 *
 * GARANTIA ANTI-DESVIO (a regra inegociável do projeto):
 *   - Dados sensíveis do cliente (telefone, e-mail, sobrenome, endereço completo)
 *     vivem SOMENTE na coleção `clientes`, que NEGA totalmente o papel
 *     `profissional` (list/view/create/update/delete só admin/gerente).
 *   - As regras do PocketBase são a NÍVEL DE REGISTRO, não de campo. Por isso a
 *     coleção `ordens_servico` NUNCA grava telefone/e-mail/nome completo.
 *   - O endereço completo só é escrito no campo `endereco_liberado` da OS por
 *     HOOK durante `em_andamento`, e limpo em `concluida`/`cancelada`.
 *   - O telefone NUNCA é copiado para a OS, em nenhum estado.
 */

migrate(
  (app) => {
    const ADMIN_GERENTE =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';
    const ADMIN_ONLY = '@request.auth.role = "admin"';

    // =====================================================================
    // 1) users (auth) — estende a coleção auth padrão com `role` e `nome`.
    //    Os três papéis (admin, gerente, profissional) vivem aqui.
    //    O _superusers do PocketBase é só para administração da plataforma.
    // =====================================================================
    const users = app.findCollectionByNameOrId("users");

    users.fields.add(
      new SelectField({
        name: "role",
        required: true,
        maxSelect: 1,
        values: ["admin", "gerente", "profissional"],
      })
    );
    users.fields.add(new TextField({ name: "nome", required: false, max: 120 }));

    // Profissional NÃO lista usuários; só vê o próprio registro (perfil).
    users.listRule = ADMIN_GERENTE;
    users.viewRule = ADMIN_GERENTE + " || id = @request.auth.id";
    users.createRule = ADMIN_GERENTE;
    // self-update permitido; o hook impede troca de role/email por não-admin.
    users.updateRule = ADMIN_GERENTE + " || id = @request.auth.id";
    users.deleteRule = ADMIN_ONLY;
    app.save(users);

    // =====================================================================
    // 2) clientes (base) — DADO SENSÍVEL. Cofre de contato do cliente.
    //    Profissional é TOTALMENTE negado.
    // =====================================================================
    const clientes = new Collection({
      type: "base",
      name: "clientes",
      id: "clientes0000001",
    });
    clientes.fields.add(new TextField({ name: "nome", required: true, max: 80 })); // primeiro nome
    clientes.fields.add(new TextField({ name: "sobrenome", required: false, max: 80 })); // SENSÍVEL
    clientes.fields.add(new TextField({ name: "telefone", required: true, max: 30 })); // SENSÍVEL
    clientes.fields.add(new EmailField({ name: "email", required: false })); // SENSÍVEL
    clientes.fields.add(new TextField({ name: "endereco_rua", required: false, max: 160 })); // SENSÍVEL
    clientes.fields.add(new TextField({ name: "endereco_numero", required: false, max: 20 })); // SENSÍVEL
    clientes.fields.add(new TextField({ name: "endereco_complemento", required: false, max: 80 })); // SENSÍVEL
    clientes.fields.add(new TextField({ name: "endereco_bairro", required: true, max: 80 })); // seguro (vira "bairro" na OS)
    clientes.fields.add(new TextField({ name: "endereco_cidade", required: false, max: 80 }));
    clientes.fields.add(new TextField({ name: "endereco_cep", required: false, max: 12 }));
    clientes.fields.add(new BoolField({ name: "ativo" }));
    clientes.fields.add(new TextField({ name: "observacoes", required: false, max: 2000 }));
    clientes.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));
    clientes.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));
    // ----- ANTI-DESVIO: profissional nunca lê este cofre -----
    clientes.listRule = ADMIN_GERENTE;
    clientes.viewRule = ADMIN_GERENTE;
    clientes.createRule = ADMIN_GERENTE;
    clientes.updateRule = ADMIN_GERENTE;
    clientes.deleteRule = ADMIN_ONLY;
    app.save(clientes);

    // =====================================================================
    // 3) servicos (base) — catálogo. NÃO é sensível.
    //    Leitura para qualquer autenticado; escrita só admin/gerente.
    // =====================================================================
    const servicos = new Collection({
      type: "base",
      name: "servicos",
      id: "servicos0000001",
    });
    servicos.fields.add(new TextField({ name: "nome", required: true, max: 120 }));
    servicos.fields.add(new TextField({ name: "descricao", required: false, max: 500 }));
    servicos.fields.add(new NumberField({ name: "preco_base", required: false, min: 0 }));
    servicos.fields.add(new BoolField({ name: "ativo" }));
    servicos.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));
    servicos.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));
    servicos.listRule = '@request.auth.id != ""';
    servicos.viewRule = '@request.auth.id != ""';
    servicos.createRule = ADMIN_GERENTE;
    servicos.updateRule = ADMIN_GERENTE;
    servicos.deleteRule = ADMIN_ONLY;
    app.save(servicos);

    // =====================================================================
    // 4) ordens_servico (base) — "visão de job". APENAS campos seguros.
    //    Telefone/e-mail/nome completo NUNCA são gravados aqui.
    //    O profissional só vê SUAS OS (regra de registro).
    // =====================================================================
    const usersId = app.findCollectionByNameOrId("users").id;

    const ordens = new Collection({
      type: "base",
      name: "ordens_servico",
      id: "ordserv00000001",
    });
    // vínculo com o cofre — apenas o ID opaco (profissional não consegue
    // expandir/ler clientes, então isto não vaza contato).
    ordens.fields.add(
      new RelationField({
        name: "cliente",
        required: true,
        maxSelect: 1,
        minSelect: 0,
        collectionId: "clientes0000001",
        cascadeDelete: false,
      })
    );
    // ----- campos SEGUROS denormalizados (mantidos por hook) -----
    ordens.fields.add(new TextField({ name: "nome_curto", required: false, max: 90 })); // "Carlos S."
    ordens.fields.add(new TextField({ name: "bairro", required: false, max: 80 }));
    ordens.fields.add(
      new RelationField({
        name: "servico",
        required: false,
        maxSelect: 1,
        minSelect: 0,
        collectionId: "servicos0000001",
        cascadeDelete: false,
      })
    );
    ordens.fields.add(new TextField({ name: "tipo_servico_nome", required: false, max: 120 })); // snapshot
    ordens.fields.add(new DateField({ name: "data_hora", required: true }));
    ordens.fields.add(
      new RelationField({
        name: "profissional",
        required: false,
        maxSelect: 1,
        minSelect: 0,
        collectionId: usersId,
        cascadeDelete: false,
      })
    );
    ordens.fields.add(
      new SelectField({
        name: "status",
        required: true,
        maxSelect: 1,
        values: ["agendada", "atribuida", "em_andamento", "concluida", "cancelada"],
      })
    );
    ordens.fields.add(new NumberField({ name: "valor_servico", required: false, min: 0 }));
    // ----- endereço efêmero: só preenchido em em_andamento, por hook -----
    ordens.fields.add(new TextField({ name: "endereco_liberado", required: false, max: 400 }));
    // ----- pagamento (registrado pelo profissional na maquininha) -----
    ordens.fields.add(new NumberField({ name: "valor_pago", required: false, min: 0 }));
    ordens.fields.add(
      new SelectField({
        name: "forma_pagamento",
        required: false,
        maxSelect: 1,
        values: ["debito", "credito", "pix_maquininha"],
      })
    );
    // ----- repasse ao profissional (marcado manualmente por admin) -----
    ordens.fields.add(
      new SelectField({
        name: "repasse_status",
        required: false,
        maxSelect: 1,
        values: ["pendente", "pago"],
      })
    );
    ordens.fields.add(new NumberField({ name: "repasse_valor", required: false, min: 0 }));
    ordens.fields.add(new TextField({ name: "observacoes", required: false, max: 2000 }));
    ordens.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }));
    ordens.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));

    ordens.indexes = [
      "CREATE INDEX idx_os_status ON ordens_servico (status)",
      "CREATE INDEX idx_os_profissional ON ordens_servico (profissional)",
      "CREATE INDEX idx_os_data ON ordens_servico (data_hora)",
    ];

    // ----- Regras de registro -----
    // admin/gerente veem tudo; profissional vê SÓ as OS atribuídas a ele.
    ordens.listRule = ADMIN_GERENTE + " || profissional = @request.auth.id";
    ordens.viewRule = ADMIN_GERENTE + " || profissional = @request.auth.id";
    // Só admin/gerente criam OS (atribuem cliente/profissional/valor).
    ordens.createRule = ADMIN_GERENTE;
    // admin/gerente OU o profissional atribuído podem dar update; o hook de
    // request trava os campos que o profissional pode tocar (ver pb_hooks).
    ordens.updateRule = ADMIN_GERENTE + " || profissional = @request.auth.id";
    ordens.deleteRule = ADMIN_GERENTE;
    app.save(ordens);
  },

  // ----------------------------- DOWN -----------------------------
  (app) => {
    try { app.delete(app.findCollectionByNameOrId("ordserv00000001")); } catch (_) {}
    try { app.delete(app.findCollectionByNameOrId("servicos0000001")); } catch (_) {}
    try { app.delete(app.findCollectionByNameOrId("clientes0000001")); } catch (_) {}
    try {
      const users = app.findCollectionByNameOrId("users");
      const role = users.fields.getByName("role");
      if (role) users.fields.removeById(role.id);
      const nome = users.fields.getByName("nome");
      if (nome) users.fields.removeById(nome.id);
      users.listRule = null;
      users.viewRule = "id = @request.auth.id";
      users.createRule = "";
      users.updateRule = "id = @request.auth.id";
      users.deleteRule = "id = @request.auth.id";
      app.save(users);
    } catch (_) {}
  }
);
