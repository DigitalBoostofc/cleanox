# Excluir Ordem de Serviço — Design

**Data:** 2026-07-16 · **Decisor:** dono (via sessão de brainstorm)

## Objetivo

Dar ao painel (admin/gerente) a opção de **excluir definitivamente** uma OS —
qualquer status, **inclusive concluída** — sem deixar lixo financeiro nem
quebrar no banco.

## Decisões do dono

1. **Escopo:** qualquer OS pode ser excluída, inclusive concluída (com estorno
   automático de receita e comissão).
2. **Permissão:** admin e gerente (a `deleteRule = ADMIN_GERENTE` já existente
   permanece; nenhuma migration).

## Estado medido (por que não dá pra só chamar delete)

- `ordens_servico.deleteRule = ADMIN_GERENTE` já em produção; profissional negado.
- `OrdensRepository.delete()` já implementado no Flutter, sem UI que o use.
- `os_evidencias.os` tem `cascadeDelete: true` → fotos somem junto (ok).
- `prof_comissoes.os` é `required: true` + `cascadeDelete: false` → deletar OS
  concluída **falha no banco** enquanto a comissão existir (mesma armadilha do
  prof_delete).
- `fin_lancamentos` referencia a OS por **texto** (`os_id`) → deletar OS
  concluída com receita paga deixaria receita órfã e **saldo inflado**.

## Solução (abordagem A — hook de modelo)

### Backend — `cleanos/pb/pb_hooks/`

Novo par no padrão `prof_delete`:

- **`os_delete_lib.js`** (CommonJS, testável fora do PB):
  - `apagarReceitasDaOs(app, osId)` — apaga TODO `fin_lancamentos` com
    `os_id = {osId} && origem = 'via_os'`, **qualquer status (inclusive pago)**.
    O delete de cada lançamento dispara o hook `fin_saldo` (onRecordDelete em
    `fin_lancamentos`), que estorna o saldo atomicamente — este lib **nunca**
    toca em `fin_contas.saldo_atual` (R1). Erro aqui **propaga** (aborta a
    exclusão da OS antes de qualquer outro efeito).
  - `handleDelete(app, record, next)` — ordem crítica (R3: tudo ANTES de
    `next()`, que comita):
    1. `apagarReceitasDaOs` (falha → throw, OS intacta);
    2. `removerComissoesDaOs` (reusa `prof_comissao_lib`; remove comissão +
       despesa ligada com estorno; sem isso `next()` falharia na relação
       required sem cascade);
    3. `next()` apaga a OS; evidências caem por cascade.
- **`os_delete.pb.js`** — registra `onRecordDelete(..., "ordens_servico")`
  chamando o lib via `require()` (R9). Vale para API e Admin UI.

Sem migration. Sem mudança de regra.

### Flutter — `cleanos/flutter/lib/painel/ordens/`

- `ordens_controller.dart`: `Future<void> excluir(String osId)` →
  `ordensRepositoryProvider.delete(osId)` + `refresh()`.
- `os_detail.dart`: botão **"Excluir OS"** (variant danger, visível em qualquer
  status) ao lado de "Cancelar OS", com dialog de confirmação:
  - OS concluída: avisa que a receita será removida do caixa (saldo estornado),
    a comissão do profissional apagada e as fotos excluídas; irreversível.
  - Demais status: avisa que OS e evidências serão excluídas; irreversível.
  - Sucesso → toast + `ref.invalidate(ordensCountsProvider)` + fecha o detalhe
    com `changed: true`. Erro → toast de falha (servidor é a linha de defesa).
- Sem checagem de papel na UI: o painel já é restrito a admin/gerente e a
  `deleteRule` barra o resto (regra de ouro nº 1).

### Testes

- `cleanos/tests/integration/os_delete.unit.test.mjs` (entra no CI
  `hooks-tests.yml`): receita paga é apagada antes de `next()`; comissão
  removida antes de `next()`; `next()` chamado 1x; OS sem dependências →
  `next()` direto; falha na receita → não chama `next()`; lib nunca escreve em
  `fin_contas`.
- Flutter: teste do controller (`excluir` chama delete + refresh) e/ou do
  dialog de confirmação, no padrão dos testes existentes.

## Alternativas descartadas

- **Rota custom `/api/cleanos/os/{id}/delete`:** Admin UI continuaria órfã;
  duplica autorização que a deleteRule já resolve.
- **Flutter orquestrar múltiplos deletes:** viola "servidor é a única linha de
  defesa" e quebra no meio em falha parcial.

## Fora de escopo

- Excluir OS pelo app do profissional (nunca).
- Lixeira/soft-delete ou desfazer.
- Deploy (R5 — só com ordem do dono).
