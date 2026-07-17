# Admin redefine senha de outras contas — design

> Aprovado pelo dono em 2026-07-17.

## Problema

Hoje, alterar a senha de outro usuário só é possível pela Admin UI do PocketBase
(superuser). O dono quer que um usuário com papel **admin**, logado no app,
possa redefinir a senha de outras contas.

Um `admin` do CleanOS **não** é superuser do PocketBase, então o SDK não
consegue setar a senha de outra conta. A trava tem que ser server-side.

## Decisões (dono, 2026-07-17)

1. **Alcance:** admin pode redefinir senha de `profissional`, `gerente` e outros
   `admin`. **Nunca** superuser (`_superusers` é outra coleção → inalcançável).
2. **Confirmação:** o admin reconfirma a **própria** senha pra autorizar.
3. **UI:** botão "Redefinir senha" dentro do **editar usuário**.
4. **Gerente NÃO pode** — a ação é exclusiva de `admin` ("pelo login do admin").
5. Trocar a senha **invalida os tokens** do alvo (ele reloga com a nova senha) —
   comportamento padrão e desejado.

## Backend — rota custom

`POST /api/cleanos/users/{id}/senha` (novo `pb_hooks/users_senha.pb.js`),
espelhando `fin_routes.pb.js` (routerAdd + `$apis.requireAuth()` + `require()`
dentro do handler, R9).

- Auth: `e.auth` presente; `e.auth.get("role") === "admin"` senão `ForbiddenError`.
- Body: `{ password, passwordConfirm, adminPassword }`.
- Reconfirma: `e.auth.validatePassword(adminPassword)` → senão `BadRequestError`
  "Senha do admin incorreta.".
- Valida `password`/`passwordConfirm` (mín. 8 + iguais) — helper puro
  `users_senha_lib.js#validarNovaSenha` (testável no `test:unit`).
- Alvo: `$app.findRecordById("users", id)` (404 se não achar). Superuser é
  inalcançável por construção (coleção diferente).
- `target.setPassword(password)` + `$app.save(target)`.
- Resposta `{ ok: true }`, sem PII. `$app.logger` audita (quem mudou quem).

## Frontend — Flutter

- `UsuariosRepository.redefinirSenha({userId, novaSenha, adminSenha})` →
  `pb.send('/api/cleanos/users/$userId/senha', method: 'POST', body: {...})`.
- Erros → PT-BR (reaproveita o padrão de `conta_screen`): senha do admin
  incorreta, senha curta, não coincidem, 403.
- `usuario_form.dart` (modo editar): botão **"Redefinir senha"** → dialog com
  *nova senha / confirmar / sua senha (admin)*. Só para `role == admin`. Sucesso
  → toast "Senha redefinida".

## Testes

- Hooks unit: `validarNovaSenha` (curta, não-coincide, ok) no `test:unit`.
- Flutter: widget do dialog (validações + sucesso chama repo com args certos) +
  repo (mapeia erros do PB).
- E2E da rota precisa de PB vivo (dívida conhecida do `anti-desvio.test.mjs`).

## Deploy

- Hook novo é cirúrgico (`scp` de `users_senha.pb.js` + `users_senha_lib.js`, R11)
  + restart. UI vai no APK e no web (build web → `pb_public` com `sw.js`).

## Não-objetivos

- Não mexe no fluxo de "trocar a própria senha" (Conta, com senha atual).
- Não cria recuperação de senha por e-mail (SMTP segue desligado).
