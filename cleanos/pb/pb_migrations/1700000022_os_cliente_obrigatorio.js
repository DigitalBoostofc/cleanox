/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — Migration 22: cliente EFETIVAMENTE obrigatório em ordens_servico.
 *
 * A migration 1 criou o RelationField `cliente` com `required: true` PORÉM
 * `minSelect: 0`. Na v0.39 quem manda na obrigatoriedade de uma relation é o
 * `minSelect`: com 0, uma OS pode ser salva SEM cliente — e uma OS sem cliente é
 * um estado inválido de negócio (sem cofre não há telefone/endereço; as rotas
 * /a-caminho e /relatorio precisam de cliente para funcionar). Sem o vínculo, o
 * app derrapa e o server só se protege com guards pontuais.
 *
 * Esta migration sobe `minSelect` para 1 (mantendo `required: true`), tornando o
 * cliente obrigatório na fonte — o schema passa a rejeitar qualquer OS sem
 * cliente, em vez de depender só de guards de rota. É a "linha de defesa no
 * servidor" que o projeto exige (o cliente Flutter só traduz o 400).
 *
 * NOTA: PocketBase valida schema no WRITE, não retroativamente. OS já existentes
 * sem cliente (não deveriam existir — a mig 1 já pedia required e a criação é só
 * por admin/gerente) permanecem no banco, mas qualquer novo save precisará de
 * cliente. As rotas que salvam a OS (relatorio_enviado_em, etc.) já barram OS
 * sem cliente ANTES do save (BadRequestError), então não quebram por isso.
 *
 * IDEMPOTENTE (só altera se ainda estiver 0) / REVERSÍVEL (o DOWN volta p/ 0).
 */
migrate(
  (app) => {
    let ordens = null;
    try { ordens = app.findCollectionByNameOrId("ordserv00000001"); } catch (_) { ordens = null; }
    if (!ordens) return; // base sem a coleção — nada a fazer

    const cliente = ordens.fields.getByName("cliente");
    if (cliente && cliente.minSelect !== 1) {
      cliente.minSelect = 1;
      cliente.required = true; // garante a obrigatoriedade explícita
      app.save(ordens);
    }
  },

  // ── DOWN ──────────────────────────────────────────────────────────────────
  (app) => {
    let ordens = null;
    try { ordens = app.findCollectionByNameOrId("ordserv00000001"); } catch (_) { ordens = null; }
    if (!ordens) return;

    const cliente = ordens.fields.getByName("cliente");
    if (cliente) {
      cliente.minSelect = 0; // restaura o estado da migration 1
      app.save(ordens);
    }
  }
);
