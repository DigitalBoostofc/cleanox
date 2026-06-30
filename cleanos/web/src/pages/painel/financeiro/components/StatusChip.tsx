/**
 * StatusChip — chip do status do lançamento.
 * Cor via statusTone (pago→success, pendente→warning, previsto→info, em_atraso→error).
 */

import type { LancamentoStatus } from '../../../../lib/financeiro/types'
import { statusLabel, statusTone } from '../../../../lib/financeiro/labels'

export interface StatusChipProps {
  status: LancamentoStatus
}

export function StatusChip({ status }: StatusChipProps) {
  const tone = statusTone(status)
  return <span className={`clx-chip clx-chip-${tone}`}>{statusLabel(status)}</span>
}

export default StatusChip
