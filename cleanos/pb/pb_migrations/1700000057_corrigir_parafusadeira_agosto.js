/// 1700000057_corrigir_parafusadeira_agosto.js
/// Corrige a segunda parcela da Parafusadeira Vonder que foi materializada
/// em 24/08 apesar de a série parcelada estar configurada como mensal.
migrate(
  (app) => {
    const lanc = app.findCollectionByNameOrId("fin_lancamentos");
    const serie = app.findCollectionByNameOrId("fin_series");
    const parcela = app.findRecordById(lanc.id, "rg4cslk0ep1qp0e");
    const regra = app.findRecordById(serie.id, "55re2ws7eiddpo7");

    const parcelaValida =
      String(parcela.get("descricao") || "").trim() === "Parafusadeira Vonder" &&
      String(parcela.get("serie_id") || "") === "55re2ws7eiddpo7" &&
      String(parcela.get("data") || "").substring(0, 10) === "2026-08-24" &&
      Number(parcela.get("parcela_atual") || 0) === 2 &&
      Number(parcela.get("parcelas_total") || 0) === 2;

    const serieValida =
      String(regra.get("descricao") || "").trim() === "Parafusadeira Vonder" &&
      String(regra.get("recorrencia") || "") === "parcelada" &&
      String(regra.get("frequencia") || "") === "mensal" &&
      Number(regra.get("parcelas_total") || 0) === 2;

    if (!parcelaValida || !serieValida) {
      throw new Error(
        "mig 57 abortada: registro não corresponde exatamente à Parafusadeira Vonder parcelada",
      );
    }

    parcela.set("data", "2026-09-10");
    parcela.set("vencimento", "2026-09-10");
    app.save(parcela);

    regra.set("data_fim", "2026-09-10");
    app.save(regra);

    console.log("[mig 57] Parafusadeira Vonder: 24/08 → 10/09");
  },
  (app) => {
    const lanc = app.findCollectionByNameOrId("fin_lancamentos");
    const serie = app.findCollectionByNameOrId("fin_series");
    const parcela = app.findRecordById(lanc.id, "rg4cslk0ep1qp0e");
    const regra = app.findRecordById(serie.id, "55re2ws7eiddpo7");

    parcela.set("data", "2026-08-24");
    parcela.set("vencimento", "2026-08-24");
    app.save(parcela);
    regra.set("data_fim", "");
    app.save(regra);
  },
);
