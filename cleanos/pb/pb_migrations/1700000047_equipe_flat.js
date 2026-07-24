/// 1700000047_equipe_flat.js
///
/// Plano de contas: despesa "Equipe" deixa de ter as subcategorias
/// "Comissões" e "Profissionais". Lançamentos e limites que apontavam
/// para essas subs passam a usar só a raiz Equipe (subcategoria vazia).
///
/// IDs canônicos do seed (1700000015):
///   catdequipe00001 = Equipe (raiz)
///   catdequipeprof1 = Profissionais
///   catdequipecomi1 = Comissões
///
/// Também pega filhas pelo nome+parent caso o id tenha mudado.
migrate((app) => {
  const EQUIPE_ID = "catdequipe00001";
  const SUB_IDS = ["catdequipeprof1", "catdequipecomi1"];

  // Resolve IDs reais (seed ou criadas na UI com outro id).
  let equipeId = EQUIPE_ID;
  try {
    const e = app.findFirstRecordByFilter(
      "fin_categorias",
      "tipo = 'despesa' && nome = 'Equipe' && (parent_id = '' || parent_id = null)",
    );
    if (e) equipeId = e.id;
  } catch (_) {
    try {
      app.findRecordById("fin_categorias", EQUIPE_ID);
    } catch (err) {
      console.log("[mig 47] categoria Equipe não encontrada; abort: " + err);
      return;
    }
  }

  const subIds = {};
  for (let i = 0; i < SUB_IDS.length; i++) {
    subIds[SUB_IDS[i]] = true;
  }
  // Por nome sob Equipe
  try {
    const filhos = app.findRecordsByFilter(
      "fin_categorias",
      "tipo = 'despesa' && parent_id = {:pid}",
      "nome",
      50,
      0,
      { pid: equipeId },
    );
    for (let j = 0; j < (filhos || []).length; j++) {
      const n = String(filhos[j].get("nome") || "");
      if (
        n === "Comissões" ||
        n === "Comissão" ||
        n === "Profissionais"
      ) {
        subIds[filhos[j].id] = true;
      }
    }
  } catch (_) {}

  const subList = Object.keys(subIds);
  if (subList.length === 0) {
    console.log("[mig 47] nenhuma sub Comissões/Profissionais; noop");
    return;
  }

  // ── fin_lancamentos: move para Equipe (raiz), limpa sub ───────────────
  let nLanc = 0;
  try {
    // Categoria ou sub = uma das subs a remover
    const filter =
      "categoria_id = '" +
      subList.join("' || categoria_id = '") +
      "' || subcategoria_id = '" +
      subList.join("' || subcategoria_id = '") +
      "'";
    const list = app.findRecordsByFilter(
      "fin_lancamentos",
      filter,
      "",
      500,
      0,
      {},
    );
    for (let k = 0; k < (list || []).length; k++) {
      const rec = list[k];
      rec.set("categoria_id", equipeId);
      rec.set("subcategoria_id", "");
      app.save(rec);
      nLanc++;
    }
  } catch (e) {
    console.log("[mig 47] migrar fin_lancamentos: " + e);
  }

  // ── fin_limites: se existir campo categoria_id ────────────────────────
  let nLim = 0;
  try {
    const lims = app.findRecordsByFilter(
      "fin_limites",
      "categoria_id = '" +
        subList.join("' || categoria_id = '") +
        "' || categoria_id = '" +
        equipeId +
        "'",
      "",
      100,
      0,
      {},
    );
    for (let m = 0; m < (lims || []).length; m++) {
      const lim = lims[m];
      const cid = String(lim.get("categoria_id") || "");
      if (subIds[cid]) {
        lim.set("categoria_id", equipeId);
        app.save(lim);
        nLim++;
      }
    }
  } catch (_) {
    /* coleção sem registros / campo */
  }

  // ── delete das subcategorias ──────────────────────────────────────────
  let nDel = 0;
  for (let d = 0; d < subList.length; d++) {
    const id = subList[d];
    if (id === equipeId) continue;
    try {
      const cat = app.findRecordById("fin_categorias", id);
      // Só apaga se for filha de Equipe (ou o id canônico)
      const pid = String(cat.get("parent_id") || "");
      const nome = String(cat.get("nome") || "");
      const okNome =
        nome === "Comissões" ||
        nome === "Comissão" ||
        nome === "Profissionais";
      if (pid === equipeId || okNome) {
        app.delete(cat);
        nDel++;
      }
    } catch (_) {
      /* já apagada */
    }
  }

  console.log(
    "[mig 47] Equipe flat: lancamentos=" +
      nLanc +
      " limites=" +
      nLim +
      " subs_removidas=" +
      nDel +
      " equipe=" +
      equipeId,
  );
}, (app) => {
  // DOWN: recria as subs canônicas (vazias). Não tenta re-apontar lançamentos.
  const EQUIPE_ID = "catdequipe00001";
  try {
    const col = app.findCollectionByNameOrId("fin_categorias");
    const specs = [
      {
        id: "catdequipeprof1",
        nome: "Profissionais",
        icone: "user-check",
        cor: "#F59E0B",
      },
      {
        id: "catdequipecomi1",
        nome: "Comissões",
        icone: "hand-coins",
        cor: "#FBBF24",
      },
    ];
    for (let i = 0; i < specs.length; i++) {
      const s = specs[i];
      try {
        app.findRecordById("fin_categorias", s.id);
        continue; // já existe
      } catch (_) {}
      try {
        const rec = new Record(col);
        rec.set("id", s.id);
        rec.set("nome", s.nome);
        rec.set("tipo", "despesa");
        rec.set("icone", s.icone);
        rec.set("cor", s.cor);
        rec.set("parent_id", EQUIPE_ID);
        rec.set("arquivada", false);
        app.save(rec);
      } catch (e) {
        console.log("[mig 47 down] " + s.id + ": " + e);
      }
    }
  } catch (e) {
    console.log("[mig 47 down] " + e);
  }
});
