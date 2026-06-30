/**
 * FinKpiCard — card de KPI compacto do Financeiro (Entradas, Saídas, Saldo…).
 * Tom controla a cor do valor e do ícone circular. `trend` mostra ↑/↓ colorido;
 * `hint` é uma legenda neutra (ex.: "Disponível em contas").
 */

import type { ReactNode } from 'react'

export type FinKpiTone = 'accent' | 'success' | 'error' | 'info' | 'neutral'

export interface FinKpiCardProps {
  label: string
  value: string
  icon?: ReactNode
  tone?: FinKpiTone
  hint?: string
  trend?: { dir: 'up' | 'down'; text: string }
}

/** tom → classe da cor do valor (.fin-kpi-value.*). 'accent' usa a cor primária. */
const VALUE_TONE_CLASS: Record<FinKpiTone, string> = {
  accent: 'primary',
  success: 'success',
  error: 'error',
  info: 'info',
  neutral: '',
}

export function FinKpiCard({ label, value, icon, tone = 'neutral', hint, trend }: FinKpiCardProps) {
  const valueToneClass = VALUE_TONE_CLASS[tone]
  return (
    <div className="fin-kpi-card">
      {icon != null && (
        <div className={`fin-kpi-icon tone-${tone}`} aria-hidden="true">
          {icon}
        </div>
      )}
      <div className="fin-kpi-content">
        <div className="fin-kpi-label">{label}</div>
        <div className={`fin-kpi-value${valueToneClass ? ` ${valueToneClass}` : ''}`}>{value}</div>
        {trend && (
          <div className={`fin-kpi-delta ${trend.dir}`}>
            <span aria-hidden="true">{trend.dir === 'up' ? '↑' : '↓'}</span> {trend.text}
          </div>
        )}
        {hint && (trend ? <div className="fin-kpi-hint">{hint}</div> : <div className="fin-kpi-delta">{hint}</div>)}
      </div>
    </div>
  )
}

export default FinKpiCard
