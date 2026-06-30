/**
 * TipoChip — chip do tipo de recorrência (Única / Fixa / Recorrente / Parcelada).
 * Neutro por padrão; serve como rótulo discreto na lista de lançamentos.
 */

import type { RecorrenciaTipo } from '../../../../lib/financeiro/types'
import { recorrenciaLabel } from '../../../../lib/financeiro/labels'

export interface TipoChipProps {
  recorrencia: RecorrenciaTipo
}

export function TipoChip({ recorrencia }: TipoChipProps) {
  return <span className="clx-chip fin-chip-tipo">{recorrenciaLabel(recorrencia)}</span>
}

export default TipoChip
