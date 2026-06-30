/**
 * QuickActions — barra de AÇÕES RÁPIDAS da Visão geral financeira.
 *
 * Reproduz os "Botões rápidos" da spec §3 (Nova receita, Nova despesa,
 * Transferência, Importar): cada ação é um ícone CIRCULAR colorido + label,
 * num layout minimalista e responsivo (envolve para 2×2 em telas estreitas via
 * flex-wrap, sem media queries — o componente é autocontido e não toca o CSS
 * global). Cada cor sai dos tokens --clx-* (claro/escuro) já existentes.
 *
 * Handlers são todos OPCIONAIS. Quando um handler específico não é passado,
 * cai no `onAction(key)` genérico; sem nenhum dos dois, o botão fica PRESENTE
 * porém inerte (desabilitado e marcado para leitores de tela).
 *
 * Acessibilidade: cada ação é um <button type="button"> com aria-label próprio;
 * o grupo é um role="group" rotulado; o foco do teclado usa o anel nativo do
 * navegador (não removemos o outline).
 *
 * É EXPORT DEFAULT de propósito: a Visão geral importa direto de
 * './components/QuickActions' (caminho direto), sem depender do barrel do KIT
 * — assim esta pane não colide com a pane de infra que é dona do index.ts.
 */

import { useState, type CSSProperties, type ReactNode } from 'react'

/** Identificador de cada ação rápida (também usado no callback genérico). */
export type QuickActionKey = 'receita' | 'despesa' | 'transferencia' | 'importar'

export interface QuickActionsProps {
  /** Abre o fluxo de nova RECEITA. */
  onNovaReceita?: () => void
  /** Abre o fluxo de nova DESPESA. */
  onNovaDespesa?: () => void
  /** Abre o fluxo de TRANSFERÊNCIA entre contas. */
  onTransferencia?: () => void
  /** Abre o fluxo de IMPORTAR (extrato/planilha). */
  onImportar?: () => void
  /**
   * Fallback genérico: chamado com a `key` da ação quando o handler específico
   * dela não foi informado. Sem handler específico E sem este, o botão fica inerte.
   */
  onAction?: (action: QuickActionKey) => void
  /** Classe extra opcional no container (para espaçamento na página hospedeira). */
  className?: string
}

/* ------------------------------------------------------------------ *
 * Ícones locais (mesma convenção do components/ui/Icon: viewBox 24,
 * stroke currentColor, strokeWidth 2). Mantidos AQUI para não editar o
 * Icon.tsx compartilhado (outras panes dependem dele).
 * ------------------------------------------------------------------ */

function Svg({ children }: { children: ReactNode }) {
  return (
    <svg
      width={22}
      height={22}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {children}
    </svg>
  )
}

/** Receita → "+" (entrada), alinhado ao sinal usado em labels.signedValue. */
function ReceitaIcon() {
  return (
    <Svg>
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </Svg>
  )
}

/** Despesa → "−" (saída), alinhado ao sinal usado em labels.signedValue. */
function DespesaIcon() {
  return (
    <Svg>
      <line x1="5" y1="12" x2="19" y2="12" />
    </Svg>
  )
}

/** Transferência → setas opostas (troca entre contas). */
function TransferenciaIcon() {
  return (
    <Svg>
      <polyline points="17 1 21 5 17 9" />
      <line x1="21" y1="5" x2="3" y2="5" />
      <polyline points="7 23 3 19 7 15" />
      <line x1="3" y1="19" x2="21" y2="19" />
    </Svg>
  )
}

/** Importar → seta para uma bandeja (trazer dados para dentro). */
function ImportarIcon() {
  return (
    <Svg>
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="7 10 12 15 17 10" />
      <line x1="12" y1="15" x2="12" y2="3" />
    </Svg>
  )
}

/* ------------------------------------------------------------------ *
 * Definição declarativa das ações (label, ícone e tokens de cor).
 * ------------------------------------------------------------------ */

interface ActionDef {
  key: QuickActionKey
  label: string
  icon: ReactNode
  /** Cor de fundo do círculo (token de feedback-bg). */
  bg: string
  /** Cor do ícone (token de feedback). */
  fg: string
}

const ACTIONS: ActionDef[] = [
  { key: 'receita', label: 'Nova receita', icon: <ReceitaIcon />, bg: 'var(--clx-success-bg)', fg: 'var(--clx-success)' },
  { key: 'despesa', label: 'Nova despesa', icon: <DespesaIcon />, bg: 'var(--clx-error-bg)', fg: 'var(--clx-error)' },
  { key: 'transferencia', label: 'Transferência', icon: <TransferenciaIcon />, bg: 'var(--clx-info-bg)', fg: 'var(--clx-info)' },
  { key: 'importar', label: 'Importar', icon: <ImportarIcon />, bg: 'var(--clx-primary-bg)', fg: 'var(--clx-primary)' },
]

/* ------------------------------------------------------------------ *
 * Estilos inline (referenciam tokens --clx-*; nada vai pro CSS global).
 * ------------------------------------------------------------------ */

const rowStyle: CSSProperties = {
  display: 'flex',
  flexWrap: 'wrap',
  gap: 12,
  alignItems: 'stretch',
}

const buttonBaseStyle: CSSProperties = {
  flex: '1 1 72px',
  minWidth: 64,
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  gap: 8,
  padding: '12px 8px',
  border: 'none',
  borderRadius: 'var(--clx-r-lg)',
  background: 'transparent',
  font: 'inherit',
  color: 'var(--clx-ink-2)',
  cursor: 'pointer',
  transition: 'background 160ms var(--clx-ease-out)',
}

const labelStyle: CSSProperties = {
  fontSize: 12.5,
  fontWeight: 600,
  lineHeight: 1.2,
  textAlign: 'center',
}

export default function QuickActions({
  onNovaReceita,
  onNovaDespesa,
  onTransferencia,
  onImportar,
  onAction,
  className,
}: QuickActionsProps) {
  const [hovered, setHovered] = useState<QuickActionKey | null>(null)

  /** Resolve o handler de cada ação: específico → genérico → undefined (inerte). */
  function resolveHandler(key: QuickActionKey): (() => void) | undefined {
    const specific: Record<QuickActionKey, (() => void) | undefined> = {
      receita: onNovaReceita,
      despesa: onNovaDespesa,
      transferencia: onTransferencia,
      importar: onImportar,
    }
    if (specific[key]) return specific[key]
    if (onAction) return () => onAction(key)
    return undefined
  }

  return (
    <div role="group" aria-label="Ações rápidas" className={className} style={rowStyle}>
      {ACTIONS.map((action) => {
        const handler = resolveHandler(action.key)
        const disabled = handler === undefined
        const isHover = hovered === action.key && !disabled

        const circleStyle: CSSProperties = {
          width: 48,
          height: 48,
          borderRadius: 'var(--clx-r-pill)',
          display: 'grid',
          placeItems: 'center',
          background: action.bg,
          color: action.fg,
          transition: 'transform 160ms var(--clx-ease-out)',
          transform: isHover ? 'translateY(-2px)' : 'none',
        }

        return (
          <button
            key={action.key}
            type="button"
            onClick={handler}
            disabled={disabled}
            aria-label={action.label}
            title={action.label}
            onMouseEnter={() => setHovered(action.key)}
            onMouseLeave={() => setHovered((h) => (h === action.key ? null : h))}
            style={{
              ...buttonBaseStyle,
              cursor: disabled ? 'default' : 'pointer',
              opacity: disabled ? 0.55 : 1,
              background: isHover ? 'var(--clx-bg-2)' : 'transparent',
            }}
          >
            <span style={circleStyle}>{action.icon}</span>
            <span style={labelStyle}>{action.label}</span>
          </button>
        )
      })}
    </div>
  )
}
