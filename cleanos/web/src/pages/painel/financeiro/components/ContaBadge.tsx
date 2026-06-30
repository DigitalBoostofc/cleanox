/**
 * ContaBadge — ícone + nome da conta/carteira.
 * Usa o glifo local da conta quando existir; caso contrário, um ponto colorido.
 */

import type { Conta } from '../../../../lib/financeiro/types'
import { FinIcon, hasFinIcon } from './finIcons'

export interface ContaBadgeProps {
  conta: Conta
}

export function ContaBadge({ conta }: ContaBadgeProps) {
  const color = conta.cor ?? '#7A8893'
  const known = hasFinIcon(conta.icone)
  return (
    <span className="clx-chip fin-conta-badge" title={conta.nome}>
      <span className="fin-conta-glyph" style={{ color }} aria-hidden="true">
        {known && conta.icone ? (
          <FinIcon name={conta.icone} size={13} />
        ) : (
          <span className="fin-dot" style={{ background: color }} />
        )}
      </span>
      <span className="fin-conta-name">{conta.nome}</span>
    </span>
  )
}

export default ContaBadge
