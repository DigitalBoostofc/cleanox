# CLEANOX: Pesquisa de Mercado, Prior-Art e Componentes Técnicos

**Data:** junho de 2026  
**Objetivo:** Pesquisa exploratória para plataforma de limpeza a domicílio com modelo de desintermediação de prestadores.

---

## 1. PRIOR ART: Concorrentes e Modelos Análogos

### 1.1 Marketplaces Brasileiros de Serviços

#### GetNinjas
- **Modelo:** Profissionais compram pacotes de "moedas virtuais" para adquirir leads de clientes
- **Fundação:** 2011 por Eduardo Orlando L'Hotellier
- **Escala:** ~2.1 milhões de profissionais (2020), +500 categorias
- **Comissão:** Não explícita; monetização via venda de leads
- **Desafio:** Prestador aprende operação e sai; modelo de pre-pago reduz incentivo de fidelização
- **Fonte:** [Prospecto GetNinjas JPMorgan](https://www.jpmorgan.com.br/content/dam/jpm/global/disclosures/BR/Prospecto_Definitivo_GetNinjas.pdf)

#### Singu
- **Modelo:** "Uber da beleza" – conexão entre clientes e profissionais (manicure, cabelo, etc.)
- **Fundação:** 2016 por Tallis Gomes
- **Comissão:** 30% sobre valor do serviço
- **Pagamento:** Intermediado na plataforma
- **Retenção:** Ratings e avaliações de clientes
- **Fonte:** [Plataformas de serviços - SEGS](https://www.segs.com.br/seguros/320225-conheca-7-plataformas-que-ajudam-a-conseguir-clientes)

#### Triider
- **Modelo:** App de pequenas reformas (orçamento, conexão, pagamento intermediado)
- **Fundação:** 2017 em Porto Alegre
- **Comissão:** Apenas por serviço executado (não mensal) – reduz risco prestador
- **Retenção:** Foco em prestador não pagar taxa sem receita
- **Fonte:** [Codificar - Aplicativos de serviços](https://codificar.com.br/aplicativos-prestacao-de-servicos/)

#### Diarista / Diarissima / Dona App
- **Modelo:** Apps especializadas em faxina com pacotes semanais/mensais
- **Comissões:** AHOY! 15%, Dona App 24%, Diarix 20%
- **Retenção:** 
  - Pacotes recorrentes (semanal, quinzenal, mensal)
  - Profissional "preferencial" para cliente
  - Sistema de recompensa por quantidade + qualidade (ratings)
  - Avaliações de cliente como prova de confiabilidade
- **Fonte:** [AHOY! aplicativo de diarista](https://ahoyapp.com.br/aplicativo-para-trabalhar-de-diarista/)

#### Parafuzo
- **Modelo:** Marketplace de faxina (resultado de fusão Blumpa + Parafuzo)
- **Foco:** Limpeza residencial
- **Fonte:** [Parafuzo no Canaltech](https://canaltech.com.br/apps/melhores-apps-contratar-vender-servicos/)

### 1.2 Modelos Internacionais de Referência

#### TaskRabbit (EUA/Global)
- **Modelo:** Marketplace de serviços variados com taskers e clientes
- **Retenção Tasker:**
  - Elite status → benefícios (Onsi insurance: proteção a acidentes, morte acidental, invalidez)
  - Estratégia de mapa geográfico para maximizar requisições
  - Comunicação clara com cliente → builds trust → reviews → trabalho recorrente
  - Gerenciamento de disponibilidade impacta volume
- **Comunicação:** Usa Twilio (call masking)
- **Fonte:** [TaskRabbit Blog Portugal](https://www.taskrabbit.pt/blog/tarefas-na-taskrabbit-um-guia-de-iniciacao/)

#### Handy (EUA/Europa)
- **Modelo:** Marketplace de limpeza e serviços domésticos
- **Retenção:** Call masking (Twilio Proxy) para evitar vazamento de contato
- **Fonte:** Mencionado em contexto de masked calling, Twilio Proxy

#### Uber/iFood (Referência de Modelo)
- **Modelo:** Número mascarado, split de pagamento, avaliações
- **Retenção:** Algoritmo de alocação de tarefas, ratings públicos, benefícios marginais
- **Comunicação:** In-app apenas (sem exposição de contato direto)
- **Fonte:** [Uber Legal Brasil](https://www.uber.com/legal/en/document/?country=brazil&lang=pt-br&name=general-terms-of-use)

---

## 2. PADRÕES ANTI-DESINTERMEDIAÇÃO COMPROVADOS

### 2.1 Número/Contato Mascarado (Call Masking & SMS)

**Twilio Proxy** (Mais consolidado globalmente)
- **Funcionamento:** Intermediária anônima encaminha chamadas/SMS sem expor números reais
  - Cliente vê: 555-0000 (número mascarado)
  - Número mascarado encaminha para: número real do prestador (555-1111)
  - Prestador nunca vê número real do cliente
- **Escala:** Usado por Uber, Lyft, Airbnb, Postmates, Instacart
- **API:** REST API com SDKs, tracking de metadados, timeouts customizáveis
- **Custo:** Pago por minuto de chamada + SMS por mensagem
- **Fonte:** [Twilio Proxy Docs](https://www.twilio.com/docs/proxy), [Twilio Voice Proxy](https://www.twilio.com/docs/glossary/what-is-voice-proxy), [Masked Calling](https://www.twilio.com/docs/glossary/what-is-masked-calling)

**Zenvia** (Forte no Brasil)
- **Serviço:** SMS corporativo, chat, WhatsApp
- **Call Masking:** Suporte via integração (não primário, SMS é foco)
- **Vantagem Brasil:** Integração com operadoras BR
- **Fonte:** [Zenvia SMS](https://zenvia.com/en/sms/)

**Telnyx**
- **Serviço:** Voz, SMS, WhatsApp global
- **Call Masking:** Capacidade nativa
- **Nota:** Menos documentação sobre parcerias Zenvia em contexto BR
- **Fonte:** Mencionado em estudos comparativos

### 2.2 Pagamento Intermediado com Split/Escrow

**Princípio:** Plataforma retém pagamento, aprova/rejeita, depois repassa ao prestador com delay

**Vantagens anti-desintermediação:**
- Prestador não recebe pagamento direto do cliente → cliente não tem comprovante direto
- Split automático: comissão separada legalmente, transparência fiscal
- Retenção temporária (1-3 dias) permite apreensão de fraude/disputa
- Rastreabilidade: cada transação auditável

### 2.3 Cláusulas de Exclusividade e Restrições Contratuais

**Marco Legal BR:**
- Cláusula de exclusividade: prestador NÃO trabalha para concorrente
- Válida se:
  - Limitada no tempo (ex: 6 meses pós-término)
  - Limitada no espaço (região geográfica)
  - Limitada em atividade (tipo de serviço)
  - Com compensação financeira proporcional
- **Risco:** Pode ser questionada como abuso de poder econômico (Lei 12.529/2011)
- **Recomendação:** Usar com cautela; documentar compensação clara
- **Fonte:** [Exclusividade contrato - Almeida e Amaral](https://www.almeidaeamaral.com.br/a-clausula-de-exclusividade-no-contrato-de-prestacao-de-servico/)

### 2.4 Gamificação e Programas de Loyalty

**Elementos Comprovados:**
- **Pontos/Badges:** Por cada serviço, por qualidade, por frequência
- **Níveis:** Bronze → Silver → Gold → Elite (unlock benefícios)
- **Recompensas instantâneas:** Descontos imediatos, prioridade em tarefas
- **Rankings:** Competição social entre prestadores
- **Benefícios:** Seguros, prioridade em rotas, acesso a "super tasks" (pagamento maior)

**Resultado:** Retenção +25% (estudo Deloitte)

**Aplicação Cleanox:** Pontos por serviço completado, bônus por ratings 4.8+, acesso a clientes premium, cashback escalonado

**Fonte:** [Loyalty Loop - Gamificação](https://www.loyaltyloop.com.br/news/gamificacao-em-programas-de-fidelidade)

### 2.5 Avaliações Públicas e Reputação

- **TaskRabbit / AHOY! / Diarista:** Ratings de cliente público no perfil
- **Impacto:** Alta avaliação = mais requisições = maior receita
- **Efeito colateral:** Prestador dependente da plataforma para visibilidade
- **Implementação:** Ratings 1-5 + comentários, algoritmo oculta avaliações muito antigas

---

## 3. COMPONENTES TÉCNICOS & SERVIÇOS (Brasil)

### 3.1 Pagamentos com Split

#### Asaas ⭐ **Recomendado**
- **Split:** Sim, por percentual ou valor fixo
- **Métodos:** Pix (0.99%), TED (R$1.99–3.49), Cartão (2.99–4.99%)
- **Taxa mensal:** Não
- **Transações:** Ilimitadas no free tier
- **CNPJ-to-CNPJ:** Sim, ideal para prestador PJ
- **Documentação:** Boa, SDKs
- **Compliance:** Integra KYC básico
- **Fonte:** [Asaas Split Payment](https://blog.asaas.com/qual-api-oferece-split-de-pagamentos/), [Asaas Docs](https://docs.asaas.com/docs/split-de-pagamentos)

#### Pagar.me (Stone Group)
- **Split:** Sim, com regras customizáveis
- **Métodos:** Pix, Cartão, TED
- **Escala:** Mais usado em marketplaces de e-commerce que serviços
- **Fraude:** Prevenção avançada integrada
- **Integração:** Excelente SDK Node/Python
- **Custo:** Taxa maior que Asaas
- **Fonte:** [Pagar.me](https://www.pagar.com.br)

#### Iugu
- **Split:** Multisplit (2+ parceiros), percentual ou fixo
- **Métodos:** Cartão, Pix, TED
- **Sub-contas:** Acesso full para visualizar dados de cada parceiro
- **Pagamento Recorrente:** Nativo (bom para pacotes mensais)
- **Desvantagem:** Menos documentação que concorrentes
- **Fonte:** [Iugu Split](https://www.iugu.com/split-pagamentos)

#### Stripe Connect (Premium/Global)
- **Split:** Sim, com Connected Accounts
- **Métodos:** Pix (via parceria local), Cartão
- **Melhor para:** SaaS global, marketplaces com múltiplas moedas
- **Custo:** 2.9% + R$0.30 por transação (acima de Asaas)
- **Vantagem:** Documentação excelente, suporte 24/7
- **Desvantagem:** Mais caro para volume pequeno-médio
- **Fonte:** [Stripe Pricing](https://stripe.com/pricing), [Stripe Connect Split](https://stripe.com/resources/more/how-to-implement-split-payment-systems-what-businesses-need-to-do-to-make-it-work)

#### Mercado Pago Split
- **Split:** Sim, automático
- **Métodos:** Pix, Cartão, conta Mercado Pago
- **Integração:** Consolidada, muitos prestadores já têm conta
- **Desvantagem:** Interface mais focada em e-commerce que marketplaces de serviço
- **Fonte:** [Mercado Pago Split](https://www.mercadopago.com.br/blog/split-pagamento-complexo-marketplace)

**Recomendação inicial:** Asaas (custo baixo + bom split) ou Pagar.me (fraude).

### 3.2 Comunicação Mascarada (Número/WhatsApp)

#### Twilio Proxy (Voice + SMS)
- **Funcionalidade:** Call masking + SMS masking
- **Preço:** ~R$0.02–0.05 por minuto de chamada, R$0.05–0.10 por SMS (variável)
- **Setup:** REST API, SDKs disponíveis
- **Integração:** Boa documentação, webhook suporte
- **Escala:** Usado por Uber, Lyft, Airbnb
- **Desvantagem:** Não é nativo para WhatsApp (precisa integração adicional)
- **Fonte:** [Twilio Proxy](https://www.twilio.com/docs/proxy), [Twilio GitHub Masked Numbers](https://github.com/twilio-labs/sample-conversations-masked-numbers)

#### WhatsApp Business API via BSP (Brasil)
- **Funcionamento:** Intermediário (BSP) autorizado Meta controla conta WhatsApp
- **Métodos de Mascaramento:** 
  - Número de negócio diferente (não é número pessoal do cliente)
  - Conversa via WhatsApp Business (não mostra contato direto no app pessoal)
  - Integração de APIs permite roteamento oculto
- **Custos:** Meta charge + BSP markup (operação, suporte, LGPD)
- **Preço:** ~R$0.50–2 por mensagem (conversa) conforme BSP
- **BSPs autorizadas no Brasil (47 totais):**
  - **360dialog** ⭐ (mais barato, sem markup da Meta)
  - **SocialHub**
  - **Take Blip**
  - **Zenvia**
  - **RD Station Conversas**
  - **Octadesk**
  - **Wati**
  - **Twilio** (via parceria)
  - **Botconversa**
- **Vantagem:** WhatsApp é ubíquo no Brasil, menor atrito que SMS
- **Compliance:** BSP responsável por LGPD + ANATEL
- **Fonte:** [HelenaCRM - WhatsApp Business API 2026](https://www.helenacrm.com/post/api-whatsapp-oficial-meta), [Zenvia Blog](https://zenvia.com/blog/whatsapp-business-api-o-que-e-como-funciona-e-vantagens-fundamentais-para-empresas/), [SocialHub - BSPs Brasil](https://www.socialhub.pro/blog/bsp-whatsapp-brasil-empresas-homologadas-meta-2026/)

#### Zenvia (SMS + WhatsApp)
- **Força:** Integração com operadoras BR (TIM, Vivo, Oi, Claro)
- **Serviço:** SMS corporativo, WhatsApp Business (via Meta)
- **Preço:** Competitivo para SMS em volume
- **Desvantagem:** Call masking não é primário (SMS é foco)
- **Fonte:** [Zenvia SMS](https://zenvia.com/en/sms/), [Zenvia FAQ](https://www.zenvia.com/wp-content/uploads/2019/04/Zenvia-PDF-FAQ.pdf)

**Recomendação:** WhatsApp Business API (360dialog como BSP) + Twilio Proxy para voz.

### 3.3 Notificações Push & Agendamento

#### Firebase Cloud Messaging (FCM)
- **Funcionalidade:** Push nativo Android/iOS/Web
- **Preço:** Gratuito (Google Cloud)
- **Integração:** Twilio Conversations SDK integra FCM
- **Desvantagem:** Não é scheduler; apenas delivery de notificações
- **Documentação:** Excelente
- **Fonte:** [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)

#### Twilio Notify
- **Funcionalidade:** Notificações multi-canal (SMS, Push, WhatsApp)
- **Preço:** ~R$0.01–0.05 por notificação
- **Integração:** FCM integrado, Twilio Conversations
- **Uso:** Notificar prestador de nova tarefa, cliente do status "a caminho"
- **Fonte:** [Twilio Notify](https://www.twilio.com/docs/notify/quickstart/android)

#### Agendamento (Cron / Job Queue)
- **Options:**
  - **Bull (Node.js)** - fila de jobs em Redis, open-source
  - **APScheduler (Python)** - scheduler simples
  - **Temporal.io** - workflow engine (mais complexo)
  - **Cloud Scheduler (Google Cloud)** - serverless
- **Uso Cleanox:** Agendar notificações 24h antes, renotificação 1h antes, lembrete pós-serviço
- **Recomendação:** Bull + Redis para MVP, escalar com Temporal depois

### 3.4 Nota Fiscal (NFS-e)

**Contexto 2026:**
- Até 30 de junho 2026: DANFSe via API (descontinuado)
- A partir de 1º de julho 2026: Emissão local obrigatória
- A partir de 1º de setembro 2026: NFS-e padrão nacional obrigatória para ME/EPP Simples Nacional
- **Taxa ISS:** Varia por município (2–5% em SP, RJ)

**APIs de NFS-e:**
- **Focus NFe** ⭐ (melhor docs, suporte BR)
  - JSON REST, webhooks, validação antes de emitir
  - Preço: ~R$0.50 por NFSe
  - Suporte: Excelente
- **Brasil NFe**
  - Multi-produto (NF-e, NFC-e, NFS-e, CT-e, MDFe)
  - Preço: Variável
- **Nuvem Fiscal**
  - Bom para SaaS (whitebox)
  - Preço: Por volume
- **Tecnospeed**
  - Bem conhecida em mercado BR
  - Preço: Premium

**Implementação:** Focus NFe + automação para emitir NFSe 24h após serviço confirmado (via webhook de aprovação de pagamento)

**Fonte:** [Focus NFe - NFS-e Nacional](https://focusnfe.com.br/produtos/nfse-nacional/), [Tecnospeed - API NFSe](https://blog.tecnospeed.com.br/api-nfse-nacional-o-que-e-e-como-integrar/), [Nota Técnica CGNFS-e 2026](https://crcma.org.br/noticias/nota-tecnica-define-novo-padrao-nacional-do-danfse-e-suspende-api-atual-a-partir-de-julho-de-2026)

### 3.5 Geolocalização & Real-Time Tracking

**Opções:**
- **Google Maps Platform / Directions API** - excelente, pago por requisição (~R$0.05–0.10 por rota)
- **Mapbox** - alternativa (Similar preço)
- **OpenStreetMap + OSRM** - open-source, mas sem SDK rico
- **PostGIS (banco de dados)** - para cálculos geoespaciais próprios

**Implementação:** 
- Prestador ativa "status a caminho" → app envia locação em tempo real (polling 10–30s)
- Cliente vê marcador no mapa
- Notificação automática "Prestador a caminho" via FCM/SMS

**Fonte:** [Deliforce tracking](https://melhorenvio.com.br/blog/frete-e-logistica/loggi-rastreamento/)

---

## 4. Considerações Regulatórias Brasil

### 4.1 LGPD (Lei Geral de Proteção de Dados Pessoais)

**Risco:** Número do cliente (ativo) é dado pessoal protegido

**Obrigações:**
- Consentimento explícito do cliente para armazenar/usar número
- Transparência: Política de privacidade clara (dados compartilhados com prestador? por quanto tempo?)
- Direito à exclusão/portabilidade
- Notificação em caso de vazamento
- Compliance: ~44% dos marketplaces BR falham em transparência

**Implementação Cleanox:**
- Número NUNCA visível para prestador (usar Twilio Proxy)
- Política de privacidade clara: "Compartilhamos seu número via intermediária mascarada; nunca é armazenado no prestador"
- Consentimento checkbox no onboarding
- LGPD safeguard: banco de dados separado para telefone (criptografado)

**Fonte:** [LGPD Marketplaces - Olist](https://olist.com/blog/pt/como-empreender/abrir-empresa/lgpd-e-marketplaces/), [FGV - Proteção de Dados Marketplaces](https://direitorio.fgv.fr/sites/default/files/arquivos/final_relatorio-protecao_de_dados_em_marketplaces_no_brasil.pdf)

### 4.2 Relação Trabalhista (PJ vs. CLT)

**Contexto: STF julgará em junho 2026 se motoristas de app têm vínculo empregatício**

**Risco:** Critérios de subordinação digital podem aplicar a qualquer plataforma

**Critérios de risco de vínculo:**
- ✅ Controle de horário / jornada (Cleanox: prestador agenda próprio horário → baixo risco)
- ✅ Controle de qualidade / avaliações (Cleanox: avalia, mas não restringe = médio risco)
- ✅ Proibição de trabalhar para concorrente (Cleanox: não obrigatório → baixo risco)
- ✅ Remuneração mínima garantida (Cleanox: comissão variável → baixo risco)
- ⚠️ Algoritmo que determina quem recebe tarefa (opacidade = risco)

**Cenários Esperados pós-STF:**
1. **Vínculo total:** Cleanox seria "empregador", teria que formalizar todos prestadores (custo operacional x3)
2. **Autonomia com direitos:** Nova categoria entre CLT e PJ: contribuição INSS obrigatória, seguro contra acidentes, remuneração mínima/hora
3. **Status quo:** Manutenção de PJ puro (menos provável)

**Recomendação Cleanox:**
- Documentar que prestador é **autônomo independente**, não subordinado
- Permitir **trabalhar para concorrentes** (não exclusividade obrigatória)
- **Horário flexível:** Prestador agenda quando quiser
- **Transparência do algoritmo:** Explicar como tarefas são alocadas
- **Seguro voluntário:** Oferecer seguro contra acidentes (Onsi model do TaskRabbit)
- **Consultar advogado BR** antes de lançar (especialista em direito digital)

**Fonte:** [STF retoma julgamento junho 2026](https://www.conjur.com.br/2026-jun-24/stf-retoma-nesta-quarta-24-julgamento-sobre-vinculo-empregaticio-entre-motoristas-e-aplicativos/), [Garrastazu - Vínculo Motoristas App](https://www.garrastazu.adv.br/motoristas-de-app-tem-vinculo-empregaticio-o-que-o-stf-vai-decidir-em-junho-de-2026)

### 4.3 NFS-e (Nota Fiscal de Serviço Eletrônica)

**Obrigação:** Prestador de serviço deve emitir RPS/NFS-e

**Workflow Cleanox:**
1. Serviço completado, cliente aprova pagamento
2. Cleanox emite RPS/NFS-e automaticamente (Focus NFe API)
3. Armazena em servidor de forma que prestador possa visualizar
4. Transmite para prefeitura municipal automático
5. ISS retido ou repassado (variável por município)

**Detalhes:**
- **RPS (Recibo Provisório Serviço):** Intermediário, prazo 5–10 dias para converter NFS-e
- **NFS-e (Nota Fiscal Serviço Eletrônica):** Definitivo
- **Prazo obrigatório:** 1º de setembro 2026 (Resolução CGSN 189/2026)
- **Responsabilidade:** Cleanox (como intermediadora) pode ser responsável solidária

**Detalhe importante:** Com split de pagamento, há debate sobre quem emite a NFS-e:
- Opção 1: Cleanox emite como intermediadora
- Opção 2: Cleanox facilita, prestador emite (requer educação/suporte)
- **Melhor:** Opção 1 (Cleanox emite, retém cópia, oferece ao prestador)

**Fonte:** [Focus NFe - NFS-e](https://focusnfe.com.br/produtos/nfse-nacional/), [ENotas - O que é RPS](https://enotas.com.br/blog/o-que-e-rps/), [Contabilizei - RPA](https://www.contabilizei.com.br/contabilidade-online/rpa-recibo-de-pagamento-autonomo/)

### 4.4 AML/Compliance & Prevenção de Fraude

**Obrigações:**
- KYC (Know Your Customer): Verificação de identidade do prestador
- AML (Anti-Money Laundering): Monitorar transações suspeitas
- PLD/FTP (Prevenção Lavagem Dinheiro/Financiamento Terrorismo): Lei 9.613/1998
- Marketplace: Responsabilidade solidária com prestadores (caso de fraude)

**Implementação:**
- **KYC on signup:** Validar CPF/CNPJ, documento com foto, selfie (face match)
- **Score de risco:** Usar Identiq ou Serasa Experian para scoring
- **Monitoramento:** Asaas/Pagar.me incluem detecção de fraude (cartão)
- **Relatório:** Manter logs de transações para auditoria

**Serviços BR:**
- **Identiq** ⭐ (KYC + antifraude integrado)
- **SumSub** (KYC/AML compliance)
- **Serasa Experian** (consultoria, scoring)

**Fonte:** [Identiq Brasil](https://identiq.com.br/), [SumSub - KYC/AML](https://sumsub.com/kyc-compliance/), [Serasa - Prevenção Fraude](https://www.serasaexperian.com.br/conteudos/prevencao-a-fraude/)

---

## 5. Recomendações de Stack & Trade-offs

### 5.1 Shortlist de Stack Recomendado (MVP)

| Componente | Recomendação | Alternativa | Justificativa |
|---|---|---|---|
| **Pagamento + Split** | Asaas | Pagar.me | Asaas: 40% mais barato que Stripe, bom split. Pagar.me: se fraude for crítica. |
| **Número Mascarado (Voz/SMS)** | Twilio Proxy | Zenvia | Twilio: mais robusto internacionalmente. Zenvia: se volume SMS alto. |
| **WhatsApp** | 360dialog (BSP) | Zenvia, Octadesk | 360dialog: menor markup, melhor para devs. Alternativas: mais suporte. |
| **Notificações** | Firebase + Twilio Notify | Azure Notification Hub | Firebase: gratuito + integrado. |
| **Agendamento** | Bull + Redis | APScheduler | Bull: Node.js, escalável. |
| **NFS-e** | Focus NFe | Brasil NFe | Focus: melhor docs, suporte BR. |
| **KYC/AML** | Identiq | Serasa | Identiq: completo, uma integração. |
| **Geolocalização** | Google Maps API | Mapbox | Google: mais maduro, callbacks confiáveis. |

**Custo Estimado (mensal, 1000 serviços/mês):**
- Asaas: R$50–100 (split 5–10% comissão)
- Twilio Proxy: R$20–50 (chamadas)
- 360dialog/WhatsApp: R$100–300 (mensagens)
- Firebase: Grátis (até 1M notificações)
- Twilio Notify: R$10–30
- Focus NFe: R$30–100 (RPS/NFS-e)
- Identiq: R$100–200 (KYC on-demand)
- Google Maps: R$20–50
- **Total MVP:** ~R$400–800/mês

### 5.2 Decisões de Arquitetura Anti-Desintermediação

#### A. Não Armazenar Número do Cliente
- ✅ **Twilio Proxy** cria número intermediário, rotas internamente
- ✅ Prestador NUNCA vê número real
- ✅ LGPD compliant (número é minimizado em banco)
- ❌ Custo adicional (mas essencial)

#### B. Split Automático no Pagamento
- ✅ Comissão separada automaticamente
- ✅ Transparência: prestador vê exatamente quanto recebe
- ✅ Reduz "tentação" de contato direto (sem bypass)
- ❌ Operação 1–3 dias (não instantâneo)

#### C. Ratings Públicos & Algoritmo Opaco
- ✅ Prestador dependente de plataforma para visibilidade
- ✅ Cliente bem atendido → mais requisições
- ⚠️ Risco trabalhista: deixar claro que é "feedback", não "métrica de performance contratual"

#### D. Seguro Voluntário + Elite Status
- ✅ Benefício que não pode "levar" para concorrente
- ✅ Desativos exclusivamente na plataforma
- ✅ Emula modelo TaskRabbit (comprovado)
- ❌ Custo (mas abatível em comissão)

### 5.3 Timeline de Implementação

**Fase 1 (Mês 1–2, MVP):**
- Backend: Autenticação, cadastro prestador/cliente, matching básico
- Pagamento: Integração Asaas (split), webhook
- Comunicação: Twilio Proxy (voz), 360dialog (WhatsApp via webhook)
- Notificação: Firebase FCM
- Frontend: App React Native ou Flutter

**Fase 2 (Mês 3):**
- NFS-e: Focus NFe automática
- KYC: Identiq básico (CPF/selfie)
- Ratings: Sistema 1–5
- Relatório: Dashboards para prestador/cliente

**Fase 3 (Mês 4+):**
- Gamificação: Pontos, levels, elite status
- Seguro: Parceria (Onsi, SulAmérica, etc.)
- Geolocalização: Google Maps "a caminho"
- Analytics: Churn, retenção, LTV prestador

### 5.4 Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| STF reconhece vínculo trabalhista | Alta (jun 2026) | Crítico | Contrato claro de autonomia, permitir concorrência, sem horário obrigatório |
| Prestador ainda vaza contato | Médio | Alto | Contrato com cláusula de penalidade, monitorar (Twilio logs), educação |
| Fraude (prestador fantasma, cliente não paga) | Médio | Médio | KYC rigoroso, ratings, seguro voluntário, reembolso automático disputa |
| Churn prestador alto | Alto | Crítico | Gamificação, benefícios, comissão competitiva (18–20%), customer success |
| Custo de comunicação mascarada explode | Baixo | Médio | Monitorar Twilio/WhatsApp, considerar SMS barato em paralelo |
| Não-conformidade LGPD/NFS-e | Baixo | Crítico | Auditoria externa, advogado BR, conformidade desde dia 1 |

---

## 6. Conclusão e Próximos Passos

**O modelo de desintermediação é viável e comprovado.** Diarista, AHOY!, TaskRabbit, Singu, Triider já o implementam com sucesso.

**Stack recomendado para MVP:**
1. **Asaas** (pagamentos split) – R$ mais barato
2. **Twilio Proxy** (voz mascarada) + **360dialog** (WhatsApp) – comunicação 100% controlada
3. **Firebase + Twilio Notify** (notificações)
4. **Focus NFe** (NFS-e automática) – compliance
5. **Identiq** (KYC) – fraude zero

**Diferencial Cleanox:**
- Número 100% mascarado (Twilio Proxy, não apenas chat)
- Cliente e prestador nunca se veem (premium vs. Diarista/AHOY que mostram perfil)
- Seguro voluntário + Elite status (retenção)
- Automação NFS-e (simplicidade fiscal)

**Próximos passos:**
1. ✅ Validar com 5–10 diaristas: comissão de 20% é aceitável? Benefícios de seguro/elite valem a pena?
2. ✅ Protótipo: Twilio Proxy + Asaas (prove "sem contato direto")
3. ✅ Legal: Consultar advogado BR (contrato prestador, LGPD, relação trabalhista)
4. ✅ Fiscal: Contabilista para fluxo NFS-e, ISS, responsabilidade solidária

---

## Referências Completas

### Concorrentes / Prior Art
- [GetNinjas - Prospecto JPMorgan](https://www.jpmorgan.com.br/content/dam/jpm/global/disclosures/BR/Prospecto_Definitivo_GetNinjas.pdf)
- [SEGS - Plataformas de Serviços](https://www.segs.com.br/seguros/320225-conheca-7-plataformas-que-ajudam-a-conseguir-clientes)
- [Codificar - Aplicativos de Prestação Serviços](https://codificar.com.br/aplicativos-prestacao-de-servicos/)
- [Canaltech - Melhores Apps Contratar Serviços](https://canaltech.com.br/apps/melhores-apps-contratar-vender-servicos/)
- [AHOY! - Aplicativo Diarista](https://ahoyapp.com.br/aplicativo-para-trabalhar-de-diarista/)
- [TaskRabbit Portugal Blog](https://www.taskrabbit.pt/blog/tarefas-na-taskrabbit-um-guia-de-iniciacao/)

### Padrões Anti-Desintermediação
- [Twilio Proxy](https://www.twilio.com/docs/proxy)
- [Twilio Voice Proxy](https://www.twilio.com/docs/glossary/what-is-voice-proxy)
- [Twilio Masked Calling](https://www.twilio.com/docs/glossary/what-is-masked-calling)
- [Twilio GitHub Masked Numbers](https://github.com/twilio-labs/sample-conversations-masked-numbers)
- [Zenvia SMS](https://zenvia.com/en/sms/)
- [Loyalty Loop - Gamificação](https://www.loyaltyloop.com.br/news/gamificacao-em-programas-de-fidelidade)
- [Exclusividade Contrato - Almeida Amaral](https://www.almeidaeamaral.com.br/a-clausula-de-exclusividade-no-contrato-de-prestacao-de-servico/)

### Componentes Técnicos
- [Asaas Split](https://blog.asaas.com/qual-api-oferece-split-de-pagamentos/)
- [Asaas Docs](https://docs.asaas.com/docs/split-de-pagamentos)
- [Iugu Split](https://www.iugu.com/split-pagamentos)
- [Stripe Pricing](https://stripe.com/pricing)
- [Stripe Connect Split](https://stripe.com/resources/more/how-to-implement-split-payment-systems-what-businesses-need-to-do-to-make-it-work)
- [Mercado Pago Split](https://www.mercadopago.com.br/blog/split-pagamento-complexo-marketplace)
- [HelenaCRM - WhatsApp Business API](https://www.helenacrm.com/post/api-whatsapp-oficial-meta)
- [Zenvia WhatsApp Blog](https://zenvia.com/blog/whatsapp-business-api-o-que-e-como-funciona-e-vantagens-fundamentais-para-empresas/)
- [SocialHub - BSPs Brasil 2026](https://www.socialhub.pro/blog/bsp-whatsapp-brasil-empresas-homologadas-meta-2026/)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Twilio Notify](https://www.twilio.com/docs/notify/quickstart/android)
- [Focus NFe](https://focusnfe.com.br/produtos/nfse-nacional/)
- [Tecnospeed API NFSe](https://blog.tecnospeed.com.br/api-nfse-nacional-o-que-e-e-como-integrar/)
- [ENotas - RPS](https://enotas.com.br/blog/o-que-e-rps/)
- [Identiq Brasil](https://identiq.com.br/)
- [SumSub KYC/AML](https://sumsub.com/kyc-compliance/)

### Regulatória Brasil
- [LGPD Marketplaces - Olist](https://olist.com/blog/pt/como-empreender/abrir-empresa/lgpd-e-marketplaces/)
- [FGV - Proteção Dados Marketplaces](https://direitorio.fgv.fr/sites/default/files/arquivos/final_relatorio-protecao_de_dados_em_marketplaces_no_brasil.pdf)
- [STF Junho 2026 - Vínculo Motoristas](https://www.conjur.com.br/2026-jun-24/stf-retoma-nesta-quarta-24-julgamento-sobre-vinculo-empregaticio-entre-motoristas-e-aplicativos/)
- [Garrastazu - Vínculo App](https://www.garrastazu.adv.br/motoristas-de-app-tem-vinculo-empregaticio-o-que-o-stf-vai-decidir-em-junho-de-2026)
- [CGNFS-e Nota Técnica 2026](https://crcma.org.br/noticias/nota-tecnica-define-novo-padrao-nacional-do-danfse-e-suspende-api-atual-a-partir-de-julho-de-2026)

---

**Relatório concluído: junho 2026**
