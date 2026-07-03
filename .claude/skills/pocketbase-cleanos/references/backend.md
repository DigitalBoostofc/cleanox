# Backend PocketBase do CleanOS (`cleanos/pb`)

Como escrever hooks, migrations, regras, rotas e cron seguindo o padrão real do
projeto. PocketBase v0.39 JSVM (goja). Não é um manual genérico — copie a forma
dos arquivos citados.

## Índice
- [Como o JSVM carrega código](#como-o-jsvm-carrega-código)
- [Camadas de hook: modelo vs request](#camadas-de-hook-modelo-vs-request)
- [A denylist do profissional (anti-desvio)](#a-denylist-do-profissional-anti-desvio)
- [Ler JSONField em goja](#ler-jsonfield-em-goja)
- [Endereço efêmero e BRT](#endereço-efêmero-e-brt)
- [Regras de coleção por papel](#regras-de-coleção-por-papel)
- [Migrations up/down e índices](#migrations-updown-e-índices)
- [Rotas custom (`routerAdd`)](#rotas-custom-routeradd)
- [Cron (`cronAdd`)](#cron-cronadd)
- [Integrações externas (`$http.send`) + degradação](#integrações-externas-httpsend--degradação)
- [Gates: verificar antes de entregar](#gates-verificar-antes-de-entregar)

## Como o JSVM carrega código

Cada handler (hook, rota, cron) roda numa **VM isolada** que **não** enxerga o
escopo do arquivo. Por isso:

- Lógica compartilhada mora em módulos CommonJS (`os_logic.js`, `maps.js`,
  `push.js`, `uazapi.js`, `whatsapp_helpers.js`) com `module.exports = {...}`.
- Ela é importada **dentro** de cada handler: `const lib = require(\`${__hooks}/os_logic.js\`);`
- Globais disponíveis no contexto: `$app`, `$os` (`$os.getenv`), `$http`, `$dbx`,
  `Record`, e as classes de erro `BadRequestError` / `ForbiddenError` /
  `UnauthorizedError`.
- Todo arquivo começa com `/// <reference path="../pb_data/types.d.ts" />`.

## Camadas de hook: modelo vs request

Registrados em `main.pb.js`. Duas camadas com propósitos distintos:

- **Hooks de MODELO** (`onRecordCreate`/`onRecordUpdate`) rodam em **qualquer**
  caminho de gravação (API, seed, Admin UI, cron) → garantem consistência
  independentemente de quem grava. É onde vive denormalização de campos seguros,
  gestão de `endereco_liberado`, invariante de pagamento, snapshot imutável.
- **Hooks de REQUEST** (`onRecord*Request`, `onRecordsListRequest`,
  `onRealtimeSubscribeRequest`) rodam só em requisições autenticadas → é onde
  vive a **autorização a nível de campo por papel** (o que as regras de coleção,
  que são por registro, não conseguem expressar).

```js
onRecordUpdate((e) => {
  const lib = require(`${__hooks}/os_logic.js`);
  lib.syncDenormalized(e.app, e.record);
  lib.manageEndereco(e.app, e.record);
  lib.assertPaymentIfConcluida(e.record);
  e.next();                    // persiste
  // efeitos best-effort (push/webhook) DEPOIS do e.next(), em try/catch
}, "ordens_servico");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/os_logic.js`).guardOrdemUpdateRequest(e); // lança 403 se proibido
  e.next();
}, "ordens_servico");
```

Regras: chame `e.next()` para prosseguir. Efeitos colaterais externos
(push, webhook n8n) vão **depois** do `e.next()`, sempre em try/catch — nunca
bloqueiam a gravação. Compare com o estado anterior via `e.record.original()`
para reagir só a **transições** reais (evita disparar em saves repetidos).

## A denylist do profissional (anti-desvio)

`guardOrdemUpdateRequest` (em `os_logic.js`) é o coração da autorização fina.
Padrão a seguir ao adicionar/alterar campos da OS:

1. Ramifica por papel (`e.auth.get("role")`). Admin/gerente têm restrições
   mínimas (só admin mexe em `repasse_*`). Papéis desconhecidos → `ForbiddenError`.
2. Para `profissional`: valida que é o dono **no estado original**
   (`relId(orig.get("profissional")) === auth.id`) e que o status permite ação.
3. **Denylist de campos**: itera `locked[]` + `relLocked[]` e lança
   `ForbiddenError` se qualquer campo travado mudou. Tudo que é server-only ou
   sensível entra aqui: `endereco_liberado`, `service_snapshot`, `repasse_*`,
   coords/carimbos de tracking (`prof_lat`, `aviso_5min_em`…), campos de avaliação.
4. Valida a **transição de status** (`atribuida→em_andamento→concluida` apenas).

**Ao adicionar um campo novo na OS gravado só pelo servidor (rota/cron/hook),
adicione-o à denylist `locked`** — senão o profissional pode forjá-lo via PATCH.
Os campos que ficam **de fora** da denylist são o trabalho legítimo do
profissional: `status`, `valor_pago`, `forma_pagamento`, `checklist_exec`,
`adicionais`, `observacoes_prof`, `descontos`. Esse conjunto **precisa casar** com
o `OSExecPatch` do Flutter (`core/repositories/repo_types.dart`) — se divergir,
ou o app leva 403 à toa, ou abre um furo.

Comparação de campos usa helpers de `os_logic.js`, não `String(get())`:
- `changed(orig, rec, field)` usa `getString()` (estável para JSONField em goja).
- `relId(v)` normaliza relation (single) para id string (trata array/null).

## Ler JSONField em goja

Armadilha crítica: `record.get(jsonField)` devolve um `types.JSONRaw` que o JSVM
expõe como **array de bytes** — iterar/`String()` dá lixo instável. Sempre use
`getString()` (cast []byte→string, texto JSON UTF-8) e então `JSON.parse`. O
helper canônico é `readJsonField(rec, key)` (devolve `null` se vazio/ilegível).
Por isso `changed()` compara via `getString()`.

## Endereço efêmero e BRT

`manageEndereco` só **preenche** `endereco_liberado` na **transição** para
`em_andamento` (compara `orig.status`); em qualquer outro status limpa o campo e
zera as coords de tracking (`clearTrackingCoords`). O cron `cleanStaleEndereco`
limpa OS que ficaram `em_andamento` de um dia BRT anterior.

**Datas em BRT (UTC-3):** o "dia do serviço" e cortes de cron usam
`new Date(Date.now() - 3*3600*1000)` e `.toISOString().slice(0,10)`. Ver
`assertServiceIsToday`. `data_hora` fica em UTC no banco; a conversão para exibir
(relatório) também subtrai 3h. Nunca compare dias em UTC.

## Regras de coleção por papel

Definidas na migration como propriedades da coleção (`col.listRule = ...` etc.),
strings de filtro PocketBase com `@request.auth`. A proteção anti-desvio
principal é uma regra: **o papel `profissional` simplesmente não lê `clientes`**.
Padrão (de `push_tokens`, migration 17) — admin vê tudo, dono vê o seu:

```js
const ADMIN_ONLY = '@request.auth.role = "admin"';
const OWNER      = 'usuario = @request.auth.id';
col.listRule   = ADMIN_ONLY + " || " + OWNER;
col.viewRule   = ADMIN_ONLY + " || " + OWNER;
col.createRule = '@request.auth.id != "" && ' + OWNER;
col.updateRule = '@request.auth.id != "" && ' + OWNER;
col.deleteRule = ADMIN_ONLY + " || " + OWNER;
```

Defesa em profundidade contra oráculo relacional: `main.pb.js` também bloqueia,
para o profissional, `filter`/`sort` que atravessem `cliente.`/`@collection` em
`onRecordsListRequest` e `onRealtimeSubscribeRequest`. Ao criar coleção nova,
pense: qual papel pode ler/gravar cada linha? O default é negar.

## Migrations up/down e índices

Formato `migrate(up, down)`. Aditivas e reversíveis; idempotentes quando dá
(checa existência antes de criar). API v0.39: `collection.fields.add(new
XField({...}))`, `app.save(col)`; campos: `TextField`, `NumberField`,
`DateField`, `SelectField`, `RelationField`, `AutodateField`.

```js
migrate((app) => {
  const col = app.findCollectionByNameOrId("ordserv00000001"); // usa o ID estável
  col.fields.add(new NumberField({ name: "prof_lat", required: false }));
  col.indexes = (col.indexes || []).concat([
    "CREATE UNIQUE INDEX idx_push_tokens_user_plat ON push_tokens (usuario, plataforma)",
  ]);
  app.save(col);
}, (app) => {                    // DOWN: desfaz na ordem inversa
  const col = app.findCollectionByNameOrId("ordserv00000001");
  const f = col.fields.getByName("prof_lat");
  if (f) col.fields.removeById(f.id);
  app.save(col);
});
```

**Índice único parcial** (SQLite `WHERE`) para dedupe sem afetar linhas sem
chave — ver `1700000018_evidencias_idempotency.js`:

```sql
CREATE UNIQUE INDEX `idx_evid_idem` ON `os_evidencias` (`os`, `idempotency_key`)
WHERE `idempotency_key` != ''
```

Coleções são referenciadas por **id estável** (ex.: `"ordserv00000001"`,
`"appconfigwh0001"`, `"pushtokens00001"`), não só pelo nome. O DOWN sempre
envolve as remoções em try/catch para ser tolerante a bases parciais.

## Rotas custom (`routerAdd`)

`routerAdd(method, path, handler, ...middlewares)`. Duas formas de auth no repo:

**Auth de usuário PocketBase** — passe `$apis.requireAuth()` como middleware E
cheque papel/dono dentro do handler (o middleware só garante que há alguém
logado). Padrão de `/a-caminho` e `/relatorio`:

```js
routerAdd("POST", "/api/cleanos/os/{id}/a-caminho", (e) => {
  const lib = require(`${__hooks}/os_logic.js`);
  if (!e.auth) throw new UnauthorizedError("Autenticação necessária.");
  if (String(e.auth.get("role")) !== "profissional")
    throw new ForbiddenError("Rota exclusiva para o papel profissional.");

  const os = $app.findRecordById("ordens_servico", e.request.pathValue("id")); // 404 auto
  if (lib.relId(os.get("profissional")) !== String(e.auth.id))
    throw new ForbiddenError("Você não está atribuído a esta OS.");
  if (os.getString("status") !== "em_andamento")
    throw new BadRequestError("A OS precisa estar em_andamento.");

  // telefone lido do COFRE server-side; NUNCA vai na resposta
  const cliente = $app.findRecordById("clientes", lib.relId(os.get("cliente")));
  const numero  = require(`${__hooks}/uazapi.js`).normalizePhone(cliente.getString("telefone"));

  os.set("aviso_a_caminho_em", /* stamp */); // grava server-side (bypass do guard de request)
  $app.save(os);
  return e.json(200, { ok: true }); // sem PII
}, $apis.requireAuth());
```

**Auth de serviço (n8n)** — sem usuário PocketBase; valida
`x-cleanos-secret` == `$os.getenv("CLEANOS_SERVICE_SECRET")` (headers vêm
normalizados: `x_cleanos_secret`). Se a env var não existir, **todo** request é
401. Ver `ratings_routes.pb.js`.

Invariantes de rota: valide auth → dono → status → dados; leia PII (telefone/
endereço) só do cofre server-side; **nunca** retorne telefone, número, texto com
número, nem o token da instância WhatsApp; body via `e.requestInfo().body`,
path via `e.request.pathValue("id")`.

Escrita server-side (`$app.save`) faz **bypass** do guard de request — por isso a
denylist do profissional protege esses mesmos campos contra PATCH direto.

## Cron (`cronAdd`)

`cronAdd(name, cronExpr, handler)`. Crons no CleanOS são **best-effort** (todo o
corpo em try/catch, nunca lançam), **idempotentes** (carimbos como
`aviso_5min_em`/`aviso_1min_em` impedem reenvio) e cientes de fuso: como a
expressão roda no TZ do processo (UTC na VPS crua, não garantido),
`cleanStaleEndereco` roda de hora em hora (`5 * * * *`) e corta por **dia BRT**
para cobrir a virada independentemente do TZ.

Otimização de quota: `trackingAvisos` resolve config/status **uma vez por
rodada** e **pula o loop inteiro** se o WhatsApp não está `connected`, antes de
chamar a API paga do Google por OS. Filtre candidatos com `$dbx.hashExp({...})` e
gates baratos primeiro.

## Integrações externas (`$http.send`) + degradação

Toda chamada externa (`maps.js`, `push.js`, `uazapi.js`) segue o mesmo contrato:

- Chave via `$os.getenv(...)` — **nunca hardcode**. Chave ausente → **loga e
  retorna null/skip** (degradação graciosa), nunca lança.
- `$http.send({ method, url, headers, body: JSON.stringify(...), timeout })` com
  `timeout` sempre setado (5–8s). Cheque `res.statusCode` e `res.json`.
- Falha de rede/HTTP → loga (`console.error`, cortando o corpo em ~200 chars) e
  retorna null/`{ ok:false }`. O fluxo de negócio (concluir OS, atribuir) nunca
  quebra por causa de uma integração fora.

```js
function geocode(endereco) {
  const key = $os.getenv("GOOGLE_MAPS_API_KEY") || "";
  if (!key) { console.log("[maps] key ausente; pulado."); return null; }
  try {
    const res = $http.send({ method: "GET", url, timeout: 8 });
    if (res.statusCode < 200 || res.statusCode >= 300) { console.error(...); return null; }
    // ...
  } catch (err) { console.error("[maps] falhou (ignorado): " + err); return null; }
}
```

## Gates: verificar antes de entregar

1. `cd cleanos/pb && ./verify_rules.sh` — exercita as garantias anti-desvio pela
   API REST (precisa do PocketBase rodando + migrations/seed aplicadas + `jq`).
   Cobre: profissional não lê `clientes` (list/view), OS sem PII, endereço só em
   `em_andamento` e limpo na conclusão, campos travados bloqueados, criação de OS
   negada, day-check, admin vê tudo.
2. `cleanos/tests/integration/anti-desvio.test.mjs` — a suíte de integração.
3. Confirme que a denylist do backend e o `OSExecPatch` do Flutter continuam
   casando.
4. **Não faça deploy.** Entregue verificado localmente e peça autorização ao dono
   (o deploy é rsync de hooks + restart do serviço, decisão dele).
