/**
 * financeiro/LimiteGastos.tsx — Tela LIMITE DE GASTOS do módulo Financeiro.
 *
 * Lista vertical simples de limites por categoria: ícone + nome + "R$ gasto /
 * R$ limite" + barra de progresso (tone por faixa: <80% success, 80-100%
 * warning, >100% error) + percentual. O gasto é DERIVADO via progressoLimite,
 * calculado sobre os lançamentos do MÊS corrente (gasto_mes — não soma meses
 * anteriores). Ações: novo limite, editar valor, excluir (com confirmação em
 * modal — sem window.confirm). Estado vazio com CTA.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  listLimites,
  listCategorias,
  listLancamentos,
  createLimite,
  updateLimite,
  deleteLimite,
  progressoLimite,
  lancamentosDoPeriodo,
  mesPeriodo,
} from '../../../lib/financeiro/store'
import type {
  Categoria,
  Lancamento,
  LimiteGasto,
} from '../../../lib/financeiro/types'
import { formatCurrency } from '../../../lib/collections'
import { Spinner } from '../../../components/ui/Spinner'
import { Modal } from '../../../components/ui/Modal'
import { IconAlertCircle, IconPlus, IconEdit, IconTrash } from '../../../components/ui/Icon'
import { ProgressBar, CategoriaIcon } from './components'

const MESES_FULL = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
]

type Tone = 'success' | 'warning' | 'error'

/** Tom por faixa de uso (real ratio, pode passar de 1). */
function toneForRatio(ratio: number): Tone {
  if (ratio > 1) return 'error'
  if (ratio >= 0.8) return 'warning'
  return 'success'
}

interface LimiteView {
  limite: LimiteGasto
  categoria?: Categoria
  gasto: number
  teto: number
  /** Razão real gasto/teto (pode exceder 1). 0 quando teto ≤ 0. */
  ratio: number
  /** Razão clampada [0,1] para a barra. */
  pctBar: number
}

export default function LimiteGastos() {
  // Congela a data de referência no mount: um `new Date()` solto era recriado a
  // cada render e furava o cache do useMemo (a dep nunca era a mesma instância).
  const mountDate = useMemo(() => new Date(), [])
  const periodo = useMemo(
    () => mesPeriodo(mountDate.getFullYear(), mountDate.getMonth()),
    [mountDate],
  )
  const mesLabel = `${MESES_FULL[mountDate.getMonth()]} de ${mountDate.getFullYear()}`

  const [limites, setLimites] = useState<LimiteGasto[]>([])
  const [categorias, setCategorias] = useState<Categoria[]>([])
  const [lancamentos, setLancamentos] = useState<Lancamento[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  /* Modal de criação/edição */
  const [formOpen, setFormOpen] = useState(false)
  const [editing, setEditing] = useState<LimiteGasto | null>(null)
  const [formCat, setFormCat] = useState('')
  const [formValor, setFormValor] = useState('')
  const [formErr, setFormErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  /* Modal de exclusão */
  const [deleting, setDeleting] = useState<LimiteView | null>(null)
  const [deletingBusy, setDeletingBusy] = useState(false)

  const genRef = useRef(0)

  const load = useCallback(async () => {
    const gen = ++genRef.current
    try {
      setLoading(true)
      setError(null)
      const [lim, cat, lancs] = await Promise.all([listLimites(), listCategorias(), listLancamentos()])
      if (gen !== genRef.current) return
      setLimites(lim)
      setCategorias(cat)
      setLancamentos(lancs)
    } catch {
      if (gen === genRef.current) setError('Não foi possível carregar os limites de gastos.')
    } finally {
      if (gen === genRef.current) setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const catById = useMemo(() => {
    const m = new Map<string, Categoria>()
    categorias.forEach((c) => m.set(c.id, c))
    return m
  }, [categorias])

  /** Lançamentos do mês corrente (base do gasto_mes). */
  const lancsMes = useMemo(() => lancamentosDoPeriodo(lancamentos, periodo), [lancamentos, periodo])

  const views: LimiteView[] = useMemo(() => {
    return limites
      .map((limite) => {
        const prog = progressoLimite(limite, lancsMes)
        const ratio = limite.limite > 0 ? prog.gasto / limite.limite : 0
        return {
          limite,
          categoria: catById.get(limite.categoriaId),
          gasto: prog.gasto,
          teto: limite.limite,
          ratio,
          pctBar: prog.pct,
        }
      })
      .sort((a, b) => b.ratio - a.ratio)
  }, [limites, lancsMes, catById])

  /** Categorias de despesa ainda SEM limite (para o seletor de novo limite). */
  const categoriasDisponiveis = useMemo(() => {
    const usadas = new Set(limites.map((l) => l.categoriaId))
    return categorias.filter((c) => c.tipo === 'despesa' && !c.arquivada && (editing?.categoriaId === c.id || !usadas.has(c.id)))
  }, [categorias, limites, editing])

  function openNew() {
    setEditing(null)
    setFormCat('')
    setFormValor('')
    setFormErr(null)
    setFormOpen(true)
  }

  function openEdit(v: LimiteView) {
    setEditing(v.limite)
    setFormCat(v.limite.categoriaId)
    setFormValor(String(v.limite.limite))
    setFormErr(null)
    setFormOpen(true)
  }

  async function handleSave() {
    const valor = Number(formValor)
    if (!editing && !formCat) { setFormErr('Selecione uma categoria.'); return }
    if (isNaN(valor) || valor < 0) { setFormErr('Informe um valor de limite válido.'); return }
    try {
      setSaving(true)
      setFormErr(null)
      if (editing) {
        await updateLimite(editing.id, { limite: valor })
      } else {
        await createLimite({ categoriaId: formCat, limite: valor })
      }
      setFormOpen(false)
      await load()
    } catch {
      setFormErr('Não foi possível salvar o limite.')
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete() {
    if (!deleting) return
    try {
      setDeletingBusy(true)
      await deleteLimite(deleting.limite.id)
      setDeleting(null)
      await load()
    } catch {
      setError('Não foi possível excluir o limite.')
      setDeleting(null)
    } finally {
      setDeletingBusy(false)
    }
  }

  return (
    <div>
      {/* Header */}
      <div className="section-header" style={{ alignItems: 'flex-start' }}>
        <div>
          <h2>Limite de gastos</h2>
          <p style={{ color: 'var(--clx-ink-3)', fontSize: '0.85rem', marginTop: 2 }}>
            Acompanhe o quanto já gastou por categoria em {mesLabel}.
          </p>
        </div>
        <button className="clx-btn clx-btn-primary clx-btn-sm" onClick={openNew}>
          <IconPlus size={14} /> Novo limite
        </button>
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
      ) : views.length === 0 ? (
        <div className="empty-state">
          <h4>Nenhum limite de gastos</h4>
          <p>Defina tetos de gasto por categoria para acompanhar o orçamento do mês.</p>
          <button className="clx-btn clx-btn-primary clx-btn-sm" onClick={openNew} style={{ marginTop: 12 }}>
            <IconPlus size={14} /> Criar primeiro limite
          </button>
        </div>
      ) : (
        <div className="clx-card" style={{ padding: 0 }}>
          {views.map((v, i) => {
            const tone = toneForRatio(v.ratio)
            const pctReal = Math.round(v.ratio * 100)
            const ultrapassado = v.gasto - v.teto
            const toneColor =
              tone === 'error' ? 'var(--clx-error)' : tone === 'warning' ? 'var(--clx-warning)' : 'var(--clx-success)'
            return (
              <div
                key={v.limite.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 14,
                  padding: '16px 18px',
                  borderTop: i === 0 ? 'none' : '1px solid var(--clx-line)',
                }}
              >
                {v.categoria
                  ? <CategoriaIcon categoria={v.categoria} size={36} />
                  : <span className="fin-list-icon" style={{ background: 'var(--clx-ink-3)' }} aria-hidden />}

                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, marginBottom: 6 }}>
                    <span style={{ fontWeight: 600, color: 'var(--clx-ink)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {v.categoria?.nome ?? 'Categoria removida'}
                    </span>
                    <span style={{ fontSize: '0.82rem', color: 'var(--clx-ink-3)', whiteSpace: 'nowrap' }}>
                      <strong style={{ color: toneColor }}>{formatCurrency(v.gasto)}</strong>
                      {' / '}{formatCurrency(v.teto)}
                    </span>
                  </div>

                  {v.teto > 0 ? (
                    <ProgressBar pct={v.ratio * 100} tone={tone} />
                  ) : (
                    <div style={{ fontSize: '0.75rem', color: 'var(--clx-warning)' }}>Limite zerado</div>
                  )}

                  <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 5 }}>
                    <span style={{ fontSize: '0.75rem', fontWeight: 700, color: toneColor }}>
                      {v.teto > 0 ? `${pctReal}%` : '—'}
                    </span>
                    {v.ratio > 1 && (
                      <span style={{ fontSize: '0.72rem', color: 'var(--clx-error)' }}>
                        Ultrapassado por {formatCurrency(ultrapassado)}
                      </span>
                    )}
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                  <button className="icon-btn" onClick={() => openEdit(v)} aria-label={`Editar limite de ${v.categoria?.nome ?? ''}`} title="Editar">
                    <IconEdit size={15} />
                  </button>
                  <button className="icon-btn" onClick={() => setDeleting(v)} aria-label={`Excluir limite de ${v.categoria?.nome ?? ''}`} title="Excluir">
                    <IconTrash size={15} />
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Modal criar/editar */}
      <Modal
        open={formOpen}
        onClose={() => setFormOpen(false)}
        title={editing ? 'Editar limite' : 'Novo limite de gastos'}
        size="sm"
        footer={
          <>
            <button className="clx-btn clx-btn-ghost" onClick={() => setFormOpen(false)} disabled={saving}>Cancelar</button>
            <button className="clx-btn clx-btn-primary" onClick={handleSave} disabled={saving}>
              {saving ? <><Spinner size={14} /> Salvando…</> : 'Salvar'}
            </button>
          </>
        }
      >
        {formErr && (
          <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
            <IconAlertCircle size={15} /> {formErr}
          </div>
        )}
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="lim-cat">Categoria <span className="req">*</span></label>
            <select
              id="lim-cat"
              value={formCat}
              onChange={(e) => setFormCat(e.target.value)}
              disabled={!!editing}
            >
              <option value="">Selecione…</option>
              {categoriasDisponiveis.map((c) => (
                <option key={c.id} value={c.id}>{c.nome}</option>
              ))}
            </select>
            {editing && (
              <span style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)' }}>
                A categoria não pode ser alterada — exclua e crie um novo limite.
              </span>
            )}
          </div>
          <div className="form-field">
            <label htmlFor="lim-valor">Valor do limite (R$) <span className="req">*</span></label>
            <input
              id="lim-valor"
              type="number"
              min="0"
              step="0.01"
              value={formValor}
              onChange={(e) => setFormValor(e.target.value)}
              placeholder="0,00"
            />
          </div>
        </div>
      </Modal>

      {/* Modal excluir */}
      <Modal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        title="Excluir limite"
        size="sm"
        footer={
          <>
            <button className="clx-btn clx-btn-ghost" onClick={() => setDeleting(null)} disabled={deletingBusy}>Cancelar</button>
            <button className="clx-btn clx-btn-danger" onClick={handleDelete} disabled={deletingBusy}>
              {deletingBusy ? <><Spinner size={14} /> Excluindo…</> : 'Excluir'}
            </button>
          </>
        }
      >
        <p style={{ fontSize: '0.9rem', color: 'var(--clx-ink-2)' }}>
          Tem certeza que deseja excluir o limite de{' '}
          <strong>{deleting?.categoria?.nome ?? 'esta categoria'}</strong>? Os lançamentos não serão afetados.
        </p>
      </Modal>
    </div>
  )
}
