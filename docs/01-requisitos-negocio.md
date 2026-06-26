# Cleanox — Documento de Requisitos de Negócio e Processos
**Versão:** 0.1-draft  
**Data:** 2026-06-25  
**Autor:** Business Analyst (Claude Code)  
**Status:** Aguardando validação do dono

---

## 0. Sumário Executivo

O projeto Cleanox nasce de uma vulnerabilidade estrutural: a operação de limpeza residencial sob demanda delega ao prestador (faxineiro) o contato direto com o cliente e o recebimento do pagamento. Isso transforma o prestador no elo mais poderoso da cadeia — quem controla o cliente e o dinheiro controla o negócio. O objetivo do sistema é inverter esse vetor: a **marca Cleanox** passa a ser o único ponto de contato do cliente, o único receptor do pagamento e o único detentor da relação de confiança. O prestador vira um **executor anonimizado**, dependente da plataforma para trabalhar e receber.

---

## 1. Problema e Objetivos de Negócio

### 1.1 Problema Raiz

| Dimensão | Situação atual (risco) |
|---|---|
| Relacionamento | Prestador conhece nome, telefone e endereço completo do cliente |
| Comunicação | Prestador avisa a chegada direto pelo próprio WhatsApp pessoal |
| Pagamento | Dinheiro passa pela mão do prestador antes de chegar à empresa |
| Conhecimento operacional | Prestador aprende CAC, roteiro de vendas e base de clientes |
| Saída | Prestador pode se desligar, abrir concorrência e abordar clientes com preço menor |

**Incidente de referência:** prestador anterior aprendeu a operação completa, se desligou e abriu empresa concorrente levando clientes — confirmando o risco de desintermediação reversa.

### 1.2 Objetivos de Negócio (mensuráveis)

| # | Objetivo | KPI | Meta (12 meses pós-lançamento) |
|---|---|---|---|
| OB-01 | Reter clientes na marca após troca de prestador | % de clientes que recontratam pela plataforma após troca | ≥ 90% |
| OB-02 | Eliminar pagamento direto prestador↔cliente | % de pagamentos processados via plataforma | 100% (zero tolerância) |
| OB-03 | Bloquear contato direto fora da plataforma | % de atendimentos sem troca de contato pessoal detectada | ≥ 95% |
| OB-04 | Proteger base de clientes em caso de desligamento | Nenhum cliente abordado diretamente por ex-prestador nos 6 meses seguintes | 0 casos confirmados |
| OB-05 | Aumentar taxa de recompra | % de clientes que agendam 2ª limpeza em até 60 dias | ≥ 40% |
| OB-06 | Reduzir inadimplência | % de OS pagas antes da execução ou no ato via plataforma | ≥ 85% |
| OB-07 | Manter NPS da marca | NPS (pesquisa pós-serviço) | ≥ 70 |

---

## 2. Mapa de Processos

### 2.1 Fluxo AS-IS (atual — com vulnerabilidades marcadas)

```
[Tráfego Pago]
      ↓
[Lead entra por WhatsApp/formulário]
      ↓
[ATENDENTE] — conversa manual no WhatsApp pessoal ou business
      ↓
[Agenda visita: data, hora, endereço passado por mensagem]
      ↓
[ATENDENTE atribui ao PRESTADOR] ← ⚠️ passa nome, tel e endereço completo
      ↓
[PRESTADOR avisa cliente diretamente: "estou a caminho"] ← ⚠️ contato pessoal
      ↓
[PRESTADOR executa o serviço]
      ↓
[PRESTADOR recebe pagamento em dinheiro/Pix pessoal] ← ⚠️ dinheiro fora do controle
      ↓
[PRESTADOR repassa (ou não) parte à empresa] ← ⚠️ sem rastreabilidade
      ↓
[Sem pós-venda estruturado — relação fica com o prestador] ← ⚠️ perda de retenção
```

**Pontos críticos de vulnerabilidade:**
- P1: Atribuição expõe dados pessoais do cliente ao prestador
- P2: Prestador tem canal de comunicação direta com o cliente
- P3: Dinheiro passa pela mão do prestador
- P4: Pós-venda inexistente — cliente associa qualidade ao prestador, não à marca

### 2.2 Fluxo TO-BE (desintermediado)

```
[Tráfego Pago]
      ↓
[Lead capturado na PLATAFORMA — CRM interno]
      ↓
[ATENDENTE acessa plataforma: vê lead, inicia chat mascarado ou WhatsApp via API oficial]
      ↓
[Plataforma envia orçamento + link de pagamento/agendamento ao CLIENTE]
      ↓
[CLIENTE confirma, escolhe data/hora, paga (ou pré-autoriza) na PLATAFORMA]
      ↓
[PLATAFORMA atribui Ordem de Serviço ao PRESTADOR]
   — Prestador vê: bairro/CEP, janela de horário, tipo de serviço, m² aprox.
   — Prestador NÃO vê: nome completo, telefone, endereço exato (até D-1 ou dia do serviço)
      ↓
[D-1: PLATAFORMA notifica CLIENTE automaticamente (WhatsApp API / SMS / push)]
   "Seu prestador chegará amanhã entre 9h-11h. Acompanhe pelo app."
      ↓
[Dia do serviço: PRESTADOR recebe endereço completo via app (apenas para navegação)]
[PRESTADOR clica "Estou a caminho" → CLIENTE recebe push/WhatsApp da PLATAFORMA]
      ↓
[PRESTADOR executa. Ao finalizar: clica "Serviço concluído" + upload de fotos opcionais]
      ↓
[PLATAFORMA libera cobrança (se pré-autorizada) ou envia link de pagamento ao CLIENTE]
[CLIENTE paga diretamente na PLATAFORMA (Pix, cartão)]
      ↓
[Split automático: plataforma retém margem da marca → transfere parte ao PRESTADOR
 em ciclo semanal/quinzenal via Pix/TED]
      ↓
[PLATAFORMA envia pesquisa de satisfação (NPS) ao CLIENTE]
[PLATAFORMA aciona régua de recompra: ofertas, lembretes, assinatura recorrente]
```

**Pontos onde o prestador é isolado:**
- I1: Nunca recebe telefone do cliente — comunicação só pelo app
- I2: Endereço revelado de forma escalonada (bairro → logradouro completo no dia)
- I3: Nunca toca no dinheiro — recebe por transferência da plataforma
- I4: Pós-venda é da marca, não do prestador — cliente é segurado pela plataforma

---

## 3. Atores, Papéis e Matriz de Permissões

### 3.1 Definição dos Atores

| Ator | Descrição |
|---|---|
| **Admin/Dono** | Proprietário da empresa. Visão total do negócio, financeiro, configurações |
| **Atendente** | Responsável por converter leads em agendamentos. Sem acesso ao financeiro do prestador |
| **Prestador** | Executor do serviço. Visibilidade estritamente limitada à OS atribuída |
| **Cliente** | Contratante do serviço. Interage via app/WhatsApp com a marca, nunca diretamente com o prestador |

### 3.2 Matriz de Permissões

#### ADMIN/DONO
| Pode | Não pode (por design) |
|---|---|
| Ver todos os dados de clientes | — |
| Ver histórico financeiro completo (recebimentos, splits, repasses) | — |
| Criar/editar/desativar prestadores | — |
| Ver logs de auditoria (quem acessou dados de qual cliente) | — |
| Configurar split de pagamento por prestador | — |
| Bloquear prestador imediatamente | — |
| Exportar base de clientes | — |
| Ver conversas atendente↔cliente | — |

#### ATENDENTE
| Pode | Não pode |
|---|---|
| Ver leads e criar agendamentos | Ver dados bancários/split do prestador |
| Acessar nome, telefone, endereço do cliente para agendamento | Atribuir OS manualmente sem aprovação do dono (configurável) |
| Enviar mensagens via canal mascarado da plataforma | Exportar lista de clientes |
| Ver histórico de OS do cliente | Criar descontos acima do limite configurado |
| Cancelar/reagendar OS | — |

> **Risco latente:** O atendente também tem acesso a dados de clientes e pode replicar o risco do prestador. Ver seção 6 e perguntas abertas (Q-09).

#### PRESTADOR
| Pode | Não pode |
|---|---|
| Ver lista de OS atribuídas a si | Ver telefone/WhatsApp do cliente |
| Ver bairro/CEP da OS (para planejamento de rota) | Ver nome completo do cliente (sugestão: "Apartamento 3B — Bairro X") |
| Ver tipo e escopo do serviço (m², cômodos) | Ver histórico de OS de outros prestadores |
| Ver endereço completo no dia do serviço (via app, não copiável) | Receber pagamento direto |
| Marcar etapas: A caminho / Em execução / Concluído | Contatar o cliente fora do canal da plataforma |
| Enviar fotos de conclusão | Ver quanto o cliente pagou (vê apenas seu repasse) |
| Acessar chat com o atendente/suporte da empresa | Cancelar OS unilateralmente |
| Ver histórico das próprias OS e seus ganhos | — |

> **Restrições técnicas complementares:** endereço exibido em campo não copiável (proteção UI); app sem função de compartilhar/exportar endereço; log de abertura de cada campo sensível.

#### CLIENTE
| Pode | Não pode |
|---|---|
| Agendar, reagendar, cancelar serviços | Ver dados pessoais do prestador (nome completo, CPF, telefone) |
| Pagar via plataforma (Pix, cartão) | Contratar o prestador diretamente fora da plataforma |
| Ver status em tempo real da OS | — |
| Avaliar o serviço (nota + comentário) | — |
| Acessar histórico de serviços | — |
| Assinar pacote recorrente | — |
| Abrir chamado de reclamação | — |

---

## 4. Requisitos Funcionais (MoSCoW)

### 4.1 MUST HAVE — Lançamento

#### Módulo Lead & CRM
- **RF-01** Capturar leads de múltiplas origens (formulário web, WhatsApp API, indicação manual) e consolidar em fila única
- **RF-02** Registrar histórico completo de interações com o lead (mensagens, ligações anotadas, tentativas)
- **RF-03** Converter lead em cliente com cadastro (nome, endereço completo, telefone — dados protegidos por LGPD)

#### Módulo Agendamento
- **RF-04** Criar Ordem de Serviço (OS) com: data/hora, endereço, tipo de serviço, número de cômodos/m², observações especiais
- **RF-05** Exibir grade de disponibilidade por prestador e por região
- **RF-06** Notificar cliente automaticamente: confirmação de agendamento, lembrete D-1 e D-0 (via WhatsApp Business API ou SMS — nunca pelo celular do prestador)

#### Módulo Atribuição de Prestador
- **RF-07** Atribuir OS a prestador específico — plataforma revela apenas: bairro/CEP, janela de horário, escopo do serviço
- **RF-08** Revelar endereço completo ao prestador apenas no dia do serviço (ou X horas antes — configurável pelo admin)
- **RF-09** Prestador confirma aceite da OS no app (ou OS é recusada e volta para fila)
- **RF-10** Notificar cliente quando prestador clicar "Estou a caminho" — notificação disparada pela plataforma, não pelo prestador

#### Módulo Execução
- **RF-11** Prestador registra etapas no app: A caminho / Chegou / Em execução / Concluído
- **RF-12** Registro de check-in com geolocalização (latitude/longitude) para auditoria
- **RF-13** Upload de fotos de conclusão (visíveis para admin e cliente, não para outros prestadores)

#### Módulo Pagamento
- **RF-14** Cliente paga na plataforma via Pix (QR code gerado pela plataforma) ou cartão de crédito/débito
- **RF-15** Pagamento pode ser pré-autorizado no agendamento ou cobrado após conclusão (configurável por dono)
- **RF-16** Split automático: plataforma retém margem da marca e agenda repasse ao prestador
- **RF-17** Repasse ao prestador via Pix em ciclo configurável (semanal, quinzenal) — nunca imediato na conclusão da OS
- **RF-18** Prestador vê no app apenas seu saldo a receber e histórico de repasses — não vê valor total pago pelo cliente
- **RF-19** Admin vê dashboard financeiro completo: receita bruta, split por prestador, margem por OS

#### Módulo Comunicação Mascarada
- **RF-20** Canal de chat interno entre cliente e atendente (via app ou WhatsApp Business API com número da empresa)
- **RF-21** Canal de comunicação prestador ↔ empresa (suporte/logística) — sem linha direta prestador↔cliente
- **RF-22** Todas as mensagens enviadas ao cliente identificadas com nome/logo da marca Cleanox, nunca com nome do prestador

### 4.2 SHOULD HAVE — 90 dias pós-lançamento

- **RF-23** Sistema de avaliação pós-serviço (1-5 estrelas + comentário) enviado ao cliente automaticamente — alimenta NPS interno
- **RF-24** Régua de recompra: disparar oferta ou lembrete de reagendamento 20/30/45 dias após o último serviço
- **RF-25** Painel de performance do prestador (taxa de conclusão, nota média, atrasos) — visível para admin, oculto para o próprio prestador (ou mostrar versão limitada — decisão do dono)
- **RF-26** Fluxo de reagendamento e cancelamento com política de multa configurável
- **RF-27** Histórico de auditoria: quem acessou dados de qual cliente, em que data/hora
- **RF-28** Bloqueio imediato de prestador: admin desativa conta, app para funcionar imediatamente, OS futuras redistribuídas

### 4.3 COULD HAVE — Roadmap futuro

- **RF-29** Assinatura recorrente (semanal, quinzenal, mensal) com desconto automático e cobrança recorrente
- **RF-30** App do cliente (iOS/Android) com acompanhamento em tempo real do prestador (geolocalização no mapa)
- **RF-31** Programa de indicação: cliente que indica ganha desconto na próxima OS
- **RF-32** Módulo de contratos digitais para prestadores (termos de uso, cláusula de não-concorrência assinada digitalmente)
- **RF-33** Multi-empresa: plataforma utilizada por outras empresas de limpeza (SaaS white-label)

### 4.4 WON'T HAVE (neste ciclo)

- Marketplace aberto (cliente escolhe prestador pelo app) — isso re-cria a relação cliente↔prestador
- Pagamento em dinheiro intermediado pela plataforma
- Expansão para outros segmentos de serviço (além de limpeza)

---

## 5. Requisitos Não-Funcionais

### 5.1 LGPD e Privacidade de Dados

| Requisito | Detalhe |
|---|---|
| **RNF-01** | Dados pessoais do cliente (nome, telefone, endereço) classificados como **dado sensível de negócio** — acesso controlado por perfil |
| **RNF-02** | Prestador nunca armazena dados do cliente localmente — app sempre busca do servidor, sem cache persistente |
| **RNF-03** | Política de retenção: dados de clientes inativos (sem OS em 24 meses) anonimizados ou excluídos conforme solicitação |
| **RNF-04** | Consentimento explícito do cliente para coleta de dados no primeiro contato (opt-in LGPD) |
| **RNF-05** | Prestador assina termo de confidencialidade digital antes de ativar a conta |
| **RNF-06** | Direito do titular: cliente pode solicitar exclusão dos dados — fluxo interno deve suportar isso |

### 5.2 Auditoria e Rastreabilidade

| Requisito | Detalhe |
|---|---|
| **RNF-07** | Log imutável de acesso: toda vez que um usuário (incluindo admin) abre dados de contato de um cliente, o sistema registra userId, clienteId, campo acessado, timestamp |
| **RNF-08** | Log de mudanças de status de OS (com userId e timestamp) |
| **RNF-09** | Log de pagamentos e splits — trilha financeira completa para auditoria fiscal |
| **RNF-10** | Alertas automáticos para o admin em eventos suspeitos (ex: prestador tentou acessar dados de cliente de outra OS) |

### 5.3 Disponibilidade e Desempenho

| Requisito | Detalhe |
|---|---|
| **RNF-11** | Disponibilidade mínima: 99,5% no horário comercial (7h-22h) |
| **RNF-12** | Notificações ao cliente entregues em até 30 segundos após gatilho |
| **RNF-13** | App do prestador funcional em conexões 4G com latência ≥ 200ms (campo) |

### 5.4 Segurança

| Requisito | Detalhe |
|---|---|
| **RNF-14** | Autenticação por SMS OTP ou WhatsApp OTP para prestadores (sem senha reutilizável) |
| **RNF-15** | Sessão do app do prestador expira após 8 horas de inatividade |
| **RNF-16** | Dados em trânsito: HTTPS/TLS 1.3. Dados em repouso: criptografia de banco de dados |
| **RNF-17** | Proibição de screenshot no app do prestador (sistema operacional-level flag) — evita foto da tela com dados do cliente |

---

## 6. Regras de Negócio Anti-Desintermediação

### 6.1 Controle de Informação

| Regra | Descrição |
|---|---|
| **RN-01** | Prestador só visualiza endereço completo dentro do app, em campo sem função de copiar/compartilhar |
| **RN-02** | Endereço é revelado em etapas: (a) bairro + CEP ao aceitar OS; (b) logradouro completo no dia do serviço, X horas antes (configurável: sugestão 2h) |
| **RN-03** | Telefone do cliente **nunca** é exibido ao prestador. Comunicação só via chat da plataforma |
| **RN-04** | Nome do cliente exibido ao prestador apenas como primeiro nome + inicial do sobrenome (ex: "Maria S.") — ou apelido de endereço ("Ap. 302 – Jardim Primavera") |

### 6.2 Controle Financeiro

| Regra | Descrição |
|---|---|
| **RN-05** | Prestador não recebe pagamento no ato do serviço. Cliente é orientado no agendamento: "pagamento 100% via plataforma" |
| **RN-06** | Se cliente oferecer pagamento em dinheiro ao prestador, o prestador deve recusar e reportar via app. Falha confirmada é causa de desligamento imediato |
| **RN-07** | Prestador não vê o valor total pago pelo cliente — apenas o valor do seu repasse |
| **RN-08** | Repasse ao prestador só é liberado após cliente confirmar conclusão (ou após período de contestação, ex: 48h sem contestação) |

### 6.3 Cláusulas Contratuais com Prestadores

| Regra | Descrição |
|---|---|
| **RN-09** | Termo de confidencialidade: prestador não pode contatar clientes da Cleanox fora da plataforma, por qualquer canal, durante o vínculo e por 12 meses após desligamento |
| **RN-10** | Cláusula de não-concorrência: prestador não pode prestar serviços de limpeza residencial diretamente para clientes que conheceu pela plataforma |
| **RN-11** | Penalidade contratual por violação das RN-09/RN-10: multa de X salários-mínimos (valor a definir com advogado trabalhista/cível, considerando vínculo CLT vs. PJ/MEI) |
| **RN-12** | Aceitação digital do termo é obrigatória antes do primeiro login — sem aceite, sem acesso |

### 6.4 Detecção de "Pulo do Combinado"

| Regra | Descrição |
|---|---|
| **RN-13** | Pesquisa pós-serviço inclui pergunta direta ao cliente: "O prestador solicitou seu contato pessoal ou ofereceu preços diretos?" |
| **RN-14** | Cliente que reportar abordagem direta recebe benefício (desconto na próxima OS) e a denúncia aciona workflow de investigação para o admin |
| **RN-15** | Monitoramento de padrão: prestador que tem taxa de recompra diretamente com clientes caindo (cliente some da plataforma após usar prestador X pela primeira vez) é sinalizado para revisão |
| **RN-16** | Admin pode bloquear prestador imediatamente (RNF-10) enquanto investigação ocorre |

---

## 7. Perguntas em Aberto (Gate de Decisão)

As respostas abaixo são necessárias **antes do início do desenvolvimento**.

| # | Pergunta | Impacto se não decidido |
|---|---|---|
| **Q-01** | Qual o percentual de split entre marca e prestador? É fixo (ex: 70/30) ou variável por tipo de serviço? | Bloqueia modelagem financeira e escolha do gateway de pagamento |
| **Q-02** | Gateway de pagamento: preferência entre Pagar.me, Mercado Pago, Stripe, Asaas ou outro? Empresa já tem conta em algum? | Bloqueia RF-14 a RF-18 |
| **Q-03** | Período de transição: existe base de clientes atual que paga em dinheiro? Como migrar esse fluxo sem perder clientes que resistem a pagar online? | Bloqueia política de lançamento e comunicação com clientes atuais |
| **Q-04** | Vínculo dos prestadores: são CLT, PJ ou MEI autônomos? A cláusula de não-concorrência tem implicações diferentes para cada regime — já consultou advogado? | Afeta RN-09 a RN-11 |
| **Q-05** | Quantos prestadores ativos hoje? Qual o volume mensal de OS? (Ajuda a dimensionar escala inicial do sistema) | Sem isso, arquitetura pode ser sub ou superdimensionada |
| **Q-06** | O atendente atual tem acesso a dados completos de clientes. Como mitigar o mesmo risco de desintermediação para esse perfil? (Sugestão: logs de acesso, rotação, restrição de exportação) | Sem decisão, o elo atendente fica descoberto |
| **Q-07** | Qual o fluxo de cancelamento? Cliente pode cancelar com X horas de antecedência sem multa? Qual a política de multa? Quem absorve? | Bloqueia RF-26 e modelagem financeira |
| **Q-08** | O cliente verá o nome/foto do prestador antes do serviço? (Aumenta confiança mas também personaliza o prestador — trade-off de segurança vs. conversão) | Afeta RF-10 e experiência do cliente |
| **Q-09** | WhatsApp Business API: a empresa já tem número dedicado homologado (WABA)? Ou pretende usar solução como Twilio, Gupshup, Take Blip? | Bloqueia RF-06, RF-10, RF-20, RF-24 |
| **Q-10** | Qual o canal primário do cliente: app próprio (iOS/Android), WhatsApp ou apenas web responsivo? (Impacto enorme no custo e prazo de desenvolvimento) | Define stack tecnológica e escopo do MVP |
| **Q-11** | O dono quer receber alertas em tempo real (push/WhatsApp) sobre eventos críticos? (ex: prestador não chegou no horário, pagamento recusado) | Afeta RF-10 e módulo de alertas admin |
| **Q-12** | Existe intenção de expandir para outras cidades em 12-18 meses? (Afeta modelagem de regiões, zonas de cobertura e multi-tenancy) | Decisão arquitetural relevante mesmo no MVP |

---

## 8. Glossário

| Termo | Definição |
|---|---|
| OS | Ordem de Serviço — unidade de trabalho: uma limpeza agendada para um cliente |
| Split | Divisão automática do pagamento entre marca e prestador no gateway |
| Desintermediação reversa | Quando o intermediário (prestador) usa a plataforma para conquistar o cliente e depois remove o criador da plataforma da equação |
| WABA | WhatsApp Business API — versão oficial e programável do WhatsApp para empresas |
| Canal mascarado | Comunicação onde nenhuma das partes vê o contato real da outra — mediada pela plataforma |
| Régua de recompra | Sequência automática de mensagens/ofertas para trazer o cliente de volta após o serviço |

---

*Este documento é um artefato vivo. Deve ser revisado com o dono da empresa antes de qualquer decisão de arquitetura ou desenvolvimento. As perguntas da seção 7 são gates obrigatórios.*
