/**
 * ContasPagarReceber — Contas a pagar e a receber (PANE FIN-B4, estilo Organizze).
 *
 * Header + seletor de período (mês) + Filtros · abas A pagar / A receber / Todas ·
 * 4 KPIs (Total a pagar, Total a receber, Vencendo hoje, Em atraso) derivados das
 * funções puras contasAPagar/contasAReceber (REF = hoje) · filtros combinados ·
 * duas colunas de lista com ação "Marcar como pago" · rodapé informativo OS.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  contasAPagar,
  contasAReceber,
  listCategorias,
  listContas,
  listLancamentos,
  updateLancamento,
} from '../../../lib/financeiro/store'
import type {
  Categoria,
  Conta,
  ContaPendente,
  Lancamento,
} from '../../../lib/financeiro/types'
import { formatCurrency } from '../../../lib/collections'
import { Spinner } from '../../../components/ui/Spinner'
import {
  IconAlertCircle,
  IconCheck,
  IconChevronLeft,
  IconChevronRight,
  IconRefresh,
  IconSettings,
} from '../../../components/ui/Icon'
import { FinKpiCard } from './components'
import {
  IconArrowDownCircle,
  IconArrowUpCircle,
  IconClock,
  IconFunnel,
} from './contas/atoms'
import { ContaRow } from './contas/ContaRow'
import {
  ContasFiltros,
  FILTROS_PADRAO,
  type ContaFilters,
  type VencimentoPreset,
} from './contas/ContasFiltros'
import { todayLocalInput } from './lancamentos/dates'

type Aba = 'pagar' | 'receber' | 'todas'

/** Soma a `days` dias a uma data 'YYYY-MM-DD' (puro, não lê o relógio). */
function ymdPlus(ymd: string, days: number): string {
  const d = new Date(`${ymd}T00:00:00Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

function vencYmd(item: ContaPendente): string {
  const l = item.lancamento
  return (l.vencimento ?? l.data).slice(0, 10)
}

export default function ContasPagarReceber() {
  // REF única do "hoje" em horário LOCAL (BRT) — evita virada de dia após 21h UTC.
  const todayYmd = useMemo(() => todayLocalInput(), [])

  const [year, setYear] = useState(() => Number(todayYmd.slice(0, 4)))
  const [month, setMonth] = useState(() => Number(todayYmd.slice(5, 7)) - 1) // 0-based

  const [lancs, setLancs] = useState<Lancamento[]>([])
  const [categorias, setCategorias] = useState<Categoria[]>([])
  const [contas, setContas] = useState<Conta[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [aba, setAba] = useState<Aba>('pagar')
  const [showFilters, setShowFilters] = useState(true)
  const [filters, setFilters] = useState<ContaFilters>(FILTROS_PADRAO)
  const [savingId, setSavingId] = useState<string | null>(null)

  const loadGenRef = useRef(0)

  const load = useCallback(async () => {
    const gen = ++loadGenRef.current
    try {
      setLoading(true)
      setError(null)
      const [ls, cats, cts] = await Promise.all([
        listLancamentos(),
        listCategorias(),
        listContas(),
      ])
      if (gen !== loadGenRef.current) return
      setLancs(ls)
      setCategorias(cats)
      setContas(cts)
    } catch {
      if (gen === loadGenRef.current) setError('Não foi possível carregar as contas a pagar e a receber.')
    } finally {
      if (gen === loadGenRef.current) setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const catById = useMemo(() => new Map(categorias.map((c) => [c.id, c])), [categorias])
  const contaById = useMemo(() => new Map(contas.map((c) => [c.id, c])), [contas])

  // Derivações puras (REF = hoje). KPIs usam o conjunto GLOBAL em aberto.
  const aPagarAll = useMemo(() => contasAPagar(lancs, todayYmd), [lancs, todayYmd])
  const aReceberAll = useMemo(() => contasAReceber(lancs, todayYmd), [lancs, todayYmd])

  const sum = (items: ContaPendente[]) => items.reduce((s, i) => s + i.lancamento.valor, 0)
  const totalPagar = sum(aPagarAll)
  const totalReceber = sum(aReceberAll)
  const vencendoHojeItems = [...aPagarAll, ...aReceberAll].filter((i) => i.vencendoHoje)
  const emAtrasoItems = [...aPagarAll, ...aReceberAll].filter((i) => i.emAtraso)

  // Filtragem das listas (período do mês + filtros combinados).
  const passaVencimento = useCallback(
    (item: ContaPendente, preset: VencimentoPreset): boolean => {
      if (preset === 'todos') return true
      if (preset === 'vencidas') return item.emAtraso
      if (preset === 'hoje') return item.vencendoHoje
      const v = vencYmd(item)
      if (preset === 'd7') return v >= todayYmd && v <= ymdPlus(todayYmd, 7)
      if (preset === 'd30') return v >= todayYmd && v <= ymdPlus(todayYmd, 30)
      return true
    },
    [todayYmd],
  )

  const mesPrefix = `${year}-${String(month + 1).padStart(2, '0')}`

  const aplicarFiltros = useCallback(
    (items: ContaPendente[]): ContaPendente[] =>
      items.filter((item) => {
        const l = item.lancamento
        if (!vencYmd(item).startsWith(mesPrefix)) return false
        if (filters.origem !== 'todas' && l.origem !== filters.origem) return false
        if (
          filters.categoriaId !== 'todas' &&
          l.categoriaId !== filters.categoriaId &&
          l.subcategoriaId !== filters.categoriaId
        )
          return false
        if (filters.contaId !== 'todas' && l.contaId !== filters.contaId) return false
        if (!passaVencimento(item, filters.vencimento)) return false
        return true
      }),
    [filters, mesPrefix, passaVencimento],
  )

  const aPagarLista = useMemo(
    () => (filters.tipo === 'receita' ? [] : aplicarFiltros(aPagarAll)),
    [filters.tipo, aplicarFiltros, aPagarAll],
  )
  const aReceberLista = useMemo(
    () => (filters.tipo === 'despesa' ? [] : aplicarFiltros(aReceberAll)),
    [filters.tipo, aplicarFiltros, aReceberAll],
  )

  async function handleMarcarPago(l: Lancamento) {
    try {
      setSavingId(l.id)
      setError(null)
      await updateLancamento(l.id, { status: 'pago' })
      await load()
    } catch {
      setError('Não foi possível marcar o lançamento como pago.')
    } finally {
      setSavingId(null)
    }
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

  const mostrarPagar = aba === 'pagar' || aba === 'todas'
  const mostrarReceber = aba === 'receber' || aba === 'todas'

  return (
    <div>
      {/* Header */}
      <div className="section-header" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 4 }}>
        <h2 style={{ margin: 0 }}>Contas a pagar e a receber</h2>
        <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--clx-ink-3)' }}>
          Acompanhe e gerencie suas obrigações a pagar e os recebimentos esperados.
        </p>
      </div>

      {/* Toolbar: período + filtros + refresh */}
      <div
        className="page-toolbar"
        style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap', margin: '14px 0' }}
      >
        <div className="agenda-nav">
          <button className="agenda-nav-btn" onClick={prevMonth} title="Mês anterior" aria-label="Mês anterior">
            <IconChevronLeft size={16} />
          </button>
          <span className="agenda-period-label" style={{ textTransform: 'capitalize' }}>
            {monthLabel}
          </span>
          <button className="agenda-nav-btn" onClick={nextMonth} title="Próximo mês" aria-label="Próximo mês">
            <IconChevronRight size={16} />
          </button>
        </div>
        <button
          className="clx-btn clx-btn-ghost clx-btn-sm"
          onClick={() => setShowFilters((s) => !s)}
          aria-pressed={showFilters}
          style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
        >
          <IconFunnel size={15} /> Filtros
        </button>
        <button
          className="clx-btn clx-btn-ghost clx-btn-sm"
          onClick={load}
          title="Atualizar"
          aria-label="Atualizar"
          style={{ marginLeft: 'auto' }}
        >
          <IconRefresh size={15} />
        </button>
      </div>

      {/* Abas */}
      <div className="tab-bar" role="tablist" style={{ marginBottom: 16 }}>
        <button
          className={`tab-item${aba === 'pagar' ? ' active' : ''}`}
          role="tab"
          aria-selected={aba === 'pagar'}
          onClick={() => setAba('pagar')}
        >
          A pagar
        </button>
        <button
          className={`tab-item${aba === 'receber' ? ' active' : ''}`}
          role="tab"
          aria-selected={aba === 'receber'}
          onClick={() => setAba('receber')}
        >
          A receber
        </button>
        <button
          className={`tab-item${aba === 'todas' ? ' active' : ''}`}
          role="tab"
          aria-selected={aba === 'todas'}
          onClick={() => setAba('todas')}
        >
          Todas
        </button>
      </div>

      {error && (
        <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
          <IconAlertCircle size={16} /> {error}
          <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load} style={{ marginLeft: 'auto' }}>
            Tentar novamente
          </button>
        </div>
      )}

      {/* KPIs (globais, em aberto) */}
      <div
        className="fin-kpi-grid"
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))',
          gap: 14,
          marginBottom: 8,
        }}
      >
        <FinKpiCard
          label="Total a pagar"
          value={formatCurrency(totalPagar)}
          hint={`${aPagarAll.length} ${aPagarAll.length === 1 ? 'item' : 'itens'}`}
          tone="error"
          icon={<IconArrowDownCircle size={22} />}
        />
        <FinKpiCard
          label="Total a receber"
          value={formatCurrency(totalReceber)}
          hint={`${aReceberAll.length} ${aReceberAll.length === 1 ? 'item' : 'itens'}`}
          tone="success"
          icon={<IconArrowUpCircle size={22} />}
        />
        <FinKpiCard
          label="Vencendo hoje"
          value={formatCurrency(sum(vencendoHojeItems))}
          hint={`${vencendoHojeItems.length} ${vencendoHojeItems.length === 1 ? 'item' : 'itens'}`}
          tone="info"
          icon={<IconClock size={22} />}
        />
        <FinKpiCard
          label="Em atraso"
          value={formatCurrency(sum(emAtrasoItems))}
          hint={`${emAtrasoItems.length} ${emAtrasoItems.length === 1 ? 'item' : 'itens'}`}
          tone="error"
          icon={<IconAlertCircle size={22} />}
        />
      </div>
      <p style={{ fontSize: '0.74rem', color: 'var(--clx-ink-3)', margin: '0 0 18px' }}>
        Os totais consideram todas as contas em aberto. As listas abaixo respeitam o período e os filtros selecionados.
      </p>

      {/* Filtros */}
      {showFilters && (
        <ContasFiltros
          filters={filters}
          categorias={categorias}
          contas={contas}
          onChange={setFilters}
          onClear={() => setFilters(FILTROS_PADRAO)}
        />
      )}

      {/* Conteúdo */}
      {loading ? (
        <div className="loading-overlay">
          <Spinner size={22} /> Carregando…
        </div>
      ) : (
        <div
          className="fin-payable-grid"
          style={{
            display: 'grid',
            gridTemplateColumns: mostrarPagar && mostrarReceber ? '1fr 1fr' : '1fr',
            gap: 24,
            alignItems: 'start',
          }}
        >
          {mostrarPagar && (
            <ColunaContas
              titulo="Contas a pagar"
              kind="payable"
              itens={aPagarLista}
              catById={catById}
              contaById={contaById}
              savingId={savingId}
              onMarcarPago={handleMarcarPago}
              vazio={`Nenhuma conta a pagar em ${monthLabel}.`}
            />
          )}
          {mostrarReceber && (
            <ColunaContas
              titulo="Contas a receber"
              kind="receivable"
              itens={aReceberLista}
              catById={catById}
              contaById={contaById}
              savingId={savingId}
              onMarcarPago={handleMarcarPago}
              vazio={`Nenhuma conta a receber em ${monthLabel}.`}
            />
          )}
        </div>
      )}

      {/* Rodapé informativo — Recebimentos via OS */}
      <RodapeOS />
    </div>
  )
}

/* ============================================================
 * Coluna de contas (a pagar OU a receber)
 * ============================================================ */

function ColunaContas({
  titulo,
  kind,
  itens,
  catById,
  contaById,
  savingId,
  onMarcarPago,
  vazio,
}: {
  titulo: string
  kind: 'payable' | 'receivable'
  itens: ContaPendente[]
  catById: Map<string, Categoria>
  contaById: Map<string, Conta>
  savingId: string | null
  onMarcarPago: (l: Lancamento) => void
  vazio: string
}) {
  return (
    <section
      className="fin-payable-section clx-card"
      style={{ overflow: 'hidden', display: 'flex', flexDirection: 'column' }}
    >
      <header
        className="fin-payable-header"
        style={{
          padding: '14px 18px',
          borderBottom: '1px solid var(--clx-line)',
          background: 'var(--clx-bg-2)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
        }}
      >
        <h3 style={{ margin: 0, fontSize: '0.95rem', fontWeight: 700, color: 'var(--clx-ink)' }}>{titulo}</h3>
        <span style={{ fontSize: '0.8rem', color: 'var(--clx-ink-3)' }}>
          {itens.length} {itens.length === 1 ? 'item' : 'itens'}
        </span>
      </header>

      {itens.length === 0 ? (
        <div className="empty-state" style={{ padding: '32px 16px' }}>
          <p style={{ margin: 0, color: 'var(--clx-ink-3)' }}>{vazio}</p>
        </div>
      ) : (
        <div className="fin-payable-rows">
          {itens.map((item) => {
            const l = item.lancamento
            return (
              <ContaRow
                key={l.id}
                item={item}
                kind={kind}
                categoria={catById.get(l.categoriaId)}
                conta={contaById.get(l.contaId)}
                saving={savingId === l.id}
                onMarcarPago={() => onMarcarPago(l)}
              />
            )
          })}
        </div>
      )}
    </section>
  )
}

/* ============================================================
 * Rodapé — Recebimentos via Ordens de Serviço (informativo)
 * ============================================================ */

function RodapeOS() {
  const cards = [
    { titulo: 'Geração automática', desc: 'Contas criadas ao final da OS.' },
    { titulo: 'Menos retrabalho', desc: 'Mais agilidade no dia a dia.' },
    { titulo: 'Relatórios atualizados', desc: 'Visão completa e confiável.' },
  ]
  return (
    <div
      className="fin-os-footer clx-card"
      style={{ marginTop: 24, padding: '20px 24px', background: 'var(--clx-bg-2)' }}
    >
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, marginBottom: 14 }}>
        <span
          aria-hidden="true"
          style={{
            width: 36,
            height: 36,
            borderRadius: '50%',
            background: 'rgba(0, 194, 184, 0.12)',
            color: 'var(--clx-primary)',
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <IconCheck size={18} />
        </span>
        <div>
          <h3 style={{ margin: 0, fontSize: '0.95rem', fontWeight: 700, color: 'var(--clx-ink)' }}>
            Recebimentos via Ordens de Serviço
          </h3>
          <p style={{ margin: '2px 0 0', fontSize: '0.8rem', color: 'var(--clx-ink-3)', lineHeight: 1.5 }}>
            Quando uma OS é marcada como paga, o sistema pode gerar automaticamente a conta a receber e registrar o
            pagamento, mantendo suas finanças sempre atualizadas.
          </p>
        </div>
      </div>
      <div
        className="fin-os-footer-grid"
        style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 14 }}
      >
        {cards.map((c) => (
          <div
            key={c.titulo}
            className="fin-os-footer-card clx-card"
            style={{ padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 4 }}
          >
            <span style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--clx-ink)' }}>{c.titulo}</span>
            <span style={{ fontSize: '0.75rem', color: 'var(--clx-ink-3)', lineHeight: 1.4 }}>{c.desc}</span>
          </div>
        ))}
        <div
          className="fin-os-footer-card"
          style={{
            border: '1.5px solid var(--clx-primary)',
            borderRadius: 'var(--clx-r-md, 8px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '14px 16px',
          }}
        >
          <button
            className="clx-btn clx-btn-ghost clx-btn-sm"
            disabled
            title="Em breve"
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: 'var(--clx-primary)' }}
          >
            <IconSettings size={15} /> Configurar automações
          </button>
        </div>
      </div>
    </div>
  )
}
