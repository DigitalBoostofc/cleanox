/**
 * lancamentos/dates.ts — formatação de datas SEM depender do fuso.
 *
 * As datas do store são strings ISO ('YYYY-MM-DD' ou datetime). `new Date(...)`
 * sobre uma data-only é interpretada como UTC e, em fusos negativos (BRT = -3h),
 * "volta um dia". Por isso aqui só lemos os números 'YYYY-MM-DD' diretamente.
 */

export const MESES_PT = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
] as const

/** Quebra a parte 'YYYY-MM-DD' de um ISO em números (m é 1-based). */
function parseYmd(iso: string): { y: number; m: number; d: number } {
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number)
  return { y: y || 0, m: m || 1, d: d || 1 }
}

/** 'YYYY-MM-DD' → '29/06/2026'. */
export function formatDayHeaderBR(iso: string): string {
  const { y, m, d } = parseYmd(iso)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(d)}/${p(m)}/${y}`
}

/** ISO → '29 de Junho de 2026'. */
export function formatLongDateBR(iso: string): string {
  const { y, m, d } = parseYmd(iso)
  return `${d} de ${MESES_PT[m - 1] ?? '—'} de ${y}`
}

/** (ano, mês 0-based) → 'Junho 2026'. */
export function formatMonthYear(year: number, month: number): string {
  return `${MESES_PT[month] ?? '—'} ${year}`
}
