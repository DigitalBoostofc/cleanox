/**
 * GrupoChip — chip colorido por grupo + ícone da categoria.
 * As cores derivam dos tokens --clx-group-* definidos em tokens.css.
 */

import type { Categoria, Grupo } from '../../../../lib/servicos/types'
import { categoriaLabel, grupoLabel } from '../../../../lib/servicos/labels'
import { IconCar, IconHome } from './icons'

/** Ícone redondo da categoria (carro/casa) usado em tabelas e cards. */
export function CategoriaIcon({ categoria, size = 18 }: { categoria: Categoria; size?: number }) {
  return (
    <span className={`svc-cat-icon svc-cat-${categoria}`} aria-hidden="true">
      {categoria === 'veicular' ? <IconCar size={size} /> : <IconHome size={size} />}
    </span>
  )
}

/** Chip do grupo, colorido conforme o grupo. */
export function GrupoChip({ grupo }: { grupo: Grupo }) {
  return <span className={`clx-chip clx-chip-group-${grupo}`}>{grupoLabel(grupo)}</span>
}

/** Texto "Categoria / <chip grupo>" usado na coluna CATEGORIA/GRUPO. */
export function CategoriaGrupo({ categoria, grupo }: { categoria: Categoria; grupo: Grupo }) {
  return (
    <span className="svc-cat-grp">
      <span className="svc-cat-grp-cat">{categoriaLabel(categoria)} /</span>
      <GrupoChip grupo={grupo} />
    </span>
  )
}
