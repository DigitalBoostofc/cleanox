/**
 * financeiro/components/finIcons.tsx — conjunto LOCAL de ícones (stroke 24×24)
 * mapeando os nomes lógicos usados pelas categorias/contas do seed (convenção
 * lucide-react) para SVGs inline. Sem dependência externa.
 *
 * Não cobre todos os nomes possíveis — `hasFinIcon` permite ao chamador decidir
 * o fallback (inicial da categoria / ●). Aliases reaproveitam glifos próximos.
 */

import type { ReactNode } from 'react'

/** Nomes que reaproveitam o glifo de outro nome conhecido. */
const FIN_ICON_ALIASES: Record<string, string> = {
  'user-check': 'user',
  'circle-dashed': 'circle',
}

/** Glifos: cada valor são os filhos de um <svg viewBox="0 0 24 24">. */
const FIN_ICON_PATHS: Record<string, ReactNode> = {
  'spray-can': (
    <>
      <rect x="7" y="9" width="7" height="12" rx="1.2" />
      <path d="M9 9V5h3v4" />
      <path d="M16 4h.01M18.5 5.5h.01M16 7h.01M18.5 8.5h.01" />
    </>
  ),
  'flask-conical': (
    <>
      <path d="M9 3h6" />
      <path d="M10 3v6l-5 9a1 1 0 0 0 .9 1.5h12.2a1 1 0 0 0 .9-1.5l-5-9V3" />
      <path d="M7.5 14h9" />
    </>
  ),
  package: (
    <>
      <path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z" />
      <path d="M4 7.5l8 4.5 8-4.5" />
      <path d="M12 12v9" />
    </>
  ),
  wrench: (
    <path d="M14.7 6.3a3.5 3.5 0 0 0-4.6 4.6l-5.5 5.5a1.6 1.6 0 0 0 2.3 2.3l5.5-5.5a3.5 3.5 0 0 0 4.6-4.6l-2.2 2.2-1.8-.5-.5-1.8z" />
  ),
  cog: (
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 4v2.2M12 17.8V20M4 12h2.2M17.8 12H20M6.3 6.3l1.6 1.6M16.1 16.1l1.6 1.6M17.7 6.3l-1.6 1.6M7.9 16.1l-1.6 1.6" />
    </>
  ),
  plug: (
    <>
      <path d="M9 3v5M15 3v5" />
      <path d="M7 8h10v3a5 5 0 0 1-10 0z" />
      <path d="M12 16v5" />
    </>
  ),
  users: (
    <>
      <path d="M16 19v-1a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v1" />
      <circle cx="9.5" cy="8" r="3" />
      <path d="M21 19v-1a4 4 0 0 0-3-3.9" />
    </>
  ),
  user: (
    <>
      <path d="M19 20v-1a5 5 0 0 0-5-5H10a5 5 0 0 0-5 5v1" />
      <circle cx="12" cy="8" r="3.5" />
    </>
  ),
  'hand-coins': (
    <>
      <circle cx="16" cy="7" r="3" />
      <path d="M3 14.5l4-1 5.5 1.8 4-1.6a1.4 1.4 0 0 1 1.2 2.4L13.5 20l-5-1H3" />
    </>
  ),
  briefcase: (
    <>
      <rect x="3" y="8" width="18" height="12" rx="2" />
      <path d="M8 8V6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
      <path d="M3 13h18" />
    </>
  ),
  landmark: (
    <>
      <path d="M3 21h18" />
      <path d="M5 21V10M9.5 21V10M14.5 21V10M19 21V10" />
      <path d="M12 3l8 5H4z" />
    </>
  ),
  megaphone: (
    <>
      <path d="M4 10v4a1 1 0 0 0 1 1h2l8 4V5L7 9H5a1 1 0 0 0-1 1z" />
      <path d="M18 9.5a3 3 0 0 1 0 5" />
    </>
  ),
  search: (
    <>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </>
  ),
  'thumbs-up': (
    <>
      <path d="M7 11v9H4a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1z" />
      <path d="M7 11l4-7a2 2 0 0 1 3 1.8V9h4.4a2 2 0 0 1 2 2.4l-1.2 6A2 2 0 0 1 18.2 19H7" />
    </>
  ),
  palette: (
    <>
      <path d="M12 3a9 9 0 1 0 0 18c1.1 0 2-.9 2-2 0-.5-.2-.9-.5-1.3-.3-.3-.5-.7-.5-1.2 0-.8.7-1.5 1.5-1.5H17a4 4 0 0 0 4-4c0-4.4-4-8-9-8z" />
      <circle cx="7.5" cy="11.5" r="1" />
      <circle cx="11" cy="7.5" r="1" />
      <circle cx="15" cy="8.5" r="1" />
    </>
  ),
  truck: (
    <>
      <path d="M3 6h11v9H3z" />
      <path d="M14 9h4l3 3v3h-7z" />
      <circle cx="7" cy="18" r="1.6" />
      <circle cx="17" cy="18" r="1.6" />
    </>
  ),
  fuel: (
    <>
      <path d="M5 21V5a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v16" />
      <path d="M3 21h11" />
      <path d="M7 9h3" />
      <path d="M12 9h3a2 2 0 0 1 2 2v5a1.5 1.5 0 0 0 3 0V8.5L17 5.5" />
    </>
  ),
  car: (
    <>
      <path d="M3 13l2-5a2 2 0 0 1 1.9-1.3h10.2A2 2 0 0 1 19 8l2 5v4h-2" />
      <path d="M5 17H3v-4h18" />
      <circle cx="7.5" cy="17" r="1.6" />
      <circle cx="16.5" cy="17" r="1.6" />
      <path d="M9.5 17h5" />
    </>
  ),
  'shopping-cart': (
    <>
      <circle cx="9" cy="20" r="1.5" />
      <circle cx="17" cy="20" r="1.5" />
      <path d="M3 4h2l2.3 11.3a1 1 0 0 0 1 .7h8.2a1 1 0 0 0 1-.8L21 7H6" />
    </>
  ),
  monitor: (
    <>
      <rect x="3" y="4" width="18" height="12" rx="2" />
      <path d="M9 20h6M12 16v4" />
    </>
  ),
  utensils: (
    <>
      <path d="M7 3v8a2 2 0 0 0 4 0V3" />
      <path d="M9 11v10" />
      <path d="M17 3c-1.5 0-2.5 1.6-2.5 4s1 4 2.5 4v10" />
    </>
  ),
  home: (
    <>
      <path d="M4 11l8-7 8 7" />
      <path d="M6 10v10h12V10" />
      <path d="M10 20v-5h4v5" />
    </>
  ),
  calculator: (
    <>
      <rect x="5" y="3" width="14" height="18" rx="2" />
      <path d="M8 7h8" />
      <path d="M8 11h.01M12 11h.01M16 11h.01M8 15h.01M12 15h.01M16 14.5v3" />
    </>
  ),
  banknote: (
    <>
      <rect x="2" y="6" width="20" height="12" rx="2" />
      <circle cx="12" cy="12" r="2.5" />
      <path d="M6 9.5v5M18 9.5v5" />
    </>
  ),
  circle: <circle cx="12" cy="12" r="9" strokeDasharray="3 3" />,
  'piggy-bank': (
    <>
      <path d="M4 12a6 6 0 0 1 6-6h3.5a6 6 0 0 1 5.5 4l1.5.5v3l-1.5.5a6 6 0 0 1-1.5 2V19h-3v-2h-4v2H7v-2.2A6 6 0 0 1 4 12z" />
      <path d="M16.5 11h.01" />
      <path d="M9.5 6l1-2" />
    </>
  ),
  'rotate-ccw': (
    <>
      <path d="M3 12a9 9 0 1 0 2.6-6.3L3 8" />
      <path d="M3 3.5V8h4.5" />
    </>
  ),
  'plus-circle': (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 8v8M8 12h8" />
    </>
  ),
  wallet: (
    <>
      <path d="M4 7a2 2 0 0 1 2-2h11v4" />
      <path d="M3 8h16a1 1 0 0 1 1 1v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
      <circle cx="16.5" cy="13" r="1.1" />
    </>
  ),
  'credit-card': (
    <>
      <rect x="2" y="5" width="20" height="14" rx="2" />
      <path d="M2 10h20M6 15h4" />
    </>
  ),
}

/** Há um glifo local para este nome lógico? */
export function hasFinIcon(name: string | undefined | null): boolean {
  if (!name) return false
  return name in FIN_ICON_PATHS || name in FIN_ICON_ALIASES
}

export interface FinIconProps {
  name: string
  size?: number
  className?: string
}

/** Renderiza o glifo local; retorna `null` quando o nome não é conhecido. */
export function FinIcon({ name, size = 16, className }: FinIconProps) {
  const resolved = FIN_ICON_ALIASES[name] ?? name
  const children = FIN_ICON_PATHS[resolved]
  if (!children) return null
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.9}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      {children}
    </svg>
  )
}

export default FinIcon
