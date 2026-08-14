/// <reference path="../pb_data/types.d.ts" />

// Persiste a sequência inteira em uma única transação. A rota exige que o
// payload contenha exatamente todos os irmãos ativos do escopo, impedindo
// colisões por atualização parcial ou por uma tela desatualizada.
routerAdd("POST", "/api/cleanos/catalogo/reordenar", (e) => {
  const lib = require(`${__hooks}/catalogo_ordem_lib.js`);

  const role = String(e.auth && e.auth.get("role") || "");
  if (role !== "admin" && role !== "gerente") {
    throw new ForbiddenError("Só admin ou gerente podem reordenar o catálogo.");
  }

  let payload;
  try {
    payload = lib.parsePayload(e.requestInfo().body);
  } catch (err) {
    throw new BadRequestError(String(err && err.message || err));
  }

  $app.runInTransaction((txApp) => {
    const collection = payload.kind === "taxonomia"
      ? "servicos_taxonomia"
      : "servicos";
    const primeiro = txApp.findRecordById(collection, payload.ids[0]);
    let scope;

    if (payload.kind === "taxonomia") {
      scope = txApp.findAllRecords(
        collection,
        $dbx.hashExp({
          tipo: primeiro.getString("tipo"),
          parent: primeiro.getString("parent"),
          ativo: true,
        })
      );
    } else {
      scope = txApp.findAllRecords(
        collection,
        $dbx.hashExp({
          categoria: primeiro.getString("categoria"),
          grupo: primeiro.getString("grupo"),
          ativo: true,
        })
      );
    }

    if (!lib.hasExactIds(payload.ids, scope)) {
      throw new BadRequestError(
        "O catálogo mudou. Recarregue a tela antes de ordenar novamente."
      );
    }

    const byId = {};
    for (const record of scope) byId[String(record.id)] = record;
    for (let i = 0; i < payload.ids.length; i++) {
      const record = byId[payload.ids[i]];
      record.set("ordem", lib.orderAt(i));
      txApp.save(record);
    }
  });

  return e.json(200, { updated: payload.ids.length });
}, $apis.requireAuth());
