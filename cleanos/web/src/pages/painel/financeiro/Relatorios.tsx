/**
 * financeiro/Relatorios.tsx — Tela RELATÓRIOS do módulo Financeiro (estilo Organizze).
 *
 * Header (Exportar PDF / Imprimir / Atualizar) + filtros (Período, Categorias,
 * Contas, Status) + abas (Categorias / Entradas x Saídas / Contas / Tags).
 * 5 KPIs, 2 donuts (despesas/receitas por categoria), bar chart de fluxo de
 * caixa (6 meses), card "Resumo do período" e donut "Receitas via OS".
 *
 * Gráficos vêm do KIT (./components — pane irmã): Donut, BarChart, FinKpiCard.
 * As derivações financeiras vêm de ../../../lib/financeiro/store. Decisão de
 * produto: os KPIs/donuts honram TODOS os filtros (período, categoria, conta,
 * status); o card "Resumo do período" mostra a movimentação REALIZADA (status
 * 'pago') via resumoPeriodo. Exportar/Imprimir usam window.print() (sem alert).
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  listLancamentos,
  listContas,
  listCategorias,
  lancamentosDoPeriodo,
  resumoPeriodo,
  saldoGeral,
  mesPeriodo,
} from '../../../lib/financeiro/store'
import type {
  Categoria,
  Conta,
  Lancamento,
  LancamentoStatus,
  Periodo,
} from '../../../lib/financeiro/types'
import { statusLabel } from '../../../lib/financeiro/labels'
import { formatCurrency } from '../../../lib/collections'
import { Spinner } from '../../../components/ui/Spinner'
import {
  IconAlertCircle,
  IconRefresh,
  IconArrowRight,
} from '../../../components/ui/Icon'
import { Donut, BarChart, FinKpiCard } from './components'

/* ============================================================ */
/* Constantes / helpers locais                                  */
/* ============================================================ */

const MESES_FULL = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
]
const MESES_ABBR = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
]

/** Paleta de fallback para fatias sem cor de categoria. */
const FALLBACK_COLORS = [
  '#00C2B8', '#22C55E', '#3B82F6', '#F59E0B', '#8B5CF6',
  '#EC4899', '#64748B', '#0EA5E9', '#14B8A6', '#F97316',
]

const STATUS_OPTS: { value: LancamentoStatus | 'todos'; label: string }[] = [
  { value: 'todos', label: 'Todos' },
  { value: 'pago', label: statusLabel('pago') },
  { value: 'pendente', label: statusLabel('pendente') },
  { value: 'previsto', label: statusLabel('previsto') },
  { value: 'em_atraso', label: statusLabel('em_atraso') },
]

type ReportTab = 'categorias' | 'fluxo' | 'contas' | 'tags'

const TABS: { id: ReportTab; label: string }[] = [
  { id: 'categorias', label: 'Categorias' },
  { id: 'fluxo', label: 'Entradas x Saídas' },
  { id: 'contas', label: 'Contas' },
  { id: 'tags', label: 'Tags' },
]

/** Fatia de donut já com percentual calculado (para a legenda). */
interface Slice {
  id: string
  label: string
  value: number
  color: string
  pct: number
}

/** Rótulo "01 – 30 de Junho de 2026" para o período mensal. */
function periodoLabel(year: number, month: number): string {
  const ultimoDia = new Date(year, month + 1, 0).getDate()
  return `01 – ${ultimoDia} de ${MESES_FULL[month]} de ${year}`
}

/** Soma por tipo (receita/despesa) de um conjunto JÁ filtrado. */
function totaisPorTipo(lancs: Lancamento[]): { receita: number; despesa: number } {
  let receita = 0
  let despesa = 0
  for (const l of lancs) {
    if (l.tipo === 'receita') receita += l.valor
    else despesa += l.valor
  }
  return { receita, despesa }
}

/** Agrega o valor por categoria-mãe para um único tipo. */
function agregarPorCategoria(
  lancs: Lancamento[],
  tipo: 'receita' | 'despesa',
): Map<string, number> {
  const map = new Map<string, number>()
  for (const l of lancs) {
    if (l.tipo !== tipo) continue
    map.set(l.categoriaId, (map.get(l.categoriaId) ?? 0) + l.valor)
  }
  return map
}

/** Converte um mapa categoria→valor em fatias ordenadas (top N + "Outras"). */
function buildSlices(
  totais: Map<string, number>,
  catById: Map<string, Categoria>,
  maxSlices = 8,
): Slice[] {
  const entries = Array.from(totais.entries())
    .filter(([, v]) => v > 0)
    .sort((a, b) => b[1] - a[1])
  const total = entries.reduce((s, [, v]) => s + v, 0)
  if (total <= 0) return []

  const head = entries.slice(0, maxSlices)
  const tail = entries.slice(maxSlices)

  const slices: Slice[] = head.map(([id, value], i) => {
    const cat = catById.get(id)
    return {
      id,
      label: cat?.nome ?? 'Sem categoria',
      value,
      color: cat?.cor ?? FALLBACK_COLORS[i % FALLBACK_COLORS.length],
      pct: value / total,
    }
  })

  if (tail.length > 0) {
    const outras = tail.reduce((s, [, v]) => s + v, 0)
    slices.push({ id: '__outras__', label: 'Outras', value: outras, color: '#D1D5DB', pct: outras / total })
  }
  return slices
}

/** Variação percentual segura (atual vs anterior). */
function pctChange(atual: number, anterior: number): number {
  if (anterior === 0) return atual === 0 ? 0 : 100
  return ((atual - anterior) / Math.abs(anterior)) * 100
}

function pctLabel(v: number): string {
  return `${v >= 0 ? '+' : ''}${v.toFixed(1).replace('.', ',')}%`
}

/** Monta o objeto `trend` do FinKpiCard a partir da variação vs. mês anterior. */
function trendOf(atual: number, anterior: number): { dir: 'up' | 'down'; text: string } {
  const c = pctChange(atual, anterior)
  return { dir: c >= 0 ? 'up' : 'down', text: `${pctLabel(c)} vs. mês anterior` }
}

/* ============================================================ */
/* Subcomponentes próprios                                      */
/* ============================================================ */

/** Card de donut com legenda em lista (% + valor) — usado p/ despesas e receitas. */
function DonutCard({
  title,
  totalLabel,
  slices,
  emptyHint,
}: {
  title: string
  totalLabel: string
  slices: Slice[]
  emptyHint: string
}) {
  const total = slices.reduce((s, x) => s + x.value, 0)
  return (
    <section className="fin-graph-card">
      <div className="fin-graph-title" style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
        <span>{title}</span>
        {slices.length > 0 && (
          <span style={{ textAlign: 'right', color: 'var(--clx-ink-3)', fontWeight: 600, fontSize: '0.8rem' }}>
            {totalLabel}
            <br />
            <strong style={{ color: 'var(--clx-ink)' }}>{formatCurrency(total)}</strong>
          </span>
        )}
      </div>

      {slices.length === 0 ? (
        <div className="empty-state" style={{ padding: '28px 12px' }}>
          <p>{emptyHint}</p>
        </div>
      ) : (
        <div className="fin-donut-container">
          <Donut
            data={slices.map((s) => ({ label: s.label, value: s.value, color: s.color }))}
            size={150}
            centerLabel="Total"
            centerValue={formatCurrency(total)}
          />
          <ul className="fin-donut-legend" style={{ listStyle: 'none', margin: 0, padding: 0, width: '100%' }}>
            {slices.map((s) => (
              <li key={s.id} className="fin-donut-legend-item">
                <span className="fin-donut-dot" style={{ background: s.color }} aria-hidden />
                <span className="fin-donut-name">{s.label}</span>
                <span className="fin-donut-value">
                  <span className="fin-donut-value-amount">{formatCurrency(s.value)}</span>
                  <span className="fin-donut-value-pct">{(s.pct * 100).toFixed(1).replace('.', ',')}%</span>
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  )
}

/* ============================================================ */
/* Página                                                       */
/* ============================================================ */

export default function Relatorios() {
  const now = new Date()
  const [ym, setYm] = useState({ year: now.getFullYear(), month: now.getMonth() })
  const [catFilter, setCatFilter] = useState<string>('todas')
  const [contaFilter, setContaFilter] = useState<string>('todas')
  const [statusFilter, setStatusFilter] = useState<LancamentoStatus | 'todos'>('todos')
  const [tab, setTab] = useState<ReportTab>('categorias')

  const [lancamentos, setLancamentos] = useState<Lancamento[]>([])
  const [contas, setContas] = useState<Conta[]>([])
  const [categorias, setCategorias] = useState<Categoria[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const genRef = useRef(0)

  const load = useCallback(async () => {
    const gen = ++genRef.current
    try {
      setLoading(true)
      setError(null)
      const [l, c, cat] = await Promise.all([listLancamentos(), listContas(), listCategorias()])
      if (gen !== genRef.current) return
      setLancamentos(l)
      setContas(c)
      setCategorias(cat)
    } catch {
      if (gen === genRef.current) setError('Não foi possível carregar os dados do relatório.')
    } finally {
      if (gen === genRef.current) setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  /* ---- Índices auxiliares ---- */
  const catById = useMemo(() => {
    const m = new Map<string, Categoria>()
    categorias.forEach((c) => m.set(c.id, c))
    return m
  }, [categorias])

  const contaById = useMemo(() => {
    const m = new Map<string, Conta>()
    contas.forEach((c) => m.set(c.id, c))
    return m
  }, [contas])

  /* ---- Período atual e anterior ---- */
  const periodo: Periodo = useMemo(() => mesPeriodo(ym.year, ym.month), [ym])
  const periodoAnterior: Periodo = useMemo(() => {
    const m = ym.month === 0 ? 11 : ym.month - 1
    const y = ym.month === 0 ? ym.year - 1 : ym.year
    return mesPeriodo(y, m)
  }, [ym])

  /* ---- Aplica filtros categoria/conta ---- */
  const baseFiltrada = useMemo(() => {
    return lancamentos.filter((l) => {
      if (catFilter !== 'todas' && l.categoriaId !== catFilter && l.subcategoriaId !== catFilter) return false
      if (contaFilter !== 'todas' && l.contaId !== contaFilter) return false
      return true
    })
  }, [lancamentos, catFilter, contaFilter])

  const aplicarStatus = useCallback(
    (lancs: Lancamento[]) => (statusFilter === 'todos' ? lancs : lancs.filter((l) => l.status === statusFilter)),
    [statusFilter],
  )

  /* ---- Conjunto do período (com status) ---- */
  const viewLancs = useMemo(
    () => aplicarStatus(lancamentosDoPeriodo(baseFiltrada, periodo)),
    [aplicarStatus, baseFiltrada, periodo],
  )
  const prevLancs = useMemo(
    () => aplicarStatus(lancamentosDoPeriodo(baseFiltrada, periodoAnterior)),
    [aplicarStatus, baseFiltrada, periodoAnterior],
  )

  /* ---- KPIs ---- */
  const tot = useMemo(() => totaisPorTipo(viewLancs), [viewLancs])
  const totPrev = useMemo(() => totaisPorTipo(prevLancs), [prevLancs])
  const lucro = tot.receita - tot.despesa
  const lucroPrev = totPrev.receita - totPrev.despesa

  const viaOsLancs = useMemo(
    () => viewLancs.filter((l) => l.tipo === 'receita' && l.origem === 'via_os'),
    [viewLancs],
  )
  const receitaViaOs = viaOsLancs.reduce((s, l) => s + l.valor, 0)
  const ticketMedio = viaOsLancs.length > 0 ? receitaViaOs / viaOsLancs.length : 0
  const pctViaOs = tot.receita > 0 ? (receitaViaOs / tot.receita) * 100 : 0

  /* ---- Donuts por categoria ---- */
  const despesaSlices = useMemo(
    () => buildSlices(agregarPorCategoria(viewLancs, 'despesa'), catById),
    [viewLancs, catById],
  )
  const receitaSlices = useMemo(
    () => buildSlices(agregarPorCategoria(viewLancs, 'receita'), catById),
    [viewLancs, catById],
  )

  /* ---- Donut Receitas via OS ---- */
  const viaOsSlices: Slice[] = useMemo(() => {
    if (tot.receita <= 0) return []
    const outras = Math.max(0, tot.receita - receitaViaOs)
    return [
      { id: 'via_os', label: 'Via OS', value: receitaViaOs, color: 'var(--clx-primary, #00C2B8)', pct: receitaViaOs / tot.receita },
      { id: 'outras', label: 'Outras receitas', value: outras, color: '#D1D5DB', pct: outras / tot.receita },
    ]
  }, [tot.receita, receitaViaOs])

  /* ---- Fluxo de caixa (6 meses até o selecionado) ---- */
  const fluxoGroups = useMemo(() => {
    const groups: { label: string; receitas: number; despesas: number; lucro: number }[] = []
    for (let i = 5; i >= 0; i--) {
      let m = ym.month - i
      let y = ym.year
      while (m < 0) { m += 12; y -= 1 }
      const p = mesPeriodo(y, m)
      const mesLancs = aplicarStatus(lancamentosDoPeriodo(baseFiltrada, p))
      const t = totaisPorTipo(mesLancs)
      groups.push({ label: MESES_ABBR[m], receitas: t.receita, despesas: t.despesa, lucro: t.receita - t.despesa })
    }
    return groups
  }, [aplicarStatus, baseFiltrada, ym])

  const fluxoVazio = fluxoGroups.every((g) => g.receitas === 0 && g.despesas === 0)

  /* ---- Resumo do período (movimentação REALIZADA) ---- */
  const resumo = useMemo(() => resumoPeriodo(baseFiltrada, periodo), [baseFiltrada, periodo])
  const saldoFinal = useMemo(() => saldoGeral(contas), [contas])
  const saldoInicial = saldoFinal - resumo.saldoMes
  const variacaoSaldo = saldoInicial !== 0 ? (resumo.saldoMes / Math.abs(saldoInicial)) * 100 : 0

  /* ---- Breakdown por conta (aba Contas) ---- */
  const contaBreakdown = useMemo(() => {
    return contas.map((c) => {
      const doConta = viewLancs.filter((l) => l.contaId === c.id)
      const t = totaisPorTipo(doConta)
      return { conta: c, entradas: t.receita, saidas: t.despesa, saldo: t.receita - t.despesa }
    })
  }, [contas, viewLancs])

  /* ---- Breakdown por tag (aba Tags) ---- */
  const tagBreakdown = useMemo(() => {
    const m = new Map<string, { receita: number; despesa: number; count: number }>()
    for (const l of viewLancs) {
      for (const tag of l.tags ?? []) {
        const cur = m.get(tag) ?? { receita: 0, despesa: 0, count: 0 }
        if (l.tipo === 'receita') cur.receita += l.valor
        else cur.despesa += l.valor
        cur.count += 1
        m.set(tag, cur)
      }
    }
    return Array.from(m.entries())
      .map(([tag, v]) => ({ tag, ...v }))
      .sort((a, b) => b.receita + b.despesa - (a.receita + a.despesa))
  }, [viewLancs])

  /* ---- Opções de período (últimos 12 meses) ---- */
  const periodOptions = useMemo(() => {
    const opts: { value: string; label: string }[] = []
    for (let i = 0; i < 12; i++) {
      let m = now.getMonth() - i
      let y = now.getFullYear()
      while (m < 0) { m += 12; y -= 1 }
      opts.push({ value: `${y}-${m}`, label: periodoLabel(y, m) })
    }
    return opts
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const periodoVazio = viewLancs.length === 0

  function handlePrint() {
    window.print()
  }

  const catOptions = categorias.filter((c) => !c.arquivada)

  return (
    <div className="fin-report-root">
      {/* Header */}
      <div className="section-header" style={{ alignItems: 'flex-start' }}>
        <div>
          <h2>Relatórios financeiros</h2>
          <p style={{ color: 'var(--clx-ink-3)', fontSize: '0.85rem', marginTop: 2 }}>
            Analise o desempenho financeiro do seu negócio com relatórios completos e detalhados.
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }} className="fin-report-actions">
          <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={handlePrint} aria-label="Exportar relatório em PDF">
            Exportar PDF
          </button>
          <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={handlePrint} aria-label="Imprimir relatório">
            Imprimir
          </button>
          <button className="icon-btn" onClick={load} aria-label="Atualizar dados" title="Atualizar">
            <IconRefresh size={16} />
          </button>
        </div>
      </div>

      {/* Filtros */}
      <div className="fin-report-filters">
        <div className="fin-report-filter-item">
          <label className="fin-report-filter-label" htmlFor="rep-periodo">Período</label>
          <select
            id="rep-periodo"
            value={`${ym.year}-${ym.month}`}
            onChange={(e) => {
              const [y, m] = e.target.value.split('-').map(Number)
              setYm({ year: y, month: m })
            }}
          >
            {periodOptions.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
        </div>
        <div className="fin-report-filter-item">
          <label className="fin-report-filter-label" htmlFor="rep-cat">Categorias</label>
          <select id="rep-cat" value={catFilter} onChange={(e) => setCatFilter(e.target.value)}>
            <option value="todas">Todas as categorias</option>
            {catOptions.map((c) => (
              <option key={c.id} value={c.id}>{c.nome}</option>
            ))}
          </select>
        </div>
        <div className="fin-report-filter-item">
          <label className="fin-report-filter-label" htmlFor="rep-conta">Contas</label>
          <select id="rep-conta" value={contaFilter} onChange={(e) => setContaFilter(e.target.value)}>
            <option value="todas">Todas as contas</option>
            {contas.map((c) => (
              <option key={c.id} value={c.id}>{c.nome}</option>
            ))}
          </select>
        </div>
        <div className="fin-report-filter-item">
          <label className="fin-report-filter-label" htmlFor="rep-status">Status</label>
          <select
            id="rep-status"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as LancamentoStatus | 'todos')}
          >
            {STATUS_OPTS.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
        </div>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {error}
          <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load} style={{ marginLeft: 'auto' }}>
            Tentar novamente
          </button>
        </div>
      )}

      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando…</div>
      ) : (
        <>
          {/* Tabs */}
          <div className="fin-report-tabs" role="tablist" aria-label="Relatórios">
            {TABS.map((t) => (
              <button
                key={t.id}
                role="tab"
                aria-selected={tab === t.id}
                className={`fin-report-tab${tab === t.id ? ' active' : ''}`}
                onClick={() => setTab(t.id)}
              >
                {t.label}
              </button>
            ))}
          </div>

          {/* KPIs — sempre visíveis */}
          <div className="fin-kpi-grid">
            <FinKpiCard
              label="Receita total"
              value={formatCurrency(tot.receita)}
              tone="success"
              trend={trendOf(tot.receita, totPrev.receita)}
            />
            <FinKpiCard
              label="Despesa total"
              value={formatCurrency(tot.despesa)}
              tone="error"
              trend={trendOf(tot.despesa, totPrev.despesa)}
            />
            <FinKpiCard
              label="Lucro / Prejuízo"
              value={formatCurrency(lucro)}
              tone={lucro >= 0 ? 'info' : 'error'}
              trend={trendOf(lucro, lucroPrev)}
            />
            <FinKpiCard
              label="Ticket médio por serviço"
              value={formatCurrency(ticketMedio)}
              tone="accent"
              hint={`${viaOsLancs.length} serviço${viaOsLancs.length !== 1 ? 's' : ''} via OS`}
            />
            <FinKpiCard
              label="Receitas via OS"
              value={formatCurrency(receitaViaOs)}
              tone="accent"
              hint={`${pctViaOs.toFixed(1).replace('.', ',')}% do total`}
            />
          </div>

          {periodoVazio && (
            <div className="empty-state" style={{ marginBottom: 20 }}>
              <h4>Sem dados em {periodoLabel(ym.year, ym.month)}</h4>
              <p>Não há lançamentos no período/filtros selecionados. Ajuste os filtros acima.</p>
            </div>
          )}

          {/* ---- Aba: Categorias ---- */}
          {tab === 'categorias' && (
            <div className="fin-graphs">
              <div className="fin-graph-row">
                <DonutCard
                  title="Despesas por categoria"
                  totalLabel="Total de despesas"
                  slices={despesaSlices}
                  emptyHint="Sem despesas no período."
                />
                <DonutCard
                  title="Receitas por categoria"
                  totalLabel="Total de receitas"
                  slices={receitaSlices}
                  emptyHint="Sem receitas no período."
                />
              </div>

              <div className="fin-graph-row">
                {/* Resumo do período */}
                <section className="fin-graph-card">
                  <div className="fin-graph-title">Resumo do período</div>
                  <div className="fin-summary-card">
                    <div className="fin-summary-row">
                      <span className="fin-summary-label">Saldo inicial</span>
                      <span className="fin-summary-value">{formatCurrency(saldoInicial)}</span>
                    </div>
                    <div className="fin-summary-row">
                      <span className="fin-summary-label">Total de entradas</span>
                      <span className="fin-summary-value income">{formatCurrency(resumo.entradas)}</span>
                    </div>
                    <div className="fin-summary-row">
                      <span className="fin-summary-label">Total de saídas</span>
                      <span className="fin-summary-value expense">{formatCurrency(resumo.saidas)}</span>
                    </div>
                    <div className="fin-summary-row">
                      <span className="fin-summary-label">Saldo final</span>
                      <span className="fin-summary-value primary">{formatCurrency(saldoFinal)}</span>
                    </div>
                    <div className="fin-summary-row">
                      <span className="fin-summary-label">Variação no período</span>
                      <span
                        className="fin-summary-value"
                        style={{ color: resumo.saldoMes >= 0 ? 'var(--clx-success)' : 'var(--clx-error)' }}
                      >
                        {pctLabel(variacaoSaldo)}
                      </span>
                    </div>
                  </div>
                  <p style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)', marginTop: 8 }}>
                    Movimentação realizada (lançamentos pagos) no período.
                  </p>
                </section>

                {/* Receitas via OS (donut simples) */}
                <section className="fin-graph-card">
                  <div className="fin-graph-title">Receitas via OS</div>
                  {viaOsSlices.length === 0 ? (
                    <div className="empty-state" style={{ padding: '28px 12px' }}>
                      <p>Sem receitas no período.</p>
                    </div>
                  ) : (
                    <div className="fin-donut-container">
                      <Donut
                        data={viaOsSlices.map((s) => ({ label: s.label, value: s.value, color: s.color }))}
                        size={130}
                        centerLabel="Via OS"
                        centerValue={`${pctViaOs.toFixed(1).replace('.', ',')}%`}
                      />
                      <div style={{ textAlign: 'center' }}>
                        <div style={{ fontFamily: 'var(--clx-font-display)', fontSize: '1.3rem', fontWeight: 800, color: 'var(--clx-primary)' }}>
                          {formatCurrency(receitaViaOs)}
                        </div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--clx-ink-3)' }}>do total de receitas</div>
                      </div>
                    </div>
                  )}
                </section>
              </div>

              {/* Fluxo de caixa */}
              <section className="fin-graph-card">
                <div className="fin-graph-title">Fluxo de caixa mensal</div>
                {fluxoVazio ? (
                  <div className="empty-state" style={{ padding: '28px 12px' }}>
                    <p>Sem movimentação nos últimos meses.</p>
                  </div>
                ) : (
                  <BarChart groups={fluxoGroups} height={240} />
                )}
              </section>
            </div>
          )}

          {/* ---- Aba: Entradas x Saídas ---- */}
          {tab === 'fluxo' && (
            <div className="fin-graphs">
              <section className="fin-graph-card">
                <div className="fin-graph-title">Fluxo de caixa mensal</div>
                {fluxoVazio ? (
                  <div className="empty-state" style={{ padding: '28px 12px' }}>
                    <p>Sem movimentação nos últimos meses.</p>
                  </div>
                ) : (
                  <BarChart groups={fluxoGroups} height={260} />
                )}
              </section>

              <section className="fin-graph-card">
                <div className="fin-graph-title">Resumo do período</div>
                <div className="fin-summary-card">
                  <div className="fin-summary-row">
                    <span className="fin-summary-label">Total de entradas</span>
                    <span className="fin-summary-value income">{formatCurrency(tot.receita)}</span>
                  </div>
                  <div className="fin-summary-row">
                    <span className="fin-summary-label">Total de saídas</span>
                    <span className="fin-summary-value expense">{formatCurrency(tot.despesa)}</span>
                  </div>
                  <div className="fin-summary-row">
                    <span className="fin-summary-label">Resultado</span>
                    <span
                      className="fin-summary-value"
                      style={{ color: lucro >= 0 ? 'var(--clx-success)' : 'var(--clx-error)' }}
                    >
                      {formatCurrency(lucro)}
                    </span>
                  </div>
                </div>
              </section>
            </div>
          )}

          {/* ---- Aba: Contas ---- */}
          {tab === 'contas' && (
            <section className="fin-graph-card">
              <div className="fin-graph-title" style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Movimentação por conta</span>
                <span style={{ color: 'var(--clx-ink-3)', fontWeight: 600, fontSize: '0.8rem' }}>
                  Saldo geral: <strong style={{ color: saldoFinal >= 0 ? 'var(--clx-ink)' : 'var(--clx-error)' }}>{formatCurrency(saldoFinal)}</strong>
                </span>
              </div>
              {contaBreakdown.length === 0 ? (
                <div className="empty-state" style={{ padding: '28px 12px' }}><p>Nenhuma conta cadastrada.</p></div>
              ) : (
                <div className="table-wrap">
                  <div className="table-scroll">
                    <table className="clx-table">
                      <thead>
                        <tr>
                          <th>Conta</th>
                          <th>Entradas</th>
                          <th>Saídas</th>
                          <th>Resultado</th>
                          <th>Saldo atual</th>
                        </tr>
                      </thead>
                      <tbody>
                        {contaBreakdown.map((b) => (
                          <tr key={b.conta.id}>
                            <td data-label="Conta"><strong>{b.conta.nome}</strong></td>
                            <td data-label="Entradas" style={{ color: 'var(--clx-success)', fontWeight: 600 }}>{formatCurrency(b.entradas)}</td>
                            <td data-label="Saídas" style={{ color: 'var(--clx-error)', fontWeight: 600 }}>{formatCurrency(b.saidas)}</td>
                            <td data-label="Resultado" style={{ fontWeight: 600, color: b.saldo >= 0 ? 'var(--clx-ink)' : 'var(--clx-error)' }}>{formatCurrency(b.saldo)}</td>
                            <td data-label="Saldo atual" style={{ fontWeight: 700, color: b.conta.saldoAtual >= 0 ? 'var(--clx-ink)' : 'var(--clx-error)' }}>{formatCurrency(b.conta.saldoAtual)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </section>
          )}

          {/* ---- Aba: Tags ---- */}
          {tab === 'tags' && (
            <section className="fin-graph-card">
              <div className="fin-graph-title">Lançamentos por tag</div>
              {tagBreakdown.length === 0 ? (
                <div className="empty-state" style={{ padding: '28px 12px' }}>
                  <h4>Nenhuma tag no período</h4>
                  <p>Adicione tags aos lançamentos para vê-los agrupados aqui.</p>
                </div>
              ) : (
                <div className="table-wrap">
                  <div className="table-scroll">
                    <table className="clx-table">
                      <thead>
                        <tr>
                          <th>Tag</th>
                          <th>Lançamentos</th>
                          <th>Entradas</th>
                          <th>Saídas</th>
                        </tr>
                      </thead>
                      <tbody>
                        {tagBreakdown.map((t) => (
                          <tr key={t.tag}>
                            <td data-label="Tag"><span className="clx-chip">{t.tag}</span></td>
                            <td data-label="Lançamentos">{t.count}</td>
                            <td data-label="Entradas" style={{ color: 'var(--clx-success)', fontWeight: 600 }}>{formatCurrency(t.receita)}</td>
                            <td data-label="Saídas" style={{ color: 'var(--clx-error)', fontWeight: 600 }}>{formatCurrency(t.despesa)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </section>
          )}

          <p style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.75rem', color: 'var(--clx-ink-3)', marginTop: 20 }}>
            <IconArrowRight size={13} />
            Dica: use os filtros acima para personalizar os relatórios e obter insights mais precisos.
          </p>
        </>
      )}
    </div>
  )
}
