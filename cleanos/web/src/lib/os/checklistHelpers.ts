import type { ChecklistExecItem } from '../servicos/types'

/** Retorna true se algum item obrigatório ainda não foi concluído. */
export function temObrigatoriosPendentes(items: ChecklistExecItem[]): boolean {
  return items.some((it) => it.obrigatorio && it.status !== 'concluido')
}
