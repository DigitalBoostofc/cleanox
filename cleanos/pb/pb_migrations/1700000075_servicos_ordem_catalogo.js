/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — ordem geral dos serviços no catálogo operacional.
 *
 * A ordem é contextual ao par categoria/grupo e alimenta os seletores de OS.
 * Registros existentes recebem posições espaçadas de 10, preservando qualquer
 * ordem positiva que já exista em reaplicações defensivas.
 */
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("servicos");
    if (!collection.fields.getByName("ordem")) {
      collection.fields.add(
        new NumberField({ name: "ordem", required: false, min: 0 }),
      );
      app.save(collection);
    }

    const records = [];
    for (let offset = 0; ; offset += 500) {
      const page = app.findRecordsByFilter(
        "servicos",
        "",
        "categoria,grupo,nome,id",
        500,
        offset,
      );
      records.push(...page);
      if (page.length < 500) break;
    }
    const maxByGroup = {};
    for (const record of records) {
      const key = `${String(record.get("categoria") || "")}\u0000${String(record.get("grupo") || "")}`;
      const ordem = Number(record.get("ordem") || 0);
      if (ordem > (maxByGroup[key] || 0)) maxByGroup[key] = ordem;
    }
    for (const record of records) {
      if (Number(record.get("ordem") || 0) > 0) continue;
      const key = `${String(record.get("categoria") || "")}\u0000${String(record.get("grupo") || "")}`;
      const ordem = (maxByGroup[key] || 0) + 10;
      record.set("ordem", ordem);
      app.save(record);
      maxByGroup[key] = ordem;
    }

    // Profissionais já enxergam o catálogo ativo; liberar somente leitura da
    // árvore permite aplicar a mesma ordem no seletor de serviço extra.
    const taxonomia = app.findCollectionByNameOrId("servicos_taxonomia");
    taxonomia.listRule = '@request.auth.id != ""';
    taxonomia.viewRule = '@request.auth.id != ""';
    app.save(taxonomia);
  },
  (app) => {
    const cofre =
      '@request.auth.role = "admin" || @request.auth.role = "gerente"';
    const taxonomia = app.findCollectionByNameOrId("servicos_taxonomia");
    taxonomia.listRule = cofre;
    taxonomia.viewRule = cofre;
    app.save(taxonomia);

    const collection = app.findCollectionByNameOrId("servicos");
    const field = collection.fields.getByName("ordem");
    if (field) {
      collection.fields.removeById(field.id);
      app.save(collection);
    }
  },
);
