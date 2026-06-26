# Cleanox — Pacote de Pré-Projeto e MVP

**Data de referência:** 2026-06-25

Este repositório de documentos é a fonte única de verdade para a fase de descoberta, arquitetura e planejamento do MVP do Cleanox. Reúne pesquisa de mercado, modelagem de negócio, decisões de arquitetura, análise de ameaças, backlog priorizado, fluxos de produto e plano técnico de sprint — tudo produzido antes do início do desenvolvimento para alinhar tecnologia, negócio e compliance em um só lugar.

**Premissa central:** a marca Cleanox é dona do relacionamento com o cliente e do dinheiro; o prestador é um executor anônimo. Nenhum dado de contato (telefone, endereço, e-mail) do cliente é visível ao prestador fora do período estrito de execução do serviço, e nenhum dado do prestador (CPF, Pix, telefone) é visível ao cliente em nenhum momento. O modelo de anti-desintermediação — GPS + botão "a caminho" no lugar de número mascarado — é a principal diferença técnica e operacional que protege a recorrência dentro da plataforma.

---

## Documentos

**👉 COMECE POR AQUI: [MVP-BUILD-SPEC.md](MVP-BUILD-SPEC.md) — o que vamos construir (versão enxuta).**

| # | Arquivo | Conteúdo |
|---|---------|---------|
| 01 | [01-requisitos-negocio.md](01-requisitos-negocio.md) | Requisitos de negócio: objetivos, KPIs, processos AS-IS/TO-BE, matriz de atores, requisitos funcionais MoSCoW, regras de anti-desintermediação |
| 02 | [02-pesquisa-ux.md](02-pesquisa-ux.md) | Pesquisa UX: 4 personas (cliente, atendente, prestador, admin), jornadas end-to-end, análise privacidade vs. usabilidade, benchmark Uber/iFood/GetNinjas, recomendações de design |
| 03 | [03-mercado-prior-art-stack.md](03-mercado-prior-art-stack.md) | Mercado e stack: concorrentes BR e internacionais, padrões de anti-desintermediação, componentes de pagamento/fiscal/geo BR, stack recomendado com estimativas de custo |
| 04 | [04-arquitetura-e-adrs.md](04-arquitetura-e-adrs.md) | Arquitetura: diagrama lógico, modelo de dados conceitual, ADR-001 a ADR-003, tabela de trade-offs, riscos arquiteturais, roadmap em 3 fases |
| 05 | [05-threat-model-seguranca.md](05-threat-model-seguranca.md) | Threat model STRIDE: ativos priorizados, atores de ameaça, análise por fluxo, árvore de ataque anti-desintermediação, LGPD/DPIA inicial, controles MUST/SHOULD/COULD |
| 06 | [06-backlog-mvp.md](06-backlog-mvp.md) | Backlog MVP: escopo IN/OUT, 26 user stories em 9 épicos com Gherkin, tratamento fiscal de autônomo informal, modelo de custo com 3 cenários de split, regras anti-risco-trabalhista, Definition of Done |
| 07 | [07-fluxos-mvp.md](07-fluxos-mvp.md) | Fluxos e telas: wireframes ASCII do PWA cliente, app prestador (Flutter/Android) e painel admin, edge cases e fallbacks por superfície, tabela consolidada de mecânicas anti-desvio |
| 08 | [08-plano-sprint0-tecnico.md](08-plano-sprint0-tecnico.md) | Plano técnico Sprint 0: modelo de dados MVP com DDL, máquina de estados da OS com diagrama Mermaid, contratos de API REST por superfície, integrações de borda (Asaas/FCM/Maps/OTP/storage), token de endereço efêmero, ADR-004, plano de 7 sprints até MVP, checklist de go-live LGPD/segurança/fiscal |

---

> ⚠ **Nota de versão:** o MVP foi simplificado. O documento de verdade para construção é **[MVP-BUILD-SPEC.md](MVP-BUILD-SPEC.md)**. Os documentos 04 (arquitetura) e 08 (plano técnico) registram a exploração inicial mais ampla (com Asaas, Flutter, GPS, split) que foi enxugada — leia-os como histórico/aprofundamento, não como o escopo atual.

---

## Decisões-chave (ADRs)

### ADR-001 — GPS + "A Caminho" como mecanismo principal de anti-desintermediação

**Decisão:** O app do prestador envia localização GPS em tempo real ao cliente enquanto está a caminho e durante a execução. Não há número de telefone mascarado (proxy de voz). A comunicação cliente ↔ prestador passa exclusivamente pela plataforma (push notifications, painel de atendente).

**Motivação:** Número mascarado resolve o problema de comunicação mas expõe o prestador como identidade reconhecível; com GPS o cliente acompanha o serviço sem precisar falar com o prestador diretamente. Custo operacional de proxy de voz (~R$100–300/mês) eliminado.

---

### ADR-002 — Pagamento sem gateway no MVP

**Decisão:** O cliente paga numa MAQUININHA DA EMPRESA (CNPJ da empresa, ex: Stone/PagBank/Cielo); o dinheiro cai na conta da empresa e o prestador nunca o recebe. SEM gateway online, SEM split, SEM link de pagamento. Repasse ao profissional é manual (Pix semanal pelo dono). (Supera a decisão anterior de usar Asaas/split.)

---

### ADR-003 — Stack: PWA React (Vite) para painel + app do profissional; backend PocketBase (Go+SQLite, binário único) numa VPS.

**Decisão:** Frontend é um PWA único em React/Vite que serve o painel (admin/gerente) e o app do profissional (colaborador) por papel — sem app nativo. Backend é PocketBase numa VPS (auth com papéis, API REST/realtime, storage de arquivos e regras de acesso por coleção nativos), atrás de proxy HTTPS, com backup do pb_data. A proteção anti-desvio (profissional não lê telefone/endereço do cliente) é imposta por regras/hooks do PocketBase, não pela UI. (Atualiza ADR-003 anterior: substitui Node/Fastify+PostgreSQL+Redis por PocketBase, e Next.js por React/Vite.)

---

### ADR-004 — Bloqueio de prestador requer revisão humana obrigatória (sem bloqueio automático)

**Decisão:** Nenhum código do sistema bloqueia ou suspende um prestador automaticamente com base em contagem de flags, GPS desligado ou avaliações. O sistema SOMENTE gera alertas e incrementa contadores. O admin humano revisa as evidências e executa a suspensão manualmente via endpoint dedicado (com motivo mínimo de 20 chars e referência ao alert_id).

**Motivação:** Bloqueio algorítmico automático caracteriza subordinação e é evidência de vínculo empregatício em eventual reclamação trabalhista. A decisão de encerrar uma relação comercial com autônomo informal deve ser humana, documentada e justificada — não delegada a um threshold numérico.

---

## Questões-gate abertas (bloqueiam Sprint 1)

As questões abaixo não têm resposta no pacote de pré-projeto e precisam ser resolvidas **antes do início do desenvolvimento** (Sprint 1). Itens marcados como BLOQUEANTE impedem go-live se não respondidos antes do Sprint correspondente.

| # | Questão | Impacto | Urgência |
|---|---------|---------|---------|
| G-01 | **Município de operação do MVP** | Define alíquota ISS (2–5%), código de serviço NFS-e e portal da prefeitura a usar | BLOQUEANTE Sprint 5 |
| G-02 | **Retenções no RPA** — percentuais de INSS e IRRF a reter do repasse ao autônomo informal | Define cálculo do valor líquido ao prestador e o PDF do RPA. Precisa de contador | BLOQUEANTE Sprint 5 |
| G-03 | **Catálogo inicial + preços** — quais serviços (tipos de limpeza) e faixas de preço por tipo; e qual maquininha da empresa será usada (Stone/PagBank/Cielo) e em que conta cai o recebimento | Necessário para exibir preços na PWA e definir o fluxo de recebimento | BLOQUEANTE Sprint 1 |
| G-04 | **Termo de parceria do prestador** — documento revisado por advogado trabalhista | Sem termo assinado, qualquer prestador pode alegar vínculo empregatício | BLOQUEANTE go-live |
| G-05 | **Holdback do repasse** — quantos dias/horas após conclusão o Pix manual é enviado ao prestador | Define frequência e prazo do repasse semanal manual pelo dono | Alta — Sprint 0 |
| G-06 | **Política de cancelamento** — até quando o cliente pode cancelar com reembolso integral | Define fluxo manual do atendente e estorno via maquininha para exceções | Alta — Sprint 1 |

---

*Documento produzido em 2026-06-25 — Cleanox Pacote de Pré-Projeto v1.0*
