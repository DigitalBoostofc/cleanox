/**
 * Agenda compromissos — profissional só muda status da própria tarefa.
 */
function ehCofre(role) {
  return role === "admin" || role === "gerente";
}

function ehProfissional(role, roles) {
  if (role === "profissional") return true;
  const list = Array.isArray(roles) ? roles : [];
  return list.indexOf("profissional") >= 0;
}

function camposTravadosProf() {
  return [
    "titulo",
    "descricao",
    "profissional",
    "data_hora",
    "duracao_min",
    "recorrencia",
    "serie_id",
  ];
}

/** @returns {string|null} mensagem de erro, ou null se ok */
function validarUpdateProf(opts) {
  const authId = String((opts && opts.authId) || "");
  const recordProf = String((opts && opts.recordProfId) || "");
  const status = String((opts && opts.status) || "");
  if (!authId || authId !== recordProf) {
    return "Você só pode concluir as suas tarefas.";
  }
  if (status !== "pendente" && status !== "concluida") {
    return "Status inválido.";
  }
  return null;
}

if (typeof module !== "undefined") {
  module.exports = {
    ehCofre,
    ehProfissional,
    camposTravadosProf,
    validarUpdateProf,
  };
}
