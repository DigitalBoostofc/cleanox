/**
 * Ícones locais das telas Contas a pagar/receber (PANE FIN-B4).
 * Apenas os glifos que não existem no Icon.tsx compartilhado nem no KIT
 * (`../components`). Os componentes visuais (chips, KPI, ícone de categoria,
 * badge de conta) vêm do KIT.
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

/** Seta para baixo em círculo — saídas / a pagar. */
export function IconArrowDownCircle(p: IconProps) {
  return (
    <Svg {...p}>
      <circle cx="12" cy="12" r="10" />
      <polyline points="8 12 12 16 16 12" />
      <line x1="12" y1="8" x2="12" y2="16" />
    </Svg>
  )
}

/** Seta para cima em círculo — entradas / a receber. */
export function IconArrowUpCircle(p: IconProps) {
  return (
    <Svg {...p}>
      <circle cx="12" cy="12" r="10" />
      <polyline points="16 12 12 8 8 12" />
      <line x1="12" y1="16" x2="12" y2="8" />
    </Svg>
  )
}

/** Relógio — vencendo hoje. */
export function IconClock(p: IconProps) {
  return (
    <Svg {...p}>
      <circle cx="12" cy="12" r="10" />
      <polyline points="12 6 12 12 16 14" />
    </Svg>
  )
}

/** Funil — filtros. */
export function IconFunnel(p: IconProps) {
  return (
    <Svg {...p}>
      <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3" />
    </Svg>
  )
}

/** Kebab (3 pontos verticais) — menu de ações. */
export function IconMore(p: IconProps) {
  return (
    <svg
      width={p.size ?? 18}
      height={p.size ?? 18}
      viewBox="0 0 24 24"
      fill="currentColor"
      stroke="none"
      className={p.className}
      aria-hidden="true"
    >
      <circle cx="12" cy="5" r="1.6" />
      <circle cx="12" cy="12" r="1.6" />
      <circle cx="12" cy="19" r="1.6" />
    </svg>
  )
}
