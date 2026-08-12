/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — catálogo personalizável da Vitrine.
 *
 * Aditivo e retrocompatível:
 * - serviços recebem copy/layout/preço/ordem exclusivamente comerciais;
 * - vitrine_midia pode pertencer a um serviço e representar capa, galeria ou
 *   um dos lados de um par antes/depois;
 * - chaves globais antigas (hero, categoria_*) continuam válidas.
 */
migrate((app) => {
  const servicos = app.findCollectionByNameOrId("servicos");

  if (!servicos.fields.getByName("vitrine_layout")) {
    servicos.fields.add(
      new SelectField({
        name: "vitrine_layout",
        required: false,
        maxSelect: 1,
        values: ["destaque", "fotografico", "antes_depois", "compacto"],
      }),
    );
  }
  if (!servicos.fields.getByName("vitrine_titulo")) {
    servicos.fields.add(
      new TextField({ name: "vitrine_titulo", required: false, max: 160 }),
    );
  }
  if (!servicos.fields.getByName("vitrine_descricao")) {
    servicos.fields.add(
      new TextField({ name: "vitrine_descricao", required: false, max: 500 }),
    );
  }
  if (!servicos.fields.getByName("vitrine_badge")) {
    servicos.fields.add(
      new TextField({ name: "vitrine_badge", required: false, max: 60 }),
    );
  }
  if (!servicos.fields.getByName("vitrine_cta")) {
    servicos.fields.add(
      new TextField({ name: "vitrine_cta", required: false, max: 60 }),
    );
  }
  if (!servicos.fields.getByName("vitrine_preco_modo")) {
    servicos.fields.add(
      new SelectField({
        name: "vitrine_preco_modo",
        required: false,
        maxSelect: 1,
        values: ["valor", "a_partir_de", "sob_avaliacao", "ocultar"],
      }),
    );
  }
  if (!servicos.fields.getByName("vitrine_ordem")) {
    servicos.fields.add(
      new NumberField({ name: "vitrine_ordem", required: false, min: 0 }),
    );
  }
  app.save(servicos);

  const midia = app.findCollectionByNameOrId("vitrine_midia");
  if (!midia.fields.getByName("servico")) {
    midia.fields.add(
      new RelationField({
        name: "servico",
        required: false,
        maxSelect: 1,
        minSelect: 0,
        collectionId: servicos.id,
        cascadeDelete: false,
      }),
    );
  }
  if (!midia.fields.getByName("papel")) {
    midia.fields.add(
      new SelectField({
        name: "papel",
        required: false,
        maxSelect: 1,
        values: ["capa", "galeria", "antes", "depois"],
      }),
    );
  }
  if (!midia.fields.getByName("par_id")) {
    midia.fields.add(
      new TextField({ name: "par_id", required: false, max: 80 }),
    );
  }
  if (!midia.fields.getByName("legenda")) {
    midia.fields.add(
      new TextField({ name: "legenda", required: false, max: 240 }),
    );
  }
  if (!midia.fields.getByName("foco_x")) {
    midia.fields.add(
      new NumberField({ name: "foco_x", required: false, min: 0, max: 100 }),
    );
  }
  if (!midia.fields.getByName("foco_y")) {
    midia.fields.add(
      new NumberField({ name: "foco_y", required: false, min: 0, max: 100 }),
    );
  }
  app.save(midia);
}, (app) => {
  function removeFields(collectionName, names) {
    const collection = app.findCollectionByNameOrId(collectionName);
    for (const name of names) {
      const field = collection.fields.getByName(name);
      if (field) collection.fields.removeById(field.id);
    }
    app.save(collection);
  }

  removeFields("vitrine_midia", [
    "servico",
    "papel",
    "par_id",
    "legenda",
    "foco_x",
    "foco_y",
  ]);
  removeFields("servicos", [
    "vitrine_layout",
    "vitrine_titulo",
    "vitrine_descricao",
    "vitrine_badge",
    "vitrine_cta",
    "vitrine_preco_modo",
    "vitrine_ordem",
  ]);
});
