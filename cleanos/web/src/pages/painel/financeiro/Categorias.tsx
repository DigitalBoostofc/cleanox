/**
 * Categorias — Categorias financeiras (PANE FIN-B4, estilo Organizze).
 *
 * Header + abas Despesas/Receitas + "Nova subcategoria"/"Nova categoria" · duas
 * colunas (despesas / receitas) com categorias e subcategorias indentadas (via
 * parentId), contagem de lançamentos derivada de listLancamentos, ações editar /
 * arquivar / +subcategoria · coluna lateral "Resumo das categorias" + dica.
 * Regras: arquivar = oculta sem perder histórico; excluir bloqueado quando há
 * lançamentos ou subcategorias (orienta arquivar).
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  createCategoria,
  deleteCategoria,
  listCategorias,
  listLancamentos,
  updateCategoria,
} from '../../../lib/financeiro/store'
import type {
  Categoria,
  CategoriaInput,
  Lancamento,
  TipoLancamento,
} from '../../../lib/financeiro/types'
import { Spinner } from '../../../components/ui/Spinner'
import { IconAlertCircle, IconArrowRight, IconPlus } from '../../../components/ui/Icon'
import { useIsMobile } from '../../../hooks/useIsMobile'
import { CategoriaRow } from './categorias/CategoriaRow'
import { CategoriaModal } from './categorias/CategoriaModal'
import { IconArchive, IconInfo, IconList } from './categorias/atoms'

interface ModalState {
  open: boolean
  mode: 'new' | 'edit'
  categoria?: Categoria
  presetParentId?: string
}

const MODAL_FECHADO: ModalState = { open: false, mode: 'new' }

export default function Categorias() {
  const isMobile = useIsMobile()

  const [categorias, setCategorias] = useState<Categoria[]>([])
  const [lancs, setLancs] = useState<Lancamento[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [aba, setAba] = useState<TipoLancamento>('despesa')
  const [showArquivadas, setShowArquivadas] = useState(false)

  const [modal, setModal] = useState<ModalState>(MODAL_FECHADO)
  const [saving, setSaving] = useState(false)
  const [modalErr, setModalErr] = useState<string | null>(null)
  const [busyRowId, setBusyRowId] = useState<string | null>(null)

  const loadGenRef = useRef(0)

  const load = useCallback(async () => {
    const gen = ++loadGenRef.current
    try {
      setLoading(true)
      setError(null)
      const [cats, ls] = await Promise.all([listCategorias(), listLancamentos()])
      if (gen !== loadGenRef.current) return
      setCategorias(cats)
      setLancs(ls)
    } catch {
      if (gen === loadGenRef.current) setError('Não foi possível carregar as categorias.')
    } finally {
      if (gen === loadGenRef.current) setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  /* ---- Contagem de lançamentos por categoria ----
   * Convenção do seed: categoriaId = mãe, subcategoriaId = filha.
   * Mãe → conta por categoriaId · Subcategoria → conta por subcategoriaId. */
  const { porCategoria, porSub } = useMemo(() => {
    const porCategoria = new Map<string, number>()
    const porSub = new Map<string, number>()
    for (const l of lancs) {
      porCategoria.set(l.categoriaId, (porCategoria.get(l.categoriaId) ?? 0) + 1)
      if (l.subcategoriaId) porSub.set(l.subcategoriaId, (porSub.get(l.subcategoriaId) ?? 0) + 1)
    }
    return { porCategoria, porSub }
  }, [lancs])

  const countFor = useCallback(
    (cat: Categoria): number => (cat.parentId ? porSub.get(cat.id) ?? 0 : porCategoria.get(cat.id) ?? 0),
    [porCategoria, porSub],
  )

  const childrenOf = useCallback(
    (id: string): Categoria[] => categorias.filter((c) => c.parentId === id),
    [categorias],
  )

  /* ---- Resumo ---- */
  const resumo = useMemo(() => {
    const ativas = categorias.filter((c) => !c.arquivada)
    const despesas = ativas.filter((c) => c.tipo === 'despesa').length
    const receitas = ativas.filter((c) => c.tipo === 'receita').length
    const arquivadas = categorias.filter((c) => c.arquivada).length
    return { despesas, receitas, total: despesas + receitas, arquivadas }
  }, [categorias])

  /* ---- Ações ---- */
  function abrirNovaCategoria() {
    setModalErr(null)
    setModal({ open: true, mode: 'new' })
  }
  function abrirNovaSubcategoria() {
    setModalErr(null)
    // Pré-seleciona a 1ª categoria-mãe da aba ativa (se houver).
    const primeiraMae = categorias.find((c) => c.tipo === aba && !c.parentId && !c.arquivada)
    setModal({ open: true, mode: 'new', presetParentId: primeiraMae?.id })
  }
  function abrirSubDe(cat: Categoria) {
    setModalErr(null)
    setModal({ open: true, mode: 'new', presetParentId: cat.id })
  }
  function abrirEdicao(cat: Categoria) {
    setModalErr(null)
    setModal({ open: true, mode: 'edit', categoria: cat })
  }

  async function toggleArquivar(cat: Categoria) {
    try {
      setBusyRowId(cat.id)
      setError(null)
      await updateCategoria(cat.id, { arquivada: !cat.arquivada })
      await load()
    } catch {
      setError('Não foi possível alterar o arquivamento da categoria.')
    } finally {
      setBusyRowId(null)
    }
  }

  async function handleSubmit(input: CategoriaInput) {
    try {
      setSaving(true)
      setModalErr(null)
      if (modal.mode === 'edit' && modal.categoria) {
        await updateCategoria(modal.categoria.id, input)
      } else {
        await createCategoria(input)
      }
      setModal(MODAL_FECHADO)
      await load()
    } catch {
      setModalErr('Não foi possível salvar a categoria.')
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete() {
    if (!modal.categoria) return
    try {
      setSaving(true)
      setModalErr(null)
      const ok = await deleteCategoria(modal.categoria.id)
      if (!ok) {
        setModalErr('Categoria não encontrada.')
        return
      }
      setModal(MODAL_FECHADO)
      await load()
    } catch {
      setModalErr('Não foi possível excluir a categoria.')
    } finally {
      setSaving(false)
    }
  }

  const maes = useMemo(() => categorias.filter((c) => !c.parentId && !c.arquivada), [categorias])

  const tipoTitulo: Record<TipoLancamento, string> = {
    despesa: 'Categorias de despesas',
    receita: 'Categorias de receitas',
  }

  // Colunas visíveis: no mobile, só a aba ativa; no desktop, ambas.
  const tiposVisiveis: TipoLancamento[] = isMobile ? [aba] : ['despesa', 'receita']

  return (
    <div>
      {/* Header */}
      <div className="section-header" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 4 }}>
        <h2 style={{ margin: 0 }}>Categorias financeiras</h2>
        <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--clx-ink-3)' }}>
          Organize suas receitas e despesas com categorias e subcategorias.
        </p>
      </div>

      {/* Abas + ações */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          flexWrap: 'wrap',
          margin: '14px 0 18px',
        }}
      >
        <div className="tab-bar" role="tablist">
          <button
            className={`tab-item${aba === 'despesa' ? ' active' : ''}`}
            role="tab"
            aria-selected={aba === 'despesa'}
            onClick={() => setAba('despesa')}
          >
            Despesas
          </button>
          <button
            className={`tab-item${aba === 'receita' ? ' active' : ''}`}
            role="tab"
            aria-selected={aba === 'receita'}
            onClick={() => setAba('receita')}
          >
            Receitas
          </button>
        </div>
        <div style={{ display: 'flex', gap: 8, marginLeft: 'auto', flexWrap: 'wrap' }}>
          <button
            className="clx-btn clx-btn-ghost clx-btn-sm"
            onClick={abrirNovaSubcategoria}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
          >
            <IconPlus size={15} /> Nova subcategoria
          </button>
          <button
            className="clx-btn clx-btn-primary clx-btn-sm"
            onClick={abrirNovaCategoria}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
          >
            <IconPlus size={15} /> Nova categoria
          </button>
        </div>
      </div>

      {error && (
        <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
          <IconAlertCircle size={16} /> {error}
          <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load} style={{ marginLeft: 'auto' }}>
            Tentar novamente
          </button>
        </div>
      )}

      {loading ? (
        <div className="loading-overlay">
          <Spinner size={22} /> Carregando…
        </div>
      ) : (
        <div
          className="fin-cat-main"
          style={{
            display: 'grid',
            gridTemplateColumns: isMobile ? '1fr' : '1fr 1fr 320px',
            gap: 24,
            alignItems: 'start',
          }}
        >
          {tiposVisiveis.map((tipo) => (
            <ColunaCategorias
              key={tipo}
              titulo={tipoTitulo[tipo]}
              tipo={tipo}
              categorias={categorias}
              showArquivadas={showArquivadas}
              countFor={countFor}
              busyRowId={busyRowId}
              onEditar={abrirEdicao}
              onArquivar={toggleArquivar}
              onAddSub={abrirSubDe}
            />
          ))}

          <ResumoCategorias
            resumo={resumo}
            showArquivadas={showArquivadas}
            onToggleArquivadas={() => setShowArquivadas((s) => !s)}
          />
        </div>
      )}

      <CategoriaModal
        open={modal.open}
        mode={modal.mode}
        categoria={modal.categoria}
        presetTipo={aba}
        presetParentId={modal.presetParentId}
        parents={maes}
        lancCount={modal.categoria ? countFor(modal.categoria) : 0}
        hasChildren={modal.categoria ? childrenOf(modal.categoria.id).length > 0 : false}
        saving={saving}
        error={modalErr}
        onSubmit={handleSubmit}
        onDelete={handleDelete}
        onClose={() => setModal(MODAL_FECHADO)}
      />
    </div>
  )
}

/* ============================================================
 * Coluna de categorias de um tipo (com subcategorias indentadas)
 * ============================================================ */

function ColunaCategorias({
  titulo,
  tipo,
  categorias,
  showArquivadas,
  countFor,
  busyRowId,
  onEditar,
  onArquivar,
  onAddSub,
}: {
  titulo: string
  tipo: TipoLancamento
  categorias: Categoria[]
  showArquivadas: boolean
  countFor: (c: Categoria) => number
  busyRowId: string | null
  onEditar: (c: Categoria) => void
  onArquivar: (c: Categoria) => void
  onAddSub: (c: Categoria) => void
}) {
  const doTipo = categorias.filter((c) => c.tipo === tipo)
  const ativas = doTipo.filter((c) => !c.arquivada)
  const arquivadas = doTipo.filter((c) => c.arquivada)
  const totalCount = ativas.length

  const maes = ativas.filter((c) => !c.parentId)
  const maesIds = new Set(maes.map((m) => m.id))
  // Subcategorias órfãs (mãe arquivada/inexistente) sobem para o topo.
  const orfas = ativas.filter((c) => c.parentId && !maesIds.has(c.parentId))

  const vazio = maes.length === 0 && orfas.length === 0

  return (
    <section
      className="fin-cat-list clx-card"
      style={{ overflow: 'hidden', display: 'flex', flexDirection: 'column' }}
    >
      <header
        className="fin-cat-list-header"
        style={{
          padding: '14px 18px',
          borderBottom: '1px solid var(--clx-line)',
          background: 'var(--clx-bg-2)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <h3 style={{ margin: 0, fontSize: '0.95rem', fontWeight: 700, color: 'var(--clx-ink)' }}>{titulo}</h3>
        <span style={{ fontSize: '0.8rem', color: 'var(--clx-ink-3)' }}>{totalCount}</span>
      </header>

      {vazio ? (
        <div className="empty-state" style={{ padding: '32px 16px' }}>
          <p style={{ margin: 0, color: 'var(--clx-ink-3)' }}>
            Nenhuma categoria de {tipo === 'despesa' ? 'despesa' : 'receita'}.
          </p>
        </div>
      ) : (
        <div className="fin-cat-rows">
          {maes.map((mae) => {
            const filhas = ativas.filter((c) => c.parentId === mae.id)
            return (
              <div key={mae.id}>
                <CategoriaRow
                  categoria={mae}
                  count={countFor(mae)}
                  busy={busyRowId === mae.id}
                  onEditar={() => onEditar(mae)}
                  onArquivar={() => onArquivar(mae)}
                  onAddSub={() => onAddSub(mae)}
                />
                {filhas.map((f) => (
                  <CategoriaRow
                    key={f.id}
                    categoria={f}
                    count={countFor(f)}
                    indent
                    busy={busyRowId === f.id}
                    onEditar={() => onEditar(f)}
                    onArquivar={() => onArquivar(f)}
                  />
                ))}
              </div>
            )
          })}
          {orfas.map((o) => (
            <CategoriaRow
              key={o.id}
              categoria={o}
              count={countFor(o)}
              busy={busyRowId === o.id}
              onEditar={() => onEditar(o)}
              onArquivar={() => onArquivar(o)}
            />
          ))}
        </div>
      )}

      {/* Arquivadas */}
      {showArquivadas && arquivadas.length > 0 && (
        <div>
          <div
            style={{
              padding: '10px 18px',
              background: 'var(--clx-bg-2)',
              borderTop: '1px solid var(--clx-line)',
              borderBottom: '1px solid var(--clx-line)',
              fontSize: '0.74rem',
              fontWeight: 700,
              textTransform: 'uppercase',
              letterSpacing: '0.06em',
              color: 'var(--clx-ink-3)',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <IconArchive size={13} /> Arquivadas ({arquivadas.length})
          </div>
          <div className="fin-cat-rows">
            {arquivadas.map((c) => (
              <CategoriaRow
                key={c.id}
                categoria={c}
                count={countFor(c)}
                indent={!!c.parentId}
                busy={busyRowId === c.id}
                onEditar={() => onEditar(c)}
                onArquivar={() => onArquivar(c)}
              />
            ))}
          </div>
        </div>
      )}
    </section>
  )
}

/* ============================================================
 * Resumo das categorias (coluna lateral)
 * ============================================================ */

function ResumoCategorias({
  resumo,
  showArquivadas,
  onToggleArquivadas,
}: {
  resumo: { despesas: number; receitas: number; total: number; arquivadas: number }
  showArquivadas: boolean
  onToggleArquivadas: () => void
}) {
  const itens = [
    { label: 'Total de categorias', valor: resumo.total, icon: <IconList size={16} />, tone: 'var(--clx-ink-2)' },
    { label: 'Categorias de despesas', valor: resumo.despesas, icon: <IconList size={16} />, tone: 'var(--clx-error)' },
    { label: 'Categorias de receitas', valor: resumo.receitas, icon: <IconList size={16} />, tone: 'var(--clx-success)' },
    { label: 'Categorias arquivadas', valor: resumo.arquivadas, icon: <IconArchive size={16} />, tone: 'var(--clx-ink-3)' },
  ]

  return (
    <aside style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div className="fin-cat-summary clx-card" style={{ padding: '20px 22px' }}>
        <h3 style={{ margin: '0 0 14px', fontSize: '0.95rem', fontWeight: 700, color: 'var(--clx-ink)' }}>
          Resumo das categorias
        </h3>
        {itens.map((it, i) => (
          <div
            key={it.label}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              padding: '10px 0',
              borderBottom: i < itens.length - 1 ? '1px dashed var(--clx-line)' : 'none',
            }}
          >
            <span style={{ color: it.tone, display: 'inline-flex' }}>{it.icon}</span>
            <span style={{ flex: 1, fontSize: '0.82rem', color: 'var(--clx-ink-2)' }}>{it.label}</span>
            <strong style={{ fontSize: '0.9rem', color: 'var(--clx-ink)' }}>{it.valor}</strong>
          </div>
        ))}
        {resumo.arquivadas > 0 && (
          <button
            className="clx-btn clx-btn-ghost clx-btn-sm"
            onClick={onToggleArquivadas}
            style={{ marginTop: 12, display: 'inline-flex', alignItems: 'center', gap: 6 }}
          >
            {showArquivadas ? 'Ocultar categorias arquivadas' : 'Ver categorias arquivadas'}
            <IconArrowRight size={14} />
          </button>
        )}
      </div>

      {/* Dica */}
      <div
        className="fin-cat-tip"
        style={{
          background: 'rgba(0, 194, 184, 0.04)',
          border: '1.5px solid var(--clx-primary)',
          borderRadius: 'var(--clx-r-md, 8px)',
          padding: '14px 16px',
          display: 'flex',
          gap: 10,
        }}
      >
        <span style={{ color: 'var(--clx-primary)', flexShrink: 0, marginTop: 1 }}>
          <IconInfo size={18} />
        </span>
        <div>
          <div style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--clx-ink)', marginBottom: 4 }}>Dica</div>
          <p style={{ margin: 0, fontSize: '0.78rem', color: 'var(--clx-ink-2)', lineHeight: 1.5 }}>
            Organize suas categorias para ter relatórios mais precisos e uma melhor análise financeira do seu negócio.
          </p>
        </div>
      </div>
    </aside>
  )
}
