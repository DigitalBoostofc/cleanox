/**
 * OrigemChip — chip da origem do lançamento.
 * Via OS → tom info (azul); Manual → neutro.
 */

import type { OrigemLancamento } from '../../../../lib/financeiro/types'
import { origemLabel } from '../../../../lib/financeiro/labels'

export interface OrigemChipProps {
  origem: OrigemLancamento
}

export function OrigemChip({ origem }: OrigemChipProps) {
  const className = origem === 'via_os' ? 'clx-chip clx-chip-info' : 'clx-chip'
  return <span className={className}>{origemLabel(origem)}</span>
}

export default OrigemChip
