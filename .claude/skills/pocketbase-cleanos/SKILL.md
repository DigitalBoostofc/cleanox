---
name: pocketbase-cleanos
description: >-
  Referência autoritativa do PocketBase no projeto CleanOS — como consumir o
  backend pelo SDK Dart `pocketbase` ^0.22 no app Flutter (cleanos/flutter) E
  como escrever/entender o próprio backend PocketBase (cleanos/pb): hooks JS,
  migrations up/down, regras de coleção por papel, rotas custom, cron e as
  convenções anti-desvio. USE SEMPRE que o trabalho tocar qualquer arquivo em
  cleanos/pb (pb_hooks/*.js, pb_migrations/*.js, regras de coleção, rotas
  routerAdd, cronAdd, $http.send, $app.save) OU as camadas de dados do Flutter
  que falam com o PocketBase (lib/core/pb, lib/core/repositories,
  lib/core/models/collections.dart, lib/core/errors, lib/profissional/data,
  qualquer Repository/authWithPassword/pb.filter/subscribe/pb.send/pb.files).
  Acione mesmo que o pedido pareça "só um CRUD", "só ler uma coleção", "só uma
  query" ou "só adicionar um campo" — as convenções de segurança do CleanOS
  (anti-desvio, BRT, servidor como linha de defesa) valem em todos esses casos e
  errar nelas vaza PII do cliente. NÃO acione para trabalho de UI pura do
  Flutter sem acesso a dados, nem para o módulo financeiro do painel que não
  toque PocketBase.
---

# PocketBase no CleanOS

Guia específico do projeto para trabalhar com PocketBase — dos dois lados: o
**backend** em `cleanos/pb` (hooks JS / migrations / regras / rotas / cron) e o
**SDK Dart** `pocketbase: ^0.22.0` no app unificado `cleanos/flutter`.

Não é um manual genérico de PocketBase. Tudo aqui está ancorado nos arquivos
reais do repo — cite-os e siga o padrão deles. Quando este guia e o código
divergirem, o código vence; atualize o guia.

## A regra de ouro (leia primeiro, sempre)

O CleanOS separa dois mundos de dados por um motivo de negócio: o profissional
**nunca** pode contatar o cliente por fora (anti-desvio). Isso vira três
invariantes que valem em TODA mudança, em qualquer camada:

1. **O servidor é a única linha de defesa. O cliente nunca barra — ele só
   traduz o 403.** Regras de coleção + hooks de request retornam 403/400; a UI
   Flutter trata o erro graciosamente (`describeOSError`, `os_error.dart`) e
   **nunca** esconde um botão assumindo que "passou". Se você se pegar validando
   permissão só no Flutter, está errado — a trava tem que existir no PocketBase.

2. **Anti-desvio server-side.** O papel `profissional` **não lê** a coleção
   `clientes` (nem por `expand=cliente`, nem por `filter`/`sort` relacional).
   Telefone/e-mail/sobrenome do cliente **nunca** são copiados para a OS nem
   retornados por nenhuma rota. O endereço completo (`endereco_liberado`) só
   existe durante `em_andamento` e é limpo em qualquer outro status. Campos
   sensíveis e server-only ficam numa **denylist** que o profissional não pode
   gravar.

3. **Fuso BRT (UTC-3) em toda lógica de data.** `data_hora` é gravada em UTC; o
   "dia do serviço", os cortes de cron e o que se mostra ao usuário são
   calculados em BRT (`new Date(Date.now() - 3*3600*1000)`). Nunca compare dias
   em UTC.

Se uma mudança sua puder violar qualquer uma dessas, pare e reveja. Vazar PII do
cliente é o pior bug possível neste projeto.

## Escolha o lado

- **Vou consumir o PocketBase pelo Flutter** (Repository, auth, listagem,
  realtime, upload, rota custom, tratamento de erro) → leia
  `references/dart-sdk.md`.
- **Vou mexer no backend PocketBase** (hook, migration, regra de coleção, rota
  `routerAdd`, `cronAdd`, integração `$http.send`) → leia `references/backend.md`.

Na dúvida, leia os dois — as convenções anti-desvio atravessam a fronteira e o
contrato precisa casar (ex.: a denylist do hook = os campos do `OSExecPatch`).

## Mapa dos arquivos reais (a fonte da verdade)

Backend (`cleanos/pb`):
- `pb_hooks/os_logic.js` — lógica de negócio da OS (módulo CommonJS): denylist do
  profissional (`guardOrdemUpdateRequest`), `manageEndereco`, snapshot imutável,
  `readJsonField` (JSONField em goja), pagamento, repasse, webhook de avaliação.
- `pb_hooks/main.pb.js` — registro de hooks (modelo vs request), guards de
  list/subscribe anti-oráculo, cron `cleanStaleEndereco` e `trackingAvisos`.
- `pb_hooks/whatsapp_routes.pb.js` — rotas custom (`routerAdd` + `$apis.requireAuth()`),
  checagem de dono + status, telefone lido só server-side, respostas sem PII.
- `pb_hooks/ratings_routes.pb.js` — rotas de serviço autenticadas por
  `x-cleanos-secret` (n8n), não por usuário PocketBase.
- `pb_hooks/maps.js`, `pb_hooks/push.js`, `pb_hooks/uazapi.js` — integrações
  externas via `$http.send` com timeout + **degradação graciosa**.
- `pb_hooks/evidencias.pb.js` — dedupe idempotente no create (curto-circuito de request).
- `pb_migrations/*.js` — migrations `migrate(up, down)`; ver `1700000017_tracking_push.js`
  (cria coleção, campos, índice único, regras por papel) e `1700000018_evidencias_idempotency.js`
  (índice único **parcial**).
- `verify_rules.sh` + `tests/integration/anti-desvio.test.mjs` — os gates. Rode-os.

Flutter (`cleanos/flutter/lib`):
- `core/pb/pb_client.dart` — singleton `PocketBase` + `AsyncAuthStore` em secure
  storage + `authRefresh` no boot.
- `core/repositories/ordens_repository.dart` + `repo_types.dart` — padrão
  Repository, `pb.filter`, `getList` paginado, `subscribe`/`UnsubscribeFunc`,
  `OSExecPatch` (espelha a denylist do backend).
- `core/models/collections.dart` — nomes de coleção e enums (`OSStatus`, `Role`…).
  Ponto único de verdade; nunca hardcode string de coleção.
- `core/errors/os_error.dart` + `profissional/data/server_error.dart` —
  `ClientException` → mensagem amigável (0/403/404/corpo).
- `profissional/data/pb_evidencias_repository.dart` — upload multipart + file
  token protegido + `idempotency_key`.
- `profissional/data/pb_tracking_repository.dart`, `pb_whatsapp_repository.dart` —
  rotas custom via `pb.send`.
- Web legado `cleanos/web/src/lib` (`collections.ts`, `pb.ts`, `osStore.ts`) é o
  espelho histórico do contrato — útil de consultar, mas o Flutter é o alvo.

## Env vars (nunca hardcode chaves)

Lidas com `$os.getenv(...)` nos hooks; declaradas em `cleanos.env.example` e, em
produção, em `/opt/cleanos/cleanos.env`:
`UAZAPI_BASE_URL`, `UAZAPI_ADMIN_TOKEN`, `CLEANOS_SERVICE_SECRET`,
`GOOGLE_MAPS_API_KEY`, `FCM_SERVER_KEY`, `N8N_RATING_WEBHOOK_URL`. Se faltar uma
chave, o helper **degrada** (loga e segue), nunca derruba o fluxo.

## Gates e disciplina de deploy

- Toda mudança de regra/hook/anti-desvio passa por: `cleanos/pb/verify_rules.sh`
  (via API REST, com o PocketBase rodando + seed) **e** a suíte
  `cleanos/tests/integration/anti-desvio.test.mjs`. Rode antes de considerar
  pronto.
- Migrations são **aditivas e reversíveis** por padrão (up cria, down desfaz);
  idempotentes quando possível (checar existência antes de criar).
- **Nunca faça deploy sem pedir.** O fluxo de deploy (rsync de hooks + restart) é
  decisão do dono; entregue verificado localmente e peça autorização.

Detalhes práticos e exemplos completos estão nos dois references.
