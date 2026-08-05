/// 1700000054_fin_series_parcelada.js
///
/// Parceladas entram em Cobranças fixas (fin_series):
/// - Select `recorrencia` aceita `parcelada`
/// - Campo `parcelas_total` na série
/// - Backfill: agrupa fin_lancamentos parcelados sem serie_id
migrate((app) => {
  function tryFind(id) {
    try {
      return app.findCollectionByNameOrId(id);
    } catch (_) {
      return null;
    }
  }

  const series = tryFind("finseries0000001") || tryFind("fin_series");
  if (!series) {
    console.log("[mig 54] fin_series ausente — rode 51 antes");
    return;
  }

  // A) recorrencia: + parcelada
  const recField = series.fields.getByName("recorrencia");
  if (recField && Array.isArray(recField.values)) {
    if (recField.values.indexOf("parcelada") < 0) {
      recField.values = recField.values.concat(["parcelada"]);
    }
  }

  // B) parcelas_total
  if (!series.fields.getByName("parcelas_total")) {
    series.fields.add(
      new NumberField({ name: "parcelas_total", required: false, min: 1 }),
    );
  }
  app.save(series);

  // C) Backfill parceladas sem serie_id
  const lanc = app.findCollectionByNameOrId("fin_lancamentos");
  function ymd(v) {
    if (v == null || v === "") return "";
    const s = String(v);
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
  function softKey(r) {
    const tipo = String(r.get("tipo") || "");
    const desc = String(r.get("descricao") || "").trim();
    const valor = Number(r.get("valor") || 0);
    const conta = String(r.get("conta_id") || "");
    const cat = String(r.get("categoria_id") || "");
    const sub = String(r.get("subcategoria_id") || "");
    const n = Number(r.get("parcelas_total") || 0);
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
      "|parcelada|" +
      n
    );
  }

  let rows = [];
  try {
    rows = app.findRecordsByFilter(
      lanc.id,
      "recorrencia = 'parcelada' && (serie_id = '' || serie_id = null)",
      "data",
      500,
      0,
    );
  } catch (e) {
    console.log("[mig 54] list parceladas: " + e);
    return;
  }

  const groups = {};
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const k = softKey(r);
    if (!groups[k]) groups[k] = [];
    groups[k].push(r);
  }

  let nSeries = 0;
  let nLink = 0;
  const keys = Object.keys(groups);
  for (let gi = 0; gi < keys.length; gi++) {
    const members = groups[keys[gi]];
    members.sort(function (a, b) {
      return ymd(a.get("data")).localeCompare(ymd(b.get("data")));
    });
    const first = members[0];
    const last = members[members.length - 1];
    let maxParc = 0;
    let anyOpen = false;
    for (let mi = 0; mi < members.length; mi++) {
      const m = members[mi];
      const pt = Number(m.get("parcelas_total") || 0);
      if (pt > maxParc) maxParc = pt;
      const st = String(m.get("status") || "");
      if (st !== "pago") anyOpen = true;
    }
    if (maxParc < members.length) maxParc = members.length;

    const s = new Record(series);
    s.set("tipo", String(first.get("tipo") || "despesa"));
    s.set("descricao", String(first.get("descricao") || "").trim());
    s.set("categoria_id", String(first.get("categoria_id") || ""));
    s.set("subcategoria_id", String(first.get("subcategoria_id") || ""));
    s.set("valor", Number(first.get("valor") || 0));
    s.set("conta_id", String(first.get("conta_id") || ""));
    s.set("recorrencia", "parcelada");
    s.set("frequencia", "mensal");
    s.set("status", anyOpen ? "ativa" : "encerrada");
    s.set("data_inicio", ymd(first.get("data")));
    s.set("data_fim", ymd(last.get("data")));
    s.set("parcelas_total", maxParc);
    s.set("forma_pagamento", String(first.get("forma_pagamento") || ""));
    s.set("observacao", String(first.get("observacao") || ""));
    s.set("tags", first.get("tags") || []);
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
    "[mig 54] fin_series parcelada backfill: " +
      nSeries +
      " séries, " +
      nLink +
      " lançamentos",
  );
}, (app) => {
  // no destructive down — keep series + parcela links
});
