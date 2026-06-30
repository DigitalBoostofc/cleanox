/**
 * Lançamentos — tela "estilo Organizze" do módulo Financeiro do CleanOS.
 *
 * Header (mês ‹ › + Filtros + busca + Novo lançamento), 4 KPIs derivados do
 * período (Receitas/Despesas realizadas, Previstas, Saldo) e a LISTA AGRUPADA
 * POR DATA (cabeçalho de dia com contagem e total). Clicar numa linha abre o
 * painel lateral de detalhes; o kebab abre um menu de ações rápidas; "Novo
 * lançamento"/Editar abrem o formulário modal.
 *
 * Camada de dados 100% mock (src/lib/financeiro/store, localStorage). KIT visual
 * importado direto dos arquivos de ./components (o barrel index.ts é da pane de
 * infra), incluindo o `ContaBadge` oficial do KIT.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Spinner } from '../../../components/ui/Spinner'
import { Modal } from '../../../components/ui/Modal'
import {
  IconAlertCircle,
  IconChevronLeft,
  IconChevronRight,
  IconPlus,
  IconRefresh,
  IconTrash,
} from '../../../components/ui/Icon'
import { useIsMobile } from '../../../hooks/useIsMobile'
import { formatCurrency } from '../../../lib/collections'
import {
  agruparPorData,
  createLancamento,
  deleteLancamento,
  duplicateLancamento,
  lancamentosDoPeriodo,
  listCategorias,
  listContas,
  listLancamentos,
  mesPeriodo,
  repeatLancamento,
  resumoPeriodo,
  updateLancamento,
} from '../../../lib/financeiro/store'
import { formatSigned } from '../../../lib/financeiro/labels'
import type {
  Categoria,
  Conta,
  Lancamento,
  LancamentoInput,
  LancamentoStatus,
  TipoLancamento,
} from '../../../lib/financeiro/types'
import { FinKpiCard } from './components/FinKpiCard'
import { CategoriaIcon } from './components/CategoriaIcon'
import { StatusChip } from './components/StatusChip'
import { TipoChip } from './components/TipoChip'
import { OrigemChip } from './components/OrigemChip'
import { ContaBadge } from './components/ContaBadge'
import { IconDots } from './lancamentos/icons'
import { MESES_PT, formatDayHeaderBR, formatMonthYear } from './lancamentos/dates'
import { LancamentoDetailPanel } from './lancamentos/LancamentoDetailPanel'
import { LancamentoFormModal } from './lancamentos/LancamentoFormModal'

/* ============================================================
 * Toasts (mesmo padrão inline de MeusServicos)
 * ============================================================ */
interface Toast {
  id: number
  text: string
  type: 'success' | 'error' | 'info'
}
let toastSeq = 0

interface MonthCursor {
  y: number
  m: number
}

interface Filtros {
  tipo: '' | TipoLancamento
  status: '' | LancamentoStatus
  categoriaId: string
  contaId: string
}

const FILTROS_VAZIO: Filtros = { tipo: '', status: '', categoriaId: '', contaId: '' }

function prevCursor({ y, m }: MonthCursor): MonthCursor {
  return m === 0 ? { y: y - 1, m: 11 } : { y, m: m - 1 }
}

function fmtPct(v: number): string {
  return v.toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 })
}

/** Variação % vs. período anterior, para o `trend` do FinKpiCard. */
function buildTrend(
  cur: number,
  prev: number,
  label: string,
): { dir: 'up' | 'down'; text: string } | undefined {
  if (!Number.isFinite(prev) || prev <= 0) return undefined
  const pct = ((cur - prev) / prev) * 100
  return { dir: pct >= 0 ? 'up' : 'down', text: `${fmtPct(Math.abs(pct))}% vs. ${label}` }
}

export default function Lancamentos() {
  const isMobile = useIsMobile()

  const now = new Date()
  const [cursor, setCursor] = useState<MonthCursor>({ y: now.getFullYear(), m: now.getMonth() })

  const [allLancs, setAllLancs] = useState<Lancamento[]>([])
  const [categorias, setCategorias] = useState<Categoria[]>([])
  const [contas, setContas] = useState<Conta[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [search, setSearch] = useState('')
  const [filtros, setFiltros] = useState<Filtros>(FILTROS_VAZIO)
  const [filtrosOpen, setFiltrosOpen] = useState(false)

  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [formOpen, setFormOpen] = useState(false)
  const [formInitial, setFormInitial] = useState<Lancamento | null>(null)
  const [confirmTarget, setConfirmTarget] = useState<Lancamento | null>(null)
  const [deleting, setDeleting] = useState(false)
  const [actionBusy, setActionBusy] = useState(false)
  const [menuFor, setMenuFor] = useState<string | null>(null)

  const [toasts, setToasts] = useState<Toast[]>([])
  const showToast = useCallback((text: string, type: Toast['type'] = 'info') => {
    const id = ++toastSeq
    setToasts((prev) => [...prev, { id, text, type }])
    setTimeout(() => setToasts((prev) => prev.filter((t) => t.id !== id)), 3600)
  }, [])

  /* ---- carga inicial ---- */
  const genRef = useRef(0)
  const load = useCallback(async () => {
    const gen = ++genRef.current
    try {
      setLoading(true)
      setError(null)
      const [lancs, cats, cnts] = await Promise.all([
        listLancamentos(),
        listCategorias(),
        listContas(),
      ])
      if (gen !== genRef.current) return
      setAllLancs(lancs)
      setCategorias(cats)
      setContas(cnts)
    } catch {
      if (gen === genRef.current) setError('Não foi possível carregar os lançamentos.')
    } finally {
      if (gen === genRef.current) setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const reloadLancs = useCallback(async () => {
    const lancs = await listLancamentos()
    setAllLancs(lancs)
    return lancs
  }, [])

  /* ---- índices ---- */
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

  const categoriasRaiz = useMemo(
    () => categorias.filter((c) => !c.parentId),
    [categorias],
  )

  /* ---- derivações do período ---- */
  const periodo = useMemo(() => mesPeriodo(cursor.y, cursor.m), [cursor])
  const periodLancs = useMemo(
    () => lancamentosDoPeriodo(allLancs, periodo),
    [allLancs, periodo],
  )

  const resumo = useMemo(() => resumoPeriodo(allLancs, periodo), [allLancs, periodo])
  const prevResumo = useMemo(() => {
    const pc = prevCursor(cursor)
    return resumoPeriodo(allLancs, mesPeriodo(pc.y, pc.m))
  }, [allLancs, cursor])

  const previstas = useMemo(
    () => periodLancs.filter((l) => l.status !== 'pago'),
    [periodLancs],
  )
  const previstasTotal = useMemo(
    () => previstas.reduce((s, l) => s + l.valor, 0),
    [previstas],
  )

  const activeFilterCount = useMemo(
    () => Object.values(filtros).filter((v) => v !== '').length,
    [filtros],
  )

  /* ---- busca + filtros ---- */
  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return periodLancs.filter((l) => {
      if (filtros.tipo && l.tipo !== filtros.tipo) return false
      if (filtros.status && l.status !== filtros.status) return false
      if (
        filtros.categoriaId &&
        l.categoriaId !== filtros.categoriaId &&
        l.subcategoriaId !== filtros.categoriaId
      )
        return false
      if (filtros.contaId && l.contaId !== filtros.contaId) return false
      if (q) {
        const hay = [
          l.descricao,
          l.observacao,
          l.servicoNome,
          l.clienteNome,
          l.osNumero,
          ...(l.tags ?? []),
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase()
        if (!hay.includes(q)) return false
      }
      return true
    })
  }, [periodLancs, search, filtros])

  const grupos = useMemo(() => agruparPorData(filtered), [filtered])

  const selected = useMemo(
    () => (selectedId ? allLancs.find((l) => l.id === selectedId) ?? null : null),
    [selectedId, allLancs],
  )

  /* ---- navegação de mês ---- */
  function shiftMonth(delta: number) {
    setCursor(({ y, m }) => {
      let nm = m + delta
      let ny = y
      if (nm < 0) {
        nm = 11
        ny -= 1
      } else if (nm > 11) {
        nm = 0
        ny += 1
      }
      return { y: ny, m: nm }
    })
  }

  /* ---- ações ---- */
  function openNew() {
    setFormInitial(null)
    setFormOpen(true)
  }

  function openEdit(l: Lancamento) {
    setMenuFor(null)
    setFormInitial(l)
    setFormOpen(true)
  }

  async function handleFormSubmit(input: LancamentoInput, id?: string) {
    if (id) {
      await updateLancamento(id, input)
    } else {
      await createLancamento(input)
    }
    await reloadLancs()
    setFormOpen(false)
    showToast(id ? 'Lançamento atualizado.' : 'Lançamento criado.', 'success')
  }

  async function handleRepeat(l: Lancamento) {
    setMenuFor(null)
    try {
      setActionBusy(true)
      await repeatLancamento(l.id)
      await reloadLancs()
      showToast('Próxima ocorrência criada (prevista).', 'success')
    } catch {
      showToast('Não foi possível repetir o lançamento.', 'error')
    } finally {
      setActionBusy(false)
    }
  }

  async function handleDuplicate(l: Lancamento) {
    setMenuFor(null)
    try {
      setActionBusy(true)
      await duplicateLancamento(l.id)
      await reloadLancs()
      showToast('Lançamento copiado.', 'success')
    } catch {
      showToast('Não foi possível copiar o lançamento.', 'error')
    } finally {
      setActionBusy(false)
    }
  }

  function askDelete(l: Lancamento) {
    setMenuFor(null)
    setConfirmTarget(l)
  }

  async function confirmDelete() {
    if (!confirmTarget) return
    try {
      setDeleting(true)
      await deleteLancamento(confirmTarget.id)
      await reloadLancs()
      if (selectedId === confirmTarget.id) setSelectedId(null)
      showToast('Lançamento excluído.', 'success')
      setConfirmTarget(null)
    } catch {
      showToast('Não foi possível excluir o lançamento.', 'error')
    } finally {
      setDeleting(false)
    }
  }

  function handleVerOs(l: Lancamento) {
    showToast(`Abrir OS #${l.osNumero ?? '—'} (em breve).`, 'info')
  }

  const prevMonthLabel = MESES_PT[prevCursor(cursor).m]
  const saldoNeg = resumo.saldoMes < 0
  const monthEmpty = periodLancs.length === 0
  const hasSearchOrFilter = search.trim() !== '' || activeFilterCount > 0

  return (
    <div className="fin-lancamentos-page">
      {/* Cabeçalho */}
      <header style={{ marginBottom: 14 }}>
        <h1
          style={{
            fontFamily: 'var(--clx-font-display)',
            fontSize: '1.5rem',
            fontWeight: 800,
            color: 'var(--clx-ink)',
            letterSpacing: '-0.02em',
          }}
        >
          Lançamentos
        </h1>
        <p style={{ color: 'var(--clx-ink-3)', fontSize: '0.85rem', marginTop: 2 }}>
          Acompanhe e controle todas as receitas e despesas da empresa.
        </p>
      </header>

      {/* Toolbar: mês + filtros + busca + novo */}
      <div className="fin-list-toolbar">
        <div className="fin-month-nav">
          <button
            className="fin-month-nav-btn"
            onClick={() => shiftMonth(-1)}
            aria-label="Mês anterior"
          >
            <IconChevronLeft size={18} />
          </button>
          <span className="fin-month-label">{formatMonthYear(cursor.y, cursor.m)}</span>
          <button
            className="fin-month-nav-btn"
            onClick={() => shiftMonth(1)}
            aria-label="Próximo mês"
          >
            <IconChevronRight size={18} />
          </button>
        </div>

        <button
          className="clx-btn clx-btn-ghost clx-btn-sm"
          onClick={() => setFiltrosOpen(true)}
        >
          Filtros
          {activeFilterCount > 0 && (
            <span
              className="clx-chip clx-chip-primary"
              style={{ marginLeft: 6, padding: '0 6px' }}
            >
              {activeFilterCount}
            </span>
          )}
        </button>

        <div className="fin-list-search">
          <input
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar lançamento…"
            aria-label="Buscar lançamento"
          />
        </div>

        <button className="clx-btn clx-btn-primary clx-btn-sm" onClick={openNew}>
          <IconPlus size={15} /> Novo lançamento
        </button>
      </div>

      {/* KPIs */}
      <div className="fin-kpi-grid">
        <FinKpiCard
          label="Receitas realizadas"
          value={formatCurrency(resumo.entradas)}
          tone="success"
          trend={buildTrend(resumo.entradas, prevResumo.entradas, prevMonthLabel)}
        />
        <FinKpiCard
          label="Despesas realizadas"
          value={formatCurrency(resumo.saidas)}
          tone="error"
          trend={buildTrend(resumo.saidas, prevResumo.saidas, prevMonthLabel)}
        />
        <FinKpiCard
          label="Previstas"
          value={formatCurrency(previstasTotal)}
          tone="info"
          hint={`${previstas.length} lançamento${previstas.length !== 1 ? 's' : ''}`}
        />
        <FinKpiCard
          label="Saldo do período"
          value={formatCurrency(resumo.saldoMes)}
          tone={saldoNeg ? 'error' : 'accent'}
          hint={
            saldoNeg
              ? 'Despesas maiores que receitas'
              : resumo.saldoMes > 0
                ? 'Receitas maiores que despesas'
                : 'Equilíbrio no período'
          }
        />
      </div>

      {/* Erro */}
      {error && (
        <div className="error-banner" role="alert" style={{ marginBottom: 16 }}>
          <IconAlertCircle size={16} /> {error}
          <button
            className="clx-btn clx-btn-ghost clx-btn-sm"
            style={{ marginLeft: 'auto' }}
            onClick={load}
          >
            <IconRefresh size={14} /> Tentar novamente
          </button>
        </div>
      )}

      {/* Conteúdo */}
      {loading ? (
        <div className="loading-overlay">
          <Spinner size={22} /> Carregando lançamentos…
        </div>
      ) : monthEmpty ? (
        <div className="empty-state">
          <h4>Nenhum lançamento em {formatMonthYear(cursor.y, cursor.m)}</h4>
          <p>Comece registrando uma receita ou despesa deste mês.</p>
          <button className="clx-btn clx-btn-primary" onClick={openNew} style={{ marginTop: 12 }}>
            <IconPlus size={15} /> Novo lançamento
          </button>
        </div>
      ) : grupos.length === 0 ? (
        <div className="empty-state">
          <h4>Nenhum resultado</h4>
          <p>
            {search.trim()
              ? `Nada encontrado para "${search.trim()}" neste mês.`
              : 'Nenhum lançamento corresponde aos filtros.'}
          </p>
          <button
            className="clx-btn clx-btn-ghost"
            style={{ marginTop: 12 }}
            onClick={() => {
              setSearch('')
              setFiltros(FILTROS_VAZIO)
            }}
          >
            Limpar busca e filtros
          </button>
        </div>
      ) : (
        <div className="fin-list-grouped">
          {grupos.map((g) => (
            <div key={g.data} className="fin-list-day-group">
              <div className="fin-list-day-header">
                <div className="fin-list-day-left">
                  <span className="fin-list-day-date">{formatDayHeaderBR(g.data)}</span>
                  <span className="fin-list-day-count">
                    {g.itens.length} lançamento{g.itens.length !== 1 ? 's' : ''}
                  </span>
                </div>
                <span className={`fin-list-day-total${g.totalDia < 0 ? ' negative' : ''}`}>
                  Total do dia: {formatCurrency(g.totalDia)}
                </span>
              </div>

              <div className="fin-list-rows">
                {g.itens.map((l) => {
                  const cat = catById.get(l.categoriaId)
                  const subcat = l.subcategoriaId ? catById.get(l.subcategoriaId) : undefined
                  const conta = contaById.get(l.contaId)
                  const isReceita = l.tipo === 'receita'
                  const subParts: string[] = []
                  if (l.observacao?.trim()) subParts.push(l.observacao.trim())
                  else if (l.servicoNome) subParts.push(l.servicoNome)
                  else if (subcat) subParts.push(subcat.nome)
                  else if (cat) subParts.push(cat.nome)
                  if (l.recorrencia === 'parcelada' && l.parcelasTotal)
                    subParts.push(`Parcela ${l.parcelaAtual ?? 1}/${l.parcelasTotal}`)
                  const sub = subParts.join(' · ')

                  return (
                    <div
                      key={l.id}
                      className="fin-list-row"
                      role="button"
                      tabIndex={0}
                      onClick={() => setSelectedId(l.id)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault()
                          setSelectedId(l.id)
                        }
                      }}
                    >
                      <CategoriaIcon categoria={cat} size={36} />

                      <div className="fin-list-main">
                        <div className="fin-list-row-title">{l.descricao}</div>
                        {sub && <div className="fin-list-row-sub">{sub}</div>}
                      </div>

                      <div className="fin-list-badges">
                        <OrigemChip origem={l.origem} />
                        {conta && <ContaBadge conta={conta} />}
                        <TipoChip recorrencia={l.recorrencia} />
                        <StatusChip status={l.status} />
                      </div>

                      <div className={`fin-list-value ${isReceita ? 'income' : 'expense'}`}>
                        {formatSigned(l)}
                      </div>

                      <div style={{ position: 'relative', flexShrink: 0 }}>
                        <button
                          className="fin-list-kebab"
                          aria-label="Mais ações"
                          aria-haspopup="menu"
                          onClick={(e) => {
                            e.stopPropagation()
                            setMenuFor((cur) => (cur === l.id ? null : l.id))
                          }}
                        >
                          <IconDots size={16} />
                        </button>

                        {menuFor === l.id && (
                          <div
                            role="menu"
                            onClick={(e) => e.stopPropagation()}
                            style={{
                              position: 'absolute',
                              top: 'calc(100% + 4px)',
                              right: 0,
                              minWidth: 168,
                              background: 'var(--clx-bg)',
                              border: '1px solid var(--clx-line)',
                              borderRadius: 'var(--clx-r-md)',
                              boxShadow: 'var(--clx-shadow-md)',
                              padding: 4,
                              zIndex: 25,
                              display: 'flex',
                              flexDirection: 'column',
                            }}
                          >
                            <RowMenuItem label="Ver detalhes" onClick={() => { setMenuFor(null); setSelectedId(l.id) }} />
                            <RowMenuItem label="Editar" onClick={() => openEdit(l)} />
                            <RowMenuItem label="Repetir" onClick={() => handleRepeat(l)} />
                            <RowMenuItem label="Copiar" onClick={() => handleDuplicate(l)} />
                            <RowMenuItem label="Excluir" danger onClick={() => askDelete(l)} />
                          </div>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          ))}

          <div
            style={{
              textAlign: 'center',
              padding: '14px 0 4px',
              fontSize: '0.78rem',
              color: 'var(--clx-ink-3)',
            }}
          >
            Exibindo {filtered.length} de {periodLancs.length} lançamento
            {periodLancs.length !== 1 ? 's' : ''} em {formatMonthYear(cursor.y, cursor.m)}
          </div>
        </div>
      )}

      {/* Painel lateral de detalhes */}
      {selected && (
        <LancamentoDetailPanel
          lancamento={selected}
          categoria={catById.get(selected.categoriaId)}
          subcategoria={selected.subcategoriaId ? catById.get(selected.subcategoriaId) : undefined}
          conta={contaById.get(selected.contaId)}
          isMobile={isMobile}
          busy={actionBusy}
          onClose={() => setSelectedId(null)}
          onEdit={openEdit}
          onRepeat={handleRepeat}
          onDuplicate={handleDuplicate}
          onDelete={askDelete}
          onVerOs={handleVerOs}
        />
      )}

      {/* Formulário criar/editar */}
      <LancamentoFormModal
        open={formOpen}
        initial={formInitial}
        categorias={categorias}
        contas={contas}
        onSubmit={handleFormSubmit}
        onClose={() => setFormOpen(false)}
      />

      {/* Filtros */}
      <Modal
        open={filtrosOpen}
        onClose={() => setFiltrosOpen(false)}
        title="Filtros"
        size="sm"
        footer={
          <>
            <button
              className="clx-btn clx-btn-ghost"
              onClick={() => setFiltros(FILTROS_VAZIO)}
              disabled={activeFilterCount === 0}
            >
              Limpar
            </button>
            <button className="clx-btn clx-btn-primary" onClick={() => setFiltrosOpen(false)}>
              Aplicar
            </button>
          </>
        }
      >
        <div className="form-grid">
          <div className="form-field">
            <label>Tipo</label>
            <select
              value={filtros.tipo}
              onChange={(e) =>
                setFiltros((f) => ({ ...f, tipo: e.target.value as Filtros['tipo'] }))
              }
            >
              <option value="">Todos</option>
              <option value="receita">Receita</option>
              <option value="despesa">Despesa</option>
            </select>
          </div>
          <div className="form-field">
            <label>Status</label>
            <select
              value={filtros.status}
              onChange={(e) =>
                setFiltros((f) => ({ ...f, status: e.target.value as Filtros['status'] }))
              }
            >
              <option value="">Todos</option>
              <option value="pago">Pago</option>
              <option value="pendente">Pendente</option>
              <option value="previsto">Previsto</option>
              <option value="em_atraso">Em atraso</option>
            </select>
          </div>
          <div className="form-field">
            <label>Categoria</label>
            <select
              value={filtros.categoriaId}
              onChange={(e) => setFiltros((f) => ({ ...f, categoriaId: e.target.value }))}
            >
              <option value="">Todas</option>
              {categoriasRaiz.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.nome}
                </option>
              ))}
            </select>
          </div>
          <div className="form-field">
            <label>Conta</label>
            <select
              value={filtros.contaId}
              onChange={(e) => setFiltros((f) => ({ ...f, contaId: e.target.value }))}
            >
              <option value="">Todas</option>
              {contas.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.nome}
                </option>
              ))}
            </select>
          </div>
        </div>
      </Modal>

      {/* Confirmação de exclusão */}
      <Modal
        open={!!confirmTarget}
        onClose={() => (deleting ? undefined : setConfirmTarget(null))}
        title="Excluir lançamento"
        size="sm"
        footer={
          <>
            <button
              className="clx-btn clx-btn-ghost"
              onClick={() => setConfirmTarget(null)}
              disabled={deleting}
            >
              Cancelar
            </button>
            <button className="clx-btn clx-btn-danger" onClick={confirmDelete} disabled={deleting}>
              {deleting ? (
                <>
                  <Spinner size={14} /> Excluindo…
                </>
              ) : (
                <>
                  <IconTrash size={14} /> Excluir
                </>
              )}
            </button>
          </>
        }
      >
        <p style={{ fontSize: '0.9rem', color: 'var(--clx-ink-2)' }}>
          Tem certeza que deseja excluir{' '}
          <strong>{confirmTarget?.descricao}</strong>? Esta ação não pode ser desfeita.
        </p>
      </Modal>

      {/* Overlay de click-away do menu do kebab */}
      {menuFor && (
        <div
          onClick={() => setMenuFor(null)}
          style={{ position: 'fixed', inset: 0, zIndex: 24 }}
          aria-hidden="true"
        />
      )}

      {/* Toasts */}
      {toasts.length > 0 && (
        <div
          style={{
            position: 'fixed',
            bottom: 20,
            left: '50%',
            transform: 'translateX(-50%)',
            display: 'flex',
            flexDirection: 'column',
            gap: 8,
            zIndex: 60,
            width: '90vw',
            maxWidth: 360,
            pointerEvents: 'none',
          }}
        >
          {toasts.map((t) => (
            <div
              key={t.id}
              style={{
                padding: '10px 16px',
                borderRadius: 'var(--clx-r-pill)',
                fontSize: '0.85rem',
                fontWeight: 600,
                color: '#fff',
                background:
                  t.type === 'success'
                    ? 'var(--clx-success)'
                    : t.type === 'error'
                      ? 'var(--clx-error)'
                      : 'var(--clx-accent)',
                boxShadow: 'var(--clx-shadow-md)',
                textAlign: 'center',
                animation: 'modal-fade-in 0.2s ease',
              }}
            >
              {t.text}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

/* ============================================================
 * Item do menu de contexto (kebab) da linha
 * ============================================================ */
interface RowMenuItemProps {
  label: string
  onClick: () => void
  danger?: boolean
}

function RowMenuItem({ label, onClick, danger }: RowMenuItemProps) {
  return (
    <button
      type="button"
      role="menuitem"
      onClick={(e) => {
        e.stopPropagation()
        onClick()
      }}
      style={{
        textAlign: 'left',
        padding: '8px 12px',
        background: 'none',
        border: 'none',
        borderRadius: 'var(--clx-r-sm)',
        cursor: 'pointer',
        fontSize: '0.82rem',
        fontWeight: 500,
        color: danger ? 'var(--clx-error)' : 'var(--clx-ink-2)',
      }}
    >
      {label}
    </button>
  )
}
