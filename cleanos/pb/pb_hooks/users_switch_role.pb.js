/// <reference path="../pb_data/types.d.ts" />

/**
 * Alterna o papel ativo da própria conta.
 * `roles` é a autorização de papéis; `role` continua sendo o papel ativo que
 * as regras PocketBase usam para aplicar o menor privilégio.
 */
routerAdd(
  "POST",
  "/api/cleanos/users/switch-role",
  (e) => {
    const auth = e.auth;
    if (!auth) throw new UnauthorizedError("Autenticação necessária.");

    const body = e.requestInfo().body || {};
    const target = String(body.role || "").trim();
    const allowedRoles = ["admin", "gerente", "profissional"];
    if (!allowedRoles.includes(target)) {
      throw new BadRequestError("Papel inválido.");
    }

    let roles = auth.get("roles");
    if (!Array.isArray(roles) || roles.length === 0) {
      roles = [String(auth.get("role") || "")];
    }
    if (!roles.includes(target)) {
      throw new ForbiddenError("Este usuário não possui esse papel.");
    }

    auth.set("role", target);
    auth.set("roles", roles);
    $app.save(auth);
    return e.json(200, { ok: true, role: target });
  },
  $apis.requireAuth(),
);
