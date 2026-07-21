# CleanOS — DNA do Projeto

> **Fonte da verdade operacional** para devs e agentes.  
> Medido em **2026-07-14** contra repositório local, `origin/main` e produção
> (`ssh hostinger` + `https://app.cleanox.com.br/api/health`).  
> Spec de negócio / MVP: `docs/MVP-BUILD-SPEC.md`. Contrato PB: `cleanos/pb/README.md`.

> **Stack canônica: Flutter + PocketBase.** Todo frontend é Flutter
> (`cleanos/flutter/`). Não existe frontend React no repositório. Novas
> features, fixes, QA e orientações a agentes/devs são **sempre em Flutter**.

---

## 1. O QUE É

Ferramenta **interna** de gestão para empresa de **higienização de estofados a
domicílio** (sofá, poltrona, colchão, cadeira, tapete). Volume esperado baixo
(&lt; 50 OS/mês). Marca: **Cleanox** / produto: **CleanOS**.

### Dor central (requisito de primeira classe)

O profissional detém o cliente no mundo real e pode virar concorrente levando a
base. O CleanOS mantém **cliente, comunicação e dinheiro com a MARCA**:

1. **Dinheiro na empresa** — cliente paga na maquininha do CNPJ (débito / crédito /
   Pix maquininha). Sem gateway online, sem split, sem link de pagamento.
2. **Profissional sem contato do cliente** — telefone **nunca** exposto; endereço
   completo só durante `em_andamento` no dia do serviço; comunicação WhatsApp sai
   do número da empresa.

A proteção é na **API (regras de coleção + hooks)**, nunca só na UI.

### Superfícies (todas Flutter)

| Superfície | Entrypoint | `AppSurface` | Quem usa | Onde roda |
|---|---|---|---|---|
| **Painel web** | `lib/main_painel.dart` | `painel` | admin / gerente | Flutter Web em `pb_public/` → https://app.cleanox.com.br |
| **APK unificado** | `lib/main_android.dart` | `android` | admin + gerente + profissional | Package `br.com.wenox.cleanos`; CI/release usam **só este** |
| App prof (legado) | `lib/main_profissional.dart` | `profissional` | só profissional | Dev local; **não** é o release |

Roteamento por papel em `app_router.dart` → `homeForRole`:
- `profissional` → `/app`
- `admin` / `gerente` → `/painel`

### UI responsiva (Fintech Clean)

- **APK:** sempre tema + casco fintech (painel: bottom nav 5 itens).
- **Web estreita (&lt; 600dp):** mesmo visual fintech do APK (login, casco, hero de saldo, empty states, checklist).
- **Web ≥ 600dp (tablet/desktop):** layout clássico do painel (sidebar/rail) — intencional.

### Papéis (`users.role`)

| Role | Acesso |
|---|---|
| `admin` | Painel completo + WhatsApp admin + marca repasse/comissão paga |
| `gerente` | Painel como admin, **exceto** WhatsApp admin e algumas ações de repasse |
| `profissional` | Só app `/app` (visão de job das **suas** OS) |
| `_superuser` | Admin UI do PocketBase (devops) — **não** é papel de negócio |

---

## 2. STACK & ESTRUTURA

```
cleanox/                          ← monorepo
  CLAUDE.md                       ← ESTE DNA
  docs/                           ← specs, ADRs, checklists (parte histórica React)
  usability-findings.md           ← contrato QA Vision Lab
  .github/workflows/
    android-release-profissional.yml
    hooks-tests.yml               ← gate unitário dos hooks PB (na main)
  cleanos/
    flutter/                      ← ÚNICO frontend (Web + Android)
    pb/                           ← PocketBase (hooks, migrations, binário)
    tests/                        ← anti-desvio + unitários de hooks
```

### Flutter — `cleanos/flutter/`

| Item | Valor medido |
|---|---|
| SDK | `~/flutter-sdk` · **3.35.5** (CI pin `FLUTTER_VERSION: '3.35.5'`) |
| Dart | 3.9.2 (`sdk: ^3.9.2`) |
| State | Riverpod (`flutter_riverpod` + `riverpod_annotation`) |
| Router | go_router |
| Backend SDK | `pocketbase: ^0.22.0` |
| Models | freezed + json_serializable em `lib/core/models/` |
| Auth token | `flutter_secure_storage` (nunca SharedPreferences) |
| Fontes | Sora (marca petrol+cyan) |
| Locale | pt_BR fixo |
| Versão `main` | **1.2.0+21** (auto-bump CI) |
| Versão web em prod | **1.2.0+20** (`pb_public/version.json`, medido 14/07) |

**Arquitetura de pastas:**

```
lib/
  main_*.dart              entrypoints
  app.dart                 CleanosApp + AppSurface
  core/                    models, repos (interfaces), auth, design, router, env, pb
  painel/                  UI + data PB do painel (admin/gerente)
  profissional/            UI + data do app do profissional
  features/login/          login compartilhado
  shared_widgets_os/       checklist, evidências, laudo PDF, relatórios
```

**Repos (interfaces)** em `lib/core/repositories/`; implementações PB em
`lib/painel/data/` e `lib/profissional/data/`.

**Orientação a agentes:** editar só `cleanos/flutter/` e `cleanos/pb/`. Nunca
propor React, Vite, TSX. Referências a React em `docs/` ou findings antigos =
histórico.

### Módulos de produto (Flutter)

**Painel** (`/painel/*`):

| Seção | Rota | Função |
|---|---|---|
| Dashboard | `/painel/dashboard` | Resumo do dia / operação |
| Clientes | `/painel/clientes` | Cofre de clientes (LGPD / anti-desvio) |
| Ordens | `/painel/ordens` | OS por status + form + execução admin |
| Agenda | `/painel/agenda` | Calendário estilo Google (dia/semana/mês) |
| Financeiro | `/painel/financeiro/*` | Visão, lançamentos, carteiras, categorias, comissões, limites, relatórios |
| Serviços | `/painel/servicos` | Catálogo + checklist |
| Usuários | `/painel/usuarios` | admin/gerente/profissional + disponibilidade |
| Avaliações | `/painel/avaliacoes` | Ratings |
| WhatsApp | `/painel/whatsapp` | **admin-only** |
| Conta | `/painel/conta` | Perfil / tema |

**App profissional** (`/app/*`):

| Aba | Rota | Função |
|---|---|---|
| Meus serviços | `/app` | Lista do dia + execução OS |
| Financeiro | `/app/financeiro` | Estimativa / comissões do prof |
| Mapa | `/app/mapa` | Rotas (Maps externo) |
| Perfil | `/app/perfil` | Conta do profissional |

**Flags de ambiente** (`Env` / `--dart-define`):

| Flag | Default | Estado |
|---|---|---|
| `PB_URL` | `https://app.cleanox.com.br` | Prod embutido no release |
| `TRACKING_ENABLED` | `false` | GPS/foreground — código presente, flag off |
| `PUSH_ENABLED` | `false` | FCM client — stub até gate do dono |
| `GOOGLE_MAPS_API_KEY` | `''` | Server-side em `cleanos.env` / Maps helper |

### PocketBase — `cleanos/pb/`

| Item | Valor medido |
|---|---|
| Binário | **v0.39.4** (local e prod) |
| Hooks | `pb_hooks/` · 21 arquivos · JSVM + `require()` de libs |
| Migrations | `pb_migrations/` · até `1700000028_comissao_despesa.js` |
| Credenciais prod | `/opt/cleanos/cleanos.env` (EnvironmentFile do systemd) — **nunca no repo** |
| Frontend web prod | `/opt/cleanos/pb/pb_public/` (rsync do `flutter build web`) |
| Contrato | `cleanos/pb/README.md` |

### Coleções de negócio (prod = schema vivo)

```
users (auth)          role, nome, avatar, comissão, whatsapp…
clientes              🔒 COFRE — profissional NEGADO em tudo
servicos              catálogo + checklist
ordens_servico        job + snapshot + endereco_liberado efêmero
config_atuacao        área de atuação (singleton operacional)
disponibilidade       agenda do profissional
os_evidencias         fotos antes/depois (idempotency_key)
prof_comissoes        comissão gerada ao concluir OS
fin_contas            carteiras (saldo_atual só server-side)
fin_categorias        plano de contas
fin_lancamentos       receitas/despesas (incl. via_os)
fin_limites           limites de gasto
app_config            singleton (WhatsApp, templates, Meta CAPI…)
push_tokens           tokens FCM por usuário
```

Sistema PB: `_superusers`, `_authOrigins`, `_externalAuths`, `_mfas`, `_otps`.

### Hooks (`pb_hooks/`) — mapa

| Arquivo | Papel |
|---|---|
| `main.pb.js` | OS: denorm, endereço efêmero, travas de request, repasse |
| `os_logic.js` | Lógica anti-desvio da OS (CommonJS) |
| `os_servicos.pb.js` | Snapshot imutável serviço + evidências |
| `os_financeiro.pb.js` + `_lib` | OS concluída → receita `via_os` |
| `fin_saldo.pb.js` + `_lib` | Saldo atômico + guard `saldo_atual` |
| `fin_routes.pb.js` | `POST …/fin/conta/{id}/ajuste`, `POST …/fin/transferencia` |
| `prof_comissao_lib.js` | Gera `prof_comissoes` ao concluir OS |
| `prof_comissao_pago.pb.js` + `_lib` | Comissão paga → despesa real (F-231) |
| `prof_delete.pb.js` + `_lib` | Delete seguro de profissional |
| `evidencias.pb.js` | Idempotência de upload |
| `whatsapp_routes.pb.js` + helpers + `uazapi.js` | WhatsApp / a-caminho / relatório |
| `ratings_routes.pb.js` | Ingest de avaliação + config templates |
| `meta_capi_lib.js` | Meta CAPI (Schedule / Purchase / Lead) — **versionado** |
| `maps.js` | Google Maps helper (degradação graciosa) |
| `push.js` | FCM **HTTP v1** (inerte sem `FCM_PROJECT_ID` + `FCM_ACCESS_TOKEN`) |

### Rotas custom (`/api/cleanos/…`)

- Financeiro: `POST /fin/conta/{id}/ajuste`, `POST /fin/transferencia`
- WhatsApp: status, connect, disconnect, config
- OS: `POST /os/{id}/a-caminho`, `/relatorio`, `/posicao`, `/cheguei`
- Ratings: `POST /ratings/ingest`, `GET /ratings/pending`
- Push: `POST /push/register`

### Migrations relevantes (últimas)

| ID | O quê |
|---|---|
| 20 | Índices de performance em `ordens_servico` |
| 21 | Conta padrão única (`padrao=true`) |
| 22 | OS.cliente obrigatório |
| 23 | Comissão do profissional |
| 24 | Avatar de users |
| 25 | Meta CAPI (idempotente) |
| 26 | Origem do lead em clientes |
| 27 | Duração de OS |
| 28 | Comissão paga como despesa |

**Nunca** rsyncar `1700000002_seed.js` para prod (R8).

### Testes

| Camada | Onde | CI |
|---|---|---|
| Flutter unit/widget | `cleanos/flutter/test/` (~80 arquivos) | Sim — job Android (se path Flutter) |
| Hooks unitários | `cleanos/tests/integration/*.unit.test.mjs` | Sim — `hooks-tests.yml` (paths `pb/**`) |
| Anti-desvio E2E API | `anti-desvio.test.mjs` | **Não** no CI (precisa PB vivo + secrets; dívida conhecida) |

### CI

1. **`android-release-profissional.yml`** — Flutter 3.35.5, entrypoint `main_android.dart`, package `br.com.wenox.cleanos`. Gate `analyze --fatal-infos` + `test`. Auto-bump `+N` em push main. Assina se secrets de keystore. Play só se `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` existir (**hoje: publish skipped**).
2. **`hooks-tests.yml`** (main) — Node 22, `npm run test:unit` em PRs/pushes que tocam `cleanos/pb/**` ou `cleanos/tests/**`.

---

## 3. REGRAS INVIOLÁVEIS

**R1 — Saldo é server-side atômico; Flutter NUNCA muta `saldo_atual`.**  
`PbFinanceiroRepository` omite `saldo_atual` do body. Ajustes só via
`POST /api/cleanos/fin/conta/{id}/ajuste`. Razão: lost-update em concorrência.

**R2 — Campo opcional no PB guarda `""`, NUNCA `null`.**  
Comparar `!= ""`. Normalizar `"" → null` no `fromRecord`, não nos call sites.

**R3 — Em hook JSVM, `e.next()` COMMITA.**  
Throw depois de `e.next()` não faz rollback. `e.next()` dentro de
`runInTransaction` deadlocka. Padrão: validar → `e.next()` → efeito colateral.

**R4 — Mobile NUNCA tabela. Sempre card por item.**  
Vale para APK **e** web estreita (&lt; 600dp).

**R5 — Merge ≠ deploy.** Nada sobe pra prod sem ordem explícita do dono.

**R6 — `git add` por path explícito. NUNCA `-A`.**  
Evita `pb_data/`, `.env*`, binários, `node_modules`, `dist/`.

**R7 — Deploy web SEMPRE inclui `sw.js` kill-switch em `pb_public/`.**  
Fonte: `cleanos/flutter/web/sw.js`.

**R8 — NUNCA rsyncar `1700000002_seed.js` para prod.**

**R9 — Hooks de rota: `require()` dentro do handler.**  
Cada `routerAdd` roda em VM isolada.

**R10 — Frontend = Flutter only.**

**R11 — Deploy de hook é cirúrgico (`scp` do arquivo). NUNCA rsyncar `pb_hooks/` inteiro.**

**R13 — Deploy web do painel SEMPRE passa o gate da Agenda.**  
Antes de `flutter build web` + rsync:  
`bash cleanos/scripts/assert-agenda-features.sh`  
Garante cards serviço/valor/bairro, showOSDetail + Editar, colunas por profissional.

Estado **medido** em 14/07/2026 (revalidado nesta análise):

```bash
rsync -az --delete hostinger:/opt/cleanos/pb/pb_hooks/ /tmp/prodhooks-fresh/
diff -rq /tmp/prodhooks-fresh/ cleanos/pb/pb_hooks/   # vazio: 21 arquivos, byte-idênticos
```

Prod e repo em **paridade**. Drift antigo do Meta CAPI (`meta_capi_lib.js` só em
prod; hooks divergentes) foi **fechado** pelos PRs #40/#43. A premissa “prod roda
código que não está no repo” **não vale mais** — mas a regra de deploy cirúrgico
continua:

1. `rsync` da pasta apaga em prod qualquer hook de emergência fora do repo.
2. Hot-reload: um arquivo alterado = 1 restart; rsync da pasta = N restarts.

**Sempre diffar com diretório FRESCO e `rsync --delete`.** Espelho velho sem
`--delete` mente.

**R12 — Nunca deduzir o que a CI faz lendo só o `on:` do workflow. Conferir o run.**

| push na `main` que toca… | `build-and-release` | auto-bump | Play publish |
|---|---|---|---|
| `cleanos/flutter/**` ou o workflow Android | roda | sim | **NÃO** (secret Play ausente) |
| só backend / docs / `cleanos/pb/**` | **skipped** | não | não |

Filtro de path: `dorny/paths-filter` no job `setup`, **não** no `on:`.  
Checagem: `gh run view <id> --json jobs -q '…'`.

---

## 4. FLUXO DE TRABALHO

### Desenvolvimento

1. Branch a partir de `main` → commit → PR → dono aprova e mergeia.
2. Co-author em commits de agente: `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` (ou o autor do agente em uso).
3. **Gate antes de PR:**
   - `flutter analyze --fatal-infos` + `flutter test` (CI Android se path Flutter).
   - Se tocou `cleanos/pb/**`: `cd cleanos/tests && npm run test:unit` (CI `hooks-tests.yml` na main).
   - `anti-desvio.test.mjs` precisa de PB vivo; ~10 casos de ratings/dispatch/seed falham por ambiente — dívida conhecida, não trate como regressão de feature sem medir.
4. Dev web:  
   `flutter run -d chrome --dart-define=PB_URL=http://127.0.0.1:8090 -t lib/main_painel.dart`  
   (em `cleanos/flutter/`)
5. Dev Android:  
   `flutter run -d <DEVICE> --dart-define=PB_URL=http://10.0.2.2:8090 -t lib/main_android.dart`
6. PB local: `cd cleanos/pb && ./pocketbase serve --http=127.0.0.1:8090`

### Deploy produção (`ssh hostinger`)

```bash
# 1) Backup ANTES de risco (CLI `backup create` NÃO existe nesta build)
ssh hostinger "cd /opt/cleanos/pb && mkdir -p /opt/cleanos/predeploy-\$(date +%F) && \
  /opt/cleanos/forensics/tools/sqlite3 pb_data/data.db \
  \".backup '/opt/cleanos/predeploy-\$(date +%F)/data.db'\" && \
  tar czf /opt/cleanos/predeploy-\$(date +%F)/pb_public.tar.gz -C /opt/cleanos/pb pb_public"

# 2) Diff hooks (diretório FRESCO + --delete)
rm -rf /tmp/prodhooks-fresh && mkdir -p /tmp/prodhooks-fresh
rsync -az --delete hostinger:/opt/cleanos/pb/pb_hooks/ /tmp/prodhooks-fresh/
diff -rq /tmp/prodhooks-fresh/ cleanos/pb/pb_hooks/

# 3) Hooks: CIRÚRGICO (R11)
scp cleanos/pb/pb_hooks/<arquivo>.js hostinger:/opt/cleanos/pb/pb_hooks/

# 4) Migrations: aditivo, sem --delete, sem seed (R8)
rsync -az --exclude='1700000002_seed.js' \
  cleanos/pb/pb_migrations/ hostinger:/opt/cleanos/pb/pb_migrations/
ssh hostinger "cd /opt/cleanos/pb && ./pocketbase migrate up"
ssh hostinger "systemctl restart cleanos.service"

# 5) Frontend web
bash cleanos/scripts/assert-agenda-features.sh   # R13
cd cleanos/flutter
flutter build web --release -t lib/main_painel.dart
# Validar: app.cleanox.com.br no main.dart.js; SEM 127.0.0.1:8090; sw.js presente
rsync --delete build/web/ hostinger:/opt/cleanos/pb/pb_public/
ssh hostinger "chown -R ubuntu:ubuntu /opt/cleanos/pb/pb_public"

# 6) Smoke: /api/health == 200 + login real na UI
```

**NUNCA tocar:** Traefik/EasyPanel (`/etc/easypanel/traefik/config/cleanox.yaml`),
iptables, `pb_data/` direto, outros apps da VPS (`flowcrm`, `appexcrm`, `mapawenox`).

---

## 5. PRODUÇÃO vs LOCAL (snapshot 2026-07-14)

### Produção

| Item | Valor medido |
|---|---|
| URL | https://app.cleanox.com.br |
| Health | `GET /api/health` → **200** `API is healthy.` |
| Host | VPS Hostinger · IP **181.215.134.11** |
| Serviço | `systemd cleanos.service` · **active** · User=root |
| Bind PB | `0.0.0.0:8090` + TLS/proxy Traefik EasyPanel |
| Env | `/opt/cleanos/cleanos.env` |
| PB | 0.39.4 |
| `pb_hooks` | **== repo** (21 arquivos) |
| Migrations | até **0028** presente |
| Web | Flutter em `pb_public/` · `sw.js` **sim** · version **1.2.0+20** |
| `pb_data` | ~21 MB |
| VPS RAM/disco | 7.8 Gi / 96 G (~57% usado) |

**Contagens de negócio (aprox., prod):**

| Coleção | n |
|---|---|
| users | 6 |
| clientes | 4 |
| servicos | 33 |
| ordens_servico | 4 |
| fin_contas | 2 |
| fin_lancamentos | 1 |
| fin_categorias | 41 |
| app_config | 1 |
| config_atuacao | 1 |
| disponibilidade | 2 |
| os_evidencias | 0 |

Ambiente ainda **pequeno / early production** — não é só seed de dev, mas volume baixo.

**Backup:** auto PB `@auto_pb_backup_acme_*` ~03:30 (visto `…20260714033000.zip`) em
`pb_data/backups/` **na mesma VPS**. Off-site **PENDENTE** (maior risco residual).
Predeploys manuais em `/opt/cleanos/predeploy-*`. Forense SQLite em `/opt/cleanos/forensics/`.

### Local (máquina de dev)

| Item | Valor medido |
|---|---|
| Branch de trabalho (exemplo) | `fix/qa-painel-os` (pode estar **atrás** de `origin/main`) |
| PB | `127.0.0.1:8090` · **healthy** · `./pocketbase` 0.39.4 |
| Flutter | 3.35.5 / Dart 3.9.2 |
| `pb_hooks` workspace | em paridade com prod (mesmos 21 arquivos no tree atual) |
| Atenção | Sempre `git fetch` + comparar com `origin/main` antes de afirmar “estado do projeto” — worktrees e branches de QA divergem |

### Histórico de corrupção SQLite (causa raiz ABERTA)

- Gatilho: `SQLITE_IOERR_SHORT_READ (522)` → `SQLITE_CORRUPT (11)`. Origem provável: virt-storage / WAL.
- `PRAGMA integrity_check` em modo `ro` deu falso-negativo — validar com processo **vivo**.
- Reparo: stop → cópia forense → `sqlite3 .recover` com **`/opt/cleanos/forensics/tools/sqlite3`** (não o sqlite do APT sem `sqlite_dbpage`) → validar → swap → start.
- Perda real 08/jul: linha de `app_config` (token WhatsApp + templates).

### Pendências estruturais abertas

| Item | Estado |
|---|---|
| Backup off-site (S3/R2) | PENDENTE |
| FCM em produção | Código **HTTP v1** deployado; inerte sem `FCM_PROJECT_ID` + `FCM_ACCESS_TOKEN` + projeto Firebase do dono |
| Tracking GPS no app | Código atrás de `TRACKING_ENABLED=false` |
| 2º superuser na instância | Auditar identidade |
| SMTP + MFA | Desligados; sem recuperação de senha |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Ausente → merge **não** publica na Play |
| Backup externo do keystore | CRÍTICO pendente com o dono |
| `anti-desvio` E2E no CI | Dívida (precisa PB + secrets estáveis) |
| iOS | Fora de escopo (gate conta Apple) |

---

## 6. FLUXO DE UMA OS (ponta a ponta)

```
Lead (WhatsApp / telefone / indicação)
  → Painel cadastra cliente (+ origem) e cria OS (agendada)
  → Atribui profissional (atribuida) + agenda por disponibilidade
  → Prof vê "visão de job": nome parcial, bairro, horário, serviço
  → No dia: Iniciar → em_andamento → hook libera endereco_liberado
  → A-caminho / cheguei (WhatsApp empresa + posicao opcional)
  → Checklist + evidências + pagamento (débito/crédito/pix maquininha)
  → Concluir → concluida
       ├─ os_financeiro → receita fin_lancamentos (via_os) + saldo atômico
       ├─ prof_comissao → prof_comissoes (se % ou fixo)
       └─ meta_capi → Purchase (se valor_pago > 0)
  → Admin marca comissão paga → despesa real + debita saldo (F-231)
  → Endereço some do histórico do prof
```

Status canônicos: `agendada` → `atribuida` → `em_andamento` → `concluida` | `cancelada`.

---

## 7. O QUE NÃO É ESTE PROJETO

- Não é SaaS multi-tenant.
- Não é React/Vite/PWA (legado de docs).
- Não é gateway de pagamento / split / Asaas (histórico de spec).
- Não é app iOS (ainda).
- Não é CRM genérico — é operação de limpeza com anti-desvio e caixa real.

---

*Última medição de paridade hooks prod↔repo e health: 2026-07-14. Atualizar este DNA quando a medição mudar — não quando a intuição mudar.*
