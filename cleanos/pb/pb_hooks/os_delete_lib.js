/**
 * CleanOS — exclusão de OS com estorno financeiro (os_delete_lib.js).
 *
 * Módulo CommonJS carregado via require() pelo os_delete.pb.js (e pelos testes
 * unitários em cleanos/tests, fora do PocketBase).
 *
 * Por que existe: a deleteRule (ADMIN_GERENTE) sempre permitiu apagar uma OS,
 * mas o delete "cru" ou FALHA no banco (OS concluída tem `prof_comissoes.os`
 * required sem cascadeDelete) ou deixa LIXO (a receita `via_os` referencia a OS
 * por texto `os_id` — sem FK, o lançamento pago vira órfão e o saldo do caixa
 * fica inflado para sempre).
 *
 * Semântica de transação (ver header de fin_saldo.pb.js): `next()` COMITA a
 * exclusão; throw depois dele não faz rollback. Por isso TODA a limpeza roda
 * ANTES de next(), e a receita vem primeiro — se ela falhar, nada foi tocado.
 *
 * R1: este lib NUNCA escreve em fin_contas.saldo_atual. Apagar o lançamento
 * dispara o onRecordDelete do fin_saldo.pb.js, que estorna o efeito por UPDATE
 * SQL atômico.
 */

/**
 * Apaga TODOS os lançamentos `via_os` da OS — qualquer status, INCLUSIVE pago
 * (diferente do removeReceitaPrevista do os_financeiro_lib, que preserva pago:
 * lá a OS continua existindo; aqui ela vai deixar de existir).
 *
 * Erro num delete PROPAGA de propósito: melhor abortar a exclusão da OS do que
 * deixar receita órfã no caixa.
 */
function apagarReceitasDaOs(app, osId) {
  if (!osId) return 0;
  let list = [];
  try {
    list = app.findRecordsByFilter(
      "fin_lancamentos",
      "os_id = {:id} && origem = 'via_os'",
      "",
      50,
      0,
      { id: osId },
    );
  } catch (_) {
    list = [];
  }
  if (!list || list.length === 0) return 0;
  for (let i = 0; i < list.length; i++) {
    app.delete(list[i]); // fin_saldo estorna o efeito no hook de delete
    console.log(
      "[os-delete] receita via_os " + list[i].id + " removida (OS " + osId + ")",
    );
  }
  return list.length;
}

/**
 * Exclusão completa da OS. Chamada pelo onRecordDelete("ordens_servico") com
 * `next` (que COMITA). Ordem crítica:
 *   1) receitas via_os (falha → throw ANTES de qualquer outro efeito);
 *   2) comissões da OS (required sem cascade: sem isso o próprio next() falha) —
 *      o prof_comissao_lib apaga junto a despesa ligada, com estorno de saldo;
 *   3) next() apaga a OS; os_evidencias caem por cascadeDelete do schema.
 */
/**
 * Só OS cancelada pode ser excluída (UI + API/Admin).
 * Concluída/aberta: use cancelar primeiro se for o caso.
 */
function assertPodeExcluir(record) {
  const status = String(record.get("status") || "");
  if (status !== "cancelada") {
    const msg =
      "Só é possível excluir OS cancelada. Cancele a OS antes de excluí-la.";
    if (typeof BadRequestError !== "undefined") {
      throw new BadRequestError(msg);
    }
    throw new Error(msg);
  }
}

function handleDelete(app, record, next) {
  assertPodeExcluir(record);
  const osId = record.id;
  apagarReceitasDaOs(app, osId);
  require(`${__hooks}/prof_comissao_lib.js`).removerComissoesDaOs(app, osId);
  next();
  console.log("[os-delete] OS " + osId + " excluída");
}

module.exports = {
  apagarReceitasDaOs,
  assertPodeExcluir,
  handleDelete,
};
