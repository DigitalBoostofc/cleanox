/// 1700000029_fin_lancamento_frequencia.js
///
/// Adiciona `frequencia` em `fin_lancamentos` para fixas/recorrentes:
/// diario | semanal | quinzenal | mensal | bimestral | trimestral | semestral | anual.
/// Opcional; vazio/"mensal" = comportamento mensal legado.
migrate((app) => {
  const col = app.findCollectionByNameOrId("fin_lancamentos");
  col.fields.add(
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
  app.save(col);
}, (app) => {
  const col = app.findCollectionByNameOrId("fin_lancamentos");
  const f = col.fields.getByName("frequencia");
  if (f) {
    col.fields.removeById(f.id);
    app.save(col);
  }
});
