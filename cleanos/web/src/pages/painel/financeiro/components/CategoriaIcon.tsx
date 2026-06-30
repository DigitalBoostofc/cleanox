/**
 * CategoriaIcon — círculo colorido com o ícone da categoria.
 * Fundo = cor da categoria (translúcida, harmoniosa); ícone na cor sólida.
 * Sem glifo conhecido → inicial do nome; sem nome → ●.
 */

import type { Categoria } from '../../../../lib/financeiro/types'
import { FinIcon, hasFinIcon } from './finIcons'
import { hexToRgba } from './utils'

export interface CategoriaIconProps {
  categoria?: Categoria
  icone?: string
  cor?: string
  size?: number
}

export function CategoriaIcon({ categoria, icone, cor, size = 32 }: CategoriaIconProps) {
  const name = icone ?? categoria?.icone
  const color = cor ?? categoria?.cor ?? '#7A8893'
  const nome = categoria?.nome ?? ''
  const known = hasFinIcon(name)
  const initial = nome.trim().charAt(0).toUpperCase()
  const bg = hexToRgba(color, 0.16)

  return (
    <span
      className="fin-cat-circle"
      style={{ width: size, height: size, background: bg, color }}
      role="img"
      aria-label={nome || 'Categoria'}
      title={nome || undefined}
    >
      {known && name ? (
        <FinIcon name={name} size={Math.round(size * 0.56)} />
      ) : (
        <span className="fin-cat-initial" style={{ fontSize: Math.round(size * 0.42) }}>
          {initial || '●'}
        </span>
      )}
    </span>
  )
}

export default CategoriaIcon
