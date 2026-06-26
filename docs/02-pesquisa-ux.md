# CLEANOX — Pesquisa de Usuários, Jornadas e Dores
### Documento de Especificação de UX para Plataforma de Serviços Domésticos Sob Demanda
**Versão 1.0 — Junho 2026**

---

## Sumário executivo

A Cleanox opera hoje como um negócio de geração de leads digitais acoplado a uma operação presencial artesanal. O funil de marketing funciona (tráfego pago converte em WhatsApp), mas a execução do serviço cria um risco estrutural crítico: o prestador detém os três ativos mais valiosos do negócio — o relacionamento com o cliente, o canal de comunicação e o fluxo de caixa. Este documento mapeia os quatro atores do sistema, suas jornadas completas, tensões de UX, dores prioritárias e um conjunto de recomendações para a construção de uma plataforma que reverta essa equação sem gerar atrito inaceitável para nenhum dos lados.

---

## 1. PERSONAS

### (a) CLIENTE FINAL — "Fernanda, 34 anos"

**Perfil demográfico**
Fernanda tem 34 anos, mora em São Paulo (Zona Oeste), trabalha como coordenadora de RH em empresa de médio porte, renda familiar mensal de R$ 8.500. Mora em apartamento com marido e dois filhos pequenos. Tem um carro popular 2021 e dois sofás na sala.

**Contexto de uso**
- Smartphone: iPhone SE (ou Samsung A-series, dependendo do segmento exato)
- Apps que usa intensivamente: iFood, Rappi, Uber, Instagram, WhatsApp, Nubank
- Acostumada a pagar com Pix e cartão de crédito via aplicativo
- Faz pesquisa de serviços pelo Google e Instagram antes de contratar
- Usa o celular para praticamente tudo relacionado a consumo; não tolera ligar para nenhum serviço

**Nível de letramento digital**
Alto. Navega apps com fluidez, entende onboarding, não tem resistência a criar conta se o benefício for claro.

**Objetivos principais**
- Resolver o problema (manchas no sofá, odor no carro, pelo de pet) sem sair de casa
- Saber o preço antes de confirmar — sem surpresas na hora do pagamento
- Ter previsibilidade de horário (ela precisa reorganizar a rotina para receber alguém)
- Sentir que a marca é de confiança antes de dar o endereço residencial a um desconhecido

**Frustrações atuais**
- Cota um serviço, a atendente some e responde horas depois
- O prestador liga do celular pessoal e ela não sabe se é da empresa
- Pagamento em dinheiro ou transferência avulsa para a pessoa gera desconforto ("parece informalidade")
- Não recebe nenhuma confirmação formal do agendamento
- Quando algo dá errado, não sabe com quem reclamar — a empresa ou o prestador?

**Motivações**
Praticidade e resultado visível. O argumento do "antes e depois" na plataforma atual funciona bem para ela. Ela também fica mais disposta a recomendar quando o serviço tem cara de empresa, não de autônomo.

**Frase representativa**
> "Eu quero marcar, saber exatamente quando vem e pagar tudo pelo app. Não preciso de mais nada."

---

### (b) ATENDENTE / SDR — "Patrícia, 28 anos"

**Perfil demográfico**
Patrícia tem 28 anos, é funcionária CLT da Cleanox, trabalha de casa ou de um coworking pequeno. Nível superior incompleto. Salário fixo mais comissão por agendamento fechado. Cuida de 3 a 5 atendimentos simultâneos durante o horário comercial.

**Contexto de uso**
- WhatsApp Business no celular pessoal (conta empresa) + WhatsApp Web no notebook
- Planilha Google Sheets para controlar agendamentos
- Às vezes usa papel para anotar confirmações rápidas
- Sem sistema integrado: ela gerencia manualmente os horários dos prestadores, o status de cada serviço e o histórico de cada cliente

**Nível de letramento digital**
Médio-alto. Usa bem WhatsApp, planilha e ferramentas do Google. Resiste a sistemas muito complexos porque já tem muita coisa para fazer ao mesmo tempo.

**Objetivos principais**
- Fechar o maior número de agendamentos possíveis (impacta comissão)
- Não errar horário ou prestador (erros geram reclamação direta para ela)
- Comunicar com agilidade: cliente que espera mais de 5 minutos some

**Frustrações atuais**
- Confirmar disponibilidade de prestador é manual: ela manda mensagem para o prestador, espera, depois volta para o cliente. Esse loop pode durar 20 minutos
- Quando o prestador cancela na última hora, ela precisa ligar para vários outros tentando encaixar alguém — um pesadelo
- Não tem visibilidade de onde o prestador está no dia do serviço
- Quando o cliente paga e depois questiona o valor, ela não tem comprovante formal
- A planilha não avisa de conflitos de horário automaticamente

**Motivações**
Eficiência e reconhecimento. Quer que o sistema faça o trabalho chato para que ela possa focar em convencer clientes.

**Frase representativa**
> "Se eu pudesse ver em um lugar só os horários livres e mandar a confirmação com um clique, eu fecharia o dobro de pedidos por dia."

---

### (c) PRESTADOR / HIGIENIZADOR — "Rosangela, 44 anos"

**Perfil demográfico**
Rosangela tem 44 anos, mora na periferia de São Paulo, ensino médio completo, mãe de dois filhos adolescentes. Trabalha como prestadora de serviço autônoma, atende em média 4 a 6 clientes por semana, combinando serviços com a Cleanox e alguns clientes próprios que foi acumulando ao longo do tempo. Renda mensal variável, entre R$ 2.800 e R$ 4.500.

**Contexto de uso**
- Smartphone Android básico (Samsung A14 ou similar), 64 GB, sempre com pouco armazenamento
- WhatsApp é o principal canal de comunicação para tudo: família, trabalho, clientes, banco
- Usa aplicativo do banco (Inter ou Caixa) para receber Pix
- Já usou app de entregador (iFood) e entende a lógica de "receber pedido e aceitar"
- Internet 4G que oscila dependendo da região onde está trabalhando

**Nível de letramento digital**
Médio-baixo para apps novos. Aprendeu o que precisou por necessidade (WhatsApp Business, Pix), mas desconfia de apps desconhecidos. Fica ansiosa quando tem que aprender algo novo no celular, especialmente se o aplicativo exige muitos passos.

**Objetivos principais**
- Ter previsibilidade de renda: saber quantos serviços tem na semana
- Receber o pagamento assim que terminar o serviço
- Ser reconhecida pelo trabalho bem feito
- Ter flexibilidade de horário para resolver coisas pessoais quando necessário

**Frustrações atuais**
- Às vezes o cliente não está em casa no horário marcado e ela já foi até o endereço
- Combinações de pagamento mudam na última hora
- Não tem certeza se vai receber o valor certo ao final
- Quando há reclamação, ela fica sem informação de como resolver
- Sente que construiu relacionamento com clientes e a empresa pode "tirar" esses clientes dela

**Motivações latentes (que ela não diz, mas orientam o comportamento)**
Ela quer manter o acesso direto ao cliente porque isso é sua rede de segurança. Se o relacionamento for dela, ela pode atender o cliente de forma independente caso a parceria com a Cleanox acabe. Isso explica por que ela troca o número com clientes proativamente — não por má-fé declarada, mas por autopreservação financeira.

**Frase representativa**
> "Eu preciso saber o dia, o horário e quanto vou receber. O resto eu resolvo."

---

### (d) DONO / ADMIN — "Eduardo, 41 anos"

**Perfil demográfico**
Eduardo tem 41 anos, fundou a empresa há 4 anos, começou sozinho e hoje tem entre 8 e 15 prestadores cadastrados (dependendo da temporada). Formação em administração, experiência prévia em vendas. Investe em tráfego pago (Meta e Google Ads), é ele quem decide as campanhas, preços e estratégia geral.

**Contexto de uso**
- iPhone, MacBook, Google Workspace
- Meta Business Suite para campanhas
- Planilha para acompanhar faturamento
- WhatsApp Business para comunicação com prestadores e clientes VIP
- Já usou CRMs simples (RD Station, HubSpot básico)

**Nível de letramento digital**
Alto. Confortável com ferramentas de marketing digital, integrações via Zapier, dashboards básicos. Tem opinião formada sobre produto e quer tomar decisões com dados.

**Objetivos principais**
- Escalar o faturamento sem aumentar proporcionalmente o risco de churn de prestadores
- Ter controle total sobre o relacionamento com o cliente
- Saber em tempo real o status de cada serviço em andamento
- Eliminar a dependência do prestador como intermediário financeiro e comunicacional
- Construir uma base de clientes recorrentes que comprem da Cleanox, não do prestador

**Frustrações atuais**
- Perde clientes para ex-prestadores sistematicamente — o cliente vai embora com o prestador quando ele sai
- Não tem visibilidade de onde cada prestador está durante o dia
- O controle financeiro é manual: fica esperando o prestador repassar o dinheiro
- Não consegue escalar atendimento sem contratar mais atendentes
- Campanhas de retenção não funcionam porque o cliente identifica o prestador, não a marca

**Motivações**
Construir um ativo de verdade. Eduardo não quer apenas um negócio de serviços — quer uma plataforma com valor de marca, base de dados de clientes e operação previsível.

**Frase representativa**
> "Cada cliente que o prestador leva embora é dinheiro que eu investi em marketing indo pro bolso de outra pessoa."

---

## 2. JORNADAS PONTA-A-PONTA

### Jornada do Cliente

---

**ETAPA 1 — Descoberta e primeiro contato**

Canal atual: Anúncio Meta/Google Ads → landing page Cleanox → cotador online ou WhatsApp

Dores:
- O anúncio promete praticidade, mas ao clicar no WhatsApp o cliente cai numa fila de mensagens e espera resposta por minutos ou horas
- O cotador online termina com opções (baixar PDF, enviar no WhatsApp, agendar pelo Google Calendar) — nenhuma dessas é um agendamento real confirmado pela empresa
- O cliente não tem certeza se vai ser contactado ou se mandou para o "buraco negro do WhatsApp"

Emoção predominante: Curiosidade + incerteza inicial

🔴 **Ponto de atrito crítico:** A transição entre o cotador online e a confirmação humana é um gap não fechado. O cliente faz todo o trabalho de cotar, preenche nome, telefone e endereço, e termina sem nenhuma confirmação de retorno com prazo. A taxa de abandono aqui tende a ser alta.

---

**ETAPA 2 — Atendimento e negociação**

Canal atual: WhatsApp Business (atendente humana)

Dores:
- Tempo de resposta variável — se a atendente está com outros chats, o cliente aguarda
- O cliente repete informações que já preencheu no cotador porque a atendente não tem contexto automático
- O preço pode mudar na conversa ("dependendo do estado dos bancos, pode ter acréscimo")
- Não há confirmação formal: o agendamento é verbal via WhatsApp, sem nenhum documento ou link com os dados

Emoção predominante: Impaciência + desconfiança latente

---

**ETAPA 3 — Confirmação do agendamento**

Canal atual: WhatsApp (mensagem de texto da atendente)

Dores:
- A "confirmação" é uma mensagem de texto sem nenhum mecanismo de lembrete
- O cliente muitas vezes esquece o horário ou a janela combinada ("de manhã")
- Não recebe lembretes 24h antes ou 2h antes

Emoção predominante: Alívio momentâneo, mas ansiedade residual

⭐ **Momento de verdade:** A confirmação formal do agendamento é o primeiro momento em que o cliente decide se vai recomendar a empresa. Se a confirmação for profissional (mensagem estruturada com data, horário, serviços, valor), a percepção de qualidade aumenta antes mesmo do serviço acontecer.

---

**ETAPA 4 — Véspera e dia do serviço**

Canal atual: WhatsApp (prestador manda mensagem avisando que está a caminho)

Dores:
- O cliente recebe uma mensagem de um número desconhecido dizendo "Oi, sou a Rosangela da Cleanox, tô a caminho"
- Ele não tem como verificar se é realmente da empresa
- O prestador tem o número do celular pessoal do cliente
- Se o prestador se atrasa, não há rastreamento — o cliente fica esperando sem saber onde a pessoa está

Emoção predominante: Ansiedade moderada + sensação de exposição ("quem é essa pessoa com o meu endereço?")

🔴 **Ponto de atrito crítico:** A ausência de rastreamento e de identidade verificada do prestador cria dois problemas simultâneos — falta de segurança para o cliente e falta de controle para a empresa.

⭐ **Momento de verdade:** O momento em que o prestador chega. Se chegar no horário, com identificação visual da marca (uniforme, crachá), com comportamento profissional, toda a incerteza anterior é apagada. Se chegar atrasado e sem identificação, a experiência entra em colapso.

---

**ETAPA 5 — Execução do serviço**

Canal atual: Presencial, sem nenhuma mediação digital

Dores:
- O cliente não sabe quanto tempo vai durar exatamente
- Se surgir um problema (mancha difícil, dano acidental em estofado), não há protocolo claro
- O prestador pode fazer cobranças adicionais que não estavam no orçamento original

Emoção predominante: Observação passiva + ansiedade residual sobre resultado

---

**ETAPA 6 — Pagamento**

Canal atual: Pix direto para o prestador, dinheiro em mãos ou transferência para conta pessoal do prestador

Dores:
- Pagar para a pessoa física (nome da Rosangela, não da Cleanox) gera desconforto
- Não há comprovante da empresa — só o comprovante de transferência bancária
- O cliente não tem recibo com logo da Cleanox, descrição do serviço, CNPJ
- Se o valor for diferente do orçado, não há como contestar formalmente

Emoção predominante: Desconforto + sensação de informalidade

🔴 **Ponto de atrito crítico:** Este é o ponto de maior risco para a marca. O cliente está pagando para uma pessoa física, não para a Cleanox. Isso quebra toda a percepção de profissionalismo construída pelo site e pelo marketing. É também o momento em que o prestador pode dizer "pode pagar direto para mim na próxima vez" — e o desvio de cliente começa aqui.

---

**ETAPA 7 — Avaliação e pós-serviço**

Canal atual: Nenhum (não existe fluxo formal de avaliação)

Dores:
- O cliente não recebe nenhuma mensagem de agradecimento ou pedido de avaliação
- Se quiser reclamar, não sabe para quem
- Se quiser reagendar, vai ter que passar por todo o processo novamente no WhatsApp
- Não há programa de fidelidade ou incentivo à recompra

Emoção predominante: Vácuo pós-serviço — o engajamento se perde aqui

🔴 **Ponto de atrito crítico:** A ausência de pós-serviço estruturado é onde a empresa perde a guerra de retenção. O cliente que ficou satisfeito simplesmente não tem estímulo para voltar pela Cleanox — e quando lembrar do serviço, pode chamar a Rosangela diretamente.

---

### Jornada do Prestador

---

**ETAPA 1 — Recebe o job**

Canal atual: Mensagem de WhatsApp da atendente ("Oi Rosangela, tem um serviço amanhã às 10h, pode?")

Dores:
- A confirmação é informal e pode mudar
- Não tem todas as informações de uma vez: endereço, tipo de serviço, valor combinado, nome do cliente
- Às vezes recebe o endereço e o contato do cliente diretamente — e os retém

Emoção predominante: Neutro/positivo (ela precisa do trabalho)

---

**ETAPA 2 — Aceita e se prepara**

Canal atual: Resposta por WhatsApp ("pode, confirmo"), sem sistema

Dores:
- Não tem confirmação formal do que foi combinado
- Não sabe com antecedência qual o material específico precisa trazer para aquele job
- Às vezes o endereço fica para depois e ela não consegue planejar o trajeto

Emoção predominante: Aceitação pragmática

---

**ETAPA 3 — Desloca-se até o cliente**

Canal atual: Google Maps com o endereço recebido via WhatsApp

Dores:
- Em alguns bairros, o endereço é impreciso e ela precisa ligar para o cliente
- Quando liga, usa o número pessoal dela — o cliente passa a ter esse número
- Atrasos de trânsito não têm como ser comunicados automaticamente

Emoção predominante: Estresse de logística urbana

⭐ **Momento de verdade para a operação:** O momento do deslocamento é onde a empresa perde o controle. Se o prestador e o cliente falam diretamente, a extração do relacionamento já começou.

---

**ETAPA 4 — Avisa que está a caminho**

Canal atual: Mensagem de WhatsApp pessoal para o número do cliente

Dores:
- Ela usa o celular pessoal, então o cliente vê seu número real
- A mensagem não tem padrão — cada prestador escreve do jeito que acha melhor
- Não há nenhum mecanismo que confirme ao cliente que aquela mensagem é legítima

Emoção predominante: Neutro (parte da rotina)

🔴 **Ponto de atrito crítico (para a empresa):** É aqui que acontece a troca de contatos que viabiliza o desvio de clientes. Qualquer solução de comunicação mascarada precisa substituir exatamente este momento.

---

**ETAPA 5 — Executa o serviço**

Canal atual: Presencial, autônomo, sem check-in ou check-out registrado

Dores:
- Se surgir algum problema, a prestadora não tem protocolo
- Não há registro fotográfico formal do antes/depois vinculado ao pedido
- O tempo de execução não é rastreado

Emoção predominante: Foco profissional (é o que ela sabe fazer)

---

**ETAPA 6 — Finaliza o serviço**

Canal atual: Avisa a atendente por WhatsApp ("terminei, cliente aprovou"), às vezes envia foto

Dores:
- O processo de finalização é manual e informal
- Não há avaliação formal do cliente registrada no momento
- O check-out não está vinculado ao pagamento automaticamente

Emoção predominante: Alívio + expectativa pelo pagamento

---

**ETAPA 7 — Recebe o pagamento**

Canal atual: Pix na hora, diretamente do cliente para a conta pessoal da prestadora

Dores:
- O repasse para a empresa depende dela ser honesta sobre o valor recebido
- A empresa não tem forma de verificar se o valor pago foi o orçado
- Se a empresa quiser mudar o modelo de pagamento, enfrentará resistência alta ("mas eu sempre recebo na hora")

Emoção predominante: Satisfação imediata (dinheiro em mãos)

🔴 **Ponto de atrito crítico (para a empresa):** O modelo de pagamento direto é o ativo mais defendido pela prestadora. Qualquer mudança aqui é o maior risco de churn e boicote da prestadora. A transição precisa ser gerenciada com muita delicadeza.

---

## 3. TENSÃO CENTRAL DE UX: PRIVACIDADE SEM FRICÇÃO

### O problema estrutural

A Cleanox precisa resolver simultaneamente três sub-problemas que se contradizem entre si:

1. O prestador precisa saber onde ir (endereço do cliente)
2. O cliente precisa saber que alguém está a caminho (comunicação em tempo real)
3. A empresa não pode permitir que os dois se comuniquem diretamente (risco de desvio)

Toda solução técnica produz um trade-off entre usabilidade e proteção.

---

### Opção A — Chat in-app

**Vantagens:** controle total, histórico auditável, sem exposição de contatos.

**Desvantagens:** exige app instalado com notificação ativa; prestadoras com Android básico tendem a desativar notificações; latência percebida maior que WhatsApp; curva de adoção alta.

**Mitigação:** desenvolver o chat in-app com fallback controlado — se o prestador não ler em X minutos, a empresa envia notificação push. O WhatsApp da empresa (não do prestador) age como espelho de notificação.

---

### Opção B — Número virtual mascarado

**Vantagens:** funciona no WhatsApp sem exigir app do cliente; familiar para o prestador.

**Desvantagens:** custo operacional por pair (R$ 0,30–1,20/serviço via Twilio, Zenvia, Infobip); pode ser contornado verbalmente durante o serviço; WhatsApp de número virtual tem problemas de verificação de conta no Brasil.

**Viabilidade:** Média-alta para o cliente, baixa-média para contenção total.

---

### Opção C — Ligação VoIP mascarada

**Vantagens:** nenhum número real exposto; ligação registrada na plataforma.

**Desvantagens:** exige dados estáveis do prestador; mudança comportamental grande; custo de infraestrutura VoIP alto.

**Viabilidade:** Baixa para operação do dia-a-dia. Alta como funcionalidade complementar para casos de problema de endereço.

---

### Opção D — Rastreamento GPS com botão "Estou a caminho" ⭐ RECOMENDADO

**Como funciona:** quando o prestador inicia o deslocamento e aperta "a caminho" no app, isso dispara automaticamente: notificação push para o cliente com "Sua higienizadora está a caminho", link de rastreamento em tempo real (mapa estilo Uber), previsão de chegada. O cliente vê o prestador se movendo no mapa — sem nenhuma comunicação direta entre eles.

**Vantagens:** elimina a necessidade de a prestadora ligar ou mandar mensagem pessoal; o cliente tem a informação que precisa sem exposição de contato; a empresa tem rastreamento completo; experiência familiar ao cliente (padrão Uber/iFood).

**Desvantagens:** GPS do celular básico pode ser impreciso ou drenar bateria; exige dados móveis durante o deslocamento.

**Viabilidade:** Alta para o cliente. Média para o prestador — depende do dispositivo e conexão. É a funcionalidade de maior impacto na percepção de qualidade do serviço.

---

### Como o endereço do cliente chega ao prestador sem ser retido

Modelo de "endereço efêmero":

1. O prestador recebe o endereço completo somente no momento em que aceita o job e inicia o deslocamento
2. O endereço é exibido diretamente em um mapa integrado ao app — ele navega sem precisar copiar o texto
3. Após o serviço finalizado, o campo de endereço desaparece do histórico — ele só vê bairro/referência
4. O prestador não tem acesso à lista de endereços anteriores — apenas o job atual em andamento

Este modelo é tecnicamente simples mas requer framing cuidadoso: "o app te leva lá, não precisa salvar nada."

---

### Benchmark

**Uber** eliminou completamente a troca de contato direto. O rastreamento em tempo real substituiu a necessidade de comunicação verbal. O modelo Cleanox precisa replicar exatamente isso.

**iFood** resolve com chat in-app para perguntas sobre o pedido. O cliente e o entregador nunca trocam contato real.

**GetNinjas** não resolveu — e pagou o preço. Sem controle pós-contato, a plataforma virou gerador de leads para os próprios profissionais.

**Maid Easy / Homejoy (extintos)** demonstraram que o modelo de marketplace onde o profissional conhece o cliente pessoalmente tem ciclo de vida curto. A solução não é comportamental — é estrutural: o design do produto precisa tornar o desvio inviável, não apenas proibido.

---

## 4. DORES E NECESSIDADES POR ATOR (PRIORIZADO)

### Cliente Final

| Prioridade | Dor / Necessidade |
|---|---|
| Alta | Não saber se o serviço foi realmente agendado após preencher o cotador |
| Alta | Pagar para uma pessoa física em vez da empresa (quebra de confiança) |
| Alta | Receber mensagem de número desconhecido (o prestador) sem verificação da empresa |
| Alta | Não ter rastreamento de quando o prestador vai chegar |
| Média | Ter que repetir informações no WhatsApp que já preencheu no cotador |
| Média | Não receber lembrete antes do serviço |
| Média | Não saber para quem reclamar em caso de problema |
| Média | Não ter histórico de serviços anteriores para reagendar com facilidade |
| Baixa | Interface do cotador não estar disponível em app nativo |
| Baixa | Não ter opção de parcelamento no cartão de crédito |

---

### Atendente / SDR

| Prioridade | Dor / Necessidade |
|---|---|
| Alta | Confirmar disponibilidade de prestador manualmente via WhatsApp (loop lento) |
| Alta | Não ter visibilidade do status em tempo real dos jobs do dia |
| Alta | Gerenciar agenda em planilha sem alertas de conflito de horário |
| Alta | Cliente cancela ou não aparece sem aviso — o prestador foi até o endereço à toa |
| Média | Não ter contexto automático do cliente ao atender no WhatsApp |
| Média | Quando prestador cancela, precisar fazer busca manual por substituto |
| Média | Não ter comprovante formal de valor acordado para resolver disputas |
| Baixa | Ausência de templates de mensagem padronizados para cada etapa do funil |

---

### Prestador / Higienizador

| Prioridade | Dor / Necessidade |
|---|---|
| Alta | Receber o pagamento imediatamente ao finalizar o serviço (sem atraso) |
| Alta | Saber com antecedência todos os dados do job (endereço, o que vai fazer, valor) |
| Alta | Ter previsibilidade da agenda da semana inteira |
| Média | Não ter acesso a suporte rápido quando surge problema durante o serviço |
| Média | App simples: poucos passos, funciona em Android básico, consome pouca bateria |
| Média | Receber reconhecimento por boas avaliações (impacto na distribuição de jobs) |
| Baixa | Ter acesso ao histórico dos jobs realizados (para fins de comprovação de renda) |
| Baixa | Comunicação em português simples, sem jargão de aplicativo |

---

### Dono / Admin

| Prioridade | Dor / Necessidade |
|---|---|
| Alta | Eliminar o repasse financeiro manual (prestador detém o dinheiro) |
| Alta | Manter o cliente vinculado à marca, não ao prestador |
| Alta | Ter rastreamento em tempo real de todos os prestadores em campo |
| Alta | Visualizar em dashboard o status de todos os jobs do dia |
| Média | Ter métricas de recompra, LTV e NPS por cohort de clientes |
| Média | Automatizar lembretes e confirmações de agendamento |
| Média | Controlar qual prestador vai para qual cliente (impedir consolidação excessiva de par) |
| Baixa | Integração com ferramentas de marketing para nutrição de leads |
| Baixa | Relatório de produtividade por prestador |

---

## 5. RISCOS DE ADOÇÃO E MITIGAÇÕES

### Risco Prestador: Boicote, Recusa do App e Desvio Preventivo

**Reações previsíveis:**
- Contatar proativamente os clientes atuais antes da plataforma entrar
- Recusar instalar o app ("meu celular não tem espaço" / "não sei mexer nisso")
- Fingir usar o app mas combinar negociações fora
- Simplesmente parar de trabalhar com a Cleanox com a carteira de clientes acumulada

**Estratégias de mitigação:**

**Design de incentivo:** O app precisa ser percebido como vantagem, não como controle. Framing correto: "Você não precisa mais resolver agendamento no WhatsApp, o app te manda tudo organizado." Elementos de valor percebido: calendário de jobs automatizado, comprovante de renda para crédito/financiamento, avaliações que aumentam a prioridade de distribuição de jobs.

**Transição em fases:** Não corte o pagamento direto do dia para a noite.
- Fase 1 (mês 1-2): manter pagamento presencial, mas passar a comunicação pelo app
- Fase 2 (mês 3-4): introduzir pagamento pela plataforma com repasse no mesmo dia (D+0 via Pix)
- Fase 3 (mês 5+): pagamento presencial deixa de existir

**Política de retenção por senioridade:** Prestadoras com mais tempo de casa recebem repasse prioritário e bônus de fidelidade.

**Bloqueio progressivo de dados:** Implementar o sistema de endereço efêmero silenciosamente. Os que reclamam são exatamente os que apresentam maior risco.

**Rotação estratégica de pares:** Nunca mande a mesma prestadora ao mesmo cliente mais de 2 vezes consecutivas sem alternância. A Cleanox pode criar perfis de tipo de serviço (e.g., "prestadora especialista em colchões") ao invés de identidade pessoal como diferencial.

---

### Risco Cliente: Fricção no Pagamento Digital

**Reações previsíveis:**
- Desconfiança ("por que tenho que pagar antes da pessoa chegar?")
- Dificuldade técnica ("não consigo cadastrar o cartão")
- Percepção de custo adicional ("vai ficar mais caro pagando pelo app?")
- Recusa em criar conta ("não quero dar meu CPF")

**Estratégias de mitigação:**

**Pix como porta de entrada:** O link de pagamento deve ser um link de Pix — o cliente copia ou scanneia o QR e paga como sempre fez, mas agora o dinheiro vai para o CNPJ da Cleanox. Mudança de backend invisível para o cliente.

**Sequência de pagamento:**
1. Cliente paga link de Pix gerado pela Cleanox após a finalização — igual ao que já faz, mas para a empresa
2. Depois de 2 serviços, oferecer opção de salvar cartão para pagamento automático com desconto
3. Para clientes recorrentes, introduzir pré-autorização

**Transparência de valor:** Nunca cobrar "taxa de plataforma" visível. Se houver margem, absorver no preço.

**Recibo formal como recompensa:** Após cada pagamento pelo link da plataforma, o cliente recebe automaticamente um recibo em PDF com CNPJ da Cleanox, descrição detalhada do serviço, valor, data e avaliação. Isso é algo que o pagamento em dinheiro nunca entregou.

---

### Risco Operacional: Falha Tecnológica no Dia do Serviço

**Plano B por cenário:**

- **App do prestador offline:** A atendente tem número de trabalho (não pessoal) do prestador para casos de falha. O prestador tem o número de WhatsApp da empresa. A empresa (não o prestador) contata o cliente.
- **Cliente não recebe notificação "a caminho":** Sistema de notificação de backup (SMS ou WhatsApp via API da empresa) dispara automaticamente quando o prestador marca "a caminho" no app.
- **Falha no pagamento:** Manter Pix manual como fallback. O prestador instrui o cliente: "Se o pagamento pelo app não funcionar, faça Pix para este número [CNPJ da Cleanox]." Nunca para o número pessoal do prestador.
- **Prestador não aparece:** Botão "Prestador não chegou" para o cliente acionar a partir de 15 minutos do horário combinado. Dispara alerta imediato para a atendente e para o dono.

**Protocolo de SLA:** Toda falha que impacte o cliente deve gerar contato humano da empresa em até 10 minutos.

---

## 6. RECOMENDAÇÕES DE DESIGN DE ALTO NÍVEL

### Estratégia mobile-first por ator

**Cliente final — PWA como MVP, app nativo em V2**
O cliente já tem o comportamento de acessar via link (WhatsApp, anúncio, e-mail). Forçar download de app antes de ver o serviço é atrito desnecessário. A estratégia correta para MVP é uma PWA que pode ser adicionada à tela inicial do celular, carrega rápido e pode receber notificações push.

Gatilho para app nativo: quando o cliente chegar ao terceiro serviço contratado, oferecer download do app com benefício concreto (5% de desconto no próximo agendamento via app).

**Atendente / SDR — painel web responsivo, desktop como primário**
Interface de gestão de agenda com múltiplas colunas visíveis simultaneamente. Painel estilo kanban com colunas por status (a confirmar / confirmado / a caminho / em andamento / finalizado).

**Prestador — app nativo Android (obrigatório), iOS secundário**
App nativo por três razões: notificações push confiáveis, GPS em segundo plano e funcionamento com dados limitados.

Telas do app do prestador:
1. Tela inicial: job do dia (data, horário, tipo de serviço, bairro)
2. Botão "A caminho"
3. Botão "Iniciei o serviço"
4. Botão "Finalizei" + foto antes/depois
5. Confirmação de recebimento de pagamento

O onboarding do app deve ter no máximo 4 telas. Deve ser feito presencialmente pela atendente ou por um vídeo curto de 90 segundos no WhatsApp.

**Dono / Admin — painel web desktop com dashboard em tempo real**
Mapa com posição de todos os prestadores, lista de jobs do dia com status, alertas de atraso, métricas de faturamento diário e mensal, taxa de recompra e NPS. Pode ser desenvolvido sobre Metabase para o MVP.

---

### Papel do WhatsApp na jornada

O WhatsApp não deve ser eliminado — deve ser reposicionado como canal de entrada e comunicação de emergência.

| Etapa | Canal atual | Canal recomendado |
|---|---|---|
| Geração de lead | WhatsApp | Continua |
| Primeiro atendimento | WhatsApp | WhatsApp + bot de qualificação |
| Confirmação de agendamento | WhatsApp texto | Link para a plataforma via WhatsApp |
| Notificação "a caminho" | WhatsApp do prestador | App/SMS da plataforma (WhatsApp como fallback) |
| Pagamento | Pix avulso | Link Pix da Cleanox via WhatsApp |
| Pós-serviço | Nada | Mensagem automática com link de avaliação |

**Bot de qualificação:** bot simples no WhatsApp Business API que recebe o lead, pergunta "o que você quer higienizar?" com botões (carro / sofá / colchão / outro), captura o CEP para verificar cobertura e agenda resposta humana com informações já preenchidas. Isso elimina o loop manual da atendente e reduz o tempo de primeira resposta de minutos para segundos.

---

### Arquitetura de comunicação

**MVP (0-6 meses):** Rastreamento GPS com botão "A caminho" + notificação push/SMS para o cliente. Isso elimina a necessidade de comunicação direta para o caso mais comum.

**V2 (6-12 meses):** Chat in-app com histórico completo, mediado pela empresa.

**Nunca implementar:** Número virtual mascarado via WhatsApp — custo operacional e complexidade técnica (WhatsApp não permite número virtual facilmente no Brasil sem Meta Business API verificada) não justificam.

---

### Fluxo de pagamento recomendado

**MVP:**
1. Prestador aperta "Finalizar serviço" no app
2. App gera automaticamente link de pagamento Pix para o CNPJ da Cleanox com o valor do job
3. Link enviado via WhatsApp Business da Cleanox para o cliente
4. Cliente paga pelo Pix como sempre fez, mas para o CNPJ da empresa
5. Plataforma detecta o pagamento (via webhook da API bancária) e libera o repasse para o prestador
6. Repasse acontece via Pix para o CPF/CNPJ do prestador — mesmo dia (D+0) ou até às 18h

**V2:**
- Cartão de crédito via link de pagamento (Stripe, MercadoPago, Asaas)
- Pré-autorização para clientes recorrentes
- Split automático: a plataforma recebe o total e repassa o percentual do prestador instantaneamente

**Regra de ouro:** O prestador nunca deve saber quanto o cliente pagou no total — apenas o valor do repasse que ele recebe.

---

### Onboarding do prestador sem resistência

**Princípio central:** O prestador não pode sentir que está perdendo algo. O onboarding deve ser enquadrado como "a empresa resolveu várias coisas que você tinha que fazer na mão."

**Sequência:**
- **Semana 1:** Apresentação por vídeo WhatsApp (3 minutos): "Baixe o app, veja como funciona. A partir de agora, você recebe todos os jobs organizados aqui, com horário, endereço e o que precisa fazer."
- **Semana 2:** Primeiro job pelo app com acompanhamento em tempo real pela atendente.
- **Semana 3:** Introdução ao repasse: "Agora o pagamento vai ser pelo app — você recebe no mesmo dia via Pix."
- **Semana 4:** Avaliações e gamificação: "Quanto mais estrelas você recebe, mais jobs aparecem para você."

**Red flags de resistência a monitorar:** Prestador que não usa o botão "A caminho" em nenhum job; prestador com taxa de cancelamento no app alta; prestador com reclamações de clientes sobre pagamento diferente do acordado.

---

## 7. PERGUNTAS ABERTAS DE PESQUISA

### Tema: Clientes

1. Qual é a taxa atual de clientes que retornam para um segundo serviço, e em qual canal eles retornam (WhatsApp da empresa, WhatsApp do prestador diretamente, orgânico)? Esse dado revela o tamanho real do problema de desvio.

2. Qual é o motivo declarado pelos clientes para não terem retornado? (Preço alto, serviço insatisfatório, passaram a contratar o prestador diretamente, simplesmente esqueceram?) Define se o problema principal é retenção ou desvio.

3. Em quais momentos da jornada atual o cliente demonstra mais hesitação ou abandono? Existe algum dado de analytics do cotador mostrando onde os usuários saem sem completar o orçamento?

4. O cliente atual está disposto a pagar pelo link de Pix para o CNPJ da empresa, ou existe resistência ("prefiro pagar diretamente")? Precisa ser testado com 5 a 10 clientes antes de implementar.

5. Qual é a percepção do cliente sobre a segurança de receber um prestador em casa? Há clientes que recusam o serviço por segurança? Isso orienta o quanto a verificação de identidade do prestador precisa ser comunicada.

### Tema: Prestadores

6. Dos prestadores atuais, quantos têm smartphone com espaço suficiente para instalar um app (acima de 2 GB livres) e dados móveis contratados? Sem essa informação, não é possível definir se o app nativo é viável ou se precisa de uma versão ultra-leve.

7. Alguma prestadora atual já tem clientes próprios captados dentro do trabalho com a Cleanox? Se sim, quantos e em que frequência? Este é o dado mais crítico de risco operacional.

8. Qual é o nível de conforto das prestadoras com apps de trabalho? Alguma usa app de outros serviços (iFood entregadora, app de diarista, Parafuzo)? Quem já usou outros apps tem curva de aprendizado muito menor.

9. O que as prestadoras fazem quando um cliente pergunta o número delas durante o serviço? Qual é o comportamento real atual, antes de qualquer mudança de sistema?

### Tema: Operação

10. Qual é o volume médio de agendamentos por semana, por dia da semana e por horário? Fundamental para dimensionar o sistema de calendário e evitar bottlenecks de disponibilidade de prestadores.

11. Qual é a taxa de cancelamento ou não-comparecimento do prestador e do cliente? Cancelamentos de última hora são o maior custo oculto da operação.

12. Quanto tempo em média a atendente gasta por agendamento fechado (do primeiro contato até a confirmação)? Define o ROI de automatizar as etapas do funil.

### Tema: Financeiro

13. Qual é o ticket médio atual e a margem operacional por serviço, considerando CAC via tráfego pago, comissão da atendente e repasse ao prestador? Sem esse número não é possível decidir se o custo da plataforma é viável no modelo de preço atual.

14. Qual é o percentual de repasse atual para o prestador e como ele é calculado? O modelo de split automático precisa replicar exatamente essa lógica ou ter uma proposta de renegociação clara.

15. O negócio tem volume suficiente para justificar uma integração com gateway de pagamento (mínimo de 50 transações/mês para que as taxas sejam absorvíveis)? Abaixo desse volume, um link de pagamento manual via WhatsApp Pay ou MercadoPago pode ser mais eficiente que uma integração própria.

---

## Nota metodológica

Este documento foi produzido com base em pesquisa secundária (análise do produto atual, benchmarks de mercado, literatura sobre plataformas de serviços sob demanda no Brasil) combinada com análise inferencial do modelo operacional descrito. As personas e jornadas representam hipóteses fundamentadas que precisam ser validadas com pesquisa primária: idealmente, 5 entrevistas em profundidade com clientes reais, 3 entrevistas com prestadoras e 2 sessões de observação de um job completo (shadowing). O documento deve ser tratado como ponto de partida para validação, não como verdade definitiva.

---

*Os pontos de maior urgência para decisão imediata são: (1) definir o modelo de pagamento centralizado e quando começa a transição, (2) escolher entre app nativo ou PWA para o prestador como decisão de stack, e (3) mapear quantas prestadoras já têm clientes desviados para mensurar o tamanho real do problema antes de qualquer anúncio interno sobre a plataforma.*
