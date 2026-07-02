---
name: qa-fix-protocol
description: Protocolo do resolvedor de QA — poll no contrato usability-findings.md, prioridade por severidade, clusters por arquivo, 1 commit por finding com ID, git add específico, validação no dev antes de marcar corrigido. Use sempre que for corrigir findings no QA Vision Lab.
---

# qa-fix-protocol

Você corrige findings do contrato `<workspace>/usability-findings.md`, em loop.

## Seleção (poll)

1. Leia o contrato inteiro.
2. Candidatos = findings `status: aberto`.
3. Prioridade: severidade `alta` > `média` > `baixa`; empate = menor ID.
4. **Clusters por arquivo**: bugs que tocam o MESMO arquivo pertencem ao MESMO
   resolvedor. Se outro resolvedor já está num finding daquele arquivo, pule
   pro próximo candidato. Nunca edite arquivo que outro worker está corrigindo.

## Correção

1. Read antes de Edit — leia o arquivo apontado + call sites + evidência
   (screenshot/trecho) até entender a CAUSA RAIZ. Sintoma ≠ causa.
2. Fix mínimo que resolve o finding. Zero refactor de carona, zero "melhoria"
   em código adjacente.
3. **Valide ANTES de marcar**: typecheck da área + reproduzir o cenário do
   finding no dev server ao vivo (main process do Electron = restart completo;
   renderer = HMR costuma bastar). Olhe o log do dev por erros novos.
   Validação não rodada = finding que volta `reaberto`.

## Commit (1 por finding)

- `git add` SÓ dos arquivos que VOCÊ tocou neste finding — NUNCA `git add -A`,
  NUNCA `git add .`. Arquivo de outro worker no stage = contaminação.
- Mensagem com o ID: `fix(área): F-XXX — resumo do fix`.
- 1 finding = 1 commit. Dois findings no mesmo arquivo = ainda assim commits
  separados, na ordem em que corrigiu.

## Atualização do contrato

Após commit + validação, no finding:

- `status: aberto` → `status: corrigido`
- preencha `- (resolvedor) Correção:` com: causa raiz (1-2 frases), arquivos +
  commit hash, e COMO validou (o que rodou/observou).

## Exceções

- Dúvida de PRODUTO (comportamento esperado ambíguo, decisão de UX/escopo):
  marque `precisa-decisão` + pergunta objetiva no finding e SIGA pro próximo.
  Não decida produto sozinho, não trave.
- 3 tentativas máx na mesma abordagem; na 3ª falha registre o que tentou no
  finding e mude de abordagem ou devolva no handoff.
- Nunca derrube processo que você não subiu (produção pode estar rodando —
  mate dev por PID específico, jamais pkill por nome).

## Handoff (esgotou)

Sem mais `aberto` elegível, ou orçamento do briefing atingido: handoff com IDs
corrigidos + commits, `precisa-decisão` pendentes, clusters restantes.
