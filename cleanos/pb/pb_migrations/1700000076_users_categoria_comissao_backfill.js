/// <reference path="../pb_data/types.d.ts" />

/**
 * Backfill: profissionais sem users.categoria_comissao recebem
 * Equipe → nome (reutiliza sub existente; nunca sobrescreve vínculo válido).
 */
migrate(
  (app) => {
    const EQUIPE_ID = "catdequipe00001";
    let equipe = null;
    try {
      equipe = app.findFirstRecordByFilter(
        "fin_categorias",
        "tipo = 'despesa' && nome = 'Equipe' && (parent_id = '' || parent_id = null)",
      );
    } catch (_) {}
    if (!equipe) {
      try {
        equipe = app.findRecordById("fin_categorias", EQUIPE_ID);
      } catch (_) {}
    }
    if (!equipe) {
      console.log("[mig 76] categoria Equipe não encontrada; sem backfill");
      return;
    }

    const cats = app.findCollectionByNameOrId("fin_categorias");

    function temProfissional(user) {
      const role = String(user.get("role") || "").trim();
      let roles = user.get("roles");
      if (!Array.isArray(roles) || roles.length === 0) {
        roles = [role || "profissional"];
      }
      for (let i = 0; i < roles.length; i++) {
        if (String(roles[i]) === "profissional") return true;
      }
      return false;
    }

    function nomeDoUsuario(user) {
      const nome = String(user.get("nome") || "").trim();
      if (nome) return nome;
      return String(user.get("name") || "").trim();
    }

    function subDoNome(nome) {
      const safe = nome.replace(/'/g, "\\'");
      try {
        const sub = app.findFirstRecordByFilter(
          cats.id,
          "tipo = 'despesa' && parent_id = '" +
            equipe.id +
            "' && nome = '" +
            safe +
            "'",
        );
        if (sub) return sub.id;
      } catch (_) {}
      const novo = new Record(cats);
      novo.set("nome", nome);
      novo.set("tipo", "despesa");
      novo.set("parent_id", equipe.id);
      novo.set("icone", "");
      novo.set("cor", "");
      novo.set("arquivada", false);
      app.save(novo);
      return novo.id;
    }

    const users = app.findRecordsByFilter("users", "", "", 500, 0);
    let alterados = 0;
    for (let i = 0; i < users.length; i++) {
      const user = users[i];
      if (!temProfissional(user)) continue;
      const atual = String(user.get("categoria_comissao") || "").trim();
      if (atual) continue;
      const nome = nomeDoUsuario(user);
      if (!nome) continue;
      user.set("categoria_comissao", subDoNome(nome));
      app.save(user);
      alterados++;
    }
    console.log(
      "[mig 76] profissionais com categoria_comissao preenchida: " + alterados,
    );
  },
  (app) => {
    // Não desfaz vínculos históricos.
  },
);
