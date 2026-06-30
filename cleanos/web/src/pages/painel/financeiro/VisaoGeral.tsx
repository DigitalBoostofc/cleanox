/**
 * VisaoGeral — tela "Visão geral" do módulo Financeiro.
 * KPIs do mês + ações rápidas + blocos (a receber / a pagar / maiores gastos /
 * receitas por origem / limites). Período = mês atual com navegação ‹ ›.
 * Dados via camada mock (src/lib/financeiro/store). Estados vazio/carregando/erro.
 */

import { useCallback, useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { formatCurrency, formatDate } from '../../../lib/collections'
import { origemLabel } from '../../../lib/financeiro/labels'
import type {
  Categoria,
  Conta,
  ContaPendente,
  Lancamento,
  LimiteGasto,
} from '../../../lib/financeiro/types'
import {
  contasAPagar,
  contasAReceber,
  gastoPorCategoria,
  lancamentosDoPeriodo,
  listCategorias,
  listContas,
  listLancamentos,
  listLimites,
  mesPeriodo,
  progressoLimite,
  resumoPeriodo,
  saldoGeral,
} from '../../../lib/financeiro/store'
import { Spinner } from '../../../components/ui/Spinner'
import {
  IconAlertCircle,
  IconChevronLeft,
  IconChevronRight,
  IconDollar,
  IconRefresh,
} from '../../../components/ui/Icon'
import {
  CategoriaIcon,
  Donut,
  FinIcon,
  FinKpiCard,
  FIN_NEUTRAL_COLOR,
  ProgressBar,
  QuickActions,
  StatusChip,
  seriesColor,
  type DonutDatum,
} from './components'

/* ---- glifos locais p/ os KPIs ---- */
function TrendUp() {
  return (
    <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <polyline points="3 17 9 11 13 15 21 7" />
      <polyline points="16 7 21 7 21 12" />
    </svg>
  )
}
function TrendDown() {
  return (
    <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <polyline points="3 7 9 13 13 9 21 17" />
      <polyline points="16 17 21 17 21 12" />
    </svg>
  )
}

const PERCENT_FMT: Intl.NumberFormatOptions = {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
}
function pctLabel(value: number, total: number): string {
  const p = total > 0 ? (value / total) * 100 : 0
  return `${p.toLocaleString('pt-BR', PERCENT_FMT)}%`
}

interface FinData {
  lancamentos: Lancamento[]
  contas: Conta[]
  categorias: Categoria[]
  limites: LimiteGasto[]
}

export default function VisaoGeral() {
  const now = new Date()
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth())

  const [data, setData] = useState<FinData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [toast, setToast] = useState<string | null>(null)

  const loadGenRef = useRef(0)
  const toastTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)

  const load = useCallback(async () => {
    const gen = ++loadGenRef.current
    try {
      setLoading(true)
      setError(null)
      const [lancamentos, contas, categorias, limites] = await Promise.all([
        listLancamentos(),
        listContas(),
        listCategorias(),
        listLimites(),
      ])
      if (gen !== loadGenRef.current) return
      setData({ lancamentos, contas, categorias, limites })
    } catch {
      if (gen === loadGenRef.current) setError('Não foi possível carregar os dados financeiros.')
    } finally {
      if (gen === loadGenRef.current) setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => () => clearTimeout(toastTimer.current), [])

  function showToast(msg: string) {
    setToast(msg)
    clearTimeout(toastTimer.current)
    toastTimer.current = setTimeout(() => setToast(null), 2600)
  }

  function prevMonth() {
    if (month === 0) {
      setMonth(11)
      setYear((y) => y - 1)
    } else setMonth((m) => m - 1)
  }
  function nextMonth() {
    if (month === 11) {
      setMonth(0)
      setYear((y) => y + 1)
    } else setMonth((m) => m + 1)
  }

  const monthLabel = new Date(year, month, 1).toLocaleDateString('pt-BR', {
    month: 'long',
    year: 'numeric',
  })

  /* ---- Derivações ---- */
  const periodo = mesPeriodo(year, month)
  const lancsAll = data?.lancamentos ?? []
  const contas = data?.contas ?? []
  const categorias = data?.categorias ?? []
  const limites = data?.limites ?? []

  const catById = new Map(categorias.map((c) => [c.id, c]))
  const lancsPeriodo = lancamentosDoPeriodo(lancsAll, periodo)
  const resumo = resumoPeriodo(lancsAll, periodo)
  const saldoGeralVal = saldoGeral(contas)
  const todayIso = now.toISOString()

  const receber = contasAReceber(lancsAll, todayIso).slice(0, 5)
  const pagar = contasAPagar(lancsAll, todayIso).slice(0, 5)

  // Maiores gastos do mês (top 5 + Outros)
  const gastoMap = gastoPorCategoria(lancsPeriodo)
  const gastoEntries = Array.from(gastoMap.entries())
    .map(([catId, value]) => ({ cat: catById.get(catId), value }))
    .sort((a, b) => b.value - a.value)
  const TOP_GASTOS = 5
  const topGastos = gastoEntries.slice(0, TOP_GASTOS)
  const restGastos = gastoEntries.slice(TOP_GASTOS).reduce((s, e) => s + e.value, 0)
  const totalGastos = gastoEntries.reduce((s, e) => s + e.value, 0)
  const gastoDonut: DonutDatum[] = topGastos.map((e, i) => ({
    label: e.cat?.nome ?? 'Categoria',
    value: e.value,
    color: e.cat?.cor ?? seriesColor(i),
  }))
  if (restGastos > 0) gastoDonut.push({ label: 'Outros', value: restGastos, color: FIN_NEUTRAL_COLOR })

  // Receitas por origem (pagas no período)
  let receitaViaOs = 0
  let receitaManual = 0
  for (const l of lancsPeriodo) {
    if (l.tipo !== 'receita' || l.status !== 'pago') continue
    if (l.origem === 'via_os') receitaViaOs += l.valor
    else receitaManual += l.valor
  }
  const totalReceitas = receitaViaOs + receitaManual
  const origemDonut: DonutDatum[] = [
    { label: origemLabel('via_os'), value: receitaViaOs, color: '#00C2B8' },
    { label: origemLabel('manual'), value: receitaManual, color: '#3B82F6' },
  ]

  // Limites
  const limiteRows = limites
    .map((l) => ({ limite: l, cat: catById.get(l.categoriaId), prog: progressoLimite(l, lancsPeriodo) }))
    .slice(0, 6)

  const periodVazio = !loading && !error && lancsPeriodo.length === 0

  return (
    <div className="fin-page">
      {/* Header da tela */}
      <div className="fin-page-head">
        <div className="fin-page-head-text">
          <h2 className="fin-page-title">Visão geral financeira</h2>
          <p className="fin-page-sub">
            Acompanhe as entradas, saídas e o desempenho financeiro do seu negócio.
          </p>
        </div>
        <div className="fin-page-head-actions">
          <div className="fin-month-nav">
            <button className="fin-month-nav-btn" onClick={prevMonth} aria-label="Mês anterior" title="Mês anterior">
              <IconChevronLeft size={18} />
            </button>
            <span className="fin-month-label">{monthLabel}</span>
            <button className="fin-month-nav-btn" onClick={nextMonth} aria-label="Próximo mês" title="Próximo mês">
              <IconChevronRight size={18} />
            </button>
          </div>
          <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load} title="Atualizar">
            <IconRefresh size={15} /> Atualizar
          </button>
        </div>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {error}
          <button className="clx-btn clx-btn-ghost clx-btn-sm" style={{ marginLeft: 'auto' }} onClick={load}>
            Tentar novamente
          </button>
        </div>
      )}

      {loading ? (
        <div className="loading-overlay">
          <Spinner size={22} /> Carregando…
        </div>
      ) : (
        !error && (
          <>
            {/* KPIs */}
            <div className="fin-kpi-grid">
              <FinKpiCard
                label="Entradas do mês"
                value={formatCurrency(resumo.entradas)}
                tone="success"
                icon={<TrendUp />}
                hint="Receitas realizadas"
              />
              <FinKpiCard
                label="Saídas do mês"
                value={formatCurrency(resumo.saidas)}
                tone="error"
                icon={<TrendDown />}
                hint="Despesas realizadas"
              />
              <FinKpiCard
                label="Saldo do mês"
                value={formatCurrency(resumo.saldoMes)}
                tone={resumo.saldoMes < 0 ? 'error' : 'info'}
                icon={<IconDollar size={20} />}
                hint="Entradas − saídas"
              />
              <FinKpiCard
                label="Saldo geral"
                value={formatCurrency(saldoGeralVal)}
                tone={saldoGeralVal < 0 ? 'error' : 'accent'}
                icon={<FinIcon name="wallet" size={20} />}
                hint="Disponível em contas"
              />
            </div>

            {/* Ações rápidas */}
            <QuickActions
              className="fin-actions-row"
              onNovaReceita={() => showToast('Nova receita — em breve')}
              onNovaDespesa={() => showToast('Nova despesa — em breve')}
              onTransferencia={() => showToast('Transferência — em breve')}
              onImportar={() => showToast('Importar — em breve')}
            />

            {periodVazio && (
              <div className="empty-state fin-empty-note">
                <h4>Nenhum lançamento em {monthLabel}</h4>
                <p>Os gráficos do período aparecem vazios. As contas a pagar/receber abaixo consideram todos os períodos.</p>
              </div>
            )}

            {/* Bloco 1: a receber | a pagar | maiores gastos */}
            <div className="fin-three-col">
              <section className="fin-col-block">
                <header className="fin-col-header">
                  <h3>Contas a receber</h3>
                  <span className="fin-col-badge">{receber.length} próximas</span>
                </header>
                <PendenteList items={receber} kind="receber" catById={catById} />
                <Link to="/painel/financeiro/contas" className="fin-link">
                  Ver todas as contas a receber →
                </Link>
              </section>

              <section className="fin-col-block">
                <header className="fin-col-header">
                  <h3>Contas a pagar</h3>
                  <span className="fin-col-badge error">{pagar.length} próximas</span>
                </header>
                <PendenteList items={pagar} kind="pagar" catById={catById} />
                <Link to="/painel/financeiro/contas" className="fin-link error">
                  Ver todas as contas a pagar →
                </Link>
              </section>

              <section className="fin-col-block">
                <header className="fin-col-header">
                  <h3>Maiores gastos do mês</h3>
                </header>
                {gastoDonut.length > 0 ? (
                  <>
                    <div className="fin-donut-wrapper">
                      <Donut
                        data={gastoDonut}
                        size={132}
                        centerValue={formatCurrency(totalGastos)}
                        centerLabel="Gastos"
                      />
                      <ul className="fin-donut-legend">
                        {gastoDonut.map((d, i) => (
                          <li className="fin-donut-item" key={i}>
                            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
                              <span className="fin-donut-dot" style={{ background: d.color }} />
                              <span className="fin-donut-name">{d.label}</span>
                            </span>
                            <span className="fin-donut-value">
                              <span className="fin-donut-value-pct">{pctLabel(d.value, totalGastos)}</span>
                              <span className="fin-donut-value-amount">{formatCurrency(d.value)}</span>
                            </span>
                          </li>
                        ))}
                      </ul>
                    </div>
                    <Link to="/painel/financeiro/relatorios" className="fin-link">
                      Ver relatório completo →
                    </Link>
                  </>
                ) : (
                  <p className="fin-block-empty">Nenhuma despesa paga em {monthLabel}.</p>
                )}
              </section>
            </div>

            {/* Bloco 2: receitas por origem | limites */}
            <div className="fin-two-col">
              <section className="fin-col-block">
                <header className="fin-col-header">
                  <h3>Receitas por origem</h3>
                </header>
                {totalReceitas > 0 ? (
                  <div className="fin-donut-wrapper">
                    <Donut
                      data={origemDonut}
                      size={132}
                      centerValue={formatCurrency(totalReceitas)}
                      centerLabel="Receitas"
                    />
                    <ul className="fin-donut-legend">
                      {origemDonut.map((d, i) => (
                        <li className="fin-donut-item" key={i}>
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
                            <span className="fin-donut-dot" style={{ background: d.color }} />
                            <span className="fin-donut-name">{d.label}</span>
                          </span>
                          <span className="fin-donut-value">
                            <span className="fin-donut-value-pct">{pctLabel(d.value, totalReceitas)}</span>
                            <span className="fin-donut-value-amount">{formatCurrency(d.value)}</span>
                          </span>
                        </li>
                      ))}
                    </ul>
                  </div>
                ) : (
                  <p className="fin-block-empty">Nenhuma receita recebida em {monthLabel}.</p>
                )}
              </section>

              <section className="fin-col-block">
                <header className="fin-col-header">
                  <h3>Limite de gastos do mês</h3>
                  <span className="fin-col-header-count">{limiteRows.length} categorias</span>
                </header>
                {limiteRows.length > 0 ? (
                  <div className="fin-limit-list">
                    {limiteRows.map(({ limite, cat, prog }) => {
                      const pct = prog.pct * 100
                      const estourado = prog.gasto > prog.limite && prog.limite > 0
                      return (
                        <div className="fin-limit-row" key={limite.id}>
                          <div className="fin-limit-head">
                            <span className="fin-limit-label">{cat?.nome ?? 'Categoria'}</span>
                            <span className={`fin-limit-value${estourado ? ' over' : ''}`}>
                              {formatCurrency(prog.gasto)} / {formatCurrency(prog.limite)}
                            </span>
                          </div>
                          <ProgressBar pct={pct} />
                        </div>
                      )
                    })}
                  </div>
                ) : (
                  <p className="fin-block-empty">Nenhum limite definido.</p>
                )}
                <Link to="/painel/financeiro/limites" className="fin-link">
                  Gerenciar limites →
                </Link>
              </section>
            </div>

            <p className="fin-page-foot">
              <IconAlertCircle size={13} /> Dica: mantenha suas categorias e limites atualizados para relatórios cada vez mais precisos.
            </p>
          </>
        )
      )}

      {toast && <div className="fin-toast" role="status">{toast}</div>}
    </div>
  )
}

/* ============================================================
 * Lista de contas a pagar/receber (compacta)
 * ============================================================ */

interface PendenteListProps {
  items: ContaPendente[]
  kind: 'receber' | 'pagar'
  catById: Map<string, Categoria>
}

function PendenteList({ items, kind, catById }: PendenteListProps) {
  if (items.length === 0) {
    return (
      <p className="fin-block-empty">
        {kind === 'receber' ? 'Nenhuma conta a receber.' : 'Nenhuma conta a pagar.'}
      </p>
    )
  }
  return (
    <ul className="fin-list">
      {items.map((p) => {
        const l = p.lancamento
        const cat = catById.get(l.categoriaId)
        const venc = l.vencimento ?? l.data
        const sub = l.origem === 'via_os' && l.clienteNome ? `Cliente: ${l.clienteNome}` : formatDate(venc)
        return (
          <li className="fin-list-item" key={l.id}>
            <CategoriaIcon categoria={cat} size={34} />
            <div className="fin-list-meta">
              <div className="fin-list-title">{l.descricao}</div>
              <div className="fin-list-sub">{sub}</div>
            </div>
            <div className="fin-list-right">
              <span className={`fin-list-value ${kind === 'receber' ? 'success' : 'error'}`}>
                {formatCurrency(l.valor)}
              </span>
              <StatusChip status={l.status} />
            </div>
          </li>
        )
      })}
    </ul>
  )
}
