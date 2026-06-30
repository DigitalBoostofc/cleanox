/**
 * financeiro/components/utils.ts — helpers internos do KIT de UI do Financeiro.
 *
 * Sem dependência externa. Usado por CategoriaIcon, ContaBadge e pelos gráficos
 * (Donut/BarChart) para cores de série quando a categoria não traz cor própria.
 */

/** Paleta de séries (donut/barras) — alinhada à spec visual (teal → cinza claro). */
export const FIN_SERIES_COLORS = [
  '#00C2B8', // teal
  '#22C55E', // verde
  '#3B82F6', // azul
  '#F59E0B', // âmbar
  '#8B5CF6', // roxo
  '#EC4899', // rosa
  '#64748B', // slate
  '#D1D5DB', // cinza claro (sobra/Outros)
] as const

/** Cor neutra para fatias agregadas ("Outros") e fallbacks. */
export const FIN_NEUTRAL_COLOR = '#D1D5DB'

/**
 * Converte um hex (#RGB ou #RRGGBB) em rgba() com a opacidade dada.
 * Tolerante: valores não-hex (ex.: var(--token)) caem num cinza neutro translúcido.
 */
export function hexToRgba(hex: string, alpha: number): string {
  if (typeof hex !== 'string' || !hex.startsWith('#')) {
    return `rgba(122, 136, 147, ${alpha})`
  }
  let h = hex.slice(1).trim()
  if (h.length === 3) h = h.split('').map((c) => c + c).join('')
  const n = Number.parseInt(h, 16)
  if (Number.isNaN(n) || h.length !== 6) return `rgba(122, 136, 147, ${alpha})`
  const r = (n >> 16) & 255
  const g = (n >> 8) & 255
  const b = n & 255
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

/** Escolhe uma cor de série pelo índice (faz wrap se passar do tamanho da paleta). */
export function seriesColor(index: number): string {
  return FIN_SERIES_COLORS[index % FIN_SERIES_COLORS.length]
}
