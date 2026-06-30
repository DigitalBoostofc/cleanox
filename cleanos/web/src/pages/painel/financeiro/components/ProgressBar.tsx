/**
 * ProgressBar — barra de progresso fina (limites de gasto).
 *
 * `pct` é PERCENTUAL (0–100). O preenchimento visual é limitado a 100%, mas o
 * tom é derivado do valor real: <80 success, 80–100 warning, >100 error.
 * Passe `tone` para forçar a cor.
 */

export interface ProgressBarProps {
  pct: number
  tone?: 'success' | 'warning' | 'error'
}

export function ProgressBar({ pct, tone }: ProgressBarProps) {
  const safe = Number.isFinite(pct) ? pct : 0
  const width = Math.max(0, Math.min(100, safe))
  const resolvedTone = tone ?? (safe > 100 ? 'error' : safe >= 80 ? 'warning' : 'success')
  return (
    <div
      className="fin-progress-bar"
      role="progressbar"
      aria-valuenow={Math.round(safe)}
      aria-valuemin={0}
      aria-valuemax={100}
    >
      <div className={`fin-progress-fill ${resolvedTone}`} style={{ width: `${width}%` }} />
    </div>
  )
}

export default ProgressBar
