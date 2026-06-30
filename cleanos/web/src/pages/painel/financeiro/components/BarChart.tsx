/**
 * BarChart — barras agrupadas (fluxo de caixa: Receitas / Despesas / Lucro).
 * SVG hand-rolled com viewBox responsivo (largura 100% via CSS) e linha de base
 * no zero (suporta lucro/prejuízo negativo). Legenda embutida e discreta.
 */

export interface BarGroup {
  label: string
  receitas: number
  despesas: number
  lucro?: number
}

export interface BarChartProps {
  groups: BarGroup[]
  height?: number
}

const COLORS = {
  receitas: 'var(--clx-success)',
  despesas: 'var(--clx-error)',
  lucro: 'var(--clx-info)',
}

export function BarChart({ groups, height = 240 }: BarChartProps) {
  const hasLucro = groups.some((g) => typeof g.lucro === 'number')

  if (groups.length === 0) {
    return (
      <div className="fin-bar-empty" style={{ height }}>
        Sem dados no período
      </div>
    )
  }

  // Coordenadas virtuais (viewBox); o CSS estica a largura para 100%.
  const padL = 8
  const padR = 8
  const padTop = 12
  const padBottom = 26
  const groupW = 92
  const vbWidth = Math.max(360, padL + padR + groups.length * groupW)
  const plotTop = padTop
  const plotBottom = height - padBottom
  const plotH = plotBottom - plotTop

  const allValues: number[] = []
  for (const g of groups) {
    allValues.push(g.receitas, g.despesas)
    if (typeof g.lucro === 'number') allValues.push(g.lucro)
  }
  const maxVal = Math.max(1, ...allValues)
  const minVal = Math.min(0, ...allValues)
  const range = maxVal - minVal || 1

  const yOf = (v: number) => plotBottom - ((v - minVal) / range) * plotH
  const zeroY = yOf(0)

  const seriesCount = hasLucro ? 3 : 2
  const barGap = 6
  const innerW = groupW - 18
  const barW = Math.max(7, (innerW - barGap * (seriesCount - 1)) / seriesCount)

  // Linhas de grade horizontais discretas.
  const gridLines = [0, 0.25, 0.5, 0.75, 1].map((t) => plotTop + t * plotH)

  function bar(x: number, v: number, fill: string, key: string) {
    const y = yOf(v)
    const top = Math.min(y, zeroY)
    const h = Math.max(1, Math.abs(zeroY - y))
    return <rect key={key} x={x} y={top} width={barW} height={h} rx={2} fill={fill} />
  }

  return (
    <div className="fin-bar-wrap">
      <svg
        viewBox={`0 0 ${vbWidth} ${height}`}
        className="fin-bar-chart"
        preserveAspectRatio="none"
        role="img"
        aria-label={`Fluxo de caixa por período: ${groups
          .map((g) => g.label)
          .join(', ')}`}
      >
        {gridLines.map((y, i) => (
          <line
            key={`g${i}`}
            x1={padL}
            y1={y}
            x2={vbWidth - padR}
            y2={y}
            stroke="var(--clx-fin-track)"
            strokeWidth={1}
          />
        ))}
        {/* baseline do zero, levemente mais forte */}
        <line
          x1={padL}
          y1={zeroY}
          x2={vbWidth - padR}
          y2={zeroY}
          stroke="var(--clx-line-2)"
          strokeWidth={1}
        />

        {groups.map((g, gi) => {
          const gx = padL + gi * groupW + (groupW - innerW) / 2
          let x = gx
          const rects: React.ReactNode[] = []
          rects.push(bar(x, g.receitas, COLORS.receitas, `r${gi}`))
          x += barW + barGap
          rects.push(bar(x, g.despesas, COLORS.despesas, `d${gi}`))
          if (hasLucro) {
            x += barW + barGap
            rects.push(bar(x, g.lucro ?? 0, COLORS.lucro, `l${gi}`))
          }
          return (
            <g key={gi}>
              {rects}
              <text
                x={padL + gi * groupW + groupW / 2}
                y={height - 8}
                textAnchor="middle"
                className="fin-bar-label"
              >
                {g.label}
              </text>
            </g>
          )
        })}
      </svg>

      <div className="fin-bar-legend">
        <span className="fin-bar-legend-item">
          <span className="fin-bar-legend-dot" style={{ background: COLORS.receitas }} /> Receitas
        </span>
        <span className="fin-bar-legend-item">
          <span className="fin-bar-legend-dot" style={{ background: COLORS.despesas }} /> Despesas
        </span>
        {hasLucro && (
          <span className="fin-bar-legend-item">
            <span className="fin-bar-legend-dot" style={{ background: COLORS.lucro }} /> Lucro / Prejuízo
          </span>
        )}
      </div>
    </div>
  )
}

export default BarChart
