/// 1700000058_comissao_subcategoria_profissional.js
/// Classifica despesas de comissão/bonificação em Equipe → profissional.
migrate(
  (app) => {
    const cats = app.findCollectionByNameOrId("fin_categorias");
    const equipe = app.findFirstRecordByFilter(
      cats.id,
      "tipo = 'despesa' && nome = 'Equipe' && (parent_id = '' || parent_id = null)",
    );
    if (!equipe) throw new Error("mig 58: categoria Equipe não encontrada");

    function nomeSubcategoria(nome) {
      const n = String(nome || "").trim();
      if (!n) return "";
      const safe = n.replace(/'/g, "\\'");
      let sub = null;
      try {
        sub = app.findFirstRecordByFilter(
          cats.id,
          "tipo = 'despesa' && parent_id = '" + equipe.id + "' && nome = '" + safe + "'",
        );
      } catch (_) {}
      if (sub) return sub.id;
      const novo = new Record(cats);
      novo.set("nome", n);
      novo.set("tipo", "despesa");
      novo.set("parent_id", equipe.id);
      novo.set("icone", "");
      novo.set("cor", "");
      novo.set("arquivada", false);
      app.save(novo);
      return novo.id;
    }

    function nomeDaDescricao(descricao) {
      const s = String(descricao || "");
      const parts = s.split(" · ");
      if (parts.length >= 2) return String(parts[1] || "").trim();
      const hyphen = s.split(" - ");
      if (hyphen.length >= 2) return String(hyphen[1] || "").trim();
      return "";
    }

    const comissoes = {};
    try {
      const list = app.findRecordsByFilter(
        "prof_comissoes",
        "id != ''",
        "-created",
        5000,
        0,
        {},
      );
      for (let i = 0; i < list.length; i++) {
        const c = list[i];
        let nome = String(c.get("profissional_nome") || "").trim();
        if (!nome) {
          try {
            const p = app.findRecordById("users", String(c.get("profissional") || ""));
            nome = String(p.get("name") || p.get("nome") || "").trim();
          } catch (_) {}
        }
        comissoes[c.id] = nome;
      }
    } catch (_) {}

    const lancamentos = app.findRecordsByFilter(
      "fin_lancamentos",
      "origem = 'via_comissao'",
      "-created",
      5000,
      0,
      {},
    );
    let alterados = 0;
    for (let i = 0; i < lancamentos.length; i++) {
      const lanc = lancamentos[i];
      const nome = comissoes[String(lanc.get("comissao_id") || "")] ||
        nomeDaDescricao(lanc.get("descricao"));
      const subId = nomeSubcategoria(nome);
      if (!subId) continue;
      if (
        String(lanc.get("categoria_id") || "") === equipe.id &&
        String(lanc.get("subcategoria_id") || "") === subId
      ) continue;
      lanc.set("categoria_id", equipe.id);
      lanc.set("subcategoria_id", subId);
      app.save(lanc);
      alterados++;
    }
    console.log("[mig 58] despesas via_comissao classificadas: " + alterados);
  },
  (app) => {
    // Não desfaz classificação financeira histórica.
  },
);
