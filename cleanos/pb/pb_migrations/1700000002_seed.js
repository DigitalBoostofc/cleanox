/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 2: seed/bootstrap para testes.
 *
 * Cria: 1 _superuser (admin UI), 1 admin, 1 gerente, 2 profissionais,
 * catálogo de serviços (preços PLACEHOLDER), clientes e OS cobrindo TODOS
 * os estados (agendada, atribuida, em_andamento, concluida, cancelada).
 *
 * Os campos denormalizados (nome_curto/bairro/endereco_liberado/tipo_servico_nome)
 * são gravados EXPLICITAMENTE aqui — o CLI `migrate` não garante o carregamento
 * dos pb_hooks, então não dependemos deles no seed. Em produção (serve), os
 * hooks mantêm esses campos sincronizados automaticamente.
 *
 * Senhas de teste: ver README. NÃO usar em produção.
 */

migrate(
  (app) => {
    // datas relativas a "hoje" (necessário para o teste de day-check do Iniciar)
    const now = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    const ymd = (d) =>
      `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
    // Usa hora BRT (UTC-3) para que "today" coincida com o day-check do hook,
    // que também compara datas em BRT. Sem isso, entre 00:00 e 03:00 UTC o seed
    // gravaria data_hora com o dia UTC seguinte e o guard bloquearia o Iniciar.
    const nowBRT = new Date(now.getTime() - 3 * 3600 * 1000);
    const today = ymd(nowBRT);
    const future = ymd(new Date(now.getTime() + 3 * 86400000));
    const past = ymd(new Date(now.getTime() - 5 * 86400000));
    const dt = (day, hm) => `${day} ${hm}:00:00.000Z`;

    // ---------------- _superuser (acesso ao Admin UI p/ devops) ----------------
    const superusers = app.findCollectionByNameOrId("_superusers");
    const su = new Record(superusers);
    su.set("email", "super@cleanox.local");
    su.set("password", "cleanox-super-123");
    app.save(su);

    // ---------------- usuários de negócio ----------------
    const usersCol = app.findCollectionByNameOrId("users");
    function mkUser(email, nome, role) {
      const r = new Record(usersCol);
      r.set("email", email);
      r.set("password", "cleanox123");
      r.set("passwordConfirm", "cleanox123");
      r.set("verified", true);
      r.set("emailVisibility", true); // F-005: admin deve ver email de todos os usuários
      r.set("name", nome);
      r.set("nome", nome);
      r.set("role", role);
      app.save(r);
      return r;
    }
    const admin = mkUser("admin@cleanox.local", "Ana Admin", "admin");
    const gerente = mkUser("gerente@cleanox.local", "Gabriel Gerente", "gerente");
    const prof1 = mkUser("pedro@cleanox.local", "Pedro Profissional", "profissional");
    const prof2 = mkUser("lucas@cleanox.local", "Lucas Profissional", "profissional");

    // ---------------- catálogo de serviços (PREÇOS PLACEHOLDER) ----------------
    const servicosCol = app.findCollectionByNameOrId("servicos");
    // F-001: idempotente por nome — catalog_prod.js pode ter rodado antes (mesmo prefixo).
    function mkServico(nome, descricao, preco) {
      try {
        return app.findFirstRecordByData("servicos", "nome", nome);
      } catch (_) { /* não existe ainda — cria */ }
      const r = new Record(servicosCol);
      r.set("nome", nome);
      r.set("descricao", descricao);
      r.set("preco_base", preco); // PLACEHOLDER — preço real é gate de negócio G-03
      r.set("ativo", true);
      app.save(r);
      return r;
    }
    const sofa2 = mkServico("Sofá 2 lugares", "Higienização de sofá de 2 lugares", 180);
    const sofa3 = mkServico("Sofá 3 lugares", "Higienização de sofá de 3 lugares", 240);
    const poltrona = mkServico("Poltrona", "Higienização de poltrona", 90);
    mkServico("Colchão solteiro", "Higienização de colchão de solteiro", 120);
    const colchaoCasal = mkServico("Colchão casal", "Higienização de colchão de casal", 160);
    mkServico("Cadeira", "Higienização de cadeira estofada", 40);
    const tapete = mkServico("Tapete", "Higienização de tapete (m²)", 70);

    // ---------------- clientes (COFRE — dado sensível) ----------------
    const clientesCol = app.findCollectionByNameOrId("clientes");
    function mkCliente(o) {
      const r = new Record(clientesCol);
      r.set("nome", o.nome);
      r.set("sobrenome", o.sobrenome);
      r.set("telefone", o.telefone);
      r.set("email", o.email || "");
      r.set("endereco_rua", o.rua);
      r.set("endereco_numero", o.numero);
      r.set("endereco_complemento", o.complemento || "");
      r.set("endereco_bairro", o.bairro);
      r.set("endereco_cidade", o.cidade);
      r.set("endereco_cep", o.cep);
      r.set("ativo", true);
      app.save(r);
      return r;
    }
    const carlos = mkCliente({
      nome: "Carlos", sobrenome: "Silva", telefone: "11999990001",
      email: "carlos.silva@email.com", rua: "Rua das Acácias", numero: "100",
      complemento: "Casa", bairro: "Centro", cidade: "São Paulo", cep: "01001-000",
    });
    const maria = mkCliente({
      nome: "Maria", sobrenome: "Souza", telefone: "11999990002",
      email: "maria.souza@email.com", rua: "Av. Paulista", numero: "2000",
      complemento: "Apto 121", bairro: "Jardins", cidade: "São Paulo", cep: "01310-100",
    });
    const joao = mkCliente({
      nome: "João", sobrenome: "Pereira", telefone: "11999990003",
      email: "joao.pereira@email.com", rua: "Rua das Flores", numero: "123",
      complemento: "Apto 45", bairro: "Boa Vista", cidade: "São Paulo", cep: "02020-000",
    });

    // helper p/ "Carlos S." (sem expor sobrenome inteiro)
    const sn = (nome, sobr) =>
      `${nome} ${String(sobr).charAt(0).toUpperCase()}.`;
    // helper p/ endereço completo (mesmo formato do hook buildEndereco)
    const endereco = (c) =>
      `${c.get("endereco_rua")}, ${c.get("endereco_numero")} - ${c.get(
        "endereco_complemento"
      )} - ${c.get("endereco_bairro")} - ${c.get("endereco_cidade")} - CEP ${c.get(
        "endereco_cep"
      )}`;

    // ---------------- Ordens de Serviço (TODOS os estados) ----------------
    const osCol = app.findCollectionByNameOrId("ordens_servico");
    function mkOS(o) {
      const r = new Record(osCol);
      r.set("cliente", o.cliente.id);
      r.set("nome_curto", sn(o.cliente.get("nome"), o.cliente.get("sobrenome")));
      r.set("bairro", o.cliente.get("endereco_bairro"));
      r.set("servico", o.servico.id);
      r.set("tipo_servico_nome", o.servico.get("nome"));
      r.set("data_hora", o.data_hora);
      if (o.profissional) r.set("profissional", o.profissional.id);
      r.set("status", o.status);
      r.set("valor_servico", o.valor_servico);
      r.set("endereco_liberado", o.endereco_liberado || "");
      if (o.valor_pago) r.set("valor_pago", o.valor_pago);
      if (o.forma_pagamento) r.set("forma_pagamento", o.forma_pagamento);
      if (o.repasse_status) r.set("repasse_status", o.repasse_status);
      if (o.repasse_valor) r.set("repasse_valor", o.repasse_valor);
      app.save(r);
      return r;
    }

    // 1) agendada — sem profissional, data futura
    mkOS({
      cliente: carlos, servico: sofa3, data_hora: dt(future, "10"),
      status: "agendada", valor_servico: 240,
    });

    // 2) atribuida — prof1, data HOJE (permite o teste de Iniciar via API)
    mkOS({
      cliente: maria, servico: poltrona, data_hora: dt(today, "14"),
      profissional: prof1, status: "atribuida", valor_servico: 90,
    });

    // 3) em_andamento — prof1, HOJE, endereço LIBERADO
    mkOS({
      cliente: joao, servico: colchaoCasal, data_hora: dt(today, "09"),
      profissional: prof1, status: "em_andamento", valor_servico: 160,
      endereco_liberado: endereco(joao),
    });

    // 4) concluida — prof2, passado, pagamento registrado, repasse pendente
    mkOS({
      cliente: carlos, servico: sofa2, data_hora: dt(past, "16"),
      profissional: prof2, status: "concluida", valor_servico: 180,
      valor_pago: 180, forma_pagamento: "credito",
      repasse_status: "pendente", repasse_valor: 90,
    });

    // 5) cancelada — prof2
    mkOS({
      cliente: maria, servico: tapete, data_hora: dt(past, "11"),
      profissional: prof2, status: "cancelada", valor_servico: 70,
    });
  },

  // ----------------------------- DOWN -----------------------------
  (app) => {
    const delAll = (col) => {
      try {
        const recs = app.findAllRecords(col);
        for (let i = 0; i < recs.length; i++) app.delete(recs[i]);
      } catch (_) {}
    };
    delAll("ordens_servico");
    delAll("clientes");
    delAll("servicos");
    // usuários de seed
    try {
      const emails = [
        "admin@cleanox.local",
        "gerente@cleanox.local",
        "pedro@cleanox.local",
        "lucas@cleanox.local",
      ];
      for (const em of emails) {
        try {
          app.delete(app.findFirstRecordByData("users", "email", em));
        } catch (_) {}
      }
      try {
        app.delete(
          app.findFirstRecordByData("_superusers", "email", "super@cleanox.local")
        );
      } catch (_) {}
    } catch (_) {}
  }
);
