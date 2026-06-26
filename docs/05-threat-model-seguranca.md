# Cleanox — Threat Model Inicial & Avaliação de Riscos (Pré-Projeto)

> Escopo: marketplace/plataforma de limpeza residencial a domicílio (Brasil).
> Reviewer: Segurança. Saída: threat model + mapa de riscos + controles. **Não contém código.**
> Premissa central: o adversário primário é um **INSIDER semi-confiável** (o prestador, secundariamente o atendente) tentando **desintermediar a marca** — não um hacker externo. Modelado como tal.
> Escala de severidade: **Crítica / Alta / Média / Baixa** = f(impacto × probabilidade). Probabilidade: Muito Alta / Alta / Média / Baixa.

---

## 0. TL;DR para o dono (leia isto)

1. **A ameaça nº1 é estrutural, não técnica.** O prestador precisa, por definição, ir até a casa do cliente e falar com ele. Nenhum controle de app impede a memória humana, uma câmera externa, um papel, ou uma conversa verbal no local. **A plataforma NÃO consegue tornar o roubo de cliente impossível — consegue torná-lo caro, detectável e contratualmente punível.** Quem prometer 'à prova de roubo' está mentindo.
2. **A defesa real é um sistema de 4 camadas combinadas:** técnica (minimizar exposição) + processual (rodízio, dupla-cega) + contratual (não-concorrência com dente) + **detecção** (anomaly detection de churn pós-1º-serviço por prestador). A camada de detecção é a que mais gera ROI e é a mais subestimada pelos scouts.
3. **O maior risco de compliance NÃO é vazamento — é o conflito LGPD × 'logar tudo'** e a **responsabilidade solidária** do marketplace (CDC + LGPD) combinada com o **risco de vínculo trabalhista** (STF jun/2026). Controles anti-desvio agressivos (bloqueio de tela, rodízio forçado, GPS) aumentam a tese de subordinação. **Há um trade-off direto entre 'controlar o prestador' e 'não parecer empregador'.** Precisa de decisão consciente do dono + jurídico.
4. **Pagamento 100% on-platform com split é o controle financeiro mais importante** — sem ele, nada do resto importa, porque o desvio do dinheiro é trivial.

---

## 1. Ativos a Proteger (priorizados)

| # | Ativo | Por que é valioso | C/I/D* | Impacto se comprometido |
|---|-------|-------------------|--------|--------------------------|
| A1 | **Base de clientes / PII** (nome, telefone, **endereço**, histórico de serviços, frequência, padrão de presença em casa) | É o ativo nº1 da empresa e o alvo do insider. Telefone+endereço+rotina = receita recorrente desviável **e** dado sensível de segurança física do cliente. | **C** alta, I média, D média | Perda de receita recorrente (desintermediação), dano LGPD, risco físico ao cliente (saber quando a casa está vazia) |
| A2 | **Fluxo financeiro** (pagamentos, split, repasses, saldo retido) | Se o dinheiro passa fora da plataforma, a empresa perde a margem **e** o lock-in que sustenta todos os outros controles. | C média, **I alta**, D alta | Desvio de receita, fraude, inviabilidade do modelo |
| A3 | **Reputação / marca** | Marketplace responde solidariamente; um prestador que furta/agride/vaza arrasta a marca. Reviews fake e chantagem também. | I alta, **D média** | Churn em massa, processos, fim do negócio |
| A4 | **Credenciais & sessões** (admin, atendente, prestador, integrações: gateway, WhatsApp BSP, NFS-e, Maps) | Chave-mestra para todos os outros ativos. Token de gateway = dinheiro. | **C crítica**, I alta | Account takeover, fraude financeira, vazamento em massa |
| A5 | **Dados fiscais** (NFS-e, CPF/CNPJ, dados bancários de repasse, KYC) | Obrigação legal (NFS-e set/2026) + dado sensível (KYC, conta bancária) | C alta, I alta | Multa fiscal, fraude de repasse, vazamento KYC |
| A6 | **Integridade dos logs de auditoria** | É a prova em disputa contratual/trabalhista e a base da detecção de desvio | **I crítica**, C média | Sem prova → cláusula contratual vira papel; risco trabalhista |

*C/I/D = Confidencialidade / Integridade / Disponibilidade (qual propriedade importa mais).

**Priorização:** A1 e A2 são co-nº1 (o ataque insider precisa dos dois). A4 é a alavanca técnica de tudo. A6 é silenciosamente crítico — sem log íntegro, a defesa contratual e a detecção não existem.

---

## 2. Atores de Ameaça & Motivações

### Insiders (FOCO)

| Ator | Motivação | Capacidade / Acesso | Perfil |
|------|-----------|---------------------|--------|
| **TA-1 Prestador oportunista** | Ganhar mais cortando a comissão da plataforma; construir clientela própria 'aos poucos' | Acesso físico ao cliente e ao endereço; contato verbal; câmera pessoal; memória | **Principal.** Alta probabilidade, baixa sofisticação, alta legitimidade de acesso |
| **TA-2 Prestador malicioso/planejado** | Sair e virar concorrente levando carteira inteira (cenário que já ocorreu) | Igual + intenção sistemática de coletar dados ao longo de vários serviços | **Crítico.** Menor probabilidade individual, impacto altíssimo |
| **TA-3 Atendente (CLT)** | Vazar/vender base; conluio com prestador; exportar lista ao sair | Acesso amplo a PII para agendar (telefone, endereço de muitos clientes de uma vez) — **pior que o prestador em volume** | **Alto.** Acesso em massa, não 1-a-1 |
| **TA-4 Ex-funcionário** | Vingança; levar base para concorrente; usar credencial não revogada | Credenciais residuais, conhecimento interno, cópias antigas | Alto |
| **TA-5 Admin/Dono comprometido ou desonesto** | (insider threat de topo) ou conta de admin tomada | Acesso total | Baixa prob., impacto total — precisa de controles sobre o próprio admin |

### Externos (secundários, não ignorar)

| Ator | Motivação | Vetor |
|------|-----------|-------|
| TA-6 Fraudador de pagamento | Dinheiro | Chargeback, cartão roubado, prestador-fantasma |
| TA-7 Account takeover | Acesso à conta/dados/saldo | Phishing OTP, SIM-swap, credential stuffing |
| TA-8 Scraper / concorrente | Roubar base via API/app | Enumeração de IDs, abuso de endpoint, app reverse-engineering |
| TA-9 Cliente malicioso | Golpe, chantagem com review, fraude de 'não recebi' | Disputa, extorsão de reembolso |
| TA-10 Atacante de cadeia/integração | Comprometer BSP/gateway/NFS-e | Supply chain, token vazado |

---

## 3. Threat Model Estruturado (STRIDE por fluxo)

> Para cada ameaça: **Vetor · Impacto · Probabilidade · Severidade**.

### Fluxo 1 — Onboarding (prestador, atendente, cliente)

| ID | Ameaça (STRIDE) | Vetor | Impacto | Prob. | Sev. |
|----|------|-------|---------|-------|------|
| F1.1 | **S**poofing — prestador-fantasma | KYC fraca, doc falso, conta laranja para sacar repasse | Fraude de repasse, lavagem | Média | **Alta** |
| F1.2 | **I**nfo disclosure — atendente exporta base ao ser admitido/demitido | Acesso amplo desde o dia 1, sem need-to-know | Vazamento em massa A1 | Alta | **Crítica** |
| F1.3 | **R**epudiation — prestador nega ter aceitado cláusula de não-concorrência | Aceite não logado/sem assinatura forte | Cláusula inexequível | Média | Alta |
| F1.4 | **E**levation — prestador recém-cadastrado recebe acesso a dados além do mínimo | RBAC frouxo | Aumenta superfície de A1 | Média | Média |
| F1.5 | **T**ampering — KYC bypass (foto de foto, deepfake) | Liveness fraca | Prestador-fantasma | Média | Alta |

### Fluxo 2 — Atribuição de OS + Revelação de Endereço (o coração do problema)

| ID | Ameaça | Vetor | Impacto | Prob. | Sev. |
|----|------|-------|---------|-------|------|
| F2.1 | **I** — prestador memoriza/anota endereço+nome para uso futuro | Acesso legítimo ao endereço (precisa para ir lá) | Desintermediação A1 | **Muito Alta** | **Crítica** |
| F2.2 | **I** — prestador fotografa a tela com câmera externa (driblando bloqueio de screenshot) | Câmera de outro celular; bloqueio de screenshot só impede captura interna | Desvio | **Muito Alta** | **Crítica** |
| F2.3 | **I** — endereço 'efêmero' some da tela mas foi exportado/cacheado | Cache do app, root/jailbreak, MITM no app do prestador | Coleta sistemática (TA-2) | Média | **Alta** |
| F2.4 | **T** — manipulação de atribuição para sempre cair com o mesmo cliente | Prestador/atendente em conluio direciona OS | Constrói relação 1-a-1 (precursor de desvio) | Média | Alta |
| F2.5 | **I** — atendente vê endereço de todos os clientes ao agendar | Necessário ao trabalho, mas exportável em massa | Vazamento massa | Alta | **Crítica** |
| F2.6 | **S** — prestador clona app / usa API direto para extrair lista de OS+endereços | Reverse engineering, token de sessão | Scraping da base | Baixa | Alta |

### Fluxo 3 — Comunicação 'a caminho' / no local

| ID | Ameaça | Vetor | Impacto | Prob. | Sev. |
|----|------|-------|---------|-------|------|
| F3.1 | **I** — telefone do cliente exposto via canal mascarado que vaza o número real | Twilio Proxy/BSP mal configurado revela número; ou prestador pede 'me liga no meu pessoal' | Contato direto futuro | Média | **Alta** |
| F3.2 | **I** — prestador combina verbalmente no local ('na próxima me chama direto, sai mais barato') | Conversa presencial — **fora do alcance técnico** | Desintermediação | **Muito Alta** | **Crítica** |
| F3.3 | **I** — número mascarado vira ponte permanente (prestador salva o proxy e reusa) | Proxy não expira após a OS | Canal direto persistente | Média | Alta |
| F3.4 | **R** — mensagens fora da plataforma (sem trilha) | WhatsApp pessoal | Sem prova de desvio | Alta | Alta |

### Fluxo 4 — Pagamento / Split / Repasse

| ID | Ameaça | Vetor | Impacto | Prob. | Sev. |
|----|------|-------|---------|-------|------|
| F4.1 | **I/Repudiation** — prestador pede Pix direto e cancela a OS na plataforma | 'Cancela aí que faço por fora' | Desvio de A2 + A1 | **Muito Alta** | **Crítica** |
| F4.2 | **T** — manipulação do valor de split / dados bancários de repasse | Conta de admin/atendente, ou alteração de conta de repasse via ATO | Desvio financeiro | Baixa | **Alta** |
| F4.3 | **S** — chargeback fraudulento do cliente após serviço prestado | Cliente alega não reconhecer | Prejuízo + risco ao prestador honesto | Média | Média |
| F4.4 | conluio cliente↔prestador para fraudar/cancelar e refazer fora | Ambos ganham cortando a plataforma | Desvio | Alta | **Alta** |
| F4.5 | **Lavagem** / prestador-fantasma para mover dinheiro | OS falsas + saque | Risco regulatório/financeiro | Baixa | Alta |

### Fluxo 5 — Pós-venda

| ID | Ameaça | Vetor | Impacto | Prob. | Sev. |
|----|------|-------|---------|-------|------|
| F5.1 | **I** — prestador faz follow-up direto pós-serviço para fisgar | Já tem nome/rosto/bairro memorizados | Desvio | Alta | **Alta** |
| F5.2 | **T** — manipulação de avaliações (fake reviews, chantagem) | Cliente/prestador | Reputação A3 | Média | Média |
| F5.3 | pesquisa pós-serviço respondida falsamente ('prestador NÃO pediu contato' quando pediu) | Cliente conivenente (F4.4) | Detecção cega | Média | Média |

---

## 4. CENÁRIO PRINCIPAL — 'Como o prestador captura o cliente apesar dos controles'

### Árvore de ataque: OBJETIVO = atender o cliente X por fora, recorrentemente

```
OBJ: Desintermediar o cliente X
├── (1) OBTER identidade/contato do cliente
│   ├── 1a Memorizar nome+endereço durante o serviço .............. [não bloqueável tecnicamente]
│   ├── 1b Fotografar tela com 2º celular ......................... [bloqueio de screenshot NÃO impede]
│   ├── 1c Anotar endereço em papel no caminho .................... [não bloqueável]
│   ├── 1d Pedir telefone ao próprio cliente no local ............. [não bloqueável; só detectável]
│   ├── 1e Extrair via cache/root/MITM do app .................... [bloqueável: técnico]
│   └── 1f Conluio com atendente (que vê tudo) ................... [parcial: RBAC+log+rodízio]
├── (2) ESTABELECER canal direto
│   ├── 2a Combinar verbalmente no local ......................... [não bloqueável; detectável via pesquisa]
│   ├── 2b Salvar número mascarado e reusar ...................... [bloqueável: expirar proxy]
│   └── 2c Dar o próprio cartão/WhatsApp ......................... [não bloqueável; detectável]
└── (3) MOVER o pagamento para fora
    ├── 3a Pedir Pix direto / cancelar OS ........................ [mitigável: cancelamento gera fricção+sinal]
    └── 3b Cliente aceita 'mais barato por fora' ................. [conluio; mitigável por incentivo+detecção]
```

### Mitigação caminho-a-caminho (honesto sobre limites)

| Caminho | Técnico | Processual | Contratual | Detecção |
|--------|---------|-----------|-----------|----------|
| **1a memorizar** | ❌ impossível impedir | **Rodízio de prestadores** (não fixar o mesmo no mesmo cliente) reduz vínculo | Não-concorrência | Anomaly: cliente some após 1º serviço com prestador Y |
| **1b foto de tela externa** | ❌ bloqueio de screenshot inútil contra 2º celular. Paliativo: **mostrar o mínimo, em etapas, e nunca nome+endereço+telefone juntos na mesma tela**; watermark dinâmico com ID do prestador (dissuasão + forense) | Endereço só 'a caminho' / on-arrival | — | Watermark permite atribuir vazamento |
| **1c anotar endereço** | ❌ impossível | Rodízio | NC | Detecção pós-fato |
| **1d pedir telefone ao cliente** | ❌ | Script ao cliente: 'todo contato é pela plataforma' | NC | **Pesquisa pós-serviço** ('o prestador pediu contato direto?') |
| **1e cache/root/MITM** | ✅ **sem cache persistente, cert pinning, detecção de root/jailbreak, criptografia em trânsito e repouso, tokens curtos** | — | — | Alertas de device comprometido |
| **1f conluio atendente** | ✅ **RBAC need-to-know, atendente vê só agenda do dia, mascaramento parcial, sem export em massa** | Segregação de funções, dupla-cega | NC + NDA atendente | **Log imutável de quem viu qual contato**; anomaly de acesso em massa |
| **2a combinar verbal** | ❌ | Cartaz/aviso ao cliente; cultura | NC | Pesquisa pós-serviço + queda de recompra |
| **2b reusar proxy** | ✅ **número mascarado expira ao fim da OS** (Twilio Proxy session TTL) | — | — | Tentativa de uso pós-expiração = sinal |
| **2c dar cartão próprio** | ❌ | — | NC | Pesquisa + denúncia do cliente (incentivada) |
| **3a Pix direto / cancelar** | ✅ **pagamento 100% on-platform; cancelamento com motivo obrigatório + fricção + reputação** | — | NC + penalidade por cancelamento padrão | **Anomaly: alta taxa de cancelamento de um prestador; cliente que cancela e some** |
| **3b cliente aceita por fora** | parcial: **programa de fidelidade/preço que torne a plataforma competitiva** (remove o incentivo econômico) | — | — | Detecção de churn correlacionado a prestador |

### Verdade desconfortável (declare ao dono)
> **Os caminhos 1a, 1c, 1d, 2a, 2c são tecnicamente inimpedíveis.** Um humano na casa de outro humano vai sempre poder conversar e lembrar. A plataforma vence por **economia + detecção + consequência**, não por bloqueio: (i) tornar ficar na plataforma mais barato/cômodo que sair; (ii) **detectar o padrão de desvio** (o sinal mais forte: um cliente que recompra zero depois de um serviço com o prestador Z, repetidamente, é evidência estatística de desvio mesmo sem prova direta); (iii) ter cláusula com **dente** (multa, e prova via log/pesquisa) para tornar o desvio arriscado. **Sem a camada de detecção, as outras três são teatro.**

---

## 5. Privacidade & LGPD — DPIA Inicial

### 5.1 Bases legais (Art. 7º / 11)
| Tratamento | Base legal sugerida |
|-----------|---------------------|
| Cadastro e execução do serviço (PII cliente) | **Execução de contrato** (7º,V) |
| Telefone/endereço para prestador atender | Execução de contrato + **legítimo interesse** (com LIA) para minimização |
| **Logs de acesso a contato (auditoria anti-desvio)** | **Legítimo interesse** (7º,IX) — exige **LIA** documentado e teste de balanceamento |
| KYC / prevenção a fraude | Legítimo interesse + obrigação legal (PLD) |
| NFS-e / fiscal | **Obrigação legal** (7º,II) |
| Marketing/pesquisa pós-venda | Legítimo interesse (transacional) ou **consentimento** (se promocional) |
| Dados bancários repasse / CPF prestador | Execução de contrato + obrigação legal |

### 5.2 Minimização & o conflito 'logar tudo × minimizar'
- **Tensão real:** A6 (auditoria/detecção) quer logar **quem viu qual contato, quando, com que device, geolocalização** — isso é, por si, criação de uma 2ª base sensível (vigilância do prestador) e potencialmente excessiva para o cliente.
- **Resolução recomendada:**
  - Logar **eventos de acesso** (prestador P acessou contato do cliente C às 14h), **não o conteúdo** repetido. O log referencia IDs, não duplica PII.
  - **Retenção diferenciada:** log de auditoria com prazo definido (ex.: o necessário para a janela de detecção + defesa contratual/trabalhista), depois anonimizar/agregar. Documentar o prazo no DPIA.
  - Endereço 'efêmero' na UI ≠ apagado do banco — **deixe claro internamente**: 'efêmero' é controle de exposição, não de retenção. A retenção fiscal (NFS-e) obriga guardar parte por anos.
  - **GPS do prestador**: minimizar — só durante a janela 'a caminho/no local', não tracking contínuo (excesso + reforça tese trabalhista).

### 5.3 Direitos do titular
- Cliente pode pedir acesso/eliminação — mas há **retenção legal** (fiscal) e **legítimo interesse** (fraude) que limitam eliminação. Mapear o que pode/não pode apagar.
- Prestador também é titular: os logs de vigilância sobre ele são dados dele → direito de acesso. Isso colide com manter a detecção secreta. **Decisão consciente:** transparência mínima exigida vs. eficácia da detecção.

### 5.4 Responsabilidade solidária & vínculo trabalhista (riscos cruzados)
- **Solidária (CDC + LGPD Art. 42):** marketplace responde por dano ao cliente (furto, agressão, vazamento por prestador). → exige KYC, seguro, trilha.
- **Vínculo (STF jun/2026):** quanto mais a plataforma **controla o prestador** (rodízio forçado, GPS contínuo, bloqueio de tela, punição por cancelamento, exclusividade), mais se aproxima de **subordinação** → risco trabalhista. **Este é o trade-off mais delicado do projeto:** os controles anti-desvio mais fortes são exatamente os que aumentam o risco trabalhista. Calibrar com jurídico **antes** de implementar.

### 5.5 DPIA — veredito inicial
> Tratamento de **alto risco** (PII em escala + dado de localização/rotina do cliente + monitoramento de trabalhador). **DPIA formal obrigatório** antes do go-live; nomear **encarregado (DPO)**; registrar LIA para os tratamentos de legítimo interesse (auditoria/fraude).

---

## 6. Riscos de Fraude Financeira

| ID | Fraude | Mecanismo | Sev. | Controle-chave |
|----|--------|-----------|------|----------------|
| FF1 | **Pix direto / desvio** | cancela OS, paga por fora | **Crítica** | Pagamento on-platform + fricção/penalidade no cancelamento + detecção |
| FF2 | **Chargeback** | cliente contesta cartão após serviço | Média | Trilha de execução (check-in/out, foto, assinatura), antifraude do gateway, retenção parcial |
| FF3 | **Prestador-fantasma** | conta laranja saca repasses de OS falsas | Alta | KYC/liveness, conta bancária no mesmo CPF, limites/hold no 1º ciclo |
| FF4 | **Conluio cliente↔prestador** | ambos cancelam e refazem fora; ou inflam/forjam OS | Alta | Detecção de padrão (mesma dupla, cancelamentos), incentivo de fidelidade |
| FF5 | **Manipulação de split** | alterar % ou conta de repasse (ATO/admin) | Alta | MFA admin, aprovação dupla p/ mudar dados bancários, log imutável, alerta de mudança |
| FF6 | **Lavagem** | mover dinheiro via OS fictícias | Média | Limites, PLD do gateway, KYC, monitoramento de volume atípico |
| FF7 | **Triangulação de reembolso** | 'não recebi o serviço' + golpe | Média | Prova de execução, política de reembolso, reputação |

---

## 7. Controles Recomendados (priorizados)

### MUST (sem isto o modelo não fecha)
**Técnicos**
- M1. **Pagamento 100% on-platform com split** (Asaas/Pagar.me) + repasse retido por janela. *(mitiga FF1,FF4,F4.1)*
- M2. **Número mascarado com sessão que expira ao fim da OS** (Twilio Proxy/BSP), **telefone real nunca exposto** ao prestador. *(F3.1,F3.3)*
- M3. **RBAC need-to-know:** atendente vê só a agenda operacional; prestador vê o mínimo, em etapas; **endereço revelado só 'a caminho'/on-arrival**; nome parcial. *(F2.1,F2.5,F1.4)*
- M4. **Log imutável (append-only/WORM) de acesso a contato e a PII** — quem, quando, qual cliente, device. Base de A6 e da detecção. *(F2.4,F1.2,F5)*
- M5. **MFA/2FA forte para admin e atendente; OTP para login**; proteção contra SIM-swap no fluxo de OTP (não confiar só em SMS para ações sensíveis). *(A4,TA-7)*
- M6. **Segurança do app do prestador:** sem cache persistente de PII, criptografia em trânsito/repouso, **cert pinning**, detecção de root/jailbreak, tokens de sessão curtos. *(F2.3,F2.6,1e)*
- M7. **Aprovação dupla + alerta para mudança de dados bancários de repasse e de % de split.** *(FF5)*
- M8. **KYC com liveness** no onboarding de prestador; conta de repasse no mesmo CPF/CNPJ. *(F1.1,FF3)*

**Processuais**
- M9. **Segregação de funções** atendente/admin; revogação imediata de acesso no desligamento (offboarding checklist). *(TA-3,TA-4)*
- M10. **Aceite forte e logado** de NDA + não-concorrência (assinatura eletrônica com trilha). *(F1.3)*

**Contratuais**
- M11. **Cláusula de não-concorrência/não-aliciamento com penalidade líquida** e prova via logs/pesquisa. (Validar exequibilidade — autônomo ≠ CLT; calibrar com jurídico vs. risco STF.)

**Detecção**
- M12. **Anomaly detection de desvio:** sinalizar prestador cujos clientes têm **recompra anormalmente baixa após o 1º serviço** (o sinal-ouro); picos de cancelamento; dupla cliente-prestador recorrente; tentativa de uso de proxy expirado. *(cobre os caminhos não-bloqueáveis 1a/1c/2a/3a)*
- M13. **Pesquisa pós-serviço automática:** 'o prestador pediu contato/pagamento direto?' — alimenta M12. *(F3.2,F5.3)*

### SHOULD
- S1. **Watermark dinâmico** (ID do prestador + timestamp) sobre dados na tela — dissuasão + forense para foto externa. *(1b)*
- S2. **Rodízio de prestadores** para não fixar vínculo 1-a-1 — **calibrar contra risco trabalhista** (ver 5.4). *(F2.1)*
- S3. **GPS só na janela 'a caminho/no local'**, não contínuo. *(privacidade + trabalhista)*
- S4. **Programa de fidelidade/preço competitivo** que remova o incentivo econômico de 'fazer por fora'. *(3b)*
- S5. **Rate limiting / detecção de enumeração** nos endpoints de OS e contato (anti-scraping). *(F2.6,TA-8)*
- S6. **Política de cancelamento** com motivo obrigatório, fricção e impacto reputacional. *(F4.1)*
- S7. **Seguro de responsabilidade civil** (cobre A3/solidária).
- S8. **DPO nomeado + DPIA formal + LIA documentado** antes do go-live. *(seção 5)*
- S9. **Hold/limite no primeiro ciclo de repasse** de prestador novo (anti-fantasma/lavagem). *(FF3,FF6)*

### COULD
- C1. Alerta ao cliente: 'pagamentos/contato fora da plataforma não têm garantia/seguro' (educa + reduz conluio).
- C2. Botão de denúncia para o cliente ('me ofereceram serviço por fora') com incentivo.
- C3. Análise de rede/grafo cliente-prestador para flagrar comunidades de desvio.
- C4. Honeytokens / clientes-isca para detectar exfiltração da base.
- C5. DLP no ambiente do atendente (bloquear export/copy em massa do painel).

---

## 8. Riscos Residuais (o dono precisa aceitar conscientemente)

| RR | Risco residual | Por que sobra | Severidade residual | Aceite |
|----|----------------|----------------|---------------------|--------|
| RR1 | **Prestador memoriza/anota e contata o cliente depois** | Acesso físico e memória humana são inimpedíveis | **Alta** → reduzida a **Média** por detecção+contrato | Aceitar; mitigar por M12/M13/M11 |
| RR2 | **Combinação verbal e Pix por fora com cliente conivenente** | Fora do alcance técnico; depende de ambos quererem | **Média** | Aceitar; reduzir incentivo (S4) + detecção |
| RR3 | **Foto de tela com 2º celular** | Bloqueio de screenshot não cobre câmera externa | **Média** | Aceitar; watermark (S1) só dissuade/atribui |
| RR4 | **Trade-off controle × vínculo trabalhista** | Controles fortes ↑ risco de subordinação (STF jun/2026) | **Alta** (jurídico) | **Decisão de negócio:** quanto controle aceitar vs. risco trabalhista — exige jurídico |
| RR5 | **Atendente desonesto com acesso legítimo a volume** | Precisa ver dados para trabalhar | Média | Reduzir por RBAC+log+DLP; resíduo aceito |
| RR6 | **Dependência de terceiros** (gateway, BSP, NFS-e, KYC) | Supply chain fora do controle | Média | Due diligence + contrato + plano de contingência |
| RR7 | **Detecção é probabilística, não prova judicial** | Churn anômalo sugere, não prova, desvio | Média | Combinar com pesquisa/denúncia para formar prova |
| RR8 | **'Efêmero' não é 'apagado'** (retenção fiscal/legal) | Obrigação legal impede eliminação total | Baixa | Documentar no DPIA; comunicar ao titular |

---

## 9. Recomendação de sequência (pré-projeto)
1. **Decisões de negócio/jurídico primeiro** (RR4): definir nível de controle aceitável vs. risco trabalhista; validar exequibilidade da não-concorrência para autônomos.
2. **Fundação técnica MUST**: pagamento on-platform (M1), número mascarado expirável (M2), RBAC+log imutável (M3,M4).
3. **Camada de detecção (M12,M13)** — o maior ROI anti-desvio; começar a coletar sinal desde o dia 1.
4. **DPIA + DPO (S8)** em paralelo, antes do go-live.
5. Iterar SHOULD/COULD conforme dados de detecção revelam onde o desvio realmente acontece.

**Barra atendida:** riscos mapeados com severidade explícita; trade-offs (controle×trabalhista, auditoria×minimização, técnico×inimpedível) declarados abertamente; honestidade sobre o que a tecnologia não resolve.
