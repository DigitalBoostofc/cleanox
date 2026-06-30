/**
 * ServicosListPage — lista principal de /painel/servicos.
 * Replica o card "Outros serviços cadastrados" do mockup como página cheia,
 * com busca, filtros por categoria/grupo, toggle de status inline e ações
 * (editar / duplicar / excluir). Tabela no desktop, cards no mobile.
 */

import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  deleteServico,
  duplicateServico,
  listServicos,
  updateServico,
} from '../../../lib/servicos/store'
import type { Categoria, Grupo, Servico } from '../../../lib/servicos/types'
import {
  categoriaLabel,
  formatTempoMedio,
  formatValorServico,
  grupoLabel,
  servicoStatusLabel,
  tipoValorLabel,
} from '../../../lib/servicos/labels'
import { Spinner } from '../../../components/ui/Spinner'
import { Modal } from '../../../components/ui/Modal'
import {
  IconAlertCircle,
  IconEdit,
  IconPlus,
  IconSearch,
  IconTrash,
} from '../../../components/ui/Icon'
import { IconCopy, IconMoreVertical } from './components/icons'
import { CategoriaGrupo, CategoriaIcon } from './components/GrupoChip'
import { useIsMobile } from '../../../hooks/useIsMobile'

const CATEGORIAS: Categoria[] = ['veicular', 'residencial']
const GRUPOS: Grupo[] = ['plano', 'promocao', 'adicional', 'avulsos', 'sofa', 'colchao', 'outros']

export default function ServicosListPage() {
  const navigate = useNavigate()
  const isMobile = useIsMobile()

  const [servicos, setServicos] = useState<Servico[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [search, setSearch] = useState('')
  const [fCategoria, setFCategoria] = useState<Categoria | ''>('')
  const [fGrupo, setFGrupo] = useState<Grupo | ''>('')

  const [menuId, setMenuId] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<Servico | null>(null)
  const [deleting, setDeleting] = useState(false)
  const [busyId, setBusyId] = useState<string | null>(null)

  const load = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const list = await listServicos()
      list.sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'))
      setServicos(list)
    } catch {
      setError('Não foi possível carregar os serviços.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  /* Fecha o kebab ao clicar fora ou apertar Esc. */
  useEffect(() => {
    if (menuId === null) return
    const onDown = () => setMenuId(null)
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setMenuId(null)
    }
    document.addEventListener('click', onDown)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('click', onDown)
      document.removeEventListener('keydown', onKey)
    }
  }, [menuId])

  const searchLower = search.trim().toLowerCase()
  const filtered = servicos.filter((s) => {
    if (searchLower && !s.nome.toLowerCase().includes(searchLower)) return false
    if (fCategoria && s.categoria !== fCategoria) return false
    if (fGrupo && s.grupo !== fGrupo) return false
    return true
  })

  async function toggleStatus(s: Servico) {
    const next = s.status === 'ativo' ? 'inativo' : 'ativo'
    setBusyId(s.id)
    // atualização otimista
    setServicos((prev) => prev.map((x) => (x.id === s.id ? { ...x, status: next } : x)))
    try {
      await updateServico(s.id, { status: next })
    } catch {
      setServicos((prev) => prev.map((x) => (x.id === s.id ? { ...x, status: s.status } : x)))
      setError('Não foi possível atualizar o status do serviço.')
    } finally {
      setBusyId(null)
    }
  }

  async function handleDuplicate(s: Servico) {
    setMenuId(null)
    setBusyId(s.id)
    try {
      const novo = await duplicateServico(s.id)
      navigate(`/painel/servicos/${novo.id}`)
    } catch {
      setError('Não foi possível duplicar o serviço.')
      setBusyId(null)
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return
    setDeleting(true)
    try {
      await deleteServico(deleteTarget.id)
      setDeleteTarget(null)
      await load()
    } catch {
      setError('Não foi possível excluir o serviço.')
      setDeleteTarget(null)
    } finally {
      setDeleting(false)
    }
  }

  const hasFilters = !!search || !!fCategoria || !!fGrupo
  const emptyTitle = hasFilters ? 'Nenhum serviço encontrado' : 'Nenhum serviço cadastrado'
  const emptyHint = hasFilters
    ? 'Tente ajustar a busca ou os filtros.'
    : 'Clique em "Novo serviço" para começar.'

  function StatusToggle({ s }: { s: Servico }) {
    return (
      <button
        type="button"
        className={`svc-status svc-status-btn svc-status-${s.status}`}
        onClick={(e) => {
          e.stopPropagation()
          toggleStatus(s)
        }}
        disabled={busyId === s.id}
        title={s.status === 'ativo' ? 'Clique para inativar' : 'Clique para ativar'}
      >
        {servicoStatusLabel(s.status)}
      </button>
    )
  }

  return (
    <div>
      {/* Toolbar: busca + filtros + novo */}
      <div className="svc-toolbar">
        <div className="page-toolbar-search svc-toolbar-search">
          <input
            type="search"
            placeholder="Buscar por nome do serviço…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            aria-label="Buscar serviços"
          />
        </div>

        <select
          className="svc-filter"
          value={fCategoria}
          onChange={(e) => setFCategoria(e.target.value as Categoria | '')}
          aria-label="Filtrar por categoria"
        >
          <option value="">Todas as categorias</option>
          {CATEGORIAS.map((c) => (
            <option key={c} value={c}>{categoriaLabel(c)}</option>
          ))}
        </select>

        <select
          className="svc-filter"
          value={fGrupo}
          onChange={(e) => setFGrupo(e.target.value as Grupo | '')}
          aria-label="Filtrar por grupo"
        >
          <option value="">Todos os grupos</option>
          {GRUPOS.map((g) => (
            <option key={g} value={g}>{grupoLabel(g)}</option>
          ))}
        </select>

        <button
          type="button"
          className="clx-btn clx-btn-accent"
          onClick={() => navigate('/painel/servicos/novo')}
        >
          <IconPlus size={15} /> Novo serviço
        </button>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {error}
        </div>
      )}

      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando serviços…</div>
      ) : filtered.length === 0 ? (
        <div className="table-wrap">
          <div className="empty-state">
            <IconSearch size={32} />
            <h4>{emptyTitle}</h4>
            <p>{emptyHint}</p>
          </div>
        </div>
      ) : isMobile ? (
        <div className="mob-card-list">
          {filtered.map((s) => (
            <div
              key={s.id}
              className="mob-card"
              onClick={() => navigate(`/painel/servicos/${s.id}`)}
              style={{ cursor: 'pointer' }}
            >
              <div className="mob-card-top">
                <CategoriaIcon categoria={s.categoria} />
                <div className="mob-card-meta">
                  <div className="mob-card-title">{s.nome}</div>
                  <div className="mob-card-sub">{formatValorServico(s)}</div>
                </div>
                <div className="mob-card-badge">
                  <StatusToggle s={s} />
                </div>
              </div>
              <div className="mob-card-rows">
                <div className="mob-card-row">
                  <CategoriaGrupo categoria={s.categoria} grupo={s.grupo} />
                </div>
                <div className="mob-card-row">
                  <span className="clx-chip">{tipoValorLabel(s.tipoValor)}</span>
                  <span className="svc-muted">{formatTempoMedio(s.tempoMedioMin, s.tempoMedioLabel)}</span>
                </div>
              </div>
              <div className="mob-card-actions">
                <button
                  type="button"
                  className="icon-btn"
                  onClick={(e) => { e.stopPropagation(); navigate(`/painel/servicos/${s.id}`) }}
                  aria-label={`Editar ${s.nome}`}
                  title="Editar"
                >
                  <IconEdit size={16} />
                </button>
                <button
                  type="button"
                  className="icon-btn"
                  onClick={(e) => { e.stopPropagation(); handleDuplicate(s) }}
                  aria-label={`Duplicar ${s.nome}`}
                  title="Duplicar"
                >
                  <IconCopy size={16} />
                </button>
                <button
                  type="button"
                  className="icon-btn danger"
                  onClick={(e) => { e.stopPropagation(); setDeleteTarget(s) }}
                  aria-label={`Excluir ${s.nome}`}
                  title="Excluir"
                >
                  <IconTrash size={16} />
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="table-wrap">
          <div className="table-scroll">
            <table className="clx-table svc-table">
              <thead>
                <tr>
                  <th>Serviço</th>
                  <th>Categoria / Grupo</th>
                  <th>Valor</th>
                  <th>Tipo de valor</th>
                  <th>Tempo médio</th>
                  <th>Status</th>
                  <th aria-label="Ações" />
                </tr>
              </thead>
              <tbody>
                {filtered.map((s) => (
                  <tr
                    key={s.id}
                    onClick={() => navigate(`/painel/servicos/${s.id}`)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') { e.preventDefault(); navigate(`/painel/servicos/${s.id}`) }
                    }}
                    tabIndex={0}
                    style={{ cursor: 'pointer' }}
                  >
                    <td data-label="Serviço">
                      <span className="svc-row-name">
                        <CategoriaIcon categoria={s.categoria} size={16} />
                        <strong>{s.nome}</strong>
                      </span>
                    </td>
                    <td data-label="Categoria / Grupo">
                      <CategoriaGrupo categoria={s.categoria} grupo={s.grupo} />
                    </td>
                    <td data-label="Valor">{formatValorServico(s)}</td>
                    <td data-label="Tipo de valor">
                      <span className="clx-chip">{tipoValorLabel(s.tipoValor)}</span>
                    </td>
                    <td data-label="Tempo médio">{formatTempoMedio(s.tempoMedioMin, s.tempoMedioLabel)}</td>
                    <td data-label="Status"><StatusToggle s={s} /></td>
                    <td data-label="Ações" className="svc-actions-cell">
                      <div className="svc-row-actions">
                        <button
                          type="button"
                          className="icon-btn"
                          onClick={(e) => { e.stopPropagation(); navigate(`/painel/servicos/${s.id}`) }}
                          aria-label={`Editar ${s.nome}`}
                          title="Editar"
                        >
                          <IconEdit size={15} />
                        </button>
                        <div className="svc-kebab-wrap">
                          <button
                            type="button"
                            className="icon-btn"
                            onClick={(e) => {
                              e.stopPropagation()
                              setMenuId((cur) => (cur === s.id ? null : s.id))
                            }}
                            aria-haspopup="menu"
                            aria-expanded={menuId === s.id}
                            aria-label={`Mais ações para ${s.nome}`}
                            title="Mais ações"
                          >
                            <IconMoreVertical size={16} />
                          </button>
                          {menuId === s.id && (
                            <div
                              className="svc-kebab-menu"
                              role="menu"
                              onClick={(e) => e.stopPropagation()}
                            >
                              <button
                                type="button"
                                role="menuitem"
                                className="svc-kebab-item"
                                onClick={() => handleDuplicate(s)}
                              >
                                <IconCopy size={15} /> Duplicar
                              </button>
                              <button
                                type="button"
                                role="menuitem"
                                className="svc-kebab-item danger"
                                onClick={() => { setMenuId(null); setDeleteTarget(s) }}
                              >
                                <IconTrash size={15} /> Excluir
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Modal de confirmação de exclusão */}
      <Modal
        open={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        title="Excluir serviço"
        size="sm"
        footer={
          <>
            <button type="button" className="clx-btn clx-btn-ghost" onClick={() => setDeleteTarget(null)} disabled={deleting}>
              Cancelar
            </button>
            <button type="button" className="clx-btn clx-btn-danger" onClick={handleDelete} disabled={deleting}>
              {deleting ? <><Spinner size={14} /> Excluindo…</> : 'Excluir'}
            </button>
          </>
        }
      >
        <p style={{ fontSize: '0.9rem', color: 'var(--clx-ink-2)', lineHeight: 1.6 }}>
          Tem certeza que deseja excluir o serviço <strong>{deleteTarget?.nome}</strong>?
          Esta ação não pode ser desfeita. Considere <strong>inativar</strong> o serviço
          caso ele ainda seja usado em orçamentos ou OS.
        </p>
      </Modal>
    </div>
  )
}
