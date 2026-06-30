/**
 * Ícones locais do módulo Serviços que ainda não existem no Icon.tsx compartilhado.
 * Mesmo padrão visual (stroke 2, viewBox 24) do design system.
 */

interface IconProps {
  className?: string
  size?: number
}

type SvgProps = React.SVGProps<SVGSVGElement>

function Svg({ size = 18, children, ...props }: SvgProps & { size?: number }) {
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
      aria-hidden="true"
      {...props}
    >
      {children}
    </svg>
  )
}

/** Carro — categoria veicular. */
export function IconCar(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2" />
      <circle cx="7" cy="17" r="2" />
      <path d="M9 17h6" />
      <circle cx="17" cy="17" r="2" />
    </Svg>
  )
}

/** Casa — categoria residencial. */
export function IconHome(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
      <polyline points="9 22 9 12 15 12 15 22" />
    </Svg>
  )
}

/** Duplicar / copiar. */
export function IconCopy(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
      <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
    </Svg>
  )
}

/** Menu de ações (kebab). */
export function IconMoreVertical(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className} fill="currentColor" stroke="none">
      <circle cx="12" cy="5" r="1.6" />
      <circle cx="12" cy="12" r="1.6" />
      <circle cx="12" cy="19" r="1.6" />
    </Svg>
  )
}

/** Handle de arraste (grip). */
export function IconGrip(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className} fill="currentColor" stroke="none">
      <circle cx="9" cy="5" r="1.4" />
      <circle cx="9" cy="12" r="1.4" />
      <circle cx="9" cy="19" r="1.4" />
      <circle cx="15" cy="5" r="1.4" />
      <circle cx="15" cy="12" r="1.4" />
      <circle cx="15" cy="19" r="1.4" />
    </Svg>
  )
}

/** Informação (orientações). */
export function IconInfo(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="11" x2="12" y2="16" />
      <line x1="12" y1="8" x2="12.01" y2="8" />
    </Svg>
  )
}
