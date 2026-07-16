/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — formas de pagamento ampliadas (pedido do dono, 16/07/2026).
 *
 * `ordens_servico.forma_pagamento` (select) ganha: `dinheiro` (Dinheiro em
 * espécie), `pix` (Pix genérico) e `outros`. Os valores antigos (`debito`,
 * `credito`, `pix_maquininha`) permanecem — OS históricas continuam válidas;
 * `pix_maquininha` sai do seletor no app mas segue legível como legado.
 *
 * Novo campo `forma_pagamento_outro` (text): detalhe livre quando a forma é
 * `outros` (ex.: "Transferência", "Cortesia"). Editável pelo profissional
 * (fora da denylist), espelhado no OSExecPatch do Flutter.
 *
 * ⚠️ Campo texto opcional volta como "" quando vazio (regra R2).
 *
 * IDEMPOTENTE. DOWN restaura os values antigos e remove o campo.
 */

migrate(
  (app) => {
    const ordens = app.findCollectionByNameOrId("ordserv00000001");

    const forma = ordens.fields.getByName("forma_pagamento");
    if (forma) {
      forma.values = [
        "debito",
        "credito",
        "pix_maquininha",
        "dinheiro",
        "pix",
        "outros",
      ];
    }

    if (!ordens.fields.getByName("forma_pagamento_outro")) {
      ordens.fields.add(
        new TextField({
          name: "forma_pagamento_outro",
          required: false,
          max: 100,
        }),
      );
    }

    app.save(ordens);
  },
  (app) => {
    try {
      const ordens = app.findCollectionByNameOrId("ordserv00000001");
      const forma = ordens.fields.getByName("forma_pagamento");
      if (forma) forma.values = ["debito", "credito", "pix_maquininha"];
      const f = ordens.fields.getByName("forma_pagamento_outro");
      if (f) ordens.fields.removeById(f.id);
      app.save(ordens);
    } catch (_) {}
  },
);
