/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 62: bonificação avulsa fora de repasse de OS.
 *
 * Repara somente despesas de ciclo ainda pendentes. Comissões pagas/históricas
 * permanecem intactas. A bonificação continua na prof_comissoes com sua data
 * e status próprios.
 */
migrate((app) => {
  const lancamentos = app.findRecordsByFilter(
    "fin_lancamentos",
    "origem = \"via_comissao\" && status = \"pendente\" && observacao ~ \"repasse_ciclo:\"",
    "",
    500,
    0,
  );

  for (const lancamento of lancamentos) {
    const obs = String(lancamento.get("observacao") || "");
    const match = obs.match(
      /^repasse_ciclo:(\d{4}-\d{2}-\d{2}):(\d{4}-\d{2}-\d{2})$/,
    );
    const profId = String(lancamento.get("profissional_id") || "").trim();
    if (!match || !profId) continue;

    const comissoes = app.findRecordsByFilter(
      "prof_comissoes",
      "profissional = {:pid} && status = \"pendente\"",
      "",
      500,
      0,
      { pid: profId },
    );

    let total = 0;
    let quantidadeOs = 0;
    let nome = String(lancamento.get("descricao") || "")
      .replace(/^.*?·\s*/, "")
      .replace(/\s*·.*$/, "")
      .trim();

    for (const comissao of comissoes) {
      const data = String(comissao.get("data") || "").slice(0, 10);
      if (data < match[1] || data > match[2]) continue;
      if (String(comissao.get("tipo_aplicado") || "") === "bonificacao") continue;

      const valor = Number(comissao.get("valor_comissao") || 0);
      if (!(valor > 0)) continue;
      total += valor;
      quantidadeOs += 1;
      if (!nome) nome = String(comissao.get("profissional_nome") || "").trim();
    }

    if (!(total > 0)) {
      app.delete(lancamento);
      continue;
    }

    lancamento.set("valor", Math.round(total * 100) / 100);
    lancamento.set(
      "descricao",
      "Comissão · " + (nome || profId) + " · " + match[1] + " a " + match[2] +
        " (" + quantidadeOs + " OS)",
    );
    app.save(lancamento);
  }
}, (app) => {});
