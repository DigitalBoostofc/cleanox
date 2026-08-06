/// <reference path="../pb_data/types.d.ts" />

/**
 * Exclusão segura de lançamentos em prof_comissoes.
 *
 * A UI só oferece a ação para bonificações pendentes, mas a API também precisa
 * proteger a coleção: comissão automática de OS e bonificação paga são parte do
 * histórico financeiro e não podem ser apagadas por este caminho.
 */
onRecordDeleteRequest((e) => {
  const auth = e.auth;
  const lib = require(`${__hooks}/os_logic.js`);
  const role = auth ? String(auth.get("role") || "") : "";
  if (role !== "admin" && role !== "gerente" && !lib.isSuperuser(auth)) {
    throw new ForbiddenError("Apenas admin ou gerente pode excluir bonificação.");
  }

  const tipo = String(e.record.get("tipo_aplicado") || "");
  const status = String(e.record.get("status") || "");
  if (tipo !== "bonificacao") {
    throw new ForbiddenError("Comissão automática de OS não pode ser excluída.");
  }
  if (status !== "pendente") {
    throw new ForbiddenError("Bonificação paga não pode ser excluída.");
  }

  e.next();
}, "prof_comissoes");
