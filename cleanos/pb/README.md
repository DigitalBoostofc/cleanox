# CleanOS — Backend (PocketBase)

Backend da ferramenta interna **CleanOS** (projeto Cleanox), uma empresa de
higienização de estofados a domicílio (< 50 OS/mês). Stack conforme **ADR-003**:
PocketBase (Go + SQLite, binário único) numa VPS, atrás de proxy HTTPS, servindo
um PWA React/Vite por papel.

> **Fonte da verdade do escopo:** `../../docs/MVP-BUILD-SPEC.md`.
> Os docs `04` e `08` são histórico (citam Asaas/Flutter/GPS/split — REMOVIDOS).

---

## 1. O porquê — anti-desintermediação (REQUISITO DE PRIMEIRA CLASSE)

O problema central: hoje o profissional detém o cliente e pode sair e virar
concorrente levando a base. O CleanOS mantém **cliente, comunicação e dinheiro
com a MARCA**, tornando o profissional um executor anonimizado.

**A proteção do contato do cliente é imposta na API (regras de coleção + hooks),
NUNCA só na UI.** Esconder no front não protege — o profissional abre o navegador
e vê o JSON. As garantias abaixo são impostas pelo PocketBase:

1. O contato sensível do cliente (telefone, e-mail, sobrenome, endereço completo)
   fica na coleção **`clientes`**, que o papel `profissional` **não lê de forma
   alguma**.
2. O profissional só enxerga uma **"visão de job"**: primeiro nome + inicial
   ("Carlos S."), tipo de serviço, **bairro** e horário.
3. O **endereço completo** é liberado ao profissional **somente** quando a OS vira
   `em_andamento` (ao tocar "Iniciar"), **no dia do serviço**; ao virar
   `concluida`/`cancelada` o endereço é re-restringido (some do histórico dele).
4. O **telefone NUNCA** é exposto ao profissional em nenhum estado.

> ⚠ **Atenção arquitetural:** as regras do PocketBase são a **nível de registro**,
> não de campo. Se o profissional pode ver um registro, ele vê TODOS os campos.
> Por isso o dado sensível **nunca** é gravado num registro que o profissional
> possa ler: ele vive só em `clientes` (negada) e o endereço efêmero é copiado
> para a OS por hook apenas durante `em_andamento`. Telefone jamais é copiado.

---

## 2. Como rodar

### 2.1 Local (desenvolvimento)

```bash
cd cleanos/pb

# 1) baixar o binário (não versionado) — Linux amd64, v0.39.4
curl -sL -o pb.zip \
  https://github.com/pocketbase/pocketbase/releases/download/v0.39.4/pocketbase_0.39.4_linux_amd64.zip
unzip -o pb.zip && rm pb.zip

# 2) aplicar schema + seed (idempotente; cria pb_data)
./pocketbase migrate up

# 3) subir o servidor
./pocketbase serve --http=127.0.0.1:8090
#   REST API:  http://127.0.0.1:8090/api/
#   Admin UI:  http://127.0.0.1:8090/_/   (login com o _superuser do seed)
```

Para **recomeçar do zero** (banco limpo + seed): pare o servidor, mova/apague
a pasta `pb_data/` e rode `./pocketbase migrate up` de novo.

### 2.2 Verificar as regras anti-desvio (pela API, não pela UI)

Com o servidor rodando e o seed aplicado:

```bash
./verify_rules.sh        # 21 checagens; espera "TODAS AS GARANTIAS ... VERIFICADAS"
```

### 2.3 Produção (VPS) — esperado para a fase de deploy

- Rodar como serviço **systemd** (`Restart=always`), usuário dedicado sem shell.
- **Proxy HTTPS** (Caddy recomendado pela simplicidade do TLS automático, ou
  Nginx) na frente, encaminhando 443 → `127.0.0.1:8090`. O PocketBase **não**
  deve ficar exposto direto.
- Esqueleto systemd (`/etc/systemd/system/cleanos.service`):

  ```ini
  [Unit]
  Description=CleanOS PocketBase
  After=network.target

  [Service]
  Type=simple
  User=cleanos
  WorkingDirectory=/opt/cleanos/pb
  ExecStart=/opt/cleanos/pb/pocketbase serve --http=127.0.0.1:8090
  Restart=always
  RestartSec=3

  [Install]
  WantedBy=multi-user.target
  ```

- Esqueleto Caddy (`/etc/caddy/Caddyfile`):

  ```
  cleanos.suaempresa.com.br {
      reverse_proxy 127.0.0.1:8090
  }
  ```

### 2.4 Backup do `pb_data`

Todo o estado vive em `pb_data/` (SQLite + uploads). Estratégia mínima:

- **Backup nativo** pelo Admin UI/CLI: `./pocketbase` cria snapshots consistentes;
  ou use o endpoint de backup do Admin UI (`Settings → Backups`) com agendamento.
- **Backup por arquivo:** parar o serviço (ou usar o backup nativo, que lida com
  WAL) e copiar `pb_data/` para fora da VPS (rsync/objeto S3) **diariamente**.
- `pb_data/` contém o **cofre de clientes** (dado sensível LGPD) → o destino do
  backup deve ser criptografado e com acesso restrito.
- **Restore:** parar o serviço, restaurar `pb_data/`, subir de novo.

---

## 3. Papéis e credenciais de teste (seed)

Todos os papéis de negócio vivem na coleção auth **`users`** (campo `role`).
O **`_superuser`** é só para administrar a plataforma (Admin UI/devops), não é o
"admin" de negócio.

| Papel (role)   | E-mail                   | Senha           | Vê o quê (resumo)                                   |
|----------------|--------------------------|-----------------|----------------------------------------------------|
| _superuser     | super@cleanox.local      | `cleanox-super-123` | Tudo (Admin UI) — uso devops                   |
| admin          | admin@cleanox.local      | `cleanox123`    | Tudo no app; único que marca repasse               |
| gerente        | gerente@cleanox.local    | `cleanox123`    | Como admin, exceto marcar repasse                  |
| profissional   | pedro@cleanox.local      | `cleanox123`    | Só "visão de job" das SUAS OS                      |
| profissional   | lucas@cleanox.local      | `cleanox123`    | Só "visão de job" das SUAS OS                      |

> **Senhas de seed são para teste. Trocar antes de qualquer ambiente real.**

Autenticação (frontend):
`POST /api/collections/users/auth-with-password` com `{ "identity": email, "password": ... }`
→ retorna `{ token, record }`. Enviar `Authorization: <token>` nas próximas chamadas
(o PocketBase aceita o token **cru**, sem o prefixo `Bearer`).

---

## 4. CONTRATO DE COLEÇÕES (canônico — para o frontend)

Tipos PocketBase usados: `text`, `email`, `number`, `bool`, `select`, `date`,
`relation`, `autodate`. Toda coleção tem `id` (text, 15 chars) e, onde indicado,
`created`/`updated` (autodate, ISO `YYYY-MM-DD HH:MM:SS.000Z`).

Legenda de visibilidade: **A**=admin, **G**=gerente, **P**=profissional.
"P (própria)" = só nos registros de OS atribuídos a ele.

### 4.1 `users` (auth) — colaboradores e gestores

| Campo            | Tipo    | Obrig. | Notas                                                  |
|------------------|---------|--------|--------------------------------------------------------|
| id               | text    | —      | PK                                                     |
| email            | email   | sim    | login                                                  |
| password         | password| sim    | nunca retornado pela API                               |
| verified         | bool    | —      | auth padrão                                            |
| emailVisibility  | bool    | —      | manter `false`                                         |
| name             | text    | —      | nome (campo auth padrão)                               |
| **role**         | select  | sim    | `admin` \| `gerente` \| `profissional`                 |
| **nome**         | text    | —      | nome de exibição do colaborador                        |
| created/updated  | autodate| —      |                                                        |

**Regras de acesso**
- list: A, G
- view: A, G, **e o próprio usuário** (`id = @request.auth.id`)
- create: A, G
- update: A, G, **e o próprio** (mas o hook impede o próprio mudar `role`/`email`)
- delete: A

### 4.2 `clientes` (base) — 🔒 COFRE (dado sensível, profissional NEGADO)

| Campo                  | Tipo    | Obrig. | Sensível | Notas                          |
|------------------------|---------|--------|----------|--------------------------------|
| id                     | text    | —      |          | PK                             |
| nome                   | text    | sim    |          | primeiro nome                  |
| sobrenome              | text    | —      | ✅       |                                |
| telefone               | text    | sim    | ✅✅     | **nunca** exposto ao prof      |
| email                  | email   | —      | ✅       |                                |
| endereco_rua           | text    | —      | ✅       |                                |
| endereco_numero        | text    | —      | ✅       |                                |
| endereco_complemento   | text    | —      | ✅       |                                |
| endereco_bairro        | text    | sim    | —        | seguro → vira `bairro` na OS   |
| endereco_cidade        | text    | —      | ✅       |                                |
| endereco_cep           | text    | —      | ✅       |                                |
| ativo                  | bool    | —      |          |                                |
| observacoes            | text    | —      | ✅       |                                |
| created/updated        | autodate| —      |          |                                |

**Regras de acesso** — list/view/create/update: **A, G** · delete: **A** ·
**P: negado em tudo** (esta é a trava central anti-desvio).

### 4.3 `servicos` (base) — catálogo (não sensível)

| Campo           | Tipo    | Obrig. | Notas                                       |
|-----------------|---------|--------|---------------------------------------------|
| id              | text    | —      | PK                                          |
| nome            | text    | sim    | ex.: "Sofá 3 lugares"                        |
| descricao       | text    | —      |                                             |
| preco_base      | number  | —      | **PLACEHOLDER** (preço real é gate G-03)    |
| ativo           | bool    | —      |                                             |
| created/updated | autodate| —      |                                             |

**Regras de acesso** — list/view: **qualquer autenticado (A, G, P)** ·
create/update: **A, G** · delete: **A**.

> ⚠ Preços do seed são **placeholders**. O preço real depende do gate de negócio
> **G-03** (catálogo + preços) ainda em aberto.

### 4.4 `ordens_servico` (base) — "visão de job"

Carrega **apenas campos seguros**. Telefone/e-mail/nome completo **nunca** são
gravados aqui. `cliente` guarda só o **ID opaco** (o profissional não consegue
expandir/ler `clientes`).

| Campo               | Tipo     | Obrig. | Quem grava           | Visível a P? |
|---------------------|----------|--------|----------------------|--------------|
| id                  | text     | —      | —                    | sim (própria)|
| cliente             | relation→clientes | sim | A, G          | sim (só o id)|
| nome_curto          | text     | —      | hook (de `clientes`) | sim — "Carlos S." |
| bairro              | text     | —      | hook (de `clientes`) | sim          |
| servico             | relation→servicos | — | A, G             | sim          |
| tipo_servico_nome   | text     | —      | hook (snapshot)      | sim          |
| data_hora           | date     | sim    | A, G                 | sim          |
| profissional        | relation→users | — | A, G                | sim          |
| status              | select   | sim    | A, G; P (transições) | sim          |
| valor_servico       | number   | —      | A, G                 | sim          |
| **endereco_liberado** | text   | —      | **hook** (só em_andamento) | **só em em_andamento** |
| valor_pago          | number   | —      | **P** (e A, G)       | sim          |
| forma_pagamento     | select   | —      | **P** (e A, G)       | sim          |
| repasse_status      | select   | —      | **só A**             | sim          |
| repasse_valor       | number   | —      | só A                 | sim          |
| observacoes         | text     | —      | A, G                 | sim          |
| created/updated     | autodate | —      | —                    | sim          |

- `status`: `agendada` \| `atribuida` \| `em_andamento` \| `concluida` \| `cancelada`
- `forma_pagamento`: `debito` \| `credito` \| `pix_maquininha`
- `repasse_status`: `pendente` \| `pago`

**Regras de acesso**
- list/view: A, G, **e o profissional atribuído** (`profissional = @request.auth.id`)
- create: A, G
- update: A, G, e o profissional atribuído **(com travas de campo via hook — ver §5)**
- delete: A, G

**Importante p/ o frontend:** ao ler como profissional, `expand=cliente` vem
**vazio** (cofre protegido). Os campos `nome_curto`/`bairro`/`tipo_servico_nome`
já trazem o que a tela do profissional precisa. `endereco_liberado` só vem
preenchido quando `status == "em_andamento"`.

---

## 5. Máquina de estados e hooks (regras de negócio na API)

```
agendada → atribuida → em_andamento → concluida
        ↘__________________________↗
                  cancelada   (de qualquer estado antes de concluída)
```

Os hooks (`pb_hooks/`) impõem o que as regras de coleção (por registro) não
cobrem (controle fino por campo + ciclo de vida do endereço):

**`main.pb.js`** registra:
- **modelo** (`onRecordCreate`/`onRecordUpdate` de `ordens_servico`) — roda em
  qualquer gravação (API, seed, Admin UI):
  - denormaliza `nome_curto`, `bairro`, `tipo_servico_nome` a partir do cofre
    (só dados **não-sensíveis**);
  - gere `endereco_liberado`: copia o endereço do cliente **somente** em
    `em_andamento`; **limpa** em qualquer outro estado. **Telefone nunca é copiado.**
  - invariante: **não conclui** sem `valor_pago > 0` **e** `forma_pagamento`.
- **request** (`onRecordUpdateRequest` de `ordens_servico`) — autorização por papel:
  - **profissional** só pode: avançar status nas transições válidas
    (`atribuida→em_andamento`, `em_andamento→concluida`) e gravar `valor_pago` +
    `forma_pagamento`. Qualquer outra alteração de campo é **rejeitada** (cliente,
    valor_servico, profissional, datas, repasse, endereço, etc.);
  - só pode agir se for **o profissional atribuído** e a OS estiver em
    `atribuida`/`em_andamento`;
  - ao **Iniciar**: valida que **`data_hora` é hoje** (day-check);
  - **repasse** (`repasse_status`/`repasse_valor`) só pode ser alterado por **admin**.
- **request** (`onRecordUpdateRequest` de `users`) — impede o próprio usuário
  (não-admin/gerente) de mudar o próprio `role` ou `email` (anti-escalonamento).

**`os_logic.js`** — módulo CommonJS com a lógica (carregado via `require()` de
dentro de cada handler; no JSVM cada hook roda numa VM isolada e não enxerga o
escopo do arquivo).

---

## 6. Dinheiro (sem gateway) — ADR-002

Cliente paga na **maquininha da empresa** (CNPJ da empresa). O profissional
registra no app `valor_pago` + `forma_pagamento` **antes** de concluir. Financeiro
= registrar + conferir + coluna "a repassar" (`repasse_status` marcado manualmente
por **admin**). **Sem** gateway, split ou link de pagamento.

---

## 7. Estrutura de arquivos

```
cleanos/pb/
├── pocketbase                 # binário (não versionado — baixar por release)
├── pb_migrations/
│   ├── 1700000001_init_collections.js   # schema + regras de acesso
│   └── 1700000002_seed.js               # superuser, usuários, catálogo, clientes, OS (todos os estados)
├── pb_hooks/
│   ├── main.pb.js             # registro dos hooks (modelo + request)
│   └── os_logic.js            # lógica de negócio (CommonJS)
├── verify_rules.sh            # 21 checagens das garantias anti-desvio via REST
├── pb_data/                   # runtime (SQLite + uploads) — NÃO versionar
└── README.md
```

---

## 8. Integração WhatsApp (UAZAPI)

### 8.1 Variáveis de ambiente

| Variável             | Descrição                                                  |
|----------------------|------------------------------------------------------------|
| `UAZAPI_BASE_URL`    | URL base do servidor UAZAPI (ex.: `https://appexcrm.uazapi.com`) |
| `UAZAPI_ADMIN_TOKEN` | Admin token do UAZAPI (obtido no painel UAZAPI)            |

**Desenvolvimento local:** exporte no shell antes de subir o PocketBase:
```bash
export UAZAPI_BASE_URL=https://appexcrm.uazapi.com
export UAZAPI_ADMIN_TOKEN=<seu_token>
./pocketbase serve --http=127.0.0.1:8090
```

**Produção (systemd):** use `EnvironmentFile` no serviço. Exemplo atualizado:
```ini
[Service]
User=cleanos
WorkingDirectory=/opt/cleanos/pb
EnvironmentFile=/opt/cleanos/cleanos.env
ExecStart=/opt/cleanos/pb/pocketbase serve --http=127.0.0.1:8090
```

O arquivo `/opt/cleanos/cleanos.env` deve ter permissão `chmod 600` e pertencer ao usuário do serviço. Um template sem valores está em `cleanos/pb/cleanos.env.example`.

### 8.2 Rotas custom — contrato de API

Todas as rotas exigem `Authorization: <token>` (mesmo formato das outras rotas PocketBase).

#### `GET /api/cleanos/whatsapp/status` — admin/gerente

Consulta o status atual da instância UAZAPI e atualiza o cache em `app_config`.

**Response 200:**
```json
{
  "configured": true,
  "status": "connected",
  "instanceName": "cleanox",
  "profileName": "Cleanox Higienização"
}
```
Quando não configurada: `{ "configured": false, "status": "disconnected", "instanceName": "" }`.
O token da instância **nunca** aparece na resposta.

#### `POST /api/cleanos/whatsapp/connect` — admin/gerente

Cria a instância UAZAPI se ainda não existir (idempotente), depois inicia a conexão e retorna o QR code. O frontend deve exibir o `qrcode` (imagem base64) para o responsável escanear.

**Request:** sem body.

**Response 200:**
```json
{
  "status": "connecting",
  "qrcode": "data:image/png;base64,iVBOR...",
  "paircode": "1234-5678"
}
```
`qrcode` e `paircode` podem ser `null` dependendo da versão UAZAPI.

#### `POST /api/cleanos/whatsapp/disconnect` — admin/gerente

Desconecta a instância do WhatsApp.

**Request:** sem body.

**Response 200:**
```json
{ "status": "disconnected" }
```

#### `POST /api/cleanos/os/{id}/a-caminho` — profissional (dono da OS)

Dispara o aviso "estou a caminho" para o cliente via WhatsApp. O profissional **não** precisa saber nem vê o telefone do cliente — a rota lê o contato do cofre server-side.

**Pré-condições:**
- Auth deve ser o `profissional` atribuído à OS.
- OS deve estar com `status = em_andamento`.
- WhatsApp deve estar `connected`.

**Request:** sem body.

**Response 200:**
```json
{ "ok": true, "sentAt": "2026-06-26 14:30:00.000Z" }
```

**Response 403:** profissional não é dono da OS, ou papel incorreto.

**Response 409:** WhatsApp não conectado (ou não configurado).

```json
{ "error": "WhatsApp não está conectado (status: disconnected). Peça ao admin para reconectar." }
```

O campo `telefone` **nunca** aparece na resposta em nenhum cenário.

### 8.3 Fluxo de setup (dono escaneia QR)

```
Admin → POST /connect → frontend exibe QR → dono escaneia no celular
     → GET /status (poll) até status = "connected"
```

Depois de conectado, o profissional pode usar `POST /a-caminho` em qualquer OS `em_andamento` atribuída a ele.

### 8.4 Coleção `app_config`

Singleton (1 registro) criado na migration 3. Regras de acesso: **somente superuser** (null rules). Nenhum papel de negócio lê/escreve via API — os hooks o acessam server-side.

| Campo                     | Tipo | Descrição                                      |
|---------------------------|------|------------------------------------------------|
| `whatsapp_instance_name`  | text | Nome da instância UAZAPI (ex.: "cleanox")      |
| `whatsapp_instance_token` | text | Token da instância — **dado sensível**         |
| `whatsapp_status`         | text | Status em cache: disconnected/connecting/connected |
| `aviso_template`          | text | Template da mensagem (placeholders: {nome}, {servico}) |

### 8.5 Campo `aviso_a_caminho_em` em `ordens_servico`

Adicionado na migration 3. Data/hora do envio do aviso, gravada server-side pela rota `/a-caminho`. O profissional **não pode** gravar este campo via PATCH (está no `locked` do guard `guardOrdemUpdateRequest`).

---

## 9. Decisões e premissas

- **Versão PocketBase:** v0.39.4 (Linux amd64). A API JSVM desta versão exige
  `collection.fields.add(...)` e atribuição de regras por propriedade
  (`col.listRule = ...`) — o atalho `new Collection({ fields, listRule })` é
  silenciosamente ignorado. As migrations já usam a forma correta.
- **Papéis na coleção `users`** (não no `_superusers`). O `_superuser` é só devops.
- **`endereco_liberado` no registro da OS** (efêmero), preenchido por hook. É a
  forma compatível com o modelo record-level do PocketBase: o profissional pode
  ler a própria OS, e o campo só tem conteúdo durante `em_andamento`.
- **`cliente` (id) fica visível na OS do profissional** — é um identificador
  opaco; não é contato e não permite ler o cofre (coleção negada). Mantido para o
  admin/gerente conseguir expandir.
- **Day-check** compara no fuso **BRT (UTC-3 fixo)**: `data_hora` é UTC; o hook
  converte ambos (`Date.now() - 3h` e `new Date(raw) - 3h`) antes de comparar
  os dias. Isso evita bloquear serviços noturnos (ex.: 23h BRT = 02h UTC do dia
  seguinte) sem precisar de biblioteca de timezone.
- **Preços do catálogo são PLACEHOLDER** (gate de negócio **G-03** em aberto).
- **"Avisar que estou a caminho" / WhatsApp** implementado via UAZAPI (§8).
  O disparo é server-side: o profissional chama `POST /a-caminho` e nunca
  vê o telefone do cliente. A garantia anti-desvio permanece: o telefone
  só existe no cofre `clientes` e é lido internamente pelo hook.
- **Senhas de seed** são de teste e devem ser trocadas.

---

## 10. Segurança — checklist de go-live

### 10.1 Senhas de seed — TROCA OBRIGATÓRIA antes de produção

> ⚠️ **As senhas abaixo são SOMENTE para desenvolvimento local. Nunca usar em produção.**

| Conta                | Senha de seed         | Ação antes do deploy          |
|----------------------|-----------------------|-------------------------------|
| super@cleanox.local  | `cleanox-super-123`   | Trocar / criar nova conta     |
| admin@cleanox.local  | `cleanox123`          | Trocar (mínimo 16 chars)      |
| gerente@cleanox.local| `cleanox123`          | Trocar                        |
| pedro@cleanox.local  | `cleanox123`          | Trocar / remover se não usar  |
| lucas@cleanox.local  | `cleanox123`          | Trocar / remover se não usar  |

Procedimento seguro: após deploy, acesse o Admin UI (`/_/`), altere cada
senha via "Edit User" e desative as contas de seed que não serão usadas em
produção.

### 10.2 Rate limiting (PocketBase nativo)

PocketBase v0.39+ tem rate limiting configurável via Admin UI em
**Settings → Rate limits**. Recomendações mínimas para produção:

- **Auth (login):** ≤ 10 req/min por IP (previne brute-force de senha).
- **List records:** ≤ 60 req/min por IP (uso normal de app).

Para configurar programaticamente via API de superadmin:
```bash
# Exemplo (ajuste os valores conforme necessário)
curl -X PATCH http://127.0.0.1:8090/api/settings \
  -H "Authorization: $SUPER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"rateLimits":{"enabled":true,"rules":[...]}}'
```

Consultar a documentação do PocketBase para o formato exato de `rateLimits`.

### 10.3 Garantias anti-desvio já implementadas (resumo técnico)

| Vetor | Proteção |
|-------|----------|
| Profissional lê cofre `clientes` | listRule/viewRule bloqueiam (`ADMIN_GERENTE`) |
| Filtro relacional `cliente.telefone=...` | Hook `onRecordsListRequest` rejeita 400 + PocketBase nativo retorna 0 |
| Sort relacional `sort=cliente.telefone` | Hook `onRecordsListRequest` rejeita 400 |
| Cross-collection `@collection.clientes.*` | PocketBase rejeita 403 (only superusers) |
| Realtime subscribe com filtro relacional | Hook `onRealtimeSubscribeRequest` rejeita 403 |
| Profissional muda próprio role/email | Hook `onRecordUpdateRequest` rejeita 403 |
| Profissional solicita email-change | Hook `onRecordRequestEmailChangeRequest` rejeita 403 |
| Endereço retido em OS eterna em_andamento | Cron `cleanStaleEndereco` (03:05 UTC = 00:05 BRT) limpa diariamente |

---

## 11. Evidência da verificação (resumo)

`./verify_rules.sh` contra o seed — **21/21 PASS**. Destaques:

- (a) `GET /api/collections/clientes/records` como profissional → **negado**
  (lista vazia / `view` por id → **404**).
- (b) OS do profissional **não** possui `telefone`/`email`/`sobrenome`;
  `expand=cliente` vem **vazio**; `endereco_liberado` vazio em `agendada`/`atribuida`.
- (c) Endereço aparece **só** em `em_andamento` (liberado pelo hook ao Iniciar) e
  é **limpo** ao Concluir; concluir **sem pagamento → 400 (bloqueado)**.
- (d) Profissional **não** altera `valor_servico`, `cliente`, `profissional`,
  `data_hora`, `repasse_status`, nem faz transição inválida → **403** em todos.
- (f) Profissional **não cria** OS → **400**.
- (g) Profissional **não inicia** OS fora do dia do serviço → **400** (day-check).
