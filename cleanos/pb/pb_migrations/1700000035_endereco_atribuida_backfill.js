/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — backfill `endereco_liberado` para OS `atribuida`.
 *
 * Pedido do dono (2026-07-18): profissional vê endereço antes de Iniciar.
 * O hook `manageEndereco` passa a liberar em `atribuida`, mas OS já existentes
 * ficariam sem endereço até o próximo save. Este migration preenche uma vez.
 *
 * IDEMPOTENTE: só preenche se `endereco_liberado` estiver vazio.
 * DOWN: limpa endereco_liberado de OS ainda em `atribuida` (não toca em_andamento).
 */
migrate(
  (app) => {
    function buildEndereco(cliente) {
      const parts = [];
      const rua = cliente.get("endereco_rua");
      const num = cliente.get("endereco_numero");
      if (rua) parts.push(num ? rua + ", " + num : rua);
      const comp = cliente.get("endereco_complemento");
      if (comp) parts.push(comp);
      const bairro = cliente.get("endereco_bairro");
      if (bairro) parts.push(bairro);
      const cidade = cliente.get("endereco_cidade");
      if (cidade) parts.push(cidade);
      const cep = cliente.get("endereco_cep");
      if (cep) parts.push("CEP " + cep);
      return parts.join(" - ");
    }

    try {
      const rows = app.findRecordsByFilter(
        "ordens_servico",
        'status = "atribuida"',
        "-updated",
        500,
        0,
      );
      for (const r of rows) {
        const atual = String(r.get("endereco_liberado") || "").trim();
        if (atual) continue;
        const cid = String(r.get("cliente") || "").trim();
        if (!cid) continue;
        try {
          const c = app.findRecordById("clientes", cid);
          const end = buildEndereco(c);
          if (!end) continue;
          r.set("endereco_liberado", end);
          app.save(r);
        } catch (_) {
          /* cliente órfão */
        }
      }
    } catch (_) {
      /* vazio */
    }
  },
  (app) => {
    try {
      const rows = app.findRecordsByFilter(
        "ordens_servico",
        'status = "atribuida"',
        "-updated",
        500,
        0,
      );
      for (const r of rows) {
        r.set("endereco_liberado", "");
        app.save(r);
      }
    } catch (_) {}
  },
);
