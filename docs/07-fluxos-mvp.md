# Cleanox MVP — Fluxos e Telas (Sprint 0)

## Visão Geral: End-to-End MVP

```
CLIENTE                PRESTADOR              ATENDENTE/ADMIN
  |                       |                         |
  | (WhatsApp/anúncio)     |                         |
  v                        |                         |
[PWA Link] ────────────────────────────────────────►[Painel]
  |                        |                         |
  +──> Agendar             |                    [Fila de leads]
  |    (forms)             |                         |
  |    Confirmar           |                    [Criar/Editar OS]
  |    Pagar (Pix)         |                         |
  |                        |                    [Atribuir Prestador]
  v                        |                         |
[Acompanhamento]           |                    [Kanban Status]
  | (mapa + "Estou         |                         |
  |  a caminho")           |                    [Bloqueios/Dashboard]
  |                        |                         |
  +──────────────────────► [App Prestador]           |
  |                        | (notif GPS)             |
  |                        |                         |
  |                    [Login OTP]                   |
  |                    [Lista de OS]                 |
  |                    [Aceitar]                     |
  |                    ["Estou a caminho"]           |
  v                        v                         |
[Pós-Serviço]         ["Cheguei"/"Concluindo"]      |
  | (avaliação +          | (foto antes/depois)      |
  |  flags anti-         |  (GPS ativo)             |
  |  desvio + recibo)    |                          |
  |                   ["Concluído"]                  |
  v                        v                         v
                      [Confirmar Repasse]    [Atualizar Kanban]
                      (split visto)
```

---

# 1 PWA CLIENTE

## Fluxo Crítico
**Link → Agendar → Pagar → Acompanhar → Avaliar**

### Tela 1: Landing (acesso via WhatsApp/anúncio)

```
╔═══════════════════════════════════════╗
║         CLEANOX LIMPEZA              ║ (logotipo + ícone)
║                                       ║
║  Agende agora! Pagamento online      ║
║  Prestador rastreável em tempo real   ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ Entrar com Telefone             │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  (ou verificar se já logado)           ║
║                                       ║
║  Conheça nossos prestadores avaliados ║
║  ★★★★★ (ratings)                      ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Carregando: spinner no botão
  - Erro de SMS: "Não chegou? Reenviar em 58s"
  - Logado: pula direto para Tela 2 (Agendar)
```

---

### Tela 2: Agendar Serviço

```
╔═══════════════════════════════════════╗
║  Nova Solicitação                     ║
╠═══════════════════════════════════════╣
║                                       ║
║  Localização (PIN no mapa)            ║
║  ┌─────────────────────────────────┐  ║
║  │ [Tocar mapa para marcar ponto]  │  ║
║  │                                 │  ║
║  │         [mapa interativo]        │  ║
║  │                                 │  ║
║  │     (endereço aparece aqui)      │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  Data e Hora                          ║
║  ┌─────────────────────────────────┐  ║
║  │ Hoje, 14:00 ▼                   │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  Tipo de Limpeza                      ║
║  ☐ Apartamento (mín. 2h)             ║
║  ☐ Casa (mín. 3h)                    ║
║  ☐ Escritório (mín. 4h)              ║
║                                       ║
║  Observações (opcional)               ║
║  ┌─────────────────────────────────┐  ║
║  │ "Tenho gato, cuidado..."         │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  Valor estimado: R$ 150,00            ║
║  (sem surpresas no fim)                ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Continuar para Pagamento      │  ║
║  └─────────────────────────────────┘  ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Mapa vazio: "Toque no mapa para marcar seu endereço"
  - Carregando preço: "Calculando..."
  - Erro de localização: "Não conseguimos acessar seu mapa. 
                         Tire permissão no navegador."
  - Tipo não selecionado: botão Continuar desabilitado (cinza)

→ ANTI-DESVIO:
  - Endereço "efêmero": nunca mostra rua/número 
    (só pin no mapa, visível só a partir do "aceitei")
  - Marca CLEANOX sempre visível (header)
```

---

### Tela 3: Confirmar Pedido + Dados de Pagamento

```
╔═══════════════════════════════════════╗
║  Confirme seu Pedido                  ║
╠═══════════════════════════════════════╣
║                                       ║
║  Local (PIN)                          ║
║  [mapa pequeno com pin]               ║
║  "Saiba mais" ← (expande endereço      ║
║                 só após Asaas           ║
║                 confirmar)              ║
║                                       ║
║  Hoje, 14:00                          ║
║  Apartamento                          ║
║  R$ 150,00                            ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Pagamento (PIX)                      ║
║  ┌─────────────────────────────────┐  ║
║  │ ┌─────────────────────────────┐ │  ║
║  │ │ Seguro via CLEANOX          │ │  ║
║  │ │    (não compartilhamos seus  │ │  ║
║  │ │     dados com o prestador)   │ │  ║
║  │ └─────────────────────────────┘ │  ║
║  │                                 │  ║
║  │  ┌───────────────────────────┐  │  ║
║  │  │ Usar PIX Automático       │  │  ║
║  │  │    (Asaas gerencia)        │  │  ║
║  │  └───────────────────────────┘  │  ║
║  │                                 │  ║
║  │  ┌───────────────────────────┐  │  ║
║  │  │ Gerar QR PIX              │  │  ║
║  │  │    (para app do banco)     │  │  ║
║  │  └───────────────────────────┘  │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Confirmar e Pagar            │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  Ao confirmar, você aceita os        ║
║  Termos de Serviço de CLEANOX        ║
║  (link pequeno)                      ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Aguardando PIX: spinner / QR piscando
  - PIX confirmado: ✓ + som/vibração (confetti opcional)
  - Erro Asaas (timeout): "Algo errou. Tente novamente.
                           Seu dinheiro é seguro."
  - PIX recusado: "Seu banco recusou. Tente outro PIX 
                   ou entre em contato: 0800-CLEANOX"

→ ANTI-DESVIO:
  - "Seguro via CLEANOX" (banner destacado)
  - Nenhum número de telefone do prestador aqui
  - Ícone de cadeado em destaque (confiança)
  - Logo CLEANOX em todos os topos
```

---

### Tela 4: Acompanhamento (Prestador a Caminho)

```
╔═══════════════════════════════════════╗
║  Seu Prestador está a Caminho!       ║
╠═══════════════════════════════════════╣
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │                                 │  ║
║  │         [MAPA COM GPS]          │  ║
║  │                                 │  ║
║  │    (ponto azul = prestador)      │  ║
║  │    (casa = seu local)            │  ║
║  │                                 │  ║
║  │         ETA: 12 min              │  ║
║  │                                 │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  ⭐ João da Silva                     ║
║  (foto pequena, nome, rating ★★★★★)  ║
║                                       ║
║  ☐ Estou a caminho                  ║
║    (botão piscando = notificação      ║
║     enviada ao cliente)               ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ Reportar Problema               │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  Status: CONFIRMADO (verde)           ║
║  Horário: 14:00                       ║
║  Tipo: Apartamento                    ║
║                                       ║
║  ─────────────────────────────────    ║
║  O prestador NÃO pode ver seu         ║
║  telefone ou endereço real.           ║
║  Comunicação apenas via CLEANOX.      ║
║                                       ║
║  Cancelar OS (até 1h antes)           ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Esperando "Estou a caminho": botão piscando
  - Prestador confirmou: checkmark, ETA aparece
  - GPS perdido (4G offline): 
    "Perdemos contato. Tentando reconectar..."
    (continua mostrando ETA anterior)
  - Cancelamento: "Sua OS foi cancelada. 
                   Reembolso em 24h."

→ MICRO-INTERAÇÕES:
  - Mapa atualiza a cada 10s (ou menos se offline)
  - Sons/notificações quando status muda
  - Botão "Reportar Problema" → chat com atendente
    (não com o prestador)

→ ANTI-DESVIO:
  - Botão "Reportar Problema" sempre visível
  - Aviso em texto: "O prestador NÃO pode ver 
    seu telefone ou endereço real"
  - Marca CLEANOX reiterada
  - Se tiver tentativa de contato direto (SMS, 
    WhatsApp do prestador): flag para relatório
```

---

### Tela 5: Pós-Serviço (Avaliação + Anti-Desvio + Recibo)

```
╔═══════════════════════════════════════╗
║  Como foi o serviço?                  ║
╠═══════════════════════════════════════╣
║                                       ║
║  Avaliação                            ║
║  ⭐⭐⭐⭐⭐ (toque para mudar)            ║
║                                       ║
║  Deixe um comentário (opcional)       ║
║  ┌─────────────────────────────────┐  ║
║  │ "Ficou muito limpo, parabéns!"   │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  ANTI-DESVIO (crítico)                ║
║                                       ║
║  □ O prestador pediu seu contato     ║
║    (telefone, email, WhatsApp)?      ║
║                                       ║
║  □ O prestador pediu pagamento       ║
║    direto (cash/Pix pessoal)?        ║
║                                       ║
║  □ O prestador ofereceu um serviço   ║
║    fora da plataforma?               ║
║                                       ║
║  [Se qualquer flag marcada →          ║
║   "Muito obrigado por avisar.         ║
║    Vamos investigar e agir.           ║
║    Bloqueio em 24h se confirmado."]   ║
> ⚠ ERRATA ADR-004: substituir por "Vamos investigar. Você será informado do resultado." — sem prazo nem bloqueio automático.
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Seu Recibo                           ║
║  ┌─────────────────────────────────┐  ║
║  │ Cleanox Limpeza                 │  ║
║  │ 25/06/2026 • 14:00–16:30        │  ║
║  │ Apartamento                     │  ║
║  │ PIN: [criptografado]            │  ║
║  │                                 │  ║
║  │ Valor: R$ 150,00                │  ║
║  │ Plataforma: -R$ 15,00 (10%)     │  ║
║  │ ────────────────────────────     │  ║
║  │ Recebido por: [prestador]       │  ║
║  │ Status: ✓ Pago                  │  ║
║  │                                 │  ║
║  │ Link para PDF (arquivo)          │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Confirmar                     │  ║
║  └─────────────────────────────────┘  ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Carregando recibo: "Gerando recibo..."
  - Erro ao gerar: "Tente novamente. 
                    Recibo será enviado por email."

→ MICRO-INTERAÇÕES:
  - Flags anti-desvio com tooltips 
    ("Por que perguntamos isso?")
  - Recibo em PDF baixável
  - Avaliação salva após 2s (sem esperar clique)

→ DADOS COLETADOS (backend):
  - Rating (1-5 stars)
  - Texto comentário
  - 3 flags anti-desvio (boolean)
  - Timestamp
  - IP/User-Agent (análise de fraude)
  → Triggers: flag marcada = gera alerta 
    no painel de admin

→ ANTI-DESVIO:
  - 3 flags explícitas (não paranoia, 
    mas muito direto)
  - Resposta imediata ("Vamos investigar")
  - Recibo mostra o split, não é oculto
  - Nome do prestador no recibo 
    (rastreabilidade)
```

---

### Edge Cases & Fallbacks (PWA Cliente)

| Cenário | Fallback |
|---------|----------|
| **PIX não confirmou em 5 min** | SMS: "Não recebeu o Pix? Clique aqui para reenviar: [link]" |
| **4G caiu durante acompanhamento** | Mapa fica estático, mostra "Último visto há 2 min". Aviso: "Reconectando..." |
| **Prestador não chegou no ETA+15min** | Notificação + chat com atendente (não direto com prestador). Opção: cancelar + reembolso |
| **Cliente quer contatar prestador** | Botão "Reportar Problema" → chat CLEANOX. Nunca número direto. |
| **Cliente tenta compartilhar endereço** | PIN não copiável. Se tenta copiar: "Endereço é visto apenas no dia do serviço" |

---

---

# 2 APP PRESTADOR (Flutter/Android)

## Fluxo Crítico
**Login OTP → Lista de OS (mostra bairro) → Detalhe (aceitar) → "Estou a caminho" (GPS) → "Cheguei" → "Concluído" (foto) → Repasse confirmado**

### Onboarding (4 telas)

#### Tela 0a: Bem-vindo

```
╔═══════════════════════════════════════╗
║        Bem-vindo!                     ║
║                                       ║
║     CLEANOX Limpeza                   ║
║     Ganhe dinheiro limpando           ║
╠═══════════════════════════════════════╣
║                                       ║
║  • Receba chamados de limpeza         ║
║  • Acompanhamento em tempo real       ║
║  • Repasse rápido no seu PIX          ║
║  • Avaliações e mais serviços         ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ Continuar                       │  ║
║  └─────────────────────────────────┘  ║
╚═══════════════════════════════════════╝
```

#### Tela 0b: Login (OTP)

```
╔═══════════════════════════════════════╗
║  Seu Telefone                         ║
╠═══════════════════════════════════════╣
║                                       ║
║  Vamos enviar um código por SMS       ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ (11) 98765-4321                 │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Enviar Código                 │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  [Após SMS]                            ║
║                                       ║
║  Código de 6 dígitos                  ║
║  ┌──┬──┬──┬──┬──┬──┐                 ║
║  │  │  │  │  │  │  │ (auto-focus)   ║
║  └──┴──┴──┴──┴──┴──┘                 ║
║                                       ║
║  Não chegou? Reenviar em 45s          ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Carregando: spinner no botão
  - Erro SMS: "Não conseguimos enviar. 
              Verifique sua internet."
  - Código inválido: "Código errado. 
                     Tente novamente."
  - Código expirado: "Tempo esgotado. 
                     Reenvie um novo."
```

#### Tela 0c: Dados Bancários (Pix)

```
╔═══════════════════════════════════════╗
║  Sua Chave PIX                        ║
║  (para receber repasse rápido)        ║
╠═══════════════════════════════════════╣
║                                       ║
║  Vamos transferir o dinheiro todo     ║
║  dia direto para você                 ║
║                                       ║
║  Tipo de chave PIX                    ║
║  ○ CPF                                ║
║  ○ Email                              ║
║  ○ Telefone                           ║
║  ○ Chave aleatória                    ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ 12345678901 (CPF)               │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Continuar                     │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  (Seu banco será avisado.              ║
║   É seguro.)                           ║
╚═══════════════════════════════════════╝

→ DADOS COLETADOS:
  - Tipo de chave (CPF mais comum no MVP)
  - Valor da chave
  - Validação básica
  → Sincroniza com Asaas para split
```

#### Tela 0d: Permissões (Localização)

```
╔═══════════════════════════════════════╗
║  Permissão de Localização             ║
╠═══════════════════════════════════════╣
║                                       ║
║  CLEANOX precisa saber seu GPS        ║
║  enquanto você está a caminho         ║
║                                       ║
║  • Nós não vendemos seu endereço      ║
║  • Apagamos o histórico após 48h      ║
║  • Cliente vê só enquanto está        ║
║    a caminho (não salva)              ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Permitir Localização          │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  Você pode mudar depois em Ajustes    ║
║                                       ║
║  [Após clicar, system permission]      ║
╚═══════════════════════════════════════╝

→ APÓS ONBOARDING:
  - Cria conta no backend CLEANOX
  - Sincroniza chave PIX com Asaas
  - Ativa GPS para background (geolocalização 
    contínua quando app aberto)
  → Direciona para Tela 1 (Lista de OS)
```

---

### Tela 1: Lista de OS do Dia (Tela Inicial)

```
╔═══════════════════════════════════════╗
║  Seus Chamados Hoje            9:30  ║
║  ═════════════════════════════════    ║
║  João Silva  ⭐⭐⭐⭐⭐ (16 reviews)      ║
╠═══════════════════════════════════════╣
║                                       ║
║  ✓ CONFIRMADOS (2)                    ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ APARTAMENTO                     │  ║
║  │    Pinheiros, SP                │  ║
║  │    Hoje • 14:00                 │  ║
║  │    R$ 150,00                    │  ║
║  │    ⭐⭐⭐⭐⭐ (cliente novo)        │  ║
║  │    → Toque para detalhe         │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ CASA                            │  ║
║  │    Vila Mariana, SP             │  ║
║  │    Hoje • 16:00                 │  ║
║  │    R$ 280,00                    │  ║
║  │    ⭐⭐⭐⭐☆ (regular)            │  ║
║  │    → Toque para detalhe         │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  CONVITES NÃO ACEITOS (1)             ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ESCRITÓRIO                      │  ║
║  │    Bela Vista, SP               │  ║
║  │    Hoje • 11:00                 │  ║
║  │    R$ 400,00                    │  ║
║  │    ⭐⭐⭐⭐⭐ (cliente VIP)         │  ║
║  │    [ Aceitar ] [ Recusar ]      │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Ganhos Hoje: R$ 430,00               ║
║  (após devolução CLEANOX)              ║
║                                       ║
║  Ajustes                              ║
║  (canto inferior)                      ║
╚═══════════════════════════════════════╝

→ DADOS VISÍVEIS:
  ✓ Bairro (ex: "Pinheiros, SP")
  ✓ Data/hora da OS
  ✓ Valor
  ✓ Tipo de limpeza (apartamento/casa/escritório)
  ✓ Rating do cliente
  
→ DADOS OCULTOS (até aceitar):
  ✗ Telefone do cliente
  ✗ Endereço completo (rua/número)
  ✗ Nomes de clientes confirmados

→ CORES:
  - Azul = confirmado (foi atribuído, você foi notificado)
  - Amarelo = confirmado (outro convite)
  - Cinza = pendente (convite aberto, 30 min para aceitar)

→ MICRO-INTERAÇÕES:
  - Notificação sonora quando novo convite chega
  - Pull-to-refresh (deslizar para baixo)
  - Card incha um pouco ao tocar (feedback tátil)
  - Recusado: some da lista após 2s

→ FALLBACK (offline):
  - "Sem conexão. Mostrando dados salvos."
  - Botões desabilitados
  - Sincroniza quando conecta
```

---

### Tela 2: Detalhe da OS (Pré-Aceitar)

```
╔═══════════════════════════════════════╗
║  Detalhe do Chamado             X    ║
╠═══════════════════════════════════════╣
║                                       ║
║  APARTAMENTO                          ║
║     Pinheiros, SP                     ║
║                                       ║
║  ⭐⭐⭐⭐⭐ Cliente novo                ║
║  "Primeira vez, super cuidadoso!"    ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Hoje • 14:00                         ║
║  ~2h de trabalho                      ║
║  R$ 150,00 (seu: R$ 135,00)          ║
║     ↓ (10% plataforma)                ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Instruções do Cliente                ║
║  ┌─────────────────────────────────┐  ║
║  │ "Há uma gato solto. Vc cuidado."│  ║
║  │                                 │  ║
║  │ Tenho que sair às 17h."         │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  MORADA (aparece APÓS ACEITAR)        ║
║  (neste momento, PIN no mapa só)      ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ [mapa = PIN, sem rua/número]    │  ║
║  │                                 │  ║
║  │ (GPS será ativado quando vc     │  ║
║  │  clicar em "Estou a caminho")   │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  POLÍTICA                             ║
║  • Não compartilhe este endereço      ║
║  • Não peça contato direto ao cliente ║
║  • Qualquer desvio = bloqueio         ║
> ⚠ ERRATA ADR-004: substituir por "Qualquer desvio será investigado e pode resultar em suspensão da parceria".
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ ACEITAR CHAMADO               │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✗ Recusar                       │  ║
║  └─────────────────────────────────┘  ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Carregando: "Buscando detalhes..."
  - Aceitado: Tela 3 (Estou a caminho)
  - Recusado: volta para Lista, 
    OS pode ir para outro prestador

→ DADOS VISÍVEIS:
  ✓ Bairro
  ✓ Tipo de limpeza
  ✓ Valor (com split explícito)
  ✓ Tempo estimado
  ✓ Instruções do cliente (texto livre)
  ✓ PIN no mapa (sem endereço real)
  
→ DADOS OCULTOS:
  ✗ Telefone do cliente
  ✗ Nome completo do cliente
  ✗ Endereço (rua, número, complemento)

→ ANTI-DESVIO:
  - Aviso bem visível: "Não peça contato direto"
  - PIN não copiável (tenta: "Endereço protegido")
  - Rating do cliente (sinaliza se é cliente 
    problemático)
```

---

### Tela 3: Estou a Caminho (GPS Ativo)

```
╔═══════════════════════════════════════╗
║  Você Aceitou!                        ║
║  Estou a Caminho                      ║
╠═══════════════════════════════════════╣
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │                                 │  ║
║  │         [MAPA COM GPS]          │  ║
║  │                                 │  ║
║  │    (seu ponto azul aqui)         │  ║
║  │    (casa = PIN de destino)       │  ║
║  │                                 │  ║
║  │    Faltam 12 min de carro       │  ║
║  │                                 │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  ☐ Estou a Caminho                   ║
║    (cliente já recebeu notificação)    ║
║    (GPS enviando a cada 10s)           ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Cheguei (próx. tela)          │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ Reportar Problema               │  ║
║  │    (chat com atendente)         │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Timer: 14:00 → 14:30 (previsto)      ║
║  Ganho até agora: R$ 135,00           ║
║                                       ║
║  [Background: GPS ativo, envia        ║
║   posição a cada ~10-30s]             ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - GPS conectado: mapa atualiza em tempo real
  - GPS fraco (4G offline): 
    "Reconectando... Sua posição foi salva."
    (mapa fica estático, volta a atualizar quando 
     conecta novamente)
  - Chegou perto do PIN (< 100m): 
    notificação ao cliente + app do cliente 
    muda para "Cheguei"

→ DADOS ENVIADOS (GPS):
  - Lat/Long a cada ~10s (depende de 4G)
  - Timestamp
  - Hashed para anonimato (não salva endereço)
  - Apagado após 48h

→ ANTI-DESVIO:
  - Checkbox "Estou a Caminho" (confirma 
    que sai mesmo)
  - Cliente vê GPS em tempo real 
    (prestador não pode se fingir 
    ou desviar sem parecer suspeito)
  - Se desliga GPS durante OS, 
    flag no backend ("desligou rastreamento 
    no meio do serviço")
```

---

### Tela 4: Cheguei (Foto Antes)

```
╔═══════════════════════════════════════╗
║  Você Chegou!                         ║
╠═══════════════════════════════════════╣
║                                       ║
║  Tire uma foto do estado ANTES        ║
║  (frente da casa/porta do apto)        ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │                                 │  ║
║  │      [Câmera/Galeria]           │  ║
║  │                                 │  ║
║  │   (foto pequena preview)         │  ║
║  │   ou [Tirar Foto Agora]          │  ║
║  │                                 │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  Tempo de trabalho começou:           ║
║     14:30 (cronômetro em verde)       ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Começar Limpeza               │  ║
║  │   (desabilita até foto OK)      │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ Reportar Problema               │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  [App continua com GPS ativo]          ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Sem foto: botão "Começar" desabilitado
  - Foto capturada: checkmark ✓, botão ativa
  - Erro câmera: "Permita acesso à câmera"
  - Foto muito escura: aviso "Que tal uma 
    foto melhor iluminada?" (sugestão, 
    não bloqueio)

→ DADOS:
  - Foto (comprimida, ~500KB)
  - Timestamp
  - Coordenadas GPS
  - Salvo em encrypted storage (cliente + 
    admin veem, não compartilhado)

→ ANTI-DESVIO:
  - Foto prova de chegada
  - Timestamp + GPS = sem fake
  - Foto deve mostrar "frente da casa" 
    (não rosto do cliente, não interior)
```

---

### Tela 5: Concluindo / Depois (Foto Depois + Fim)

```
╔═══════════════════════════════════════╗
║  Limpeza Concluída? ✓                 ║
╠═══════════════════════════════════════╣
║                                       ║
║  Tire uma foto do DEPOIS               ║
║  (mesma frente/porta, limpo)           ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │      [Câmera/Galeria]           │  ║
║  │      [Tirar Foto Agora]          │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Tempo de Trabalho: 2h 15min          ║
║  (cronômetro em verde)                 ║
║                                       ║
║  Ganho: R$ 135,00                     ║
║     (cliente pagou, você recebe hoje)  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Finalizar & Confirmar Repasse │  ║
║  │   (desabilita até foto OK)      │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  [Cliente recebe notificação de        ║
║   conclusão + avaliação]               ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Sem foto depois: botão desabilitado
  - Foto capturada: ativa "Finalizar"
  - Finalizando: spinner + "Enviando fotos..."
  - Sucesso: Tela 6 (Repasse Confirmado)
  - Erro upload: "Erro ao enviar. 
                  Tentaremos novamente em 30s."

→ ANTI-DESVIO:
  - Foto dupla (antes/depois) = prova 
    de realização
  - Duração = cliente sabe quanto tempo 
    levou (verificável)
  - Sem edição de duração (imutável uma 
    vez finalizado)
```

---

### Tela 6: Repasse Confirmado (Final)

```
╔═══════════════════════════════════════╗
║  Parabéns!                            ║
║  Serviço Finalizado                   ║
╠═══════════════════════════════════════╣
║                                       ║
║  Seus ganhos foram creditados          ║
║                                       ║
║  R$ 135,00                            ║
║     Chegará em sua conta PIX           ║
║     em alguns minutos                  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Resumo                               ║
║  ┌─────────────────────────────────┐  ║
║  │ Apartamento • Pinheiros         │  ║
║  │ 25/06/2026 • 14:30–16:45        │  ║
║  │ Duração: 2h 15min               │  ║
║  │ Valor: R$ 150,00                │  ║
║  │ Taxa CLEANOX: -R$ 15,00 (10%)   │  ║
║  │ Seu ganho: R$ 135,00            │  ║
║  │                                 │  ║
║  │ Status: ✓ Pendente Repasse      │  ║
║  │ (vira verde quando chegar PIX)   │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Cliente: Ficou Adorando!             ║
║     "Apartamento impecável!"         ║
║     Avaliação 5 estrelas             ║
║                                       ║
║  ─────────────────────────────────    ║
║                                       ║
║  Você já ganhou:                      ║
║     R$ 565,00 este mês (8 serviços)  ║
║     Próximo objetivo: R$ 1.000        ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ ✓ Voltar para Meus Chamados     │  ║
║  └─────────────────────────────────┘  ║
║                                       ║
║  ┌─────────────────────────────────┐  ║
║  │ Precisa de Ajuda?               │  ║
║  │    (chat com atendente)         │  ║
║  └─────────────────────────────────┘  ║
╚═══════════════════════════════════════╝

→ ESTADOS:
  - Pendente Repasse: cinza (banco processando)
  - Repasse Confirmado: verde ✓ + som/notificação
  - Erro repasse: vermelho (aviso + contato com 
    atendente)

→ ANTI-DESVIO:
  - Avaliação do cliente visível 
    (prestador vê feedback)
  - Nenhuma tentativa de contato direto 
    aqui (sempre via CLEANOX)
```

---

### Edge Cases & Fallbacks (App Prestador)

| Cenário | Fallback |
|---------|----------|
| **Offline ao aceitar OS** | "Sem conexão. Dados salvos. Sincroniza quando conectar." |
| **GPS desliga no meio do serviço** | Flag no backend (lista de "desvios suspeitos" para admin). Notificação: "Ative GPS novamente" |
| **4G cai ao enviar fotos** | Tenta reenviar a cada 30s. "Enviando fotos..." (spinner contínuo) |
| **Foto muito escura/borrada** | Soft warning: "Quer tirar outra?" (não bloqueio) |
| **Cliente marca flags anti-desvio** | Atendente revisa, se confirmado → investigação e decisão humana do admin |
| **Prestador tenta compartilhar endereço** | PIN não copiável. GPS + foto = evidência de tentativa |

---

---

# 3 PAINEL ATENDENTE+ADMIN (Web)

## Fluxo Crítico
**Fila de Leads → Criar/Editar OS → Atribuir Prestador → Kanban Status → Dashboard → Bloqueios**

### Tela 1: Dashboard Geral (Entry Point)

```
╔════════════════════════════════════════════════════════════════╗
║ CLEANOX Painel Admin                          Bem-vindo, João! ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║ [Fila] [OS] [Kanban] [Financeiro] [Fraude] [Bloqueios]        ║
║                                                                 ║
║ ─────────────────────────────────────────────────────────────  ║
║                                                                 ║
║ KPIs do Dia (25/06/2026)                                       ║
║ ┌──────────┬──────────┬──────────┬──────────┬──────────┐       ║
║ │ OS Criadas   OS Confirmadas  Concluídas Receita  Repasse    ║
║ │     12           8              6      R$900   R$ 810      ║
║ │ (target: 20)  (80% conv)    (75%)   (10% taxa) (90% split)  ║
║ └──────────┴──────────┴──────────┴──────────┴──────────┘       ║
║                                                                 ║
║ Fila de Leads (últimas 24h)                                    ║
║                                                                 ║
║  ┌─────────────────────────────────────────────────────────┐  ║
║  │ ID  Nome         Telefone        Serviço    Criado  Ação  │  ║
║  ├─────────────────────────────────────────────────────────┤  ║
║  │ 124 Maria Santos 11-98765-4321   Apartam.   9:20   Edit  │  ║
║  │ 123 José Costa   11-91234-5678   Casa       9:10   Edit  │  ║
║  │ 122 Ana Silva    11-99999-0000   Escritório 8:55   Edit  │  ║
║  └─────────────────────────────────────────────────────────┘  ║
║                                                                 ║
║ Alertas de Fraude (últimas 48h)                               ║
║                                                                 ║
║  ┌─────────────────────────────────────────────────────────┐  ║
║  │ ID  Tipo         Cliente/Prestador    Flag      Status   │  ║
║  ├─────────────────────────────────────────────────────────┤  ║
║  │ 8   Anti-desvio  Carlos (cliente)     Pediu    Pendente  │  ║
║  │     Prestador   contato    2 flags    investigação 24h  │  ║
║  │                                                          │  ║
║  │ 7   Anti-desvio  João (prestador)     Deslig.  Suspenso │  ║
║  │     Desligou GPS no meio da OS        GPS (revisão adm) │  ║
║  │                                                          │  ║
║  └─────────────────────────────────────────────────────────┘  ║
║                                                                 ║
║ Top Prestadores (este mês)                                     ║
║                                                                 ║
║  João Silva: 16 OS • ★★★★★ • 0 flags                          ║
║  Maria Oliveira: 12 OS • ★★★★☆ • 0 flags                      ║
║  Pedro Costa: 8 OS • ★★★★☆ • 1 flag (em análise)             ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝

→ DADOS CRÍTICOS:
  - Conversão (leads → OS confirmadas)
  - Taxa de conclusão
  - Receita bruta vs. repasse aos prestadores
  - Flags anti-desvio em tempo real

→ ACESSO:
  - Admin vê tudo
  - Atendente vê: Fila, OS, Kanban (sem 
    financeiro, bloqueios, alertas de fraude 
    detalhados)
```

---

### Tela 2: Fila de Leads (Prioridade)

```
╔════════════════════════════════════════════════════════════════╗
║ Fila de Leads (24h últimas)          Total: 15    Criar Nova   ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║ Filtros: [Todos] [Não Atribuída] [Aguardando Confirmação]     ║
║          [Aguardando Pagamento] [Confirmada]                  ║
║                                                                 ║
║ ┌─────────┬──────────┬────────────┬──────────┬──────────────┐  ║
║ │ ID      │ Nome     │ Telefone   │ Serviço  │ Criado  Ação │  ║
║ ├─────────┼──────────┼────────────┼──────────┼──────────────┤  ║
║ │                                                             │  ║
║ │ [R] 125  Maria     11-98765    Apartam.  11:05   [Criar OS] │  ║
║ │         Santos   -4321                          [Ligar]    │  ║
║ │         ⭐⭐⭐⭐⭐                          [Ver Detalhes]  │  ║
║ │                                                             │  ║
║ │ [R] 124  João Costa 11-91234   Casa      10:30   [Criar OS] │  ║
║ │         -5678                          [Ligar]            │  ║
║ │         ⭐⭐⭐⭐☆                          [Ver Detalhes]  │  ║
║ │                                                             │  ║
║ │ [Y] 123  Ana Silva  11-99999   Escritório 9:50   [Criar OS] │  ║
║ │         -0000      (segunda   [Ligar]            │  ║
║ │         ⭐⭐⭐☆☆     vez)       [Ver Detalhes]  │  ║
║ │                                                             │  ║
║ │ [G] 122  Carlos    11-98888   Apartam.  8:20    [Já Criada]│  ║
║ │         Mendes    -1111      (ID: 122)         [Editar]   │  ║
║ │         ⭐⭐⭐⭐⭐                          [Atribuir]    │  ║
║ │         Status: Criada, aguardando atribuição            │  ║
║ │                                                             │  ║
║ └─────────┴──────────┴────────────┴──────────┴──────────────┘  ║
║                                                                 ║
║ [R] = Sem OS criada (lead puro)                               ║
║ [Y] = OS criada, aguardando pagamento                         ║
║ [G] = OS criada e paga, aguardando atribuição                 ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
```

---

### Tela 3: Criar/Editar OS (Formulário)

```
╔════════════════════════════════════════════════════════════════╗
║ Criar Nova OS                                         X        ║
║ (ou editar #122)                                              ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║ Cliente (obrigatório)                                           ║
║ ┌─────────────────────────────────────────────────────────┐   ║
║ │ Maria Santos (seleção de lead, ou novo contato)         │   ║
║ └─────────────────────────────────────────────────────────┘   ║
║                                                                 ║
║ Localização (PIN no mapa ou manual)                            ║
║ ┌─────────────────────────────────────────────────────────┐   ║
║ │ Rua: Rua das Flores                                     │   ║
║ │ Número: 123                                             │   ║
║ │ Complemento: Apto 501                                   │   ║
║ │ Bairro: Pinheiros, SP                                   │   ║
║ │ CEP: 05000-000                                          │   ║
║ └─────────────────────────────────────────────────────────┘   ║
║                                                                 ║
║ Data & Hora (obrigatório)                                      ║
║ ┌──────────────┬──────────┐                                     ║
║ │ 25/06/2026   │ 14:00    │ ▼                                   ║
║ └──────────────┴──────────┘                                     ║
║                                                                 ║
║ Tipo de Limpeza (obrigatório)                                  ║
║ ○ Apartamento (2h mín)                                         ║
║ ○ Casa (3h mín)                                                ║
║ ○ Escritório (4h mín)                                          ║
║                                                                 ║
║ Valor (R$)                                                     ║
║ ┌─────────────────────────────────────────────────────────┐   ║
║ │ 150,00                                                  │   ║
║ └─────────────────────────────────────────────────────────┘   ║
║                                                                 ║
║  Resumo Financeiro                                             ║
║  Valor Serviço: R$ 150,00                                     ║
║  Taxa CLEANOX (10%): R$ 15,00                                 ║
║  Repasse ao Prestador: R$ 135,00                              ║
║                                                                 ║
║ ┌──────────────────┬──────────────────┐                        ║
║ │ ✓ Salvar OS      │ ✗ Cancelar       │                        ║
║ └──────────────────┴──────────────────┘                        ║
╚════════════════════════════════════════════════════════════════╝
```

---

### Tela 4: Atribuição Manual de Prestador

```
╔════════════════════════════════════════════════════════════════╗
║ Atribuir OS #122 a Prestador          ← (volta para lista)    ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║ OS Resumo                                                      ║
║ ┌─────────────────────────────────────────────────────────┐   ║
║ │ Apartamento • Pinheiros • 25/06 14:00                   │   ║
║ │ R$ 150,00 (Prestador: R$ 135)                           │   ║
║ │ Cliente: Maria Santos ⭐⭐⭐⭐⭐ (8 serviços)             │   ║
║ └─────────────────────────────────────────────────────────┘   ║
║                                                                 ║
║ Prestadores Disponíveis para 25/06 14:00                      ║
║                                                                 ║
║ ┌──────────┬──────────┬──────────┬──────────┬──────────────┐   ║
║ │ Nome     │ Rating   │ Distância│ Próxima  │ # Flags Ação │   ║
║ ├──────────┼──────────┼──────────┼──────────┼──────────────┤   ║
║ │ João     │ ⭐⭐⭐⭐⭐ │ 3 km     │ 16:30    │ 0     [✓]    │   ║
║ │ Silva    │ (16 OS)  │          │          │      [info]  │   ║
║ │ Maria    │ ⭐⭐⭐⭐☆ │ 8 km     │ 15:00    │ 0     [✓]    │   ║
║ │ Oliveira │ (12 OS)  │          │          │      [info]  │   ║
║ │ Pedro    │ ⭐⭐⭐⭐☆ │ 12 km    │ 15:30    │ 1     [✓]    │   ║
║ │ Costa    │ (8 OS)   │          │          │   (analisado)│   ║
║ │ Carlos   │ ⭐⭐⭐☆☆ │ 2 km     │ 17:00    │ 2    [⊘]    │   ║
║ │ Mendes   │ (5 OS)   │          │          │  (suspenso)  │   ║
║ └──────────┴──────────┴──────────┴──────────┴──────────────┘   ║
║                                                                 ║
║ Sugestão: João Silva (melhor rating, mais próximo, zero flags) ║
║                                                                 ║
║ ┌──────────────────┬──────────────────┐                        ║
║ │ ✓ Atribuir a:    │ ✗ Cancelar       │                        ║
║ │ [João Silva] ▼   │                  │                        ║
║ └──────────────────┴──────────────────┘                        ║
╚════════════════════════════════════════════════════════════════╝
```

---

### Tela 5: Kanban Status (Acompanhamento em Tempo Real)

```
╔════════════════════════════════════════════════════════════════╗
║ Kanban do Dia (25/06/2026)               Atualizar a cada 10s ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  FILA         A CONFIRMAR       CONFIRMADO      A CAMINHO       ║
║  (leads)      (aguardando        (cliente        (prestador      ║
║               pagamento)         pagou Pix)      saiu)           ║
║                                                                 ║
║  ┌──────┐    ┌──────────┐     ┌──────────┐   ┌──────────┐     ║
║  │ #126 │    │ #125     │     │ #122     │   │ #120     │     ║
║  │      │    │ Maria    │     │ Carlos   │   │ Lucia    │     ║
║  │ #124 │    │ R$150    │     │ R$280    │   │ 12min ETA│     ║
║  │      │    │ pendente │     │ confirmado    │          │     ║
║  │ #123 │    │ #123     │     │ #119     │   │ #118     │     ║
║  │      │    │ Ana      │     │ Pedro    │   │ 5min ETA │     ║
║  └──────┘    └──────────┘     └──────────┘   └──────────┘     ║
║                                                                 ║
║  EM EXECUÇÃO          CONCLUÍDO             PROBLEMÁTICO       ║
║                                                                 ║
║  ┌──────────┐    ┌──────────┐         ┌──────────┐             ║
║  │ #117     │    │ #116     │         │ #115     │             ║
║  │ Fotos OK │    │ Rating ⭐⭐⭐⭐⭐ │         │ Cancelou │             ║
║  │ #114     │    │ #113     │         │ #114     │             ║
║  │ Fotos OK │    │ R$400 OK │         │ Atraso   │             ║
║  └──────────┘    └──────────┘         └──────────┘             ║
║                                                                 ║
║  Total do dia: 12 OS (6 concluídas, 2 em progresso,            ║
║                3 confirmadas, 1 cancelada)                      ║
║  Receita: R$ 900 | Repasse: R$ 810 | Taxa: R$ 90              ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝

→ COLUNAS (estados):
  1. FILA - Lead puro (sem OS criada)
  2. A CONFIRMAR - OS criada, aguardando cliente pagar PIX
  3. CONFIRMADO - PIX confirmado, prestador atribuído
  4. A CAMINHO - Prestador ativou GPS
  5. EM EXECUÇÃO - "Cheguei" + foto antes
  6. CONCLUÍDO - "Concluído" + foto depois
  7. PROBLEMÁTICO - Cancelado, atraso, flags anti-desvio
```

---

### Tela 6: Dashboard Financeiro & Detecção

```
╔════════════════════════════════════════════════════════════════╗
║ Financeiro & Fraude                        [Este Mês] [Hoje]   ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║ Fluxo de Caixa                                                 ║
║                                                                 ║
║  ┌──────────┬─────────┬──────────┬─────────┐                   ║
║  │ Receita  │ Repasses│ Taxa     │ Saldo   │                   ║
║  │ Bruta    │ Pendentes          │ Final   │                   ║
║  ├──────────┼─────────┼──────────┼─────────┤                   ║
║  │ R$900    │ R$810   │ R$90     │ +R$90   │                   ║
║  │ (12 OS)  │ (em 24h)│ (10%)    │ (caixa) │                   ║
║  └──────────┴─────────┴──────────┴─────────┘                   ║
║                                                                 ║
║ Padrões Suspeitos de Desintermediação                         ║
║                                                                 ║
║  ┌─────┬──────────┬─────────────┬──────────┬──────────┐        ║
║  │ ID  │ Cliente  │ Prestador   │ Status   │ Ação     │        ║
║  ├─────┼──────────┼─────────────┼──────────┼──────────┤        ║
║  │ 9   │ Lucia    │ João Silva  │ Possível │ [Revisar]│        ║
║  │     │ (1 OS)   │ (16 OS)     │ desvio   │          │        ║
║  │ 8   │ Tiago    │ João Silva  │ Possível │ [Revisar]│        ║
║  │ 7   │ Mariana  │ Pedro Costa │ Possível │ [Revisar]│        ║
║  │     │          │             │ (2 flags)│          │        ║
║  └─────┴──────────┴─────────────┴──────────┴──────────┘        ║
║                                                                 ║
║ Critérios de Alerta:                                           ║
║  • Cliente com 1 OS com prestador X, depois sumiu             ║
║  • Nenhuma OS nova com CLEANOX nos últimos 30 dias            ║
║  • (Inferência: migrou para contato direto)                   ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
```

---

### Tela 7: Gestão de Prestadores

> **NOTA ADR-004:** Bloqueio é SEMPRE manual. O sistema gera alertas; o admin decide e executa a suspensão. Nenhum bloqueio automático por contagem de flags ou GPS desligado.

```
╔════════════════════════════════════════════════════════════════╗
║ Gestão de Prestadores                                          ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║ Filtros: [Todos] [Ativos] [Suspensos] [Com Alertas]           ║
║                                                                 ║
║ ┌──────────┬─────────┬──────────┬──────────┬─────────────────┐ ║
║ │ Nome     │ Status  │ # OS     │ Rating   │ Flags / Ação    │ ║
║ ├──────────┼─────────┼──────────┼──────────┼─────────────────┤ ║
║ │ João     │ ✓ Ativo │ 16 OS    │ ⭐⭐⭐⭐⭐ │ 0 flags         │ ║
║ │ Silva    │         │ (mês)    │ (4.9)    │ [Info] [Editar] │ ║
║ │ Maria    │ ✓ Ativo │ 12 OS    │ ⭐⭐⭐⭐☆ │ 0 flags         │ ║
║ │ Oliveira │         │ (mês)    │ (4.6)    │ [Info] [Editar] │ ║
║ │ Pedro    │ ⚠ Alerta│ 8 OS     │ ⭐⭐⭐⭐☆ │ 1 flag (análise)│ ║
║ │ Costa    │         │ (mês)    │ (4.5)    │ [Info] [Revisar]│ ║
║ │ Carlos   │ Suspenso│ 5 OS     │ ⭐⭐⭐☆☆ │ 2 flags         │ ║
║ │ Mendes   │ (30d)   │ (mês)    │ (3.8)    │ [Info] [Reativar]│ ║
║ └──────────┴─────────┴──────────┴──────────┴─────────────────┘ ║
║                                                                 ║
║ Criação de Novo Prestador                                      ║
║                                                                 ║
║ ┌──────────────────────────────────────────────────────────┐   ║
║ │ Telefone: [11-98765-4321]                                │   ║
║ │ Nome: [João Silva]                                       │   ║
║ │ CPF: [12345678901]                                       │   ║
║ │ Chave PIX: [CPF] ▼  [12345678901]                       │   ║
║ │ Áreas de Cobertura: [Pinheiros] [Vila Mariana]           │   ║
║ │ ┌────────────────────────────────────────────────────┐  │   ║
║ │ │ ✓ Criar                                            │  │   ║
║ │ └────────────────────────────────────────────────────┘  │   ║
║ └──────────────────────────────────────────────────────────┘   ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝

→ AÇÕES:
  - [Info]: histórico completo (OS, ratings, flags, GPS log)
  - [Revisar]: abre alerta vinculado para revisão humana
  - [Aplicar Suspensão]: manual, requer motivo (min 20 chars)
  - [Reativar]: reverte suspensão com registro no audit_log
```

---

### Edge Cases & Fallbacks (Painel Admin)

| Cenário | Fallback |
|---------|----------|
| **PIX não confirmou em 24h** | Auto-SMS ao cliente: "Seu Pix não foi confirmado. [Link para reenviar]" |
| **Prestador desligou GPS** | Flag gerado: "Desligou rastreamento no meio da OS". Admin revisar antes de agir. |
| **Cliente marca 2+ flags anti-desvio** | Alerta imediato no painel. Admin revisa fotos, GPS, trilha de auditoria antes de qualquer ação. |
| **Prestador não entrou em contato (24h)** | OS volta para fila. SMS ao cliente: "Entraremos em contato para reagendar." |
| **Crash de GPS (4G 0%)** | App volta a tentar a cada 30s. Atendente vê "reconectando" no kanban. Após 2h → flag para revisão. |
| **Múltiplas OS do mesmo cliente no mesmo horário** | Sistema impede. Modal: "Cliente já tem OS em 14:00." |

---

---

# Tabela Consolidada: Anti-Desvio (Reforço de Marca)

| Superfície | Mecânica de Anti-Desvio | Implementação |
|------------|------------------------|---------------|
| **PWA Cliente** | Endereço efêmero (PIN, não copiável) | Mapa com marcador sem rua/número até acompanhamento |
| | Telefone do prestador nunca exposto | Chat sempre via CLEANOX |
| | Flags pós-serviço explícitas | 3 checkboxes (pediu contato/pagamento/off-platform) |
| **App Prestador** | GPS contínuo enquanto a caminho | Enviado a cada 10s, cliente vê tempo real |
| | Fotos antes/depois com timestamp+GPS | Evidência de realização, não fabricável |
| | Endereço oculto até aceitar OS | PIN no mapa, sem rua/número |
| | Desligamento de GPS gera alerta | Contador de incidências, revisão manual |
| **Painel Admin** | Kanban com status em tempo real | Detecta desligamento, atraso, padrão suspeito |
| | Detecção de "fuga" (cliente desaparece) | Análise de clientes 1 OS + inativo 30d |
| | Suspensão SEMPRE manual | Admin revisa evidências antes de agir (ADR-004) |

---

---

# Resumo de Caminhos Críticos & Edge Cases

## PWA CLIENTE
**Happy Path:** Link → Agendar (PIN) → Pagar (Pix) → Acompanhar (mapa) → Avaliar + Flags → Recibo

**Edge Cases (prioritários):**
1. PIX não confirmou em 5 min → SMS + retry link
2. GPS perdido durante acompanhamento → mapa estático, continua mostrando ETA, reconecta quando chegar
3. Cliente tenta compartilhar endereço → bloqueado, aviso "protegido até fim do serviço"

---

## APP PRESTADOR
**Happy Path:** OTP → Lista (bairro) → Detalhe → Aceitar → "Estou a caminho" (GPS) → "Cheguei" (foto antes) → "Concluído" (foto depois) → Repasse

**Onboarding:** 4 telas (bem-vindo, OTP, PIX, permissão GPS)

**Edge Cases (prioritários):**
1. Offline ao aceitar → dados salvos, sincroniza ao reconectar
2. GPS desliga no meio → flag gerado, notificação ao prestador ("reative"), contador de incidências
3. Foto muito escura → soft warning ("quer tirar outra?"), não bloqueio

---

## PAINEL ADMIN
**Happy Path:** Fila (lead) → Criar OS → Atribuir Prestador → Kanban (acompanhamento) → Conclusão + Dashboard → Detecção de Fraude

**Edge Cases (prioritários):**
1. PIX não confirmou em 24h → SMS automático + os-back-to-fila após timeout
2. Padrão suspeito (cliente desapareceu) → alerta no dashboard, revisor humano avalia antes de qualquer ação
3. Suspensão de prestador → sempre manual (ADR-004), com motivo obrigatório e registro no audit_log

---

# Micro-Interações Que Reduzem Atrito

- **Validação inline** (campo fica vermelho se inválido)
- **Campos com sugestões** (ex.: valor baseado em histórico)
- **Contadores & timers** (cronômetro do serviço, countdown de reenvio de SMS)
- **Feedback tátil** (vibração ao tirar foto, som ao mapa atualizar)
- **Cards com hover** (ficam destacados, chamam atenção)
- **Badges coloridas** (status visual instantâneo)
- **Pull-to-refresh** (prestador desliza para atualizar lista)
- **Auto-focus em campos** (code de OTP já pronto para digitar)

---

# Acessibilidade & Low-Tech Considerations

- **PWA Cliente:** responsive (mobile 1º), sem JavaScript pesado, carregamento rápido (2G+)
- **App Prestador:** Android básico (4.4+), 4G oscilante, telas com <5 elementos principais, linguagem coloquial (sem jargão técnico)
- **Painel Admin:** desktop (1280px+), teclado + mouse, sem arrastar se não necessário

---

Este é o **MVP Cleanox — Fluxos & Telas v1.0**. Pronto para discussão, validação com stakeholders e design final.
