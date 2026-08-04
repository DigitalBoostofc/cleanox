/// 1700000051_fin_series.js
///
/// Despesas/receitas fixas como CONTRATO (série), não só cópias soltas.
/// - Coleção `fin_series` (regra ativa|pausada|encerrada, data fim, template)
/// - `fin_lancamentos.serie_id` liga cada ocorrência à série
/// - Backfill: agrupa fixa/recorrente legadas pela chave soft e cria séries
///
/// COFRE_FIN: só admin/gerente.
migrate((app) => {
  const COFRE_FIN =
    '@request.auth.role = "admin" || @request.auth.role = "gerente"';

  function tryFind(id) {
    try {
      return app.findCollectionByNameOrId(id);
    } catch (_) {
      return null;
    }
  }

  // ── A) fin_series ─────────────────────────────────────────────────────
  if (!tryFind("finseries0000001")) {
    const c = new Collection({
      type: "base",
      name: "fin_series",
      id: "finseries0000001",
    });
    c.fields.add(
      new SelectField({
        name: "tipo",
        required: true,
        maxSelect: 1,
        values: ["receita", "despesa"],
      }),
    );
    c.fields.add(new TextField({ name: "descricao", required: true, max: 500 }));
    c.fields.add(new TextField({ name: "categoria_id", required: true, max: 50 }));
    c.fields.add(
      new TextField({ name: "subcategoria_id", required: false, max: 50 }),
    );
    c.fields.add(new NumberField({ name: "valor", required: true, min: 0 }));
    c.fields.add(new TextField({ name: "conta_id", required: true, max: 50 }));
    c.fields.add(
      new SelectField({
        name: "recorrencia",
        required: true,
        maxSelect: 1,
        values: ["fixa", "recorrente"],
      }),
    );
    c.fields.add(
      new SelectField({
        name: "frequencia",
        required: false,
        maxSelect: 1,
        values: [
          "diario",
          "semanal",
          "quinzenal",
          "mensal",
          "bimestral",
          "trimestral",
          "semestral",
          "anual",
        ],
      }),
    );
    c.fields.add(
      new SelectField({
        name: "status",
        required: true,
        maxSelect: 1,
        values: ["ativa", "pausada", "encerrada"],
      }),
    );
    c.fields.add(new DateField({ name: "data_inicio", required: true }));
    c.fields.add(new DateField({ name: "data_fim", required: false }));
    c.fields.add(
      new TextField({ name: "forma_pagamento", required: false, max: 100 }),
    );
    c.fields.add(
      new TextField({ name: "observacao", required: false, max: 1000 }),
    );
    c.fields.add(new JSONField({ name: "tags", required: false }));
    c.fields.add(
      new AutodateField({ name: "created", onCreate: true, onUpdate: false }),
    );
    c.fields.add(
      new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
    );
    c.indexes = [
      "CREATE INDEX idx_finseries_status ON fin_series (status)",
      "CREATE INDEX idx_finseries_conta ON fin_series (conta_id)",
    ];
    c.listRule = COFRE_FIN;
    c.viewRule = COFRE_FIN;
    c.createRule = COFRE_FIN;
    c.updateRule = COFRE_FIN;
    c.deleteRule = COFRE_FIN;
    app.save(c);
  }

  // ── B) fin_lancamentos.serie_id ───────────────────────────────────────
  const lanc = app.findCollectionByNameOrId("fin_lancamentos");
  if (!lanc.fields.getByName("serie_id")) {
    lanc.fields.add(
      new TextField({ name: "serie_id", required: false, max: 50 }),
    );
    try {
      lanc.indexes.push(
        "CREATE INDEX idx_finlanc_serie ON fin_lancamentos (serie_id)",
      );
    } catch (_) {
      /* índices podem já existir em builds divergentes */
    }
    app.save(lanc);
  }

  // ── C) Backfill: agrupa fixa/recorrente sem serie_id ───────────────────
  function ymd(v) {
    if (v == null || v === "") return "";
    const s = String(v);
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  function serieKey(rec) {
    const tipo = String(rec.get("tipo") || "despesa");
    const desc = String(rec.get("descricao") || "").trim();
    const valor = Number(rec.get("valor") || 0);
    const conta = String(rec.get("conta_id") || "");
    const cat = String(rec.get("categoria_id") || "");
    const sub = String(rec.get("subcategoria_id") || "");
    const freq = String(rec.get("frequencia") || "mensal") || "mensal";
    return (
      tipo +
      "|" +
      desc +
      "|" +
      valor +
      "|" +
      conta +
      "|" +
      cat +
      "|" +
      sub +
      "|" +
      freq
    );
  }

  try {
    const seriesCol = app.findCollectionByNameOrId("finseries0000001");
    const byKey = {};
    let page = 0;
    const perPage = 200;
    // PocketBase findRecordsByFilter: (collection, filter, sort, limit, offset)
    while (true) {
      const batch = app.findRecordsByFilter(
        "fin_lancamentos",
        "(recorrencia = 'fixa' || recorrencia = 'recorrente') && (serie_id = '' || serie_id = null)",
        "data",
        perPage,
        page * perPage,
        {},
      );
      if (!batch || batch.length === 0) break;
      for (let i = 0; i < batch.length; i++) {
        const rec = batch[i];
        const k = serieKey(rec);
        if (!byKey[k]) byKey[k] = [];
        byKey[k].push(rec);
      }
      if (batch.length < perPage) break;
      page++;
      if (page > 200) break; // safety
    }

    const keys = Object.keys(byKey);
    let nSeries = 0;
    let nLink = 0;
    for (let ki = 0; ki < keys.length; ki++) {
      const members = byKey[keys[ki]];
      members.sort((a, b) => ymd(a.get("data")).localeCompare(ymd(b.get("data"))));
      const first = members[0];
      const recor = String(first.get("recorrencia") || "fixa");
      const freq = String(first.get("frequencia") || "mensal") || "mensal";
      const s = new Record(seriesCol);
      s.set("tipo", first.get("tipo") || "despesa");
      s.set("descricao", String(first.get("descricao") || "").trim() || "Série");
      s.set("categoria_id", String(first.get("categoria_id") || ""));
      s.set("subcategoria_id", String(first.get("subcategoria_id") || ""));
      s.set("valor", Number(first.get("valor") || 0));
      s.set("conta_id", String(first.get("conta_id") || ""));
      s.set("recorrencia", recor === "recorrente" ? "recorrente" : "fixa");
      s.set("frequencia", freq);
      s.set("status", "ativa");
      s.set("data_inicio", ymd(first.get("data")) || "2020-01-01");
      s.set("data_fim", "");
      s.set("forma_pagamento", String(first.get("forma_pagamento") || ""));
      s.set("observacao", String(first.get("observacao") || ""));
      const tags = first.get("tags");
      s.set("tags", Array.isArray(tags) ? tags : []);
      app.save(s);
      nSeries++;
      const sid = s.id;
      for (let mi = 0; mi < members.length; mi++) {
        members[mi].set("serie_id", sid);
        app.save(members[mi]);
        nLink++;
      }
    }
    console.log(
      "[mig 51] fin_series backfill: " +
        nSeries +
        " séries, " +
        nLink +
        " lançamentos ligados",
    );
  } catch (e) {
    console.log("[mig 51] backfill séries: " + e);
  }
}, (app) => {
  // DOWN: remove campo e coleção (não desfaz backfill de dados órfãos)
  try {
    const lanc = app.findCollectionByNameOrId("fin_lancamentos");
    const f = lanc.fields.getByName("serie_id");
    if (f) {
      lanc.fields.removeById(f.id);
      app.save(lanc);
    }
  } catch (_) {}
  try {
    const c = app.findCollectionByNameOrId("finseries0000001");
    app.delete(c);
  } catch (_) {}
});
