/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 2 PRODUÇÃO: apenas catálogo de serviços.
 * NÃO cria clientes, OS, nem usuários de dev.
 * Preços são PLACEHOLDER (gate G-03 em aberto).
 * Idempotente: pula criação se o serviço já existir pelo nome.
 */

migrate(
  (app) => {
    const servicosCol = app.findCollectionByNameOrId("servicos");

    const catalog = [
      { nome: "Sofá 2 lugares",   descricao: "Higienização de sofá de 2 lugares",  preco: 180 },
      { nome: "Sofá 3 lugares",   descricao: "Higienização de sofá de 3 lugares",  preco: 240 },
      { nome: "Poltrona",         descricao: "Higienização de poltrona",            preco: 90  },
      { nome: "Colchão solteiro", descricao: "Higienização de colchão de solteiro", preco: 120 },
      { nome: "Colchão casal",    descricao: "Higienização de colchão de casal",    preco: 160 },
      { nome: "Cadeira",          descricao: "Higienização de cadeira estofada",    preco: 40  },
      { nome: "Tapete",           descricao: "Higienização de tapete (m²)",         preco: 70  },
    ];

    for (const item of catalog) {
      // Idempotência: só cria se não existir
      try {
        app.findFirstRecordByData("servicos", "nome", item.nome);
        // já existe — pula
      } catch (_) {
        const r = new Record(servicosCol);
        r.set("nome", item.nome);
        r.set("descricao", item.descricao);
        r.set("preco_base", item.preco);
        r.set("ativo", true);
        app.save(r);
      }
    }
  },

  // DOWN: remove todos os serviços do catálogo (só os do seed)
  (app) => {
    const names = [
      "Sofá 2 lugares", "Sofá 3 lugares", "Poltrona",
      "Colchão solteiro", "Colchão casal", "Cadeira", "Tapete",
    ];
    for (const nome of names) {
      try {
        const r = app.findFirstRecordByData("servicos", "nome", nome);
        app.delete(r);
      } catch (_) {}
    }
  }
);
