/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — redefinição de senha de outra conta por admin (users_senha.pb.js).
 *
 *   POST /api/cleanos/users/{id}/senha
 *   body: { password, passwordConfirm, adminPassword }
 *
 * Um `admin` do app NÃO é superuser do PocketBase, então o SDK não consegue
 * setar a senha de outra conta. Esta rota faz isso server-side com privilégio
 * elevado ($app), espelhando fin_routes/whatsapp_routes: routerAdd +
 * $apis.requireAuth() + checagem de papel + require() DENTRO do handler (a VM
 * do JSVM é isolada e não enxerga o escopo do arquivo, R9).
 *
 * Regras (dono, 2026-07-17):
 *  - só `role == admin` chama (gerente NÃO — é "pelo login do admin");
 *  - o admin reconfirma a PRÓPRIA senha (adminPassword) pra autorizar;
 *  - o alvo é um registro de `users`; superuser vive em `_superusers` (outra
 *    coleção) e por isso é INALCANÇÁVEL por esta rota;
 *  - trocar a senha invalida os tokens do alvo (ele reloga com a nova senha).
 *
 * Sem PII nas respostas.
 */
routerAdd(
  "POST",
  "/api/cleanos/users/{id}/senha",
  (e) => {
    const { validarNovaSenha } = require(`${__hooks}/users_senha_lib.js`);

    const auth = e.auth;
    if (!auth) throw new UnauthorizedError("Autenticação necessária.");
    if (String(auth.get("role") || "") !== "admin") {
      throw new ForbiddenError("Apenas administradores podem redefinir senhas.");
    }

    const body = e.requestInfo().body || {};
    const adminPassword = String(body.adminPassword || "");
    const password = String(body.password || "");
    const passwordConfirm = String(body.passwordConfirm || "");

    // Reconfirma a senha do PRÓPRIO admin (protege sessão aberta sequestrada).
    if (!adminPassword || !auth.validatePassword(adminPassword)) {
      throw new BadRequestError("Senha do admin incorreta.");
    }

    const erro = validarNovaSenha(password, passwordConfirm);
    if (erro) throw new BadRequestError(erro);

    const targetId = e.request.pathValue("id");
    let target;
    try {
      target = $app.findRecordById("users", targetId);
    } catch (_) {
      throw new NotFoundError("Usuário não encontrado.");
    }

    target.setPassword(password);
    $app.save(target);

    $app.logger().info(
      "admin redefiniu senha de usuario",
      "actor",
      String(auth.id),
      "target",
      String(target.id),
    );

    return e.json(200, { ok: true });
  },
  $apis.requireAuth(),
);
