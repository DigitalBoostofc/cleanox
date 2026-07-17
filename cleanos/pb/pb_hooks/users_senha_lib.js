/**
 * users_senha_lib.js — validação PURA da redefinição de senha por admin.
 *
 * CommonJS de propósito: é chamado com require() DENTRO do handler da rota
 * (VM isolada do JSVM, R9) E direto pelos testes unitários (test:unit), sem
 * precisar de PocketBase vivo.
 */

/** Mínimo de caracteres da senha (espelha a regra do form do painel). */
const SENHA_MIN = 8;

/**
 * Valida a nova senha proposta. Retorna a mensagem de erro (PT-BR) ou `null`
 * quando está ok. Não toca em nada do PocketBase — só regra de negócio.
 */
function validarNovaSenha(password, passwordConfirm) {
  if (typeof password !== "string" || password.length < SENHA_MIN) {
    return "A nova senha precisa de pelo menos " + SENHA_MIN + " caracteres.";
  }
  if (password !== passwordConfirm) {
    return "As senhas não coincidem.";
  }
  return null;
}

module.exports = { SENHA_MIN, validarNovaSenha };
