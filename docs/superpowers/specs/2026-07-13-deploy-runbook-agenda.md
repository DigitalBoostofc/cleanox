# Runbook de deploy — PR #39 (agenda + versionamento da prod + origem)

> **NÃO EXECUTAR sem ordem explícita do dono (R5).** Este arquivo existe para que,
> quando a ordem vier, o deploy seja um passo curto e conferido — não um improviso.

## Contexto que muda o risco

- **A produção roda código que nunca esteve em git.** O redesign EasyPay/avatar/"OS Fácil"
  foi deployado de uma árvore suja. O PR #39 versiona isso. Consequência: o build atual
  de prod **não é reproduzível a partir de nenhum commit** — só a partir do PR #39 em diante.
- **Mergear o PR na `main` dispara o workflow e publica APK na Play Store** (track internal
  + auto-bump). Merge não é inofensivo.
- A prod já teve **3 episódios de corrupção SQLite**. Backup ANTES de qualquer coisa não é
  formalidade.

## Migrations que entram (nenhuma aplicada em prod ainda)

| Migration | O quê | Reversível? |
|---|---|---|
| `1700000024_users_avatar.js` | campo avatar em `users` | sim (`down` remove o campo) |
| `1700000026_clientes_origem.js` | `clientes.origem` (select opcional) | sim |
| `1700000027_os_duracao.js` | `ordens_servico.duracao_min` (número opcional) | sim |

Todas são **aditivas** (campo novo, opcional). Nenhuma apaga ou reescreve dado existente.

## Ordem recomendada — DOIS passos, não um

### Passo 0 — SEMPRE, antes de tudo
```
ssh hostinger "cd /opt/cleanos/pb && ./pocketbase backup create"
ssh hostinger "cd /opt/cleanos/pb && ls -la pb_data/backups/ | tail -3"   # confirmar que nasceu
```

### Passo 1 — Só o que JÁ ESTÁ NO AR (risco ~zero)
Objetivo: fechar o buraco do "prod sem versão" e levar as 2 correções de bug reais
(overflow do rail; `IntrinsicHeight`+`LayoutBuilder` no Financeiro › Visão geral).

- Backend: **só a migration 24** (avatar). Hooks: nada novo obrigatório aqui.
- Frontend: build web do commit do bloco 1 e rsync.
- Smoke: login real + Financeiro › Visão geral (o donut tem que renderizar) + avatar.

### Passo 2 — Features novas (agenda + origem), com QA do dono
- Backend: hooks (`os_logic.js` com a cerca de status) + migrations 26 e 27 → `migrate up` → restart.
- Frontend: build web + rsync.
- Smoke: criar OS com duração; encaixar uma sobreposta (tem que **avisar**, não bloquear);
  arrastar/redimensionar no desktop; long-press no celular; conferir que OS **concluída**
  NÃO deixa mudar horário (a cerca do servidor).

## Comandos (padrão do CLAUDE.md — R7, R8)

```bash
# BACKEND (hooks + migrations) — R8: NUNCA rsyncar o seed
rsync -az --exclude='1700000002_seed.js' cleanos/pb/pb_hooks/      hostinger:/opt/cleanos/pb/pb_hooks/
rsync -az --exclude='1700000002_seed.js' cleanos/pb/pb_migrations/ hostinger:/opt/cleanos/pb/pb_migrations/
ssh hostinger "cd /opt/cleanos/pb && ./pocketbase migrate up"
ssh hostinger "systemctl restart cleanos.service"

# FRONTEND
cd cleanos/flutter
flutter build web --release -t lib/main_painel.dart
grep -q 'app.cleanox.com.br' build/web/main.dart.js       # tem que achar
! grep -q '127.0.0.1:8090' build/web/main.dart.js         # NÃO pode achar
test -f build/web/sw.js                                    # R7: kill-switch presente
rsync --delete build/web/ hostinger:/opt/cleanos/pb/pb_public/
ssh hostinger "chown -R ubuntu:ubuntu /opt/cleanos/pb/pb_public"

# SMOKE
curl -s -o /dev/null -w '%{http_code}\n' https://app.cleanox.com.br/api/health   # 200
# + login real na UI
```

## Armadilha já confirmada (mordeu 2x no dev)

O **service worker do Flutter cacheia agressivamente**. Depois do deploy, se a UI parecer
"a de antes", NÃO é o deploy que falhou — é cache. O `sw.js` kill-switch (R7) existe pra isso,
mas ao validar manualmente: limpar SW + caches antes de concluir qualquer coisa.

## Rollback

- Frontend: rsync do build anterior de volta em `pb_public/`.
- Backend: `./pocketbase migrate down` (as 3 migrations têm `down` real e são aditivas),
  ou restaurar o backup do Passo 0.

## O que NÃO vai neste deploy

- `wip/meta-capi` — thread inacabada, parqueada em branch própria. **Não deployar.**

## Pendências estruturais (não bloqueiam este deploy, mas seguem abertas)

- **Backup externo do keystore** (`~/.cleanos-keystore/`) — maior risco residual.
- Backup off-site (S3/R2) — hoje tudo mora na mesma VPS.
