/**
 * Ícones locais da tela Categorias financeiras (PANE FIN-B4).
 * Glifos que faltam no Icon.tsx compartilhado e no KIT (`../components`).
 * O ícone de categoria (CategoriaIcon) vem do KIT.
 */

import type { ReactNode } from 'react'

interface IconProps {
  size?: number
  className?: string
}

function Svg({ size = 18, className, children }: IconProps & { children: ReactNode }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      {children}
    </svg>
  )
}

/** Arquivar (caixa). */
export function IconArchive(p: IconProps) {
  return (
    <Svg {...p}>
      <rect x="3" y="3" width="18" height="5" rx="1" />
      <path d="M5 8v11a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8" />
      <line x1="10" y1="12" x2="14" y2="12" />
    </Svg>
  )
}

/** Desarquivar (caixa com seta para cima). */
export function IconArchiveRestore(p: IconProps) {
  return (
    <Svg {...p}>
      <rect x="3" y="3" width="18" height="5" rx="1" />
      <path d="M5 8v11a2 2 0 0 0 2 2h3" />
      <path d="M19 8v3" />
      <path d="M14 17l3-3 3 3" />
      <path d="M17 14v7" />
    </Svg>
  )
}

/** Informação (card de dica). */
export function IconInfo(p: IconProps) {
  return (
    <Svg {...p}>
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="11" x2="12" y2="16" />
      <line x1="12" y1="8" x2="12.01" y2="8" />
    </Svg>
  )
}

/** Lista (resumo). */
export function IconList(p: IconProps) {
  return (
    <Svg {...p}>
      <line x1="8" y1="6" x2="21" y2="6" />
      <line x1="8" y1="12" x2="21" y2="12" />
      <line x1="8" y1="18" x2="21" y2="18" />
      <line x1="3" y1="6" x2="3.01" y2="6" />
      <line x1="3" y1="12" x2="3.01" y2="12" />
      <line x1="3" y1="18" x2="3.01" y2="18" />
    </Svg>
  )
}
