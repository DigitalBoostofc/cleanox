# CleanOS — DNA do Projeto

> **Stack canônica: Flutter + PocketBase.** Todo frontend é Flutter
> (`cleanos/flutter/`). Não existe frontend React no repositório. Novas
> features, fixes, QA e orientações a agentes/devs são **sempre em Flutter**.

## 1. O QUE É

Gestão de empresa de limpeza: OS, agenda, clientes, profissionais, financeiro.

**Superfícies (todas Flutter):**
- **Web painel** (`AppSurface.painel`, entrypoint `main_painel.dart`) — dono/admin/gerente; servido por `pb_public/` em https://app.cleanox.com.br
- **APK unificado** (`AppSurface.android`, entrypoint `main_android.dart`) — um único APK; `app_router.dart` roteia por papel (admin → painel, profissional → app)

**Usuários:** dono/admin+gerente (painel web + APK) e profissionais (APK).

**UI responsiva (Fintech Clean):**
- **APK:** sempre tema e casco fintech (bottom nav 5 itens no painel).
- **Web estreita (&lt; 600dp):** mesmo visual fintech do APK (login, casco, hero de saldo, empty states, checklist).
- **Web ≥ 600dp (tablet/desktop):** layout clássico do painel (sidebar/rail) — intencional.

---

## 2. STACK & ESTRUTURA

```
cleanos/
  flutter/   ← ÚNICO frontend (Web + Android)
  pb/        ← backend PocketBase (hooks, migrations)
  tests/     ← integração anti-desvio + unitários de hooks PB
```

### Flutter — `cleanos/flutter/`
SDK local: `~/flutter-sdk` (v3.35.5 no CI). State: Riverpod. Roteamento: go_router.

**Entrypoints (todos em `lib/`):**
| Arquivo | Surface | Uso |
|---|---|---|
| `main_painel.dart` | `AppSurface.painel` | dev web local / `flutter build web` |
| `main_profissional.dart` | `AppSurface.profissional` | dev Android (legado, separado por papel) |
| `main_android.dart` | `AppSurface.android` | APK unificado — CI e release usam **só este** |

**Modelos:** `lib/core/models/` (freezed + json_serializable). Repos: `lib/core/repositories/` + implementações em `lib/painel/data/`.

**Orientação a agentes:** editar só `cleanos/flutter/` e `cleanos/pb/`. Nunca propor React, Vite, TSX, ou pasta `web/` de frontend. Referências a React em `docs/` antigos ou `usability-findings.md` são **histórico**, não implementação.

### PocketBase — `cleanos/pb/`
- Binário: `cleanos/pb/pocketbase` (v0.39.4)
- Hooks JS: `cleanos/pb/pb_hooks/` — JSVM, lógica via `require()` de libs
- Migrations: `cleanos/pb/pb_migrations/`
- Credenciais: `/opt/cleanos/cleanos.env` (nunca no repo)
- Referência de contrato: `cleanos/pb/README.md`

**Hooks principais:**
- `fin_saldo.pb.js` — integridade atômica de `fin_contas.saldo_atual` (lançamentos create/update/delete + guard de request)
- `fin_saldo_lib.js` — `efeito()`, `incSaldo()` (UPDATE SQL atômico, nunca read-then-write)
- `fin_routes.pb.js` — `POST /api/cleanos/fin/conta/{id}/ajuste` e `POST /api/cleanos/fin/transferencia`
- `os_financeiro.pb.js` + `os_financeiro_lib.js` — cria lançamento `via_os` ao fechar OS
- `prof_delete.pb.js` + `prof_delete_lib.js` — exclusão segura de profissional (bloqueia se há OS aberta, limpa disponibilidade antes do `e.next()`)
- `whatsapp_routes.pb.js` + `whatsapp_helpers.js` + `uazapi.js` — rotas WhatsApp
- `push.js` — FCM (inerte até chaves no cleanos.env)

**Coleções principais:** `users` (campo `role`), `clientes`, `servicos`, `ordens_servico`, `app_config` (singleton de config), `config_atuacao`, `disponibilidade`, `fin_contas`, `fin_lancamentos`, `fin_categorias`

**Migrations em produção (últimas relevantes):**
- `1700000020_perf_indexes.js` — índices de performance em `ordens_servico`
- `1700000021_conta_padrao_unica.js` — índice único parcial: só 1 conta `padrao=true`
- `1700000022_os_cliente_obrigatorio.js` — `minSelect:1` em OS.cliente (obrigatório na fonte)

### CI — `.github/workflows/android-release-profissional.yml`
- Entrypoint: `lib/main_android.dart`. Package: `br.com.wenox.cleanos`
- **Gate obrigatório antes do build:** `flutter analyze --fatal-infos` + `flutter test`
- Auto-bump `pubspec.yaml` +N (só após gate verde, em push pra main)
- Assina com keystore dos secrets (`KEYSTORE_FILE`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`)
- Publica no Play com `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

---

## 3. REGRAS INVIOLÁVEIS

**R1 — Saldo é server-side atômico; Flutter NUNCA muta `saldo_atual`.**
`PbFinanceiroRepository` omite `saldo_atual` do body de update. Ajustes só via `POST /fin/conta/{id}/ajuste`. Razão: lost-update catastrófico (race condition em concurrent requests) — ver `fin_saldo.pb.js`.

**R2 — Campo opcional no PB guarda `""`, NUNCA `null`. Comparar `!= ""`, nunca `== null`.**
`TextField` e `RelationField` opcional (`maxSelect:1`) chegam como `""` quando vazios. Normalizar `"" → null` no `fromRecord`, não nos call sites. Razão: bug silencioso — fixture Dart com `null` passa nos testes mas falha com dados reais de produção (ex: `fin_categorias.parent_id`, `fin_lancamentos.subcategoria_id`).

**R3 — Em hook JSVM, `e.next()` COMMITA. Validar SEMPRE antes.**
Throw APÓS `e.next()` NÃO faz rollback. `e.next()` dentro de `runInTransaction` DEADLOCKA. Padrão do `fin_saldo.pb.js`: `assertXxx()` → `e.next()` → efeito colateral. Razão: descoberta empírica neste binário — ignora essa regra e o banco fica num estado irrecuperável sem restore.

**R4 — Mobile NUNCA tabela. Sempre card por item.**
Qualquer `Table`/`DataTable` ou layout tabular que renderize no APK **ou web estreita (&lt;600dp)** é bug. Padrão: card com nome na linha, métricas abaixo. Razão: feedback direto do dono após ver número de R$ quebrando no meio em tela pequena.

**R5 — Merge ≠ deploy. Nada sobe pra prod sem ordem explícita do dono.**
O dono aprova merges e autoriza cada deploy. Razão: prod tem usuários reais; deploy envolve risco de corrupção SQLite (histórico abaixo).

**R6 — `git add` por path explícito. NUNCA `-A`.**
Razão: evita commitar `pb_data/`, `.env*`, binários, `node_modules`, `dist/`.

**R7 — Deploy web SEMPRE inclui `sw.js` kill-switch em `pb_public/`.**
Fonte: `cleanos/flutter/web/sw.js` (copiado no `flutter build web`). Validar presença no build. Razão: navegadores que ainda tinham Service Worker de um frontend antigo precisam desregistrar cache e carregar o Flutter.

**R8 — NUNCA rsyncar `1700000002_seed.js` para prod.**
Esse arquivo semeia superuser de dev `super@cleanox.local` e dados de teste em prod. Usar rsync aditivo (sem `--delete`) e excluir o seed explicitamente. Razão: aconteceu em prod em 2026-06-30; foi preciso limpar via API.

**R9 — Hooks de rota não enxergam escopo do arquivo. Sempre `require()` dentro do handler.**
Razão: cada `routerAdd` roda em VM isolada — funções do escopo do arquivo não estão disponíveis no handler.

**R10 — Frontend = Flutter only.**
Não recriar app React/Vite/TSX. Não documentar fluxos de dev no frontend legado. Código novo e testes de UI: `cleanos/flutter/`.

---

## 4. FLUXO DE TRABALHO

**Desenvolvimento:**
1. Branch a partir de `main` → commitar → PR → dono aprova e mergeia
2. Mensagens de commit: `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`
3. Gate antes de qualquer PR: `flutter analyze --fatal-infos` (0 issues) + `flutter test` (suíte verde)
4. Dev Flutter web local: `flutter run -d chrome --dart-define=PB_URL=http://127.0.0.1:8090 -t lib/main_painel.dart` (em `cleanos/flutter/`)
5. Dev Android local: `flutter run -d <DEVICE> --dart-define=PB_URL=http://10.0.2.2:8090 -t lib/main_android.dart`

**Deploy produção (VPS via `ssh hostinger`):**
```
# Backup ANTES de qualquer operação de risco:
ssh hostinger "cd /opt/cleanos/pb && ./pocketbase backup create"

# Backend (hooks + migrations):
rsync -az --exclude='1700000002_seed.js' cleanos/pb/pb_hooks/ hostinger:/opt/cleanos/pb/pb_hooks/
rsync -az --exclude='1700000002_seed.js' cleanos/pb/pb_migrations/ hostinger:/opt/cleanos/pb/pb_migrations/
ssh hostinger "cd /opt/cleanos/pb && ./pocketbase migrate up"
ssh hostinger "systemctl restart cleanos.service"

# Frontend Flutter Web:
cd cleanos/flutter
flutter build web --release -t lib/main_painel.dart
# Validar: grep 'app.cleanox.com.br' build/web/main.dart.js >/dev/null
# Validar: ! grep '127.0.0.1:8090' build/web/main.dart.js
# Validar: test -f build/web/sw.js
rsync --delete build/web/ hostinger:/opt/cleanos/pb/pb_public/
ssh hostinger "chown -R ubuntu:ubuntu /opt/cleanos/pb/pb_public"

# Smoke: /api/health == 200 + login real na UI
```

**NUNCA tocar:** Traefik, iptables, `pb_data/` direto, outros apps da VPS (`flowcrm`, `appexcrm`, `mapawenox`).

---

## 5. PRODUÇÃO

**Infra:** VPS Hostinger (IP 181.215.134.11), systemd `cleanos.service`, PocketBase em `0.0.0.0:8090`. TLS + proxy por Traefik do EasyPanel (`/etc/easypanel/traefik/config/cleanox.yaml`) — **não editar esse arquivo à mão** (EasyPanel pode regenerar). URL: https://app.cleanox.com.br

**Backup:** cron nativo PB às 03:30 BRT, retenção 7 dias, armazenado em `pb_data/backups/` **na mesma VPS** (off-site PENDENTE — maior risco residual).

**Histórico de corrupção SQLite (3 episódios — causa raiz ABERTA):**
- Gatilho: `SQLITE_IOERR_SHORT_READ (522)` → escala para `SQLITE_CORRUPT (11)`. Origem provável: virt-storage da VPS / WAL truncation.
- `PRAGMA integrity_check` no modo `ro` deu falso-negativo: NÃO é suficiente para declarar banco são. Testar sempre com o processo vivo.
- **Reparo:** service stop → cópia forense → `sqlite3 .recover` (usar `/opt/cleanos/forensics/tools/sqlite3`, não o do Ubuntu 3.45.1 do APT que vem sem `sqlite_dbpage`) → validação offline (integrity + contagem por coleção + hash por PK) → swap → start → `quick_check` no processo vivo.
- Forense preservada em `/opt/cleanos/forensics/` (`data.db.corrupt-20260708`, `data.db.recovered-good-20260708`, `recover-20260708.sql`).
- **Perda real (08/jul):** `app_config` perdeu 1 linha (token WhatsApp + templates). Dono precisa re-inserir via UI superuser.

**Pendências estruturais abertas:**
- Backup off-site (S3/R2) — PENDENTE (hoje tudo na mesma VPS)
- FCM v1 — `push.js` DEPLOYADO mas inerte; aguardando projeto Firebase + chaves do dono (push.js ainda usa FCM legacy, precisa migrar para HTTP v1)
- 2º superuser na instância — a auditar (identidade desconhecida)
- SMTP + MFA — desligados; sem recuperação de senha
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — falta para publicação automática na Play Store
- Keystore `~/.cleanos-keystore/` — backup externo CRÍTICO pendente com o dono
