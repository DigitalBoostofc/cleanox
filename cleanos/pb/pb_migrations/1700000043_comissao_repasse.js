/// 1700000043_comissao_repasse.js
///
/// Suporte a despesa única de repasse (não 1 por OS):
/// - fin_lancamentos.profissional_id (text) — agrupa repasse do profissional
/// - prof_comissoes.pago_em (text YYYY-MM-DD) — dia em que a comissão foi paga
migrate((app) => {
  // fin_lancamentos.profissional_id
  try {
    const lanc = app.findCollectionByNameOrId("fin_lancamentos");
    if (!lanc.fields.getByName("profissional_id")) {
      lanc.fields.add(
        new TextField({ name: "profissional_id", required: false, max: 30 }),
      );
      app.save(lanc);
    }
  } catch (e) {
    console.log("[mig 43] fin_lancamentos.profissional_id: " + e);
  }

  // prof_comissoes.pago_em
  try {
    const com = app.findCollectionByNameOrId("prof_comissoes");
    if (!com.fields.getByName("pago_em")) {
      com.fields.add(
        new TextField({ name: "pago_em", required: false, max: 10 }),
      );
      app.save(com);
    }
  } catch (e) {
    console.log("[mig 43] prof_comissoes.pago_em: " + e);
  }
}, (app) => {
  try {
    const lanc = app.findCollectionByNameOrId("fin_lancamentos");
    const f = lanc.fields.getByName("profissional_id");
    if (f) {
      lanc.fields.removeById(f.id);
      app.save(lanc);
    }
  } catch (_) {}
  try {
    const com = app.findCollectionByNameOrId("prof_comissoes");
    const f = com.fields.getByName("pago_em");
    if (f) {
      com.fields.removeById(f.id);
      app.save(com);
    }
  } catch (_) {}
});
