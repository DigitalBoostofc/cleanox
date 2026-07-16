# CleanOS — Backend (PocketBase)

Backend da ferramenta interna **CleanOS** (projeto Cleanox), uma empresa de
higienização de estofados a domicílio (< 50 OS/mês).

**Stack canônica:** PocketBase (Go + SQLite, binário único) numa VPS + **frontend
100% Flutter** (`../flutter/`) — Web (painel) e APK Android unificado. Não há
frontend React no repositório.

> **Fonte da verdade do escopo/DNA:** `../../CLAUDE.md` e `../../docs/MVP-BUILD-SPEC.md`.
> Docs `04`/`08` e trechos antigos com React/PWA/Asaas são **histórico**, não o stack atual.

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
   `em_andamento` (ao tocar "Iniciar"), **a partir do dia do serviço** — nunca
   antes; dias passados são permitidos para encerrar OS que ficou sem registro
   (o hook carimba `iniciada_em` e o cron corta por ele). Ao virar
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
| emailVisibility  | bool    | —      | manter `true` (admin precisa ver e-mail na gestão)     |
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
| **endereco_estado**    | text    | —      | ✅       | UF (2 letras) — autofill CEP   |
| endereco_cep           | text    | —      | ✅       |                                |
| ativo                  | bool    | —      |          |                                |
| observacoes            | text    | —      | ✅       |                                |
| created/updated        | autodate| —      |          |                                |

**Regras de acesso** — list/view/create/update: **A, G** · delete: **A** ·
**P: negado em tudo** (esta é a trava central anti-desvio).

> `endereco_estado`: populado pelo frontend via autofill de CEP (ViaCEP ou similar).
> Permite pré-filtrar clientes pela área de atuação definida em `config_atuacao`.

### 4.3 `servicos` (base) — catálogo RICO (não sensível)

Catálogo enriquecido pelo módulo **Serviços** (Migrations 8 e 9). Os campos
legados (`descricao`, `preco_base`, `ativo`) **continuam existindo** e são
mantidos **sincronizados** com os campos canônicos ricos.

| Campo                    | Tipo    | Obrig. | Notas                                                              |
|--------------------------|---------|--------|--------------------------------------------------------------------|
| id                       | text    | —      | PK                                                                 |
| nome                     | text    | sim    | ex.: "Cleanox Essencial"                                           |
| **slug**                 | text    | —      | referência estável (ex.: `svc_veic_essencial`) — **única** via índice parcial |
| **categoria**            | select  | —      | `veicular` \| `residencial`                                        |
| **grupo**                | select  | —      | `plano` \| `promocao` \| `adicional` \| `avulsos` \| `sofa` \| `colchao` \| `outros` |
| **valor_base**           | number  | —      | valor canônico (ou limite inferior quando `tipo_valor='faixa'`)    |
| **valor_base_max**       | number  | —      | limite superior p/ `faixa` (0 = sem máximo)                        |
| **tipo_valor**           | select  | —      | `fixo` \| `faixa` \| `variavel`                                    |
| **tempo_medio_min**      | number  | —      | minutos (limite superior; 0 = Variável)                            |
| **tempo_medio_label**    | text    | —      | rótulo humano, ex.: "1h30 a 2h"                                    |
| **status**               | select  | —      | `ativo` \| `inativo`                                               |
| **observacao**           | text    | —      | observação comercial/técnica (máx 1000)                            |
| **checklist_padrao**     | json    | —      | array de `{ id, titulo, ordem }`                                   |
| **orientacoes_pre**      | text    | —      | orientações pré-serviço (máx 1000)                                 |
| **orientacoes_pos**      | text    | —      | orientações pós-serviço (máx 1000)                                 |
| **adicionais_relacionados** | json | —      | array de **slugs** sugeridos junto deste                          |
| descricao                | text    | —      | **legado** (módulo rico usa `observacao`)                         |
| preco_base               | number  | —      | **legado — sincronizado = `valor_base`**                          |
| ativo                    | bool    | —      | **legado — sincronizado = (`status` === `ativo`)**                |
| created/updated          | autodate| —      |                                                                   |

- **Unicidade do `slug`**: `CREATE UNIQUE INDEX idx_servicos_slug ON servicos (slug) WHERE slug != ''`
  (índice **parcial** — múltiplos slugs vazios são permitidos; convivem com linhas legadas).
- `slug` é **`required:false`** no schema (a unicidade real é o índice; back-compat com
  fluxos que criam serviço sem slug). O seed e a UI do módulo Serviços sempre o preenchem.

**Regras de acesso** (inalteradas) — list/view: **qualquer autenticado (A, G, P)** ·
create/update: **A, G** · delete: **A**.

> ⚠ `preco_base`/`valor_base` do seed continuam **placeholders** até o gate **G-03**.
> A sincronia `preco_base = valor_base` e `ativo = (status==='ativo')` é responsabilidade
> do **seed (Migration 9)** e da **UI** — o schema só cria as colunas.

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
| **service_snapshot**   | json  | —      | UI/hook (na seleção) | sim          |
| **checklist_exec**     | json  | —      | **P** (e A, G)       | sim          |
| **adicionais**         | json  | —      | **P** (e A, G)       | sim          |
| **observacoes_prof**   | json  | —      | **P** (e A, G)       | sim          |
| **relatorio_enviado_em** | date | —     | backend/UI           | sim          |
| created/updated     | autodate | —      | —                    | sim          |

- `status`: `agendada` \| `atribuida` \| `em_andamento` \| `concluida` \| `cancelada`
- `forma_pagamento`: `debito` \| `credito` \| `pix_maquininha`
- `repasse_status`: `pendente` \| `pago`

**Campos ricos do módulo Serviços/OS (Migration 8, JSON):**
- `service_snapshot` — **cópia imutável** do serviço no instante da seleção
  (`ServiceSnapshot`: nome, categoria, grupo, valores, tempo, checklist, orientações).
  A OS guarda o snapshot — alterações futuras no catálogo **não** afetam OS antigas.
- `checklist_exec` — array de `ChecklistExecItem` (marcável pelo profissional na execução).
- `adicionais` — array de `ServicoAdicionalOS` (serviços extras lançados na OS).
- `observacoes_prof` — array de `ObservacaoProfissional`. **NÃO confundir** com o
  campo texto `observacoes` (livre, admin/gerente) já existente.
- `relatorio_enviado_em` — ISO datetime de quando o relatório final foi enviado ao cliente.

> 🔒 **Cofre preservado**: nenhum desses campos grava telefone/endereço. O único
> dado de endereço continua sendo o `endereco_liberado` efêmero (só em `em_andamento`).
> ⚠️ As travas de campo do profissional (hook `guardOrdemUpdateRequest` em
> `os_logic.js`) **ainda não cobrem** estes campos novos — ver §5 / nota de integração.

**Regras de acesso**
- list/view: A, G, **e o profissional atribuído** (`profissional = @request.auth.id`)
- create: A, G
- update: A, G, e o profissional atribuído **(com travas de campo via hook — ver §5)**
- delete: A, G

**Importante p/ o frontend:** ao ler como profissional, `expand=cliente` vem
**vazio** (cofre protegido). Os campos `nome_curto`/`bairro`/`tipo_servico_nome`
já trazem o que a tela do profissional precisa. `endereco_liberado` só vem
preenchido quando `status == "em_andamento"`.

### 4.5 `config_atuacao` (base, singleton) — área geográfica de cobertura

Coleção de **configuração administrativa** (profissional não acessa). Exatamente
**1 registro** é criado na migration 7; o app atualiza via `PATCH /records/:id`.

| Campo           | Tipo | Obrig. | Notas                                                               |
|-----------------|------|--------|---------------------------------------------------------------------|
| id              | text | —      | PK (gerado na migration, fixo)                                      |
| estado          | text | —      | UF de operação (2 letras, ex.: `"SP"`)                              |
| cidades         | json | —      | Array de objetos (ver shape abaixo)                                 |
| created/updated | auto | —      |                                                                     |

**Shape de `cidades`:**
```json
[
  {
    "nome": "São Paulo",
    "principal": true,
    "bairros": ["Centro", "Vila Madalena", "Pinheiros"]
  },
  {
    "nome": "Guarulhos",
    "principal": false,
    "bairros": ["Centro", "Bonsucesso"]
  }
]
```

**Regras de acesso** — list/view/create/update: **A, G** · delete: **A** ·
**P: negado em tudo.**

**Endpoints do frontend:**
```
GET  /api/collections/config_atuacao/records          → lista (somente 1 item)
PATCH /api/collections/config_atuacao/records/:id     → atualiza (admin/gerente)
```

---

### 4.6 `disponibilidade` (base) — grade de horários por profissional

Um registro por profissional (garantido por `UNIQUE INDEX idx_disp_profissional`).
O frontend sempre faz **upsert**: busca por `profissional`, atualiza se existir,
cria se não existir.

| Campo           | Tipo     | Obrig. | Notas                                                  |
|-----------------|----------|--------|--------------------------------------------------------|
| id              | text     | —      | PK                                                     |
| profissional    | relation→users | sim | single, required — UNIQUE via índice           |
| duracao_min     | number   | —      | Duração padrão do serviço em minutos; **default 60** (app grava 60 na criação) |
| dias            | json     | —      | Array de 7 objetos, um por dia da semana (ver shape)   |
| created/updated | autodate | —      |                                                        |

**Shape de `dias`** — array indexado pela posição (0=domingo, 1=segunda … 6=sábado):
```json
[
  { "ativo": false, "inicio": "08:00", "fim": "18:00" },
  { "ativo": true,  "inicio": "08:00", "fim": "18:00" },
  { "ativo": true,  "inicio": "08:00", "fim": "18:00" },
  { "ativo": true,  "inicio": "08:00", "fim": "18:00" },
  { "ativo": true,  "inicio": "08:00", "fim": "18:00" },
  { "ativo": true,  "inicio": "08:00", "fim": "18:00" },
  { "ativo": false, "inicio": "08:00", "fim": "18:00" }
]
```

**Regras de acesso** — list/view/create/update: **A, G** · delete: **A** ·
**P: negado em tudo** (config administrativa; sem impacto anti-desvio).

**Endpoints do frontend (upsert pattern):**
```
GET  /api/collections/disponibilidade/records?filter=(profissional='<id>')
     → array; length=0 → criar; length=1 → atualizar via PATCH

POST  /api/collections/disponibilidade/records          → criar (admin/gerente)
PATCH /api/collections/disponibilidade/records/:id      → atualizar (admin/gerente)
```

> Tentar criar um segundo registro para o mesmo profissional retorna 400 (violação
> do UNIQUE INDEX no banco). O frontend deve sempre verificar se já existe antes
> de criar.

---

### 4.7 `os_evidencias` (base) — 🔒 COFRE (fotos antes/durante/depois)

Evidências fotográficas de uma OS (Migration 8). Segue o **mesmo modelo de cofre**
de `ordens_servico`: o profissional só enxerga/edita evidências de **OS atribuídas
a ele** (regra de registro via relação `os.profissional`). Nada de telefone/endereço
é gravado aqui.

| Campo             | Tipo     | Obrig. | Notas                                                       |
|-------------------|----------|--------|-------------------------------------------------------------|
| id                | text     | —      | PK                                                          |
| os                | relation→ordens_servico | sim | single, required; **cascadeDelete** (apagar a OS apaga a evidência) |
| foto              | file     | —      | 1 imagem, **maxSize 5MB**, mime `image/jpeg,png,webp,gif,heic,heif` |
| fase              | select   | —      | `antes` \| `durante` \| `depois`                            |
| legenda           | text     | —      | máx 300                                                     |
| checklist_item_id | text     | —      | vínculo opcional a um item de `checklist_exec` da OS        |
| observacao_id     | text     | —      | vínculo opcional a uma `observacoes_prof` da OS             |
| adicional_id      | text     | —      | vínculo opcional a um `adicionais` da OS                    |
| enviado_por       | relation→users | —  | quem enviou (single)                                       |
| created/updated   | autodate | —      |                                                            |

- **Índice**: `CREATE INDEX idx_evid_os ON os_evidencias (os)`

**Regras de acesso** (idênticas em list/view/create/update/delete) — admin/gerente
**sempre**; profissional **só** as evidências de OS dele. Expressão literal:

```
@request.auth.id != "" && (@request.auth.role = "admin" || @request.auth.role = "gerente" || os.profissional = @request.auth.id)
```

- **create**: o profissional só consegue criar evidência cuja `os` é dele
  (`os.profissional = @request.auth.id`); admin/gerente criam para qualquer OS.
- **update/delete**: dono da OS (`os.profissional`) ou admin/gerente.

**Endpoints do frontend:**
```
GET    /api/collections/os_evidencias/records?filter=(os='<osId>')&sort=created
POST   /api/collections/os_evidencias/records   (multipart: os, foto, fase, legenda, …)
DELETE /api/collections/os_evidencias/records/:id
```

> 🔒 O profissional **não** consegue listar/ler evidências de OS que não são dele —
> a regra atravessa a relação `os → profissional`. Isso espelha a proteção de
> `ordens_servico` e mantém a garantia anti-desvio.

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
│   ├── 1700000002_seed.js               # superuser, usuários, catálogo, clientes, OS (todos os estados)
│   ├── 1700000002_catalog_prod.js       # catálogo prod (sem dados de dev)
│   ├── 1700000003_whatsapp.js           # app_config + aviso_a_caminho_em
│   ├── 1700000004_ratings.js            # campos de avaliação + templates
│   ├── 1700000005_debug_events.js       # captura temporária de webhooks (removida)
│   ├── 1700000006_drop_debug_events.js  # remove a coleção debug
│   ├── 1700000007_config_scheduling.js  # config_atuacao + disponibilidade + endereco_estado
│   ├── 1700000008_servicos_os_rich.js   # servicos rico + campos ricos da OS + os_evidencias
│   └── 1700000009_seed_servicos_rich.js # UPSERT dos 32 serviços ricos (enriquece placeholders)
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

## 9. Sistema de Avaliação (orquestrado por n8n)

### 9.1 Visão geral do fluxo

```
OS → concluida
  └→ PocketBase seta avaliacao_solicitada_em + POST best-effort para N8N_RATING_WEBHOOK_URL
       └→ n8n envia enquete de 1–5 estrelas via WhatsApp
            ├→ cliente responde (nota)
            │    └→ n8n chama POST /api/cleanos/ratings/ingest { os_id, nota }
            │         ├ nota ≤ 3 → needsReason=true → n8n faz follow-up de motivo
            │         │    └→ n8n precisa correlacionar resposta de texto com a OS:
            │         │         GET /api/cleanos/ratings/pending?phone=...
            │         │         └→ n8n chama POST /ratings/ingest { os_id, motivo }
            │         └ nota 4–5 → needsReason=false → fluxo encerra
            └→ cliente não responde → sem ação adicional
```

O PocketBase é a **fonte da verdade** (persiste tudo). O n8n é o orquestrador de mensagens (não armazena estado). A conclusão da OS **nunca é bloqueada** por falha de rede para o n8n.

### 9.2 Schema — novos campos em `ordens_servico` (Migration 4)

| Campo                    | Tipo   | Quem grava                      | Visível a P? |
|--------------------------|--------|---------------------------------|--------------|
| `avaliacao_nota`         | number | n8n via `/ratings/ingest`        | sim (própria)|
| `avaliacao_motivo`       | text   | n8n via `/ratings/ingest`        | sim (própria)|
| `avaliacao_em`           | date   | n8n via `/ratings/ingest`        | sim (própria)|
| `avaliacao_solicitada_em`| date   | hook server-side (ao concluir)   | sim (própria)|

**Todos esses campos estão no `locked` do `guardOrdemUpdateRequest`** — profissional recebe 403 ao tentar PATCH qualquer um deles.

### 9.3 Novos campos em `app_config` (Migration 4)

| Campo                    | Default                                                                |
|--------------------------|------------------------------------------------------------------------|
| `avaliacao_poll_texto`   | "Como foi o serviço de {servico}? Toque pra avaliar 👇"                |
| `avaliacao_motivo_texto` | "Poxa, queremos melhorar! Conta pra gente: o que não foi bom no atendimento? 🙏" |
| `avaliacao_agradecimento`| "Muito obrigado pela sua avaliação! 💙 Conte sempre com a Cleanox."    |

Editáveis via `POST /api/cleanos/whatsapp/config` (só admin).

### 9.4 Gatilho ao concluir

No hook `onRecordUpdate` de `ordens_servico` (em `os_logic.js`), ao detectar a transição `x → concluida`:
1. Seta `avaliacao_solicitada_em = now` no registro (antes do save).
2. Faz um `POST` best-effort (timeout 5s, try/catch) para `$N8N_RATING_WEBHOOK_URL` com:
   ```json
   { "os_id": "...", "phone": "5511999990001", "servico": "Sofá 3 lugares", "nome": "Carlos S.", "secret": "..." }
   ```
   - `phone` é lido do cofre `clientes` e normalizado (só dígitos, DDI 55 prefixado se ausente).
   - `secret` = `$CLEANOS_SERVICE_SECRET`.
   - Se `N8N_RATING_WEBHOOK_URL` não estiver definida, apenas loga e segue — OS conclui normalmente.

### 9.5 Endpoints de serviço (consumidos pelo n8n)

**Auth:** header `X-Cleanos-Secret: <valor de CLEANOS_SERVICE_SECRET>`.
**Sem** auth de usuário PocketBase. Se o segredo não bater (ou env não estiver definida) → 401.

#### `POST /api/cleanos/ratings/ingest`

**Request:**
```json
{ "os_id": "<id>", "nota": 3, "motivo": "Atendimento lento" }
```
`nota` e `motivo` são opcionais — envie apenas o campo que o n8n possui naquele momento.
`nota` deve ser inteiro 1–5.

**Response 200:**
```json
{ "ok": true, "nota": 3, "needsReason": true }
```
`needsReason: true` quando `nota ≤ 3` **e** `motivo` ainda está vazio.
`needsReason: false` quando `nota ≥ 4`, ou quando motivo já foi gravado, ou quando nota é null.

**Erros:**
- 401 — segredo inválido ou env não definida.
- 400 — `os_id` ausente, ou `nota` fora do range 1–5, ou OS não está `concluida`.
- 404 — `os_id` não encontrado.

**Idempotência:** campos só são atualizados se presentes no body. Chamadas repetidas com os mesmos dados são seguras.

#### `GET /api/cleanos/ratings/pending?phone=<número>`

Retorna a OS mais recente (últimos 7 dias) desse telefone com `avaliacao_nota` entre 1 e 3 e `avaliacao_motivo` vazio — usado pelo n8n para correlacionar a resposta textual do motivo.

**Query param:** `phone` — número no formato que a UAZAPI envia (qualquer formatação; será normalizado).

**Response 200 (encontrou):**
```json
{ "os_id": "<id>", "servico": "Sofá 3 lugares" }
```

**Response 200 (não encontrou):**
```json
{ "os_id": null }
```

**Erros:**
- 401 — segredo inválido.
- 400 — parâmetro `phone` ausente.

#### `GET /api/cleanos/whatsapp/dispatch-info`

Retorna as credenciais UAZAPI e os templates de mensagem para o n8n orquestrar os envios de avaliação. **Este é o único endpoint que expõe o token da instância WhatsApp** — o acesso é protegido pelo service secret e o consumidor é exclusivamente o n8n (infraestrutura interna).

**Response 200:**
```json
{
  "uazapi_base":     "https://appexcrm.uazapi.com",
  "uazapi_token":    "<whatsapp_instance_token do app_config>",
  "instance_status": "connected",
  "templates": {
    "aviso_template":          "Olá {nome}! ...",
    "avaliacao_poll_texto":    "Como foi o serviço de {servico}? ...",
    "avaliacao_motivo_texto":  "Poxa, queremos melhorar! ...",
    "avaliacao_agradecimento": "Muito obrigado pela sua avaliação! ..."
  }
}
```

`uazapi_base` vem da env `UAZAPI_BASE_URL`. Token, status e templates são lidos da coleção `app_config` server-side (superuser dao). `instance_status` pode ser string vazia se ainda não configurado.

**Erros:**
- 401 — secret ausente, inválido, ou `CLEANOS_SERVICE_SECRET` não definida.

### 9.6 Configuração de templates (admin/gerente)

#### `GET /api/cleanos/whatsapp/config`

Auth: token de usuário PocketBase com papel `admin` ou `gerente`.

**Response 200:**
```json
{
  "aviso_template":          "Olá {nome}! ...",
  "avaliacao_poll_texto":    "Como foi o serviço de {servico}? ...",
  "avaliacao_motivo_texto":  "Poxa, queremos melhorar! ...",
  "avaliacao_agradecimento": "Muito obrigado pela sua avaliação! ..."
}
```
O token da instância WhatsApp **nunca** aparece na resposta.

#### `POST /api/cleanos/whatsapp/config`

Auth: token de usuário com papel `admin` (gerente não pode alterar).

**Request:** qualquer subconjunto dos 4 campos acima.

**Response 200:** estado completo dos 4 campos após a atualização.

### 9.7 Variáveis de ambiente (novas)

| Variável                | Descrição                                                            |
|-------------------------|----------------------------------------------------------------------|
| `N8N_RATING_WEBHOOK_URL`| URL do webhook n8n que recebe a notificação de OS concluída. Se vazia, o gatilho é pulado. |
| `CLEANOS_SERVICE_SECRET`| Segredo compartilhado para auth dos endpoints de serviço. Se vazio, todos retornam 401. |
| `GOOGLE_MAPS_API_KEY`   | (doc 09) Chave Google Maps (Geocoding + Distance Matrix), só server-side. Se vazia, geocode/ETA retornam nulo e o rastreamento fica inerte (Cheguei manual segue). |
| `FCM_SERVER_KEY`        | (doc 09) Server key do FCM para push "Nova OS", só server-side. Se vazia, o push é pulado (sem erro). |

Configure no mesmo arquivo `cleanos.env` das variáveis UAZAPI (ver §8.1).

### 9.8 Rastreamento "estou a caminho" (GPS ao vivo) — doc 09 §3

Adições **aditivas** que servem ao app Flutter do profissional. Ficam **inertes**
até o app começar a chamar as rotas e as chaves acima serem providas.

**Schema (migration 17):**
- `ordens_servico`: `prof_lat`, `prof_lng`, `prof_pos_em`, `dest_lat`, `dest_lng`,
  `aviso_5min_em`, `aviso_1min_em`, `cheguei_em` — todos gravados **só server-side**
  (rotas dedicadas / cron) e na denylist do profissional (`os_logic.js`).
- `app_config`: `aviso_5min_texto`, `aviso_1min_texto`, `aviso_cheguei_texto`
  (editáveis em `POST /whatsapp/config`).
- Coleção `push_tokens` (`usuario`, `token`, `plataforma`, `updated`): 1 token por
  `(profissional, plataforma)`. Profissional cria/atualiza o próprio; admin lê.

**Rotas (auth: profissional dono + OS `em_andamento`; telefone só server-side):**
- `POST /api/cleanos/os/{id}/posicao` `{lat,lng}` → grava posição; na 1ª vez
  geocodifica o destino → `dest_lat/lng`. Resposta `{ ok }`.
- `POST /api/cleanos/os/{id}/cheguei` → envia `aviso_cheguei_texto` (best-effort),
  grava `cheguei_em` (sempre) e **encerra** o rastreamento. Resposta `{ ok, sentAt, avisoEnviado }`.
- `/a-caminho` (estendida) → geocodifica o destino se faltar + reseta
  `aviso_5min_em/aviso_1min_em/cheguei_em` (idempotência por viagem).
- `POST /api/cleanos/push/register` `{token,plataforma}` (qualquer usuário
  autenticado, escopado a si mesmo) → upsert em `push_tokens`.

**Cron `trackingAvisos` (`* * * * *`):** varre OS `em_andamento` com
`aviso_a_caminho_em` setado, sem `cheguei_em`, `prof_pos_em` recente (≤3 min),
`dest_lat/lng` presentes e a-caminho ≤2 h; calcula ETA (Distance Matrix c/
trânsito) e dispara **Msg2** (ETA ≤5 min) e **Msg3** (ETA ≤1 min), idempotentes
via `aviso_5min_em`/`aviso_1min_em`.

**Push:** ao atribuir uma OS a um profissional (create ou update), o hook envia
FCM "Nova OS" aos `push_tokens` dele (`FCM_SERVER_KEY`), best-effort.

**Degradação:** sem `GOOGLE_MAPS_API_KEY` o ETA/geocode retornam nulo e o cron não
avança; sem `FCM_SERVER_KEY` o push é pulado; sem WhatsApp conectado os avisos são
pulados. Nada disso lança nem bloqueia os fluxos existentes.

---

## 10. Decisões e premissas (histórico)

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

## 11. Segurança — checklist de go-live

### 11.1 Senhas de seed — TROCA OBRIGATÓRIA antes de produção

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

### 11.2 Rate limiting (PocketBase nativo)

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

### 11.3 Garantias anti-desvio já implementadas (resumo técnico)

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

## 12. Evidência da verificação (resumo)

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
