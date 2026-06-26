/** Ícones SVG inline utilizados no CleanOS (subset mínimo para o scaffold). */

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
      {...props}
    >
      {children}
    </svg>
  )
}

export function IconDashboard(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <rect x="3" y="3" width="7" height="7" rx="1" />
      <rect x="14" y="3" width="7" height="7" rx="1" />
      <rect x="3" y="14" width="7" height="7" rx="1" />
      <rect x="14" y="14" width="7" height="7" rx="1" />
    </Svg>
  )
}

export function IconClientes(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </Svg>
  )
}

export function IconOrdens(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="9" y1="13" x2="15" y2="13" />
      <line x1="9" y1="17" x2="15" y2="17" />
      <line x1="9" y1="9" x2="11" y2="9" />
    </Svg>
  )
}

export function IconAgenda(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
      <line x1="16" y1="2" x2="16" y2="6" />
      <line x1="8" y1="2" x2="8" y2="6" />
      <line x1="3" y1="10" x2="21" y2="10" />
    </Svg>
  )
}

export function IconFinanceiro(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <line x1="12" y1="1" x2="12" y2="23" />
      <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
    </Svg>
  )
}

export function IconUsuarios(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
      <circle cx="12" cy="7" r="4" fill="none" />
      <path d="M12 11 L12 15" strokeDasharray="2 2" />
    </Svg>
  )
}

export function IconMap(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21" />
      <line x1="9" y1="3" x2="9" y2="18" />
      <line x1="15" y1="6" x2="15" y2="21" />
    </Svg>
  )
}

export function IconPerfil(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </Svg>
  )
}

export function IconServices(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <line x1="8" y1="6" x2="21" y2="6" />
      <line x1="8" y1="12" x2="21" y2="12" />
      <line x1="8" y1="18" x2="21" y2="18" />
      <line x1="3" y1="6" x2="3.01" y2="6" />
      <line x1="3" y1="12" x2="3.01" y2="12" />
      <line x1="3" y1="18" x2="3.01" y2="18" />
    </Svg>
  )
}

export function IconLogOut(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <polyline points="16 17 21 12 16 7" />
      <line x1="21" y1="12" x2="9" y2="12" />
    </Svg>
  )
}

export function IconMenu(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <line x1="3" y1="6" x2="21" y2="6" />
      <line x1="3" y1="12" x2="21" y2="12" />
      <line x1="3" y1="18" x2="21" y2="18" />
    </Svg>
  )
}

export function IconX(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <line x1="18" y1="6" x2="6" y2="18" />
      <line x1="6" y1="6" x2="18" y2="18" />
    </Svg>
  )
}

export function IconAlertCircle(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="8" x2="12" y2="12" />
      <line x1="12" y1="16" x2="12.01" y2="16" />
    </Svg>
  )
}

export function IconCheck(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <polyline points="20 6 9 17 4 12" />
    </Svg>
  )
}

export function IconPlus(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </Svg>
  )
}

export function IconEdit(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
      <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
    </Svg>
  )
}

export function IconTrash(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <polyline points="3 6 5 6 21 6" />
      <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
      <path d="M10 11v6" />
      <path d="M14 11v6" />
      <path d="M9 6V4h6v2" />
    </Svg>
  )
}

export function IconChevronLeft(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <polyline points="15 18 9 12 15 6" />
    </Svg>
  )
}

export function IconChevronRight(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <polyline points="9 18 15 12 9 6" />
    </Svg>
  )
}

export function IconSearch(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <circle cx="11" cy="11" r="8" />
      <line x1="21" y1="21" x2="16.65" y2="16.65" />
    </Svg>
  )
}

export function IconEye(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
      <circle cx="12" cy="12" r="3" />
    </Svg>
  )
}

export function IconRefresh(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <polyline points="23 4 23 10 17 10" />
      <polyline points="1 20 1 14 7 14" />
      <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
    </Svg>
  )
}

export function IconDollar(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <line x1="12" y1="1" x2="12" y2="23" />
      <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
    </Svg>
  )
}

export function IconCalendar(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
      <line x1="16" y1="2" x2="16" y2="6" />
      <line x1="8" y1="2" x2="8" y2="6" />
      <line x1="3" y1="10" x2="21" y2="10" />
    </Svg>
  )
}

export function IconUser(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </Svg>
  )
}

export function IconXCircle(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <circle cx="12" cy="12" r="10" />
      <line x1="15" y1="9" x2="9" y2="15" />
      <line x1="9" y1="9" x2="15" y2="15" />
    </Svg>
  )
}

export function IconCheckCircle(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
      <polyline points="22 4 12 14.01 9 11.01" />
    </Svg>
  )
}

export function IconArrowRight(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <line x1="5" y1="12" x2="19" y2="12" />
      <polyline points="12 5 19 12 12 19" />
    </Svg>
  )
}

export function IconLock(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
      <path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </Svg>
  )
}

export function IconWhatsApp(p: IconProps) {
  return (
    <Svg size={p.size} className={p.className}>
      <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z" />
    </Svg>
  )
}
