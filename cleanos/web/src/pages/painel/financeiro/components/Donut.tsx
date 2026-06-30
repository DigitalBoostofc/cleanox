/**
 * Donut — gráfico de rosca SVG hand-rolled, discreto e sem dependência.
 * Cada fatia é um segmento de stroke num anel; o "vazado" é natural do anel.
 * Sem dados → anel cinza com "Sem dados". Acessível via aria-label resumido.
 */

export interface DonutDatum {
  label: string
  value: number
  color: string
}

export interface DonutProps {
  data: DonutDatum[]
  size?: number
  centerLabel?: string
  centerValue?: string
}

export function Donut({ data, size = 140, centerLabel, centerValue }: DonutProps) {
  const stroke = Math.max(12, Math.round(size * 0.14))
  const r = (size - stroke) / 2
  const cx = size / 2
  const cy = size / 2
  const circumference = 2 * Math.PI * r

  const positives = data.filter((d) => d.value > 0)
  const total = positives.reduce((sum, d) => sum + d.value, 0)
  const hasData = total > 0

  const ariaLabel = hasData
    ? `Gráfico de rosca: ${positives
        .map((d) => `${d.label} ${Math.round((d.value / total) * 100)}%`)
        .join(', ')}`
    : 'Gráfico de rosca sem dados'

  let offset = 0

  return (
    <svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      className="fin-donut"
      role="img"
      aria-label={ariaLabel}
    >
      <circle cx={cx} cy={cy} r={r} fill="none" stroke="var(--clx-fin-track)" strokeWidth={stroke} />

      {hasData &&
        positives.map((d, i) => {
          const dash = (d.value / total) * circumference
          const seg = (
            <circle
              key={i}
              cx={cx}
              cy={cy}
              r={r}
              fill="none"
              stroke={d.color}
              strokeWidth={stroke}
              strokeDasharray={`${dash} ${circumference - dash}`}
              strokeDashoffset={-offset}
              transform={`rotate(-90 ${cx} ${cy})`}
            />
          )
          offset += dash
          return seg
        })}

      {hasData && centerValue && (
        <text
          x={cx}
          y={centerLabel ? cy - 1 : cy + 5}
          textAnchor="middle"
          className="fin-donut-center-value"
        >
          {centerValue}
        </text>
      )}
      {hasData && centerLabel && (
        <text
          x={cx}
          y={centerValue ? cy + 14 : cy + 4}
          textAnchor="middle"
          className="fin-donut-center-label"
        >
          {centerLabel}
        </text>
      )}
      {!hasData && (
        <text x={cx} y={cy + 4} textAnchor="middle" className="fin-donut-center-label">
          Sem dados
        </text>
      )}
    </svg>
  )
}

export default Donut
