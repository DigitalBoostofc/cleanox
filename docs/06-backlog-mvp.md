# CLEANOX — ESCOPO MVP + BACKLOG PRIORIZADO (Sprint 0)
**Data de referência: 25/06/2026 | Volume alvo: <50 OS/mês | Regime de prestadores: autônomo informal**

---

## 1. ESCOPO MVP

### O QUE ENTRA

| # | Item | Justificativa |
|---|------|--------------|
| E01 | Cadastro e autenticação de cliente (PWA) | Ponto de entrada do fluxo; sem isso nada funciona |
| E02 | Cadastro e autenticação de prestador (Flutter/Android) | Idem para o lado operacional |
| E03 | Endereço salvo por cliente (exibição efêmera durante OS ativa) | Proteção anti-desintermediação desde o dia 1 |
| E04 | Catálogo de serviços com preços configuráveis por admin | Base do agendamento e da nota fiscal |
| E05 | Agendamento com seleção de data/hora em slots pré-definidos | Core da jornada; simples o suficiente para volume <50/mês |
| E06 | Atribuição manual de OS pelo atendente/admin | Dispatch automático é overkill em <50 OS/mês |
| E07 | Notificação push ao prestador (nova OS, mudanças) | Comunicação sem expor contato do cliente |
| E08 | Aceite ou recusa de OS pelo prestador (sem penalidade) | Obrigatório para mitigar risco trabalhista |
| E09 | Botão "a caminho" + compartilhamento de GPS em tempo real | ETA sem número mascarado; decisão do dono |
| E10 | Checklist de chegada e conclusão pelo prestador | Gatilho confiável para liberar pagamento |
| E11 | Pagamento pelo cliente via Asaas (PIX ou cartão) | Monetização; mantém dinheiro na plataforma |
| E12 | Split automático via Asaas na confirmação de conclusão | Repasse automático sem intervenção manual |
| E13 | Repasse Pix ao prestador com prazo configurável por admin | Cobre holdback de segurança (ex.: D+1) |
| E14 | Geração de RPA em PDF pré-preenchido (manual no MVP) | Obrigação fiscal p/ autônomo informal; <50/mês é viável manual |
| E15 | NFS-e emitida pela marca (CNPJ da plataforma) | A empresa é prestadora do serviço ao cliente; autônomo é custo |
| E16 | Log imutável de cada acesso a dado de cliente (quem/quando/OS) | Compliance + prova legal anti-desvio |
| E17 | Alerta de recompra anômala para admin (detecção, não bloqueio) | Identificar desvio desde o dia 1; sem bloquear automaticamente |
| E18 | Avaliação pós-serviço pelo cliente (nota + comentário) | Qualidade e insumo de contratação/desligamento |
| E19 | Painel web do atendente: fila de OS, atribuição, status em tempo real | Operação central do MVP |
| E20 | Painel web do admin: configuração de split, preços, prestadores, parâmetros | Parametrização sem deploy; split é variável |

### O QUE FICA DE FORA

| # | Item | Justificativa |
|---|------|--------------|
| F01 | Dispatch automático / algoritmo de matching | Volume <50/mês não justifica a engenharia; manual resolve |
| F02 | Número de telefone mascarado (proxy de voz) | GPS + push cobrem a necessidade no MVP; decisão do dono |
| F03 | App iOS para prestador | Android cobre >90% do público de prestador BR; iOS é pós-MVP |
| F04 | Suporte a MEI / PJ do prestador | Decisão firme: apenas autônomo informal no MVP |
| F05 | Franquias / operação multimarca | MVP monoproduto, 1 CNPJ |
| F06 | Chat in-app entre cliente e atendente ou prestador | Push + status de OS suficientes; chat aumenta superfície de contato direto |
| F07 | Agendamento recorrente / plano de assinatura | Adiciona lógica de renovação e cobrança recorrente; pós-MVP |
| F08 | Integração API para RPA automático (contador) | Operacional manual para <50/mês; integração futura quando escalar |
| F09 | NFS-e via API da prefeitura (automação completa) | Emissão manual no MVP; automatizar quando >50 OS/mês |
| F10 | Programa de fidelidade / pontos / gamificação | Nenhum impacto no problema central do MVP |
| F11 | Programa de indicação / referral | Pós-MVP; CAC gerenciado por tráfego pago no MVP |
| F12 | Analytics / dashboard avançado | Logs básicos suficientes; BI é pós-MVP |
| F13 | Multi-atendente com roles granulares | 1 admin + 1 atendente cobre <50 OS/mês |
| F14 | Multi-município com regras fiscais distintas | MVP opera em 1 município; ISS varia por cidade |
| F15 | Cancelamento e reembolso automatizados | Tratado manualmente pelo admin via Asaas no MVP |
| F16 | Módulo de treinamento / onboarding gamificado para prestador | Onboarding textual simples suficiente para MVP |

---

## 2. BACKLOG PRIORIZADO — USER STORIES

> **Legenda MoSCoW:** M = Must, S = Should, C = Could, W = Won't (MVP)
> **Sequência:** numeração indica ordem sugerida de implementação dentro do épico.

---

### ÉPICO A — Onboarding de Cliente (PWA)

**A-01 [M] — Cadastro de cliente**
> Como cliente, quero criar uma conta informando nome, e-mail e telefone, para acessar a plataforma.

*Critérios de aceite:*
- **Dado** que acesso a PWA pela primeira vez,
  **Quando** preencho nome, e-mail e telefone e confirmo via OTP/link mágico,
  **Então** minha conta é criada e sou redirecionado ao fluxo de agendamento.
- **Dado** que já tenho conta,
  **Quando** tento cadastrar com o mesmo e-mail,
  **Então** recebo aviso "e-mail já cadastrado" e opção de login.
- Telefone é armazenado mas **nunca exibido ao prestador**.

---

**A-02 [M] — Cadastro de endereço de serviço**
> Como cliente, quero salvar meu endereço residencial para agendar serviços sem redigitá-lo.

*Critérios de aceite:*
- **Dado** que estou logado,
  **Quando** adiciono um endereço com CEP, rua, número, complemento e ponto de referência,
  **Então** o endereço fica salvo e disponível no agendamento.
- O endereço completo (número e complemento) só fica visível ao prestador enquanto a OS estiver com status `em_execucao`; fora desse status exibe somente "Rua X, nº XXX — [BAIRRO]".
- Cada exibição do endereço completo ao prestador gera 1 registro no log imutável.

---

**A-03 [M] — Login e recuperação de acesso**
> Como cliente, quero recuperar acesso à minha conta caso perca o login.

*Critérios de aceite:*
- **Dado** que informo meu e-mail cadastrado,
  **Quando** clico em "esqueci o acesso",
  **Então** recebo link mágico no e-mail válido por 15 minutos.

---

### ÉPICO B — Onboarding de Prestador (Flutter/Android)

**B-01 [M] — Cadastro de prestador**
> Como atendente/admin, quero cadastrar um prestador autônomo informal para que ele possa receber e executar OS.

*Critérios de aceite:*
- **Dado** que estou no painel de admin,
  **Quando** preencho nome completo, CPF, telefone pessoal, chave Pix (CPF) e foto de perfil,
  **Então** o prestador é criado com status `pendente_aprovacao`.
- CPF e Pix são armazenados criptografados; visíveis apenas ao admin para fins de RPA/repasse.
- **Não é solicitado CNPJ ou MEI** — campo explicitamente ausente no formulário.

---

**B-02 [M] — App do prestador: primeiro acesso**
> Como prestador, quero fazer login no app com o telefone cadastrado pelo admin para ver minhas OS.

*Critérios de aceite:*
- **Dado** que recebi SMS/WhatsApp com credencial de acesso,
  **Quando** insiro o código no app,
  **Então** acesso minha fila de OS com status e datas.
- Login é via OTP no telefone (sem senha); sessão persiste por 30 dias.

---

**B-03 [S] — Perfil e disponibilidade do prestador**
> Como prestador, quero indicar quais dias da semana estou disponível para receber OS.

*Critérios de aceite:*
- **Dado** que acesso "meu perfil" no app,
  **Quando** marco/desmarco dias disponíveis,
  **Então** o atendente vê minha disponibilidade ao atribuir uma OS.
- Disponibilidade é **informativa** para o atendente — não bloqueia atribuição nem gera penalidade se prestador recusar OS dentro de um dia marcado como disponível.
  *(Mitigação de risco trabalhista: disponibilidade é preferência, não horário obrigatório.)*

---

### ÉPICO C — Agendamento (PWA do Cliente)

**C-01 [M] — Selecionar serviço e slot**
> Como cliente, quero escolher o tipo de serviço e um horário disponível para agendar uma limpeza.

*Critérios de aceite:*
- **Dado** que estou logado e tenho endereço cadastrado,
  **Quando** seleciono serviço (ex.: "Limpeza completa", "Limpeza pós-obra"), data e slot disponível,
  **Então** uma OS é criada com status `aguardando_atribuicao` e recebo confirmação.
- Slots são configurados pelo admin (ex.: "08h–12h", "13h–17h"); cliente não define hora exata.
- Preço exibido é o configurado no catálogo; não há negociação in-app.

---

**C-02 [M] — Confirmação de agendamento e cobrança antecipada**
> Como cliente, quero pagar no ato do agendamento para confirmar minha OS.

*Critérios de aceite:*
- **Dado** que selecionei serviço, data e slot,
  **Quando** escolho PIX ou cartão e confirmo,
  **Então** o pagamento é processado via Asaas, a OS vai a `aguardando_atribuicao` e recebo comprovante por e-mail.
- Falha no pagamento mantém a OS em `aguardando_pagamento`; após 30 min sem pagamento, a OS é cancelada automaticamente.
- **FISCAL:** o valor pago pelo cliente é receita da **marca (CNPJ da plataforma)** — a NFS-e será emitida pela empresa para o cliente.

---

**C-03 [S] — Visualização de status da OS pelo cliente**
> Como cliente, quero acompanhar o status da minha OS em tempo real na PWA.

*Critérios de aceite:*
- **Dado** que tenho uma OS ativa,
  **Quando** acesso "minhas OS",
  **Então** vejo o status atual: `agendada`, `prestador_a_caminho`, `em_execucao`, `concluida`.
- Quando status = `prestador_a_caminho`, exibo mapa com posição do prestador em tempo real.
- Endereço completo do cliente **não é exibido nesta tela** (é do lado do prestador, logado).

---

### ÉPICO D — Atribuição Manual de OS

**D-01 [M] — Fila de OS sem prestador (painel atendente)**
> Como atendente, quero ver todas as OS aguardando atribuição para agir rapidamente.

*Critérios de aceite:*
- **Dado** que acesso o painel,
  **Quando** entro em "Fila de OS",
  **Então** vejo lista de OS com status `aguardando_atribuicao`, ordenadas por data/hora do agendamento.
- Cada linha exibe: serviço, data/slot, bairro (sem número), valor pago.

---

**D-02 [M] — Atribuir prestador a uma OS**
> Como atendente, quero escolher qual prestador vai executar uma OS e notificá-lo.

*Critérios de aceite:*
- **Dado** que seleciono uma OS em `aguardando_atribuicao`,
  **Quando** escolho um prestador da lista (filtrada por disponibilidade informada) e confirmo,
  **Então** a OS passa a `atribuida`, o prestador recebe push com data/hora/bairro/serviço e pode aceitar ou recusar.
- A lista de prestadores exibe: nome, foto, avaliação média, disponibilidade no dia.
- **O endereço completo (número) NÃO é exibido ao prestador nessa tela** — apenas ao aceitar e quando a OS for iniciada.

---

**D-03 [M] — Aceite ou recusa de OS pelo prestador**
> Como prestador, quero poder aceitar ou recusar uma OS sem nenhuma consequência automática por recusar.

*Critérios de aceite:*
- **Dado** que recebi notificação de OS atribuída,
  **Quando** abro o app e vejo os detalhes (data, slot, bairro, serviço, valor de repasse estimado),
  **Então** posso tocar "Aceitar" ou "Recusar".
- Ao recusar, a OS volta a `aguardando_atribuicao` na fila do atendente; **nenhum desconto, punição ou alerta negativo é gerado automaticamente** no perfil do prestador.
  *(Mitigação de risco trabalhista: recusa é direito, não infração.)*
- Atendente recebe notificação interna: "Prestador X recusou a OS #123".

---

**D-04 [S] — Reatribuição de OS**
> Como atendente, quero reatribuir uma OS recusada ou problemática para outro prestador.

*Critérios de aceite:*
- **Dado** que uma OS está em `aguardando_atribuicao` (por recusa ou cancelamento do prestador),
  **Quando** escolho outro prestador e confirmo,
  **Então** o fluxo de aceite/recusa se repete com o novo prestador.

---

### ÉPICO E — Execução + "A Caminho" + GPS

**E-01 [M] — Botão "a caminho" no app do prestador**
> Como prestador, quero indicar que estou a caminho para que o cliente seja notificado e acompanhe minha posição.

*Critérios de aceite:*
- **Dado** que aceitei uma OS e chegou o dia do serviço,
  **Quando** toco "Estou a caminho" no app (habilitado a partir de 60 min antes do slot),
  **Então** a OS vai a `prestador_a_caminho`, o cliente recebe push e pode ver minha posição no mapa.
- Compartilhamento de GPS é ativo enquanto status = `prestador_a_caminho` ou `em_execucao`.
- **Nenhum número de telefone é exibido ao cliente** nessa tela; comunicação é exclusivamente visual (mapa + status).

---

**E-02 [M] — Registrar chegada (check-in)**
> Como prestador, quero registrar minha chegada ao endereço para iniciar a OS formalmente.

*Critérios de aceite:*
- **Dado** que status = `prestador_a_caminho`,
  **Quando** toco "Cheguei" no app (botão habilitado quando GPS do prestador está a ≤300 m do endereço),
  **Então** a OS vai a `em_execucao` e o endereço completo (número + complemento) é revelado no app do prestador.
- O acesso ao endereço completo gera registro no log imutável: `{os_id, prestador_id, timestamp, acao: "endereco_revelado"}`.
- Cliente recebe push: "Prestador chegou! Serviço iniciado."

---

**E-03 [M] — Registrar conclusão (check-out)**
> Como prestador, quero registrar a conclusão do serviço para liberar meu repasse.

*Critérios de aceite:*
- **Dado** que status = `em_execucao`,
  **Quando** marco todos os itens do checklist de conclusão e toco "Serviço concluído",
  **Então** a OS vai a `concluida_aguardando_avaliacao`, o GPS é desativado e o gatilho de split/repasse é disparado.
- Checklist mínimo do MVP: "Ambiente limpo", "Lixo descartado", "Chaves/acesso devolvido".
- Cliente recebe push solicitando avaliação.

---

### ÉPICO F — Pagamento + Split + Repasse RPA

> **TRATAMENTO DE AUTÔNOMO INFORMAL (todas as stories deste épico):**
> O valor pago pelo cliente é 100% receita da **empresa (CNPJ da plataforma)**. O repasse ao prestador é tratado como **custo operacional** e documentado por **RPA (Recibo de Pagamento Autônomo)**. Retenções de INSS (11% — prestador PF, serviço eventual) e IRRF (tabela progressiva mensal; isenção ~R$2.259,20/mês em 2026) devem ser calculadas e sinalizadas. **Alíquotas e thresholds devem ser validados com contador antes do go-live.**

---

**F-01 [M] — Split automático no evento de conclusão**
> Como sistema, quero dividir automaticamente o valor pago entre a conta da empresa e o pool de repasse ao prestador, usando o percentual configurado pelo admin.

*Critérios de aceite:*
- **Dado** que uma OS passa a `concluida_aguardando_avaliacao`,
  **Quando** o sistema processa o evento,
  **Então** o Asaas executa o split: `(100% - split_prestador_pct) → conta plataforma`, `split_prestador_pct → pool de repasse`.
- `split_prestador_pct` é lido do parâmetro global configurável pelo admin; **não é hardcoded**.
- Falha no split gera alerta para admin e não bloqueia o status da OS.

---

**F-02 [M] — Repasse Pix ao prestador**
> Como admin, quero que o sistema dispare automaticamente o Pix de repasse ao prestador após o prazo de holdback configurado.

*Critérios de aceite:*
- **Dado** que o split foi executado com sucesso,
  **Quando** o prazo de holdback (configurável, ex.: D+1) é atingido,
  **Então** o sistema dispara via Asaas o Pix para a chave cadastrada do prestador (CPF) e registra `{os_id, prestador_id, valor_bruto, valor_liquido_apos_retencoes, timestamp}`.
- **Valor líquido = valor bruto − retenção INSS − retenção IRRF** (cálculo configurável; no MVP pode ser valor bruto com flag "retenção a calcular manualmente" até validação com contador).
- Comprovante de Pix é armazenado e vinculado à OS.

---

**F-03 [M] — Geração de RPA em PDF pré-preenchido**
> Como admin, quero gerar o RPA do prestador para a OS concluída, com dados pré-preenchidos, para assinar e arquivar.

*Critérios de aceite:*
- **Dado** que uma OS está em `concluida` e o repasse foi processado,
  **Quando** clico em "Gerar RPA" no painel admin,
  **Então** o sistema gera um PDF com: nome do prestador, CPF, serviço prestado, data, valor bruto, deduções (INSS, IRRF), valor líquido, dados da empresa contratante (CNPJ, razão social).
- O PDF é salvo vinculado à OS e pode ser baixado/impresso.
- **Assinatura é manual** no MVP (impressão + assinatura física, ou envio por e-mail para assinatura eletrônica fora do sistema).
- Sinalização no painel: "RPA gerado — valide alíquotas com seu contador antes de assinar."

---

**F-04 [S] — Histórico financeiro do prestador**
> Como admin, quero ver o histórico de repasses de cada prestador para conferência e geração de RPAs mensais.

*Critérios de aceite:*
- **Dado** que acesso o perfil do prestador no painel,
  **Quando** navego para "Histórico financeiro",
  **Então** vejo lista de OS concluídas, valor bruto, deduções, valor repassado e status do Pix (sucesso/falha).

---

### ÉPICO G — NFS-e

> **PREMISSA FISCAL:** A **empresa (CNPJ da plataforma)** é a prestadora do serviço para o cliente. A NFS-e é emitida pela empresa. O prestador autônomo informal não emite nota — ele é custo da empresa. ISS incide sobre o valor total cobrado ao cliente. Alíquota de ISS varia por município (2–5%) — validar com contador.

---

**G-01 [M] — Emissão manual de NFS-e pela empresa**
> Como admin, quero emitir a NFS-e para o cliente após a conclusão do serviço.

*Critérios de aceite:*
- **Dado** que uma OS está em `concluida`,
  **Quando** acesso a OS no painel e clico em "Emitir NFS-e",
  **Então** o sistema exibe formulário pré-preenchido com: tomador (nome/CPF do cliente), valor, discriminação do serviço, competência.
- No MVP, a emissão é **manual**: admin copia os dados e emite no portal da prefeitura; após isso, registra o número da nota no sistema para vincular à OS.
- Badge visual na OS: "NFS-e pendente" → "NFS-e emitida (nº XXXX)".

---

**G-02 [C] — Envio de link da NFS-e por e-mail ao cliente**
> Como cliente, quero receber minha nota fiscal por e-mail automaticamente após a emissão.

*Critérios de aceite:*
- **Dado** que o admin registrou o número da NFS-e na OS,
  **Quando** clica em "Enviar NFS-e ao cliente",
  **Então** o sistema envia e-mail com o número e link para consulta no portal da prefeitura.

---

### ÉPICO H — Pós-serviço + Detecção de Desvio

**H-01 [M] — Avaliação pós-serviço pelo cliente**
> Como cliente, quero avaliar o serviço com nota e comentário para ajudar na qualidade da plataforma.

*Critérios de aceite:*
- **Dado** que recebi push "Serviço concluído — avalie",
  **Quando** acesso a PWA e toco na notificação,
  **Então** vejo tela com nota (1–5 estrelas) e campo de texto opcional; ao enviar, a avaliação fica vinculada à OS e ao prestador.
- A avaliação é visível apenas ao admin; **não é exibida ao prestador no MVP**.

---

**H-02 [M] — Log imutável de acesso a dados do cliente**
> Como sistema, quero registrar toda vez que dados sensíveis do cliente são acessados, para auditoria e prova legal.

*Critérios de aceite:*
- **Dado** que qualquer ação acessa telefone, endereço completo ou e-mail do cliente,
  **Quando** o acesso ocorre,
  **Então** é registrado: `{timestamp, ator_id, ator_tipo, os_id, dado_acessado, origem_ip}`.
- Registros são imutáveis: nenhum endpoint de DELETE/UPDATE nos logs (append-only).
- Admin pode exportar o log por OS ou por prestador.

---

**H-03 [M] — Detecção de recompra anômala (alerta)**
> Como sistema, quero alertar o admin quando um cliente fica inativo por mais de N dias após um serviço sem novo agendamento na plataforma.

*Critérios de aceite:*
- **Dado** que um cliente teve uma OS concluída,
  **Quando** o sistema detecta que o mesmo cliente não criou nova OS após `limiar_recompra_dias` (configurável, default: 30 dias),
  **Então** gera alerta para admin: "Cliente X não agendou nos últimos 30 dias após o serviço de [data] com [prestador Y] — possível desvio."
- No MVP, o sistema **não bloqueia** nada: apenas alerta. Ação é do admin.
- Parâmetro `limiar_recompra_dias` configurável no painel admin.

---

**H-04 [S] — Bloqueio de exibição do contato do prestador ao cliente**
> Como sistema, quero garantir que em nenhum ponto da jornada o cliente veja o telefone do prestador.

*Critérios de aceite:*
- **Dado** qualquer tela da PWA do cliente,
  **Quando** inspeciono o conteúdo exibido e o payload da API,
  **Então** nenhum campo de telefone, CPF ou e-mail pessoal do prestador está presente — nem no HTML, nem no JSON de resposta.
- Teste de aceite automatizado: varrer respostas de API do cliente por regex de telefone BR e CPF.

---

### ÉPICO I — Painel Admin

**I-01 [M] — Configuração de parâmetros globais**
> Como admin, quero configurar split %, preços de serviços, holdback e limiares de detecção sem precisar de deploy.

*Critérios de aceite:*
- **Dado** que acesso "Configurações" no painel,
  **Quando** altero `split_prestador_pct`, `holdback_dias`, `limiar_recompra_dias` ou preço de qualquer serviço do catálogo,
  **Então** o novo valor entra em vigor para OS criadas a partir daquele momento (OS existentes mantêm o valor original).
- Histórico de alteração de parâmetros é logado (quem alterou, quando, valor anterior, valor novo).

---

**I-02 [M] — Gestão de prestadores**
> Como admin, quero ativar, suspender e visualizar o histórico de OS de cada prestador.

*Critérios de aceite:*
- **Dado** que acesso o perfil de um prestador,
  **Quando** altero o status para "suspenso",
  **Então** o prestador não aparece mais na lista de atribuição e não consegue fazer login no app.
- Suspensão é reversível; histórico de OS e avaliações é mantido.

---

**I-03 [S] — Dashboard operacional básico**
> Como admin, quero ver um resumo do dia: OS agendadas, em execução, concluídas e pendentes de atribuição.

*Critérios de aceite:*
- **Dado** que acesso o painel,
  **Quando** visualizo o dashboard,
  **Então** vejo contadores: `aguardando_atribuicao`, `atribuida`, `prestador_a_caminho`, `em_execucao`, `concluida_hoje`, `repasses_pendentes`.
- Sem filtros avançados no MVP; período fixo = dia corrente.

---

## 3. TRATAMENTO FISCAL DE AUTÔNOMO INFORMAL — TABELA DE REFERÊNCIA

| Situação | Tratamento no MVP |
|----------|------------------|
| Cliente paga o serviço | Receita da empresa (CNPJ da plataforma). Asaas processa em nome da empresa. |
| Nota fiscal para o cliente | NFS-e emitida pela empresa (CNPJ). Serviço = limpeza residencial. ISS s/ valor total. |
| Prestador recebe repasse | Tratado como **custo/despesa** da empresa, não como receita do prestador. |
| Documento do repasse | **RPA (Recibo de Pagamento Autônomo)** por OS ou consolidado mensal. |
| Retenção INSS | 11% sobre o valor bruto do repasse (serviço eventual, sem vínculo). VALIDAR com contador: pode haver dispensa se autônomo contribui por conta própria. |
| Retenção IRRF | Tabela progressiva mensal; isenção ~R$2.259,20/mês (2026). VALIDAR código de retenção para serviço de limpeza. |
| Exclusividade | Proibida — prestador pode trabalhar para terceiros. |
| Controle de jornada | Evitar — horário é slot de preferência, não obrigação contratual. |

> **GATE OBRIGATÓRIO antes do go-live:** contratar contador para validar código tributário municipal do ISS, alíquotas de retenção vigentes e layout do RPA conforme exigências locais.

---

## 4. MINI-MODELO DE CUSTO — DEFINIÇÃO DO SPLIT

### Custos Fixos Mensais (MVP)

| Item | Estimativa |
|------|-----------|
| Infraestrutura (hosting, banco, CDN) | R$ 200–400 |
| Asaas (plano + taxas fixas) | R$ 79–200 |
| SMS / push / e-mail transacional | R$ 50–100 |
| Outros serviços (maps API, storage, monitoramento) | R$ 70–100 |
| **Total infraestrutura** | **~R$ 400–800/mês** |
| Atendente (meio período) | R$ 1.200–2.500/mês |
| CAC tráfego pago (estimado) | R$ 400–800/mês |

**CAC por OS estimado:** gasto em tráfego R$600/mês ÷ 10 novos clientes = R$60 CAC/cliente ÷ 6 OS de LTV = R$10 CAC/OS.

### Taxa Asaas por Transação (variável)

| Modalidade | Taxa estimada |
|-----------|--------------|
| PIX | ~1,2% + R$ 0,49 |
| Cartão de débito | ~1,99% + R$ 0,49 |
| Cartão de crédito à vista | ~2,49% + R$ 0,49 |

### Cenários de Split

| | **Cenário 1 — Conservador** | **Cenário 2 — Base** | **Cenário 3 — Otimista** |
|--|--|--|--|
| Ticket médio | R$ 150 | R$ 200 | R$ 250 |
| Volume OS/mês | 30 | 40 | 50 |
| Split prestador | 68% (R$ 102/OS) | 65% (R$ 130/OS) | 60% (R$ 150/OS) |
| **Receita bruta** | **R$ 4.500** | **R$ 8.000** | **R$ 12.500** |
| Repasse prestadores | R$ 3.060 | R$ 5.200 | R$ 7.500 |
| Taxa Asaas (~1,5% + R$0,49/OS) | R$ 82 | R$ 140 | R$ 212 |
| **Margem bruta plataforma** | **R$ 1.358** | **R$ 2.660** | **R$ 4.788** |
| Infraestrutura | R$ 600 | R$ 600 | R$ 600 |
| Atendente | R$ 2.000 | R$ 2.000 | R$ 2.000 |
| CAC tráfego pago | R$ 600 | R$ 600 | R$ 600 |
| **Resultado líquido** | **-R$ 1.842** | **-R$ 540** | **+R$ 1.588** |

### Leitura dos Cenários

- **Cenário 1 (30 OS, R$150):** Volume de 30 OS/mês não cobre custo fixo com ticket de R$150. Ponto crítico: ou aumenta ticket, ou reduz atendente para custo variável por OS.
- **Cenário 2 (40 OS, R$200):** Ponto de equilíbrio próximo. Split 65% para prestador é competitivo (vs. diarista avulsa que paga transporte e risco de calote). Reduzir atendente para meio período real (~R$1.200) fecha a conta.
- **Cenário 3 (50 OS, R$250):** Margem positiva de ~R$1.600. Sustentável; a partir daqui escala justifica automatizações. Ponto de inflexão para considerar atendente CLT.

### Recomendação para Definição do Split

1. Comece com **split prestador = 65–68%** e **ticket = R$180–220**.
2. Ajuste split para baixo **somente** se o custo do atendente for reduzido ou o volume superar 60 OS/mês.
3. Comunique ao prestador o valor líquido esperado por OS (ex.: "R$117–R$130 por limpeza completa") — transparência reduz risco trabalhista e aumenta retenção.

---

## 5. REGRAS DE NEGÓCIO — MITIGAÇÃO DE RISCO TRABALHISTA

### O que FAZER

- Prestador pode **recusar OS sem consequência automática** (sem desconto, sem rebaixamento de ranking automático, sem aviso punitivo).
- Prestador define sua própria **disponibilidade informativa** (preferências, não obrigações).
- Prestador pode atender **outros clientes e plataformas** (sem exclusividade).
- Contratos de prestação de serviço deixam claro: **relação comercial eventual, não empregatícia**.
- Repasse documentado por **RPA** com retenções legais — formaliza a relação como pagamento a autônomo.
- Prestador recebe repasse por OS concluída, não por hora trabalhada.
- Autonomia técnica preservada: checklist é de **resultado**, não de **método** de trabalho.

### O que NÃO FAZER — e não codificar no produto

| Proibido | Por quê é risco trabalhista |
|----------|----------------------------|
| Horário fixo obrigatório (ex.: "disponível das 8h às 17h") | Controle de jornada = sinal de vínculo empregatício |
| Punição automática por recusar OS (rebaixamento, multa, suspensão automática) | Subordinação + poder disciplinar = vínculo |
| Meta mínima de OS por mês obrigatória | Subordinação econômica + dependência |
| Exclusividade contratual ou prática ("não trabalhe para outros") | Ilegal para autônomo informal; forte sinal de vínculo |
| Controle de GPS do prestador fora do período da OS ativa | Monitoramento de jornada = vínculo |
| Instrução sobre "como" realizar o serviço (método prescrito) | Autonomia técnica é essencial; forneça checklist de resultado, não de processo |
| Alteração unilateral de percentual de repasse sem aviso prévio | Abuso contratual + sinal de subordinação econômica |
| Uniforme com logo obrigatório e exclusivo desde o início | Avaliar com advogado; pode ser indício de subordinação |
| Dedução de "erros" ou avaliações ruins do repasse | Poder disciplinar financeiro = vínculo |

> **RECOMENDAÇÃO:** contratar advogado trabalhista para revisar os termos do contrato de prestação de serviço e o fluxo do produto **antes do go-live**. O risco trabalhista é o maior passivo do modelo neste regime.

---

## 6. DEFINITION OF DONE DO MVP

### KPIs de Saída — medir nas primeiras 4 semanas de operação

| KPI | Meta mínima |
|-----|------------|
| % de OS com pagamento realizado 100% dentro da plataforma | ≥ 95% das OS |
| % de repasses ao prestador feitos no prazo configurado | ≥ 98% sem atraso |
| Número de telefone do cliente exposto ao prestador | 0 incidentes |
| Número de endereços completos acessados fora de OS ativa | 0 incidentes |
| Cobertura de log imutável em acessos a dados sensíveis | 100% das ações rastreadas |
| Tempo médio de atribuição de OS (criação → aceite do prestador) | < 4 horas |
| % de OS com avaliação do cliente preenchida | ≥ 60% |
| Alertas de recompra anômala revisados pelo admin | 100% revisados em < 48h |

### Checklists Técnicos Obrigatórios para Go-Live

- [ ] Fluxo ponta-a-ponta testado end-to-end: agendamento → pagamento → atribuição → aceite → execução → conclusão → repasse → RPA → NFS-e
- [ ] `split_prestador_pct` parametrizado e alterável pelo admin sem deploy
- [ ] Endereço completo do cliente ausente em todos os payloads da PWA fora de OS ativa
- [ ] Log imutável funcionando: append-only, sem endpoint de DELETE/UPDATE
- [ ] RPA em PDF gerado corretamente com campos de retenção (mesmo que valor de retenção seja "a calcular")
- [ ] Alerta de recompra anômala disparando para admin após `limiar_recompra_dias`
- [ ] Prestador consegue recusar OS sem nenhum efeito colateral no perfil
- [ ] Termos de prestação de serviço revisados por advogado trabalhista — assinados pelo prestador antes do primeiro atendimento
- [ ] Alíquotas de INSS/IRRF/ISS validadas com contador
- [ ] NFS-e emitida manualmente para pelo menos 1 OS de teste real no portal da prefeitura
- [ ] Nenhum número de telefone ou CPF do prestador retornado em endpoints da PWA do cliente (teste de segurança básico)

---

## 7. QUESTÕES-GATE REMANESCENTES DO MVP

> Já descartadas: vínculo = autônomo informal ✅ | volume = <50/mês ✅ | split = parâmetro configurável ✅

| # | Questão | Impacto se não respondida antes do go-live | Urgência |
|---|---------|-------------------------------------------|---------|
| G-01 | **Município de operação:** em qual cidade o MVP opera? | ISS varia por cidade (2–5%); alíquota e código de serviço da NFS-e dependem do município. | BLOQUEANTE |
| G-02 | **Holdback de repasse:** quantos dias após a conclusão da OS o repasse é liberado ao prestador? | Define fluxo de caixa e o parâmetro `holdback_dias` default. Recomendado: D+1 a D+2. | Alta |
| G-03 | **Retenções desde o início ou simplificado?** O dono quer calcular INSS/IRRF desde o primeiro RPA ou pagar bruto e ajustar após validação com contador? | Impacta cálculo do RPA e o valor líquido ao prestador. Tem implicação fiscal imediata. | BLOQUEANTE para go-live |
| G-04 | **Catálogo inicial:** quais serviços e quais os preços mínimos e máximos? | Necessário para configurar Asaas, exibir preços na PWA e calcular CAC sustentável. | Alta |
| G-05 | **Canal de comunicação com prestador:** app push nativo (Flutter) é suficiente, ou o dono quer WhatsApp como fallback? | WhatsApp adiciona custo (Twilio/Z-API ~R$100–300/mês) e complexidade de integração. | Alta |
| G-06 | **Política de cancelamento pelo cliente:** até quando pode cancelar com reembolso? 48h antes? 24h? Sem reembolso após confirmação? | Define regra no Asaas (estorno) e o fluxo manual de exceção para o atendente. | Alta |
| G-07 | **Quem assina o RPA físico?** Prestador assina e entrega cópia, ou empresa emite e arquiva unilateralmente? | Impacta o fluxo operacional de coleta de assinatura para <50 RPAs/mês. | Média |
| G-08 | **Plataforma de NFS-e do município:** existe API de emissão, ou é exclusivamente via portal web manual? | Define viabilidade técnica de automação de NFS-e no curto prazo pós-MVP. | Média |
| G-09 | **Atendente é CLT, PJ ou o próprio dono?** | Afeta o custo fixo real no modelo de split e a projeção de ponto de equilíbrio. | Média |
| G-10 | **Critério de suspensão de prestador:** quantas avaliações ruins ou recusas injustificadas antes de suspender? | Sem isso o admin age de forma ad hoc; e a política informal pode virar argumento de subordinação. | Média |

---

*Documento produzido em 25/06/2026 — Sprint 0 Cleanox v1.0*
*Próximo passo: responder as 4 questões BLOQUEANTES (G-01, G-03, G-04, G-05) para iniciar Sprint 1.*
