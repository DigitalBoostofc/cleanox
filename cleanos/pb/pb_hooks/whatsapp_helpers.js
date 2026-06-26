/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — helpers compartilhados para as rotas WhatsApp (módulo CommonJS).
 *
 * Deve ser carregado via require() DENTRO de cada handler de routerAdd,
 * nunca no escopo externo do arquivo .pb.js.
 * $app, ForbiddenError, UnauthorizedError são globais PocketBase disponíveis
 * no contexto de execução dos handlers.
 */

/**
 * Verifica que o usuário autenticado tem papel admin ou gerente.
 * Lança ForbiddenError/UnauthorizedError caso contrário.
 */
function requireAdminOrGerente(e) {
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  const role = String(e.auth.get("role"));
  if (role !== "admin" && role !== "gerente") {
    throw new ForbiddenError("Rota restrita a admin/gerente.");
  }
}

/**
 * Retorna o registro singleton de app_config.
 * @param {any} app  instância de $app passada pelo caller (global do handler)
 */
function getAppConfig(app) {
  return app.findFirstRecordByFilter("app_config", "id != ''");
}

/**
 * Extrai o objeto `instance` de respostas UAZAPI que podem vir com ou sem wrapper.
 */
function extractInstance(res) {
  return res.instance || res;
}

module.exports = { requireAdminOrGerente, getAppConfig, extractInstance };
