/**
 * lancamentos/icons.tsx — ícones locais usados SÓ pela tela de Lançamentos
 * (kebab, copiar, link externo). Stroke 24×24, mesma convenção do KIT/ui.
 * Mantidos aqui para não tocar em components/ui/Icon (fora do escopo desta pane).
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

/** Três pontos verticais — menu de contexto (kebab) da linha. */
export function IconDots({ size, className }: IconProps) {
  return (
    <Svg size={size} className={className}>
      <circle cx="12" cy="5" r="1.4" />
      <circle cx="12" cy="12" r="1.4" />
      <circle cx="12" cy="19" r="1.4" />
    </Svg>
  )
}

/** Copiar / duplicar. */
export function IconCopy({ size, className }: IconProps) {
  return (
    <Svg size={size} className={className}>
      <rect x="9" y="9" width="11" height="11" rx="2" />
      <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
    </Svg>
  )
}

/** Abrir vínculo externo (Ver OS ↗). */
export function IconExternalLink({ size, className }: IconProps) {
  return (
    <Svg size={size} className={className}>
      <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
      <polyline points="15 3 21 3 21 9" />
      <line x1="10" y1="14" x2="21" y2="3" />
    </Svg>
  )
}

/** Repetir (próxima ocorrência) — seta circular. */
export function IconRepeat({ size, className }: IconProps) {
  return (
    <Svg size={size} className={className}>
      <polyline points="17 1 21 5 17 9" />
      <path d="M3 11V9a4 4 0 0 1 4-4h14" />
      <polyline points="7 23 3 19 7 15" />
      <path d="M21 13v2a4 4 0 0 1-4 4H3" />
    </Svg>
  )
}

/** Anexo / clipe. */
export function IconPaperclip({ size, className }: IconProps) {
  return (
    <Svg size={size} className={className}>
      <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48" />
    </Svg>
  )
}
