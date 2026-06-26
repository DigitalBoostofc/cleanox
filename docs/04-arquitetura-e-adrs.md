# CLEANOX — PROPOSTA DE ARQUITETURA PRÉ-PROJETO
**Versão:** 0.1-draft · **Data:** 2026-06-25 · **Autor:** Arquiteto Revisor

---

## 0. PREMISSA CENTRAL

A plataforma tem um único mandato estratégico acima de qualquer decisão técnica:

> **O cliente é ativo da marca. O prestador é insumo anônimo.**

Every architectural decision is evaluated against this mandate. Where a cheaper or simpler option conflicts with it, the mandate wins.

---

## 1. VISÃO DE ARQUITETURA — DIAGRAMA LÓGICO

### 1.1 Componentes e superfícies

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                         ZONA DE CONFIANÇA ZERO                              ║
║  (internet pública — não confiável)                                         ║
╠══════════╦═══════════════════╦═══════════════════════════════════════════════╣
║          ║                   ║                                               ║
║  Cliente ║     Prestador     ║          Operação Interna                    ║
║  (alta   ║  (Android básico  ║   Atendente (CLT) + Admin/Dono               ║
║  confi-  ║  4G oscilante     ║   (alto letramento, desktop)                 ║
║  ança    ║  low-tech)        ║                                               ║
║          ║                   ║                                               ║
║  PWA     ║  App Nativo       ║   Painel Web SPA                             ║
║  Next.js ║  Flutter/Android  ║   Next.js (SSR)                              ║
╚══════╤═══╩═══════════╤═══════╩═══════════════╤═══════════════════════════════╝
       │               │                       │
       └───────────────┴───────────┬───────────┘
                                   │  HTTPS + JWT
                         ╔═════════▼═══════════╗
                         ║   API GATEWAY       ║
                         ║   (rate limit, auth,║
                         ║   WAF, CORS)        ║
                         ╚═════════╤═══════════╝
                                   │
              ╔════════════════════▼══════════════════════╗
              ║           CORE API (Node.js + Fastify)    ║
              ║                                           ║
              ║  ┌─────────┐  ┌─────────┐  ┌──────────┐ ║
              ║  │Agendamen│  │OS/Dispa-│  │Pagamento │ ║
              ║  │to       │  │tch      │  │/Split    │ ║
              ║  └────┬────┘  └────┬────┘  └────┬─────┘ ║
              ║       │            │             │       ║
              ║  ┌────▼────┐  ┌───▼─────┐  ┌───▼─────┐ ║
              ║  │Notifica-│  │Endereço │  │LogDeAces│ ║
              ║  │ção      │  │Efêmero  │  │so (imut)│ ║
              ║  └─────────┘  └─────────┘  └─────────┘ ║
              ╚══════════════╤════════════════════════════╝
                             │
            ╔════════════════▼══════════════════════════╗
            ║           CAMADA DE DADOS                ║
            ║                                          ║
            ║  ┌─────────────────┐  ┌───────────────┐ ║
            ║  │ PostgreSQL      │  │ Redis         │ ║
            ║  │ (dados princi-  │  │ (sessões,     │ ║
            ║  │  pais, dados    │  │  filas Bull,  │ ║
            ║  │  sensíveis cri-│  │  tokens efê-  │ ║
            ║  │  ptografados)   │  │  meros)       │ ║
            ║  └─────────────────┘  └───────────────┘ ║
            ╚═════════════════════════════════════════╝
                             │
╔════════════════════════════▼═══════════════════════════════╗
║                SERVIÇOS EXTERNOS (boundary)               ║
║                                                           ║
║  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ ║
║  │  Asaas   │  │ 360dialog│  │ Google   │  │ Firebase ║
║  │  (Pix +  │  │ (WABA /  │  │ Maps     │  │ FCM      ║
║  │  Cartão  │  │  BSP)    │  │ (geo +   │  │ (push    ║
║  │  + Split)│  │          │  │  routing)│  │  Android)║
║  └──────────┘  └──────────┘  └──────────┘  └──────────┘ ║
║  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ ║
║  │ Focus NFe│  │ Identiq  │  │ Twilio / │  │ Secrets  ║
║  │ (NFS-e   │  │ (KYC     │  │ Zenvia   │  │ Manager  ║
║  │  nacional│  │  presta- │  │ (OTP SMS)│  │ (chaves) ║
║  │  set/26) │  │  dor)    │  │          │  │          ║
║  └──────────┘  └──────────┘  └──────────┘  └──────────┘ ║
╚════════════════════════════════════════════════════════════╝
```

### 1.2 Limites de confiança

| Fronteira | Mecanismo de controle |
|---|---|
| Internet → API Gateway | TLS 1.3, rate limit por IP e por user, WAF (OWASP rules) |
| API Gateway → Core API | JWT assinado (HS256 MVP, RS256 V2), claims incluem `actor_type` |
| Core API → dados sensíveis | Row-level encryption (AES-256-GCM) para colunas marcadas; application-level key management |
| Core API → serviços externos | Chaves em Secrets Manager, nunca em env file no repo |
| App Prestador → dados do cliente | Jamais trafega `telefone`, `email`, `nome_completo`; endereço somente via token efêmero assinado |
| Atendente → dados do cliente | Acesso pleno mas com log imutável de toda consulta a campos sensíveis |

---

## 2. MODELO DE DADOS DE ALTO NÍVEL

### 2.1 Entidades principais

```
┌─────────────────────────────────────────────────────────────┐
│ CLIENTE                              [ZONA SENSÍVEL A]       │
│─────────────────────────────────────────────────────────────│
│ id               UUID PK                                    │
│ nome_exibicao    TEXT  ("João S." — nunca nome completo      │
│                        para prestador)                      │
│ nome_completo    TEXT  ENCRYPTED ← nunca exposto ao presta- │
│                        dor                                  │
│ telefone         TEXT  ENCRYPTED ← jamais ao prestador      │
│ email            TEXT  ENCRYPTED                            │
│ canal_preferido  ENUM  (whatsapp|sms|email)                  │
│ status           ENUM  (ativo|bloqueado|inativo)            │
│ created_at       TIMESTAMPTZ                                │
└─────────────────────────────────────────────────────────────┘
         │ 1:N
         ▼
┌──────────────────────────────────────────────────────────────┐
│ ENDERECO_CLIENTE                     [ZONA SENSÍVEL A]        │
│──────────────────────────────────────────────────────────────│
│ id               UUID PK                                     │
│ cliente_id       UUID FK                                     │
│ apelido          TEXT  ("Casa", "Trabalho")                   │
│ logradouro       TEXT  ENCRYPTED                             │
│ numero           TEXT  ENCRYPTED                             │
│ complemento      TEXT  ENCRYPTED                             │
│ bairro           TEXT  (não-criptografado: usado p/ dispatch)│
│ cidade           TEXT                                        │
│ cep              TEXT                                        │
│ lat              DECIMAL ENCRYPTED  ← revelado via token     │
│ lng              DECIMAL ENCRYPTED  ← revelado via token     │
│ is_ativo         BOOL                                        │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ PRESTADOR                            [ZONA SENSÍVEL B]        │
│──────────────────────────────────────────────────────────────│
│ id               UUID PK                                     │
│ nome_exibicao    TEXT  ("Carlos M." — inicialado)            │
│ nome_completo    TEXT  ENCRYPTED                             │
│ cpf              TEXT  ENCRYPTED                             │
│ telefone         TEXT  ENCRYPTED (não exposto ao cliente)    │
│ tipo_vinculo     ENUM  (pj|mei|autonomo)                     │
│ status_kyc       ENUM  (pendente|aprovado|reprovado)         │
│ status_ativo     BOOL                                        │
│ rating_medio     DECIMAL(3,2)                                │
│ regioes_atendidas JSONB  (array de bairros/ceps)             │
│ disponibilidade  JSONB  (janelas semanais)                   │
│ pix_key          TEXT  ENCRYPTED                             │
│ banco_dados      JSONB ENCRYPTED                             │
│ aceita_novos_clientes BOOL                                   │
│ created_at       TIMESTAMPTZ                                 │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ ORDEM_SERVICO (OS)                                            │
│──────────────────────────────────────────────────────────────│
│ id               UUID PK                                     │
│ cliente_id       UUID FK                                     │
│ prestador_id     UUID FK NULL  (nulo até atribuição)         │
│ servico_id       UUID FK                                     │
│ endereco_id      UUID FK                                     │
│ status           ENUM (lead|agendado|atribuido|a_caminho|    │
│                        em_execucao|concluido|cancelado)      │
│ agendado_para    TIMESTAMPTZ                                 │
│ janela_inicio    TIMESTAMPTZ                                 │
│ janela_fim       TIMESTAMPTZ                                 │
│ valor_total      DECIMAL(10,2)                               │
│ valor_prestador  DECIMAL(10,2)                               │
│ valor_plataforma DECIMAL(10,2)                               │
│ endereco_revelado_bairro_em  TIMESTAMPTZ  ← ao aceitar       │
│ endereco_revelado_full_em    TIMESTAMPTZ  ← N h antes        │
│ endereco_token_expira_em     TIMESTAMPTZ  ← após conclusão   │
│ metadados_cancelamento JSONB                                 │
│ created_at       TIMESTAMPTZ                                 │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ PAGAMENTO                                                     │
│──────────────────────────────────────────────────────────────│
│ id               UUID PK                                     │
│ os_id            UUID FK                                     │
│ gateway          TEXT  ("asaas")                             │
│ gateway_cobranca_id   TEXT  (ID externo)                     │
│ gateway_split_id      TEXT                                   │
│ tipo             ENUM  (pix|cartao|boleto)                   │
│ valor            DECIMAL(10,2)                               │
│ status           ENUM (pendente|pago|estornado|falhou)       │
│ pago_em          TIMESTAMPTZ                                 │
│ split_plataforma DECIMAL(10,2)                               │
│ split_prestador  DECIMAL(10,2)                               │
│ split_taxa       DECIMAL(10,2)                               │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ REPASSE                                                       │
│──────────────────────────────────────────────────────────────│
│ id               UUID PK                                     │
│ prestador_id     UUID FK                                     │
│ valor            DECIMAL(10,2)                               │
│ status           ENUM (pendente|processando|pago|falhou)     │
│ pix_destino      TEXT  ENCRYPTED                             │
│ periodo_inicio   DATE                                        │
│ periodo_fim      DATE                                        │
│ repasse_em       TIMESTAMPTZ                                 │
│ gateway_transfer_id TEXT                                     │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ LOG_ACESSO_DADOS_SENSIVEIS    [APPEND-ONLY — SEM UPDATE/DEL] │
│──────────────────────────────────────────────────────────────│
│ id               BIGSERIAL PK                                │
│ ator_id          UUID                                        │
│ ator_tipo        ENUM (admin|atendente|prestador|sistema)    │
│ recurso          ENUM (telefone|email|nome_completo|         │
│                        endereco_full|lat_lng)                │
│ cliente_id       UUID FK                                     │
│ os_id            UUID FK NULL                                │
│ ip               INET                                        │
│ user_agent       TEXT                                        │
│ motivo           TEXT  (campo obrigatório no acesso)         │
│ timestamp        TIMESTAMPTZ DEFAULT NOW()                   │
└──────────────────────────────────────────────────────────────┘
  NOTA: Conceder REVOKE UPDATE, DELETE ON log_acesso_dados_sensiveis
  FROM app_user; — aplicação literalmente não consegue apagar.

┌──────────────────────────────────────────────────────────────┐
│ AVALIACAO                                                     │
│──────────────────────────────────────────────────────────────│
│ id               UUID PK                                     │
│ os_id            UUID FK UNIQUE                              │
│ nota_cliente     SMALLINT (1-5)                              │
│ comentario       TEXT                                        │
│ flag_contato_externo BOOL  ← "prestador pediu seu contato?" │
│ flag_pagamento_externo BOOL ← "prestador pediu pagar fora?" │
│ respondida_em    TIMESTAMPTZ                                 │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Isolamento de dados sensíveis

| Campo | Quem acessa | Como | Log |
|---|---|---|---|
| `telefone` do cliente | Admin, Atendente | Descriptografia server-side, exibida mascarada (último 4 dígitos) | Sim, sempre |
| `email` do cliente | Admin, Atendente | Idem | Sim |
| `nome_completo` do cliente | Admin, Atendente | Visível somente em contexto de OS ativa | Sim |
| `endereco_full` + `lat/lng` | Prestador | Token JWT efêmero assinado, TTL máximo 4h, revogado após conclusão | Sim |
| Prestador | Sistema (dispatch) | Via ID interno, nunca exibido ao cliente | N/A |

---

## 3. ADR-001: ESTRATÉGIA DE COMUNICAÇÃO E ANTI-DESINTERMEDIAÇÃO

### Contexto

O canal de comunicação entre prestador e cliente é o principal vetor de roubo de relacionamento. Dois scouts divergiram:
- **UX-researcher**: nunca número virtual mascarado via WhatsApp (custo, impossibilidade técnica no BR), recomendar GPS + botão "a caminho" (modelo Uber).
- **Search-specialist**: Twilio Proxy + 360dialog para mascaramento de número.

O conflito é real e precisa de decisão antes de codar.

### Decisão

**Adotar modelo faseado: GPS + "a caminho" como mecanismo primário de anti-desvio. Número mascarado explicitamente rejeitado para WhatsApp. Chat in-app mediado na V2.**

#### Fase 1 — MVP
- **Nenhum contato direto possível no fluxo normal**: o app do prestador nunca exibe telefone ou email do cliente.
- **Botão "A Caminho"**: aciona notificação push (FCM) + mensagem WhatsApp ao cliente via WABA da **plataforma** (não do prestador). O cliente vê "Seu prestador está a caminho" — sem identificação do prestador.
- **GPS em background** apenas durante janela ativa da OS (X horas antes até conclusão). Coordenada registrada a cada 2 min. Anti-desvio: se GPS indica prestador a >5 km do endereço sem justificativa 30 min após horário, alerta ao atendente.
- **Endereço efêmero** (seção 2.2): não é texto copiável, é pin no mapa. App usa `FLAG_SECURE` nas telas com dados sensíveis (screenshot bloqueado no Android).
- **Pós-serviço**: pesquisa NPS enviada pela plataforma com perguntas de detecção ("o prestador pediu seu contato diretamente?", "pediu para pagar fora da plataforma?"). Flags automáticos.
- **OTP** para autenticação: SMS via Twilio/Zenvia (não WhatsApp, evitar dependência de WABA para autenticação).

#### Fase 2 — V2
- **Chat in-app mediado**: canal de texto dentro do app do prestador e PWA do cliente. Todas as mensagens armazenadas server-side, monitoradas por regex (detecção de "whatsapp", "zap", "celular", "instagram", CPF patterns, endereços em texto livre).
- Alerta automático ao atendente quando padrão suspeito detectado.

### Alternativas consideradas

| Alternativa | Por que foi descartada |
|---|---|
| **Twilio Proxy para WhatsApp** | WhatsApp Business API **não permite** proxy de número de forma legítima (viola ToS). Número virtual mascarado funciona para voz/SMS, não para WABA. Custo adicional sem resolver o canal principal no Brasil. |
| **Número mascarado via VoIP (voz/SMS)** | No Brasil, o canal primário é WhatsApp, não ligação. Adicionar proxy de voz/SMS cobre canal secundário a custo alto sem reduzir o risco principal. Válido considerar para V3 se volume justificar. |
| **Sem GPS, só confiança** | Ineficaz. Não gera evidência operacional de desvio. |
| **Chat in-app no MVP** | Aumenta escopo e complexidade do MVP sem ser o mecanismo mais crítico. Anti-desvio no MVP é pela ausência de canal, não pela substituição. |

### Consequências

**Positivas:**
- MVP viável tecnicamente sem dependência de WABA próprio para mascaramento.
- GPS + botão confere percepção de controle ao cliente (experiência Uber).
- Custo de SMS OTP (Twilio/Zenvia) é baixo e previsível.

**Negativas / Riscos:**
- Prestador determinado ainda pode pedir contato verbalmente durante o serviço. Mitigado apenas por: (a) pesquisa pós-serviço, (b) cláusula contratual com multa, (c) rating afetado.
- FLAG_SECURE no Android não é 100% à prova de root. Dados sensíveis ficam em memória mesmo sem screenshot — mitigação: token efêmero de curta duração.
- GPS em background drena bateria do dispositivo básico do prestador. Mitigação: coleta esparsa (a cada 2 min) e somente dentro da janela da OS.

---

## 4. ADR-002: PAGAMENTO, SPLIT E GATEWAY

### Contexto

O dinheiro precisa transitar inteiramente pela plataforma. A maior alavanca de retenção do prestador é repasse rápido. A transição deve ser faseada para não gerar boicote. A plataforma precisa de auditabilidade financeira e emissão de NFS-e obrigatória a partir de set/2026.

### Decisão

**Gateway primário: Asaas. Modelo de split nativo (subconta). Repasse via Pix com cadência configurável por prestador (semanal ou quinzenal, D+0 após liquidação).**

#### Justificativa da escolha do Asaas

| Critério | Asaas | Pagar.me | Iugu | Mercado Pago | Stripe Connect |
|---|---|---|---|---|---|
| Pix Cobrança nativo | ✅ | ✅ | ✅ | ✅ | ⚠️ limitado BR |
| Split/marketplace API | ✅ nativo | ✅ | ✅ | ⚠️ limitado | ✅ |
| Repasse Pix D+0 | ✅ | D+2 | D+1 | D+1 | ❌ |
| Custo MVP | R$0 plano free + % | Mensalidade | Mensalidade | % mas marca | Mensalidade |
| NFS-e (integração) | Parcial | ❌ direto | ❌ direto | ❌ | ❌ |
| LGPD / empresa BR | ✅ | ✅ | ✅ | ✅ | ❌ US |
| Suporte BR | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |

Asaas vence em **repasse Pix D+0** (crítico para retenção do prestador), **zero de custo fixo no MVP** e **empresa BR**.

#### Fluxo de pagamento por fase

**FASE 1 — Transição (MVP)**
- Cliente paga na plataforma (Pix QR gerado pela plataforma / link de pagamento).
- Sistema registra `PAGAMENTO.status = pago`.
- Plataforma faz repasse ao prestador via Pix (Asaas transfer) na cadência acordada.
- Pagamento presencial ainda coexiste (prestadores mais resistentes): OS marcada como `pagamento_externo = true`, comissão cobrada separadamente via boleto/Pix ao prestador ao final do período. **GATE**: definir se isso é viável operacionalmente ou se cria reconciliação complexa.

**FASE 2 — Plataforma Total**
- Pagamento presencial eliminado. Qualquer OS sem pagamento registrado é bloqueada.
- Split automático: Asaas subconta do prestador recebe `valor_prestador` imediatamente após confirmação do pagamento. Plataforma retém `valor_plataforma`.
- Repasse automático via job agendado (Bull + Redis): todo dia X e Y do mês (ou a critério do prestador), Asaas transfer executa.

**FASE 3 — Maturidade**
- Antecipação de recebíveis como benefício para prestador fidelizado.
- Cartão de crédito parcelado para cliente (Asaas cobra do cliente parcelado, plataforma recebe integral D+2).

#### NFS-e
- Integração com **Focus NFe** (obrigatório set/2026 para NFS-e nacional padrão ABRASF/SPED).
- Emissão automatizada via webhook `PAGAMENTO.status = pago`.
- Tomador: cliente PF ou PJ, prestador de serviço: CNPJ da marca.

### Alternativas consideradas

| Alternativa | Descarte |
|---|---|
| **Pagar.me** | Repasse D+2 mínimo mata proposta de retenção do prestador pelo repasse rápido. |
| **Mercado Pago** | Percepção de brand barata prejudica posicionamento premium. API de split menos flexível. |
| **Stripe Connect** | Melhor stack técnico mas sem suporte nativo a Pix e empresa US (LGPD). |
| **Gateway próprio (Pix direto)** | Risco regulatório (precisa de arranjo de pagamento ou parceria com IP/EC). Fora de cogitação para MVP. |

### Consequências

**Positivas:**
- Repasse D+0 é argumento concreto anti-boicote do prestador.
- Custo fixo zero no MVP (Asaas cobra % por transação).
- Split nativo elimina lógica manual de transferência.

**Negativas / Riscos:**
- Lock-in no Asaas. Mitigação: abstrair gateway atrás de interface `IPaymentGateway` — trocar por Pagar.me em 1 sprint se necessário.
- Chargeback em cartão: responsabilidade da plataforma (como marketplace). Mitigação: acionar seguro antifraude do Asaas e política de estorno documentada.
- Fase 1 com pagamento externo cria reconciliação manual. **Recomendação**: limitar Fase 1 a máximo 60 dias e empurrar para Fase 2 agressivamente.

---

## 5. ADR-003: STACK POR SUPERFÍCIE

### Contexto

Quatro superfícies com perfis radicalmente diferentes. Decisão de stack deve otimizar velocidade de MVP sem criar dívida técnica bloqueante para V2.

### 5.1 Cliente — PWA (MVP) → App Nativo (V2)

**Decisão: PWA com Next.js no MVP.**

| Critério | PWA | App Nativo React Native | App Nativo Flutter |
|---|---|---|---|
| TTM para MVP | ✅ rápido | Médio | Médio |
| Push iOS/Android | ⚠️ limitado iOS | ✅ | ✅ |
| Distribuição | ✅ link direto | App Store (demorado) | App Store |
| Atualização instantânea | ✅ | ⚠️ OTA parcial | ⚠️ OTA parcial |
| Uso offline | ⚠️ | ✅ | ✅ |

Cliente de limpeza residencial **não é DAU extremo** — não precisa de app Store no MVP. PWA cobre 95% dos casos de uso com time-to-market 2-3× menor. Push para iOS tem limitações reais mas: (a) cliente não precisa de push crítico no MVP, (b) WhatsApp/SMS cobre essa necessidade.

**V2**: app nativo React Native (compartilha lógica com backend TS, time BR mais disponível que Flutter devs).

### 5.2 Prestador — App Nativo Android

**Decisão: Flutter para Android-first, com iOS como build gratuito para V2.**

Razões:
- GPS em background confiável requer nativo. PWA não garante execução em background no Android.
- `FLAG_SECURE` (bloqueio de screenshot) é API Android nativa — Flutter expõe via platform channel.
- Push (FCM) mais confiável em app nativo.
- Endereço efêmero: dados do cliente **nunca gravados em SQLite local** — política de desenvolvimento obrigatória. Apenas armazenamento em memória, buscados via token. Token armazenado em `EncryptedSharedPreferences`.
- Flutter escolhido sobre React Native porque: (a) compilado nativamente (melhor para 4G oscilante e hardware básico), (b) uma codebase para iOS eventual, (c) Dart é mais estrito que JS — reduz bugs de dados sensíveis em memória.

**Mecanismos de segurança no app do prestador:**

```
1. FLAG_SECURE: todas as Activities com dados de cliente
2. EncryptedSharedPreferences: APENAS para token de sessão — sem dados de cliente
3. Endereço como MapWidget (não Text/EditText): não é selecionável/copiável
4. Token efêmero: chamada API retorna coordenadas com TTL, não persistidas
5. Auto-logout após 30 min de inatividade
6. Certificate pinning para prevenir MITM em 4G
7. Root detection: aviso ao usuário (não bloqueio total — pode ser falso positivo em Android basic)
8. Obfuscação: ProGuard/R8 obrigatório em release build
```

### 5.3 Painel Atendente + Admin — Web SPA

**Decisão: Next.js (SSR) com autenticação por sessão server-side (não JWT puro no browser).**

- Next.js com App Router.
- SSR para páginas sensíveis (dados do cliente nunca em localStorage/sessionStorage do browser).
- RBAC server-side: middleware Next.js verifica claims antes de renderizar páginas com dados sensíveis.
- Session cookie HttpOnly + Secure + SameSite=Strict.
- Timeout de sessão para atendente: 30 min sem interação.

### 5.4 Backend — Core API

**Decisão: Node.js + TypeScript + Fastify. PostgreSQL + Redis. Deploy em cloud BR (AWS São Paulo / Railway).**

| Camada | Tecnologia | Alternativa considerada |
|---|---|---|
| Runtime | Node.js + TypeScript | Go (mais performático, mas ecossistema menor para time MVP) |
| Framework | Fastify | Express (mais popular), NestJS (mais estruturado mas over-engenhering para MVP) |
| ORM | Drizzle ORM | Prisma (mais popular mas mais pesado), TypeORM (legacy) |
| DB principal | PostgreSQL (RDS ou Supabase) | MySQL (menos features de JSONB/crypto) |
| Cache + Filas | Redis (ElastiCache ou Upstash) | BullMQ sobre Redis para jobs |
| Infra MVP | Railway (custo ~R$100-200/mês) | AWS ECS (mais caro, mais complexo para MVP) |
| Infra V2 | AWS São Paulo (ECS + RDS + ElastiCache) | GCP São Paulo |
| Criptografia campos | `pgcrypto` (PostgreSQL nativo) + KMS | Criptografia na aplicação pura |

**Nota sobre Railway vs AWS**: Railway é aceitável para MVP (reduz ops overhead, custo baixo). Migração para AWS São Paulo deve ocorrer antes do V2 ou quando volume de OS > 200/mês — não pela capacidade, mas pela LGPD exigir documentação de data residency para dados sensíveis.

### Consequências

**Positivas:**
- PWA do cliente elimina fricção de instalação no MVP — link direto no WhatsApp é suficiente.
- Flutter no prestador garante confiabilidade de GPS e segurança de dados.
- Next.js unifica frontend do painel e PWA em mesma stack (um time).
- Node.js TypeScript = mesma linguagem end-to-end (reduz contexto switching).

**Negativas / Riscos:**
- Flutter tem curva de aprendizado. Risco: disponibilidade de devs Flutter no BR é menor que React Native. **Gate**: confirmar skill do time antes de committar.
- PWA no iOS tem limitações de push que podem frustrar clientes Apple. Mitigação: WhatsApp como canal de notificação primário para MVP.
- Railway sem SLA enterprise: avaliar impacto para dados sensíveis. Mitigação: backup diário para S3, RDS gerenciado mesmo no Railway.

---

## 6. TRADE-OFFS EXPLÍCITOS — VISÃO CONSOLIDADA

| Decisão | O que ganhamos | O que sacrificamos |
|---|---|---|
| GPS em vez de número mascarado | Viabilidade técnica real, sem custo de Twilio Proxy, anti-desvio operacional | Prestador determinado ainda pode agir verbalmente |
| Asaas em vez de Pagar.me | Repasse D+0, zero custo fixo MVP | Lock-in, menos brand enterprise |
| Flutter em vez de React Native | Performance, compilado nativo, cross-platform futuro | Menor pool de devs disponíveis no BR |
| PWA cliente em vez de app nativo | TTM 2-3× menor, sem app store | Push iOS limitada, sem offline robusto |
| Fase de transição de pagamento | Reduz boicote do prestador, adoção suave | Reconciliação complexa, risco de prestador usar a janela para desviar pagamentos |
| Endereço efêmero no mapa (não texto) | Dado copiável removido | UX levemente pior (prestador não pode exportar rota facilmente — mas pode abrir no Maps) |
| Chat in-app apenas V2 | Reduz escopo MVP | Janela de comunicação verbal não monitorada no MVP |
| Append-only log de acesso | Auditoria LGPD irrefutável | Não permite correção de registros errados — exige cuidado na gravação |

---

## 7. RISCOS ARQUITETURAIS E MITIGAÇÕES

### RISCO 1 — STF e Vínculo Trabalhista (CRÍTICO)

**Contexto**: STF julga em jun/2026 se apps de serviço criam vínculo empregatício. Resultado pode impactar modelo de negócio inteiramente.

**Sinais de subordinação no design que DEVEM ser evitados:**

| Sinal de subordinação | Como o design evita |
|---|---|
| Plataforma define horário obrigatório | Prestador cadastra janelas de disponibilidade próprias; pode recusar OS |
| Exclusividade | Contrato permite que prestador trabalhe para outras plataformas |
| GPS full-time | GPS ativado SOMENTE durante OS ativa (flag explícito no app: "rastreamento ativo") |
| Preço fixado unilateralmente | Tabela de preços tem piso mínimo; V2 permite prestador definir adicional |
| Uniforme/equipamento obrigatório | Recomendação, não obrigação contratual |
| Métricas de performance punitivas | Rating público SIM, desligamento automático NÃO — revisão humana obrigatória |
| Subordinação tecnológica | App não impede prestador de atender clientes externos — somente monitora dentro da OS |

**Mitigação adicional**: contratar advogado trabalhista especializado em marketplace antes do lançamento para revisar contrato do prestador.

### RISCO 2 — Desvio pelo Atendente (ALTO)

**Contexto**: o atendente CLT tem acesso a dados completos do cliente e pode agir como o prestador renegado.

**Mitigações:**
- Acesso a dados sensíveis somente em contexto de OS ativa (RBAC: `can_view_client_contact` required `has_active_os_context`).
- Log imutável de toda consulta (ADR-003 já resolve).
- Alertas automáticos: atendente que acessa >N contatos sem OS vinculada na mesma sessão → flag para admin.
- Cláusula de não-concorrência no contrato CLT com prazo e multa.
- Acesso revogado no mesmo dia de desligamento (processo de offboarding documentado).

### RISCO 3 — Dependência de WABA/360dialog

**Contexto**: WABA é infraestrutura crítica de comunicação com o cliente. Downtime ou banimento de conta paralisa operação.

**Mitigação:**
- Fallback automático: se WABA falha, notificação por SMS (Twilio/Zenvia) via mesmo job de notificação.
- Duas contas WABA em providers diferentes no V2 (failover).
- Nunca usar WABA para OTP de autenticação — SMS puro para isso.

### RISCO 4 — Dados Sensíveis no App do Prestador

**Contexto**: endereço efêmero pode vazar via screenshot root ou extração de memória.

**Mitigação (profundidade):**
- Token de endereço com TTL de 4h máximo, revogado pelo servidor após `status = concluido`.
- Coordenadas nunca armazenadas em banco local do device.
- Expiração em memória: após 30 min sem interação na tela do endereço, dados limpos do state.
- Certificate pinning bloqueia MITM em 4G compartilhado.

### RISCO 5 — Lock-in Asaas

**Contexto**: mudança de gateway em produção é cara e arriscada.

**Mitigação:** interface `IPaymentGateway` abstrai implementação desde o dia 1. Contrato de interface:
```
criarCobranca(os: OS): Promise<CobrancaResult>
verificarStatus(id: string): Promise<StatusPagamento>
executarRepasse(prestador: Prestador, valor: Decimal): Promise<RepasseResult>
cancelarCobranca(id: string): Promise<void>
```
Troca de Asaas por Pagar.me = nova implementação da interface, zero mudança no domínio.

### RISCO 6 — LGPD e Brecha de Dados

**Contexto**: base de dados com dados de clientes é o ativo principal. Brecha = desastre de reputação + multa ANPD.

**Mitigação:**
- Dados sensíveis criptografados em repouso (AES-256-GCM, chave gerenciada em AWS KMS ou Vault).
- Backups criptografados.
- Política de retenção: dados de cliente deletados após 5 anos de inatividade (com alerta para titular).
- DPO designado (obrigatório para empresa que trata dados em larga escala — verificar threshold de volume).
- Relatório de Impacto de Proteção de Dados (RIPD) antes do lançamento.

### RISCO 7 — NFS-e Nacional (set/2026)

**Contexto**: prazo curto. Plataforma deve emitir NFS-e padrão nacional para todos os serviços prestados.

**Mitigação:**
- Focus NFe integrado desde o V1 (não deixar para V2).
- Webhook em `PAGAMENTO.status = pago` dispara emissão.
- Município a município ainda tem variação — Focus NFe abstrai isso.
- **Gate crítico**: definir CNPJ emissor (marca), ISS retido ou não, alíquota por cidade.

---

## 8. ROADMAP DE FASES

### FASE 0 — Fundação (4-6 semanas, antes de qualquer usuário)

- [ ] Setup infra: Railway + PostgreSQL + Redis + domínios.
- [ ] Autenticação: JWT + OTP SMS (Twilio).
- [ ] RBAC base: Admin, Atendente, Prestador, Cliente.
- [ ] KYC prestador: Identiq integrado.
- [ ] Modelo de dados: todas as entidades do seção 2, criptografia de campos sensíveis.
- [ ] Log de acesso imutável: tabela append-only, REVOKE DDL.
- [ ] Asaas: conta, subconta por prestador, Pix cobrança.
- [ ] Responder questões-gate (seção 9) antes de prosseguir.

### FASE 1 — MVP Operacional (8-12 semanas)

**Objetivo**: OS saindo, dinheiro transitando pela plataforma, prestador rastreável.

- [ ] Painel Web (Atendente + Admin): CRM básico, agendamento, atribuição manual de OS.
- [ ] PWA Cliente: agendamento, pagamento Pix, NPS pós-serviço.
- [ ] App Prestador (Flutter/Android): aceitar OS, ver bairro → ver endereço em mapa, botão "a caminho", GPS background, FLAG_SECURE.
- [ ] Notificações: FCM push (prestador) + WABA (cliente) + SMS fallback.
- [ ] Split automático Asaas: repasse semanal D+0.
- [ ] Endereço efêmero: token JWT com TTL, sem cache local.
- [ ] Pesquisa pós-serviço com flags anti-desvio.
- [ ] 360dialog WABA: conta da plataforma para notificações ao cliente.
- [ ] Google Maps: geocoding + directions (somente durante OS ativa).
- [ ] NFS-e: Focus NFe integrado (set/2026 é hard deadline — se MVP for antes, preparar mas não emitir ainda se legislação não exigir).

**KPI de saída da Fase 1**: ≥80% das OS com pagamento via plataforma; ≥90% dos prestadores com repasse semanal sem reclamação de atraso.

### FASE 2 — Anti-Desvio Reforçado + Escala (12-20 semanas pós-MVP)

**Objetivo**: fechar brechas de comunicação, melhorar UX do cliente, escalar operação.

- [ ] Chat in-app mediado: mensagens armazenadas server-side, detecção de padrões suspeitos.
- [ ] App nativo cliente: React Native, com push iOS nativo.
- [ ] Agendamento recorrente (planos de limpeza mensal): maior retenção de cliente.
- [ ] Dashboard do prestador: histórico de repasses, projeção, feedback.
- [ ] Avaliações bidirecional: cliente avalia prestador, prestador avalia cliente.
- [ ] Dispatch automático: algoritmo de matching por região + rating (substitui atribuição manual).
- [ ] Cartão de crédito parcelado para cliente.
- [ ] Antecipação de recebíveis para prestador fidelizado.
- [ ] Painel de analytics: KPIs do negócio em tempo real.
- [ ] SLA + oncall: migração Railway → AWS São Paulo.

### FASE 3 — Produto Maduro

- [ ] Pagamento presencial eliminado completamente.
- [ ] App iOS para prestador (Flutter build gratuito).
- [ ] IA para detecção de anomalias: padrões de desvio, previsão de churn de cliente.
- [ ] B2B: contratos corporativos com SLA.
- [ ] Marketplace de serviços: outros tipos além de limpeza.

---

## 9. QUESTÕES-GATE CONSOLIDADAS

Essas 15 questões precisam de resposta do dono ANTES de iniciar o desenvolvimento. Decisões arquiteturais bloqueadas estão identificadas.

| # | Questão | Impacto se não respondida | Urgência |
|---|---|---|---|
| G1 | **Split %**: qual a comissão da plataforma? (ex: 20% da OS) | Modelo de dados `PAGAMENTO`, regras de repasse | BLOQUEANTE |
| G2 | **Vínculo jurídico do prestador**: PJ, MEI ou autonomo? Mix? | Contrato, NFS-e (emissor), ISS, risco STF | BLOQUEANTE |
| G3 | **Gateway definitivo**: confirmar Asaas ou outro? | ADR-002 assume Asaas — mudar agora é barato, depois não é | BLOQUEANTE |
| G4 | **Canal do cliente no MVP**: somente link/PWA via WhatsApp, ou também divulgar domínio? | Estratégia de onboarding, QR no cartão de visita | ALTO |
| G5 | **WABA próprio**: a empresa tem ou vai registrar número WABA (360dialog)? CNPJ, verificação Meta pode levar 2-4 semanas | Sem WABA, notificações ao cliente caem para SMS (mais caro, menos efetivo no BR) | BLOQUEANTE |
| G6 | **Fase 1 de pagamento**: aceitar pagamento presencial por quanto tempo? (recomendação: máximo 60 dias) | Define complexidade de reconciliação manual | ALTO |
| G7 | **Repasse ao prestador**: semanal (D+7) ou quinzenal? Prestador pode escolher? | Regras do job de repasse | MÉDIO |
| G8 | **Volume esperado de OS no MVP**: <50/mês, 50-200, >200? | Decide se Railway é suficiente ou precisamos de AWS desde o início | MÉDIO |
| G9 | **Regiões de lançamento**: quais cidades/bairros no MVP? | Geocoding, regras de dispatch, KYC de prestadores por região | ALTO |
| G10 | **NFS-e**: CNPJ emissor é a marca (plataforma) ou o prestador? Plataforma é tomadora ou prestadora? Município sede? | Integração Focus NFe, alíquota ISS, retenção | BLOQUEANTE (deadline set/2026) |
| G11 | **Skills do time técnico**: há devs Flutter disponíveis? Ou preferem React Native? | ADR-003 stack do app do prestador | BLOQUEANTE para início do sprint 1 |
| G12 | **Orçamento de serviços recorrentes**: R$400-800/mês estimado é aceitável para MVP? Limites? | Escolha de tier Railway, Asaas, Twilio, 360dialog | MÉDIO |
| G13 | **KYC do prestador**: checagem de CPF + antecedentes criminais obrigatória antes de qualquer OS? Identiq ou alternativa manual no MVP? | Experiência de onboarding do prestador, tempo de ativação | ALTO |
| G14 | **Política de cancelamento**: qual o prazo mínimo e a multa para cancelamento de OS? | Regras de negócio no status da OS, lógica de estorno | MÉDIO |
| G15 | **Atendente no MVP**: será humano full-time ou o próprio dono opera? | Define se o painel de atendente é MVP crítico ou pode ser simplificado | ALTO |

---

## 10. SUMÁRIO DE DECISÕES

| ADR | Decisão | Alternativa perdedora | Ponto de reversão |
|---|---|---|---|
| ADR-001 | GPS + botão "a caminho" (modelo Uber) como anti-desvio primário | Twilio Proxy / número mascarado | Se volume de desvio verbal >10% após 3 meses → acionar chat in-app antes do roadmap previsto |
| ADR-002 | Asaas como gateway + split nativo + repasse Pix D+0 | Pagar.me, Stripe Connect | Interface `IPaymentGateway` permite troca em 1 sprint |
| ADR-003a | PWA Next.js para cliente no MVP | App nativo React Native | Quando DAU > 1000 ou reclamação de push iOS > 15% → V2 app nativo |
| ADR-003b | Flutter Android para app do prestador | React Native | Se dificuldade de contratação Flutter > 4 semanas → React Native com as mesmas restrições de segurança |
| ADR-003c | Node.js + Fastify + PostgreSQL + Redis | Go + pgx | Não há ponto de reversão esperado para MVP/V2 |

---

*Documento produzido na fase de pré-projeto. Não contém código de produção. Todas as decisões aqui são hipóteses a serem confirmadas com as respostas às questões-gate (seção 9). Próximo passo recomendado: sessão de 2h com o dono para responder G1–G5 e G10–G11, que são os desbloqueadores do sprint 0.*
