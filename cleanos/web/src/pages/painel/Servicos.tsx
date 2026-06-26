import { useCallback, useEffect, useState } from 'react'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../../lib/pb'
import { COLLECTIONS, type Servico, formatCurrency } from '../../lib/collections'
import { Spinner } from '../../components/ui/Spinner'
import { Modal } from '../../components/ui/Modal'
import {
  IconPlus,
  IconTrash,
  IconAlertCircle,
  IconSearch,
  IconDollar,
  IconChevronRight,
} from '../../components/ui/Icon'
import { useAuth } from '../../contexts/AuthContext'
import { useIsMobile } from '../../hooks/useIsMobile'

/* ---- Types ---- */
type ServicoForm = {
  nome: string
  descricao: string
  preco_base_str: string // string para aceitar vírgula/ponto durante edição
  ativo: boolean
}

function emptyForm(): ServicoForm {
  return { nome: '', descricao: '', preco_base_str: '', ativo: true }
}

function servicoToForm(s: Servico): ServicoForm {
  return {
    nome: s.nome,
    descricao: s.descricao ?? '',
    preco_base_str: s.preco_base.toFixed(2).replace('.', ','),
    ativo: s.ativo,
  }
}

/** Converte string "1.234,56" ou "1234.56" para float, retorna NaN se inválido */
function parsePreco(raw: string): number {
  const normalized = raw.trim().replace(/\./g, '').replace(',', '.')
  return parseFloat(normalized)
}

function validateForm(f: ServicoForm): Record<string, string> {
  const errs: Record<string, string> = {}
  if (!f.nome.trim()) errs.nome = 'Nome é obrigatório'
  const preco = parsePreco(f.preco_base_str)
  if (f.preco_base_str.trim() === '') {
    errs.preco_base_str = 'Preço é obrigatório'
  } else if (isNaN(preco) || preco < 0) {
    errs.preco_base_str = 'Preço deve ser um número >= 0'
  }
  return errs
}

function pbError(err: unknown): string {
  if (err instanceof ClientResponseError) {
    if (err.status === 403) return 'Sem permissão para esta ação.'
    if (err.status === 400) {
      const data = err.data as Record<string, { message?: string }> | undefined
      if (data) {
        const first = Object.values(data)[0]
        if (first?.message) return first.message
      }
      return 'Dados inválidos. Verifique o formulário.'
    }
    if (err.status === 0) return 'Sem conexão com o servidor.'
  }
  return 'Ocorreu um erro inesperado.'
}

export default function Servicos() {
  const { role } = useAuth()
  const isAdmin = role === 'admin'
  const isMobile = useIsMobile()

  const [servicos, setServicos] = useState<Servico[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')

  /* Modal criar/editar */
  const [modalOpen, setModalOpen] = useState(false)
  const [editing, setEditing] = useState<Servico | null>(null)
  const [form, setForm] = useState<ServicoForm>(emptyForm())
  const [formErrs, setFormErrs] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState(false)
  const [saveErr, setSaveErr] = useState<string | null>(null)

  /* Modal excluir */
  const [deleteTarget, setDeleteTarget] = useState<Servico | null>(null)
  const [deleting, setDeleting] = useState(false)

  /* Load */
  const load = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const list = await pb.collection(COLLECTIONS.SERVICOS).getFullList<Servico>({
        sort: 'nome',
      })
      setServicos(list)
    } catch {
      setError('Não foi possível carregar os serviços.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  /* Filtered */
  const searchLower = search.toLowerCase()
  const filtered = servicos.filter((s) => {
    if (!search) return true
    return (
      s.nome.toLowerCase().includes(searchLower) ||
      (s.descricao ?? '').toLowerCase().includes(searchLower)
    )
  })

  /* Open create */
  function openCreate() {
    setEditing(null)
    setForm(emptyForm())
    setFormErrs({})
    setSaveErr(null)
    setModalOpen(true)
  }

  /* Open edit */
  function openEdit(s: Servico) {
    setEditing(s)
    setForm(servicoToForm(s))
    setFormErrs({})
    setSaveErr(null)
    setModalOpen(true)
  }

  /* Field change */
  function setField<K extends keyof ServicoForm>(k: K, v: ServicoForm[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
    setFormErrs((prev) => { const n = { ...prev }; delete n[k as string]; return n })
  }

  /* Save */
  async function handleSave() {
    const errs = validateForm(form)
    if (Object.keys(errs).length > 0) { setFormErrs(errs); return }
    try {
      setSaving(true)
      setSaveErr(null)
      const payload = {
        nome: form.nome.trim(),
        descricao: form.descricao.trim(),
        preco_base: parsePreco(form.preco_base_str),
        ativo: form.ativo,
      }
      if (editing) {
        await pb.collection(COLLECTIONS.SERVICOS).update(editing.id, payload)
      } else {
        await pb.collection(COLLECTIONS.SERVICOS).create(payload)
      }
      setModalOpen(false)
      await load()
    } catch (err) {
      setSaveErr(pbError(err))
    } finally {
      setSaving(false)
    }
  }

  /* Toggle ativo inline */
  async function toggleAtivo(s: Servico) {
    try {
      await pb.collection(COLLECTIONS.SERVICOS).update(s.id, { ativo: !s.ativo })
      setServicos((prev) => prev.map((x) => x.id === s.id ? { ...x, ativo: !s.ativo } : x))
    } catch (err) {
      setError(pbError(err))
    }
  }

  /* Delete */
  async function handleDelete() {
    if (!deleteTarget) return
    try {
      setDeleting(true)
      await pb.collection(COLLECTIONS.SERVICOS).delete(deleteTarget.id)
      setDeleteTarget(null)
      await load()
    } catch (err) {
      setError(pbError(err))
      setDeleteTarget(null)
    } finally {
      setDeleting(false)
    }
  }

  /* ---- Render ---- */
  return (
    <div>
      <div className="page-toolbar">
        <div className="page-toolbar-search">
          <input
            type="search"
            placeholder="Buscar por nome ou descrição…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            aria-label="Buscar serviços"
          />
        </div>
        <button className="clx-btn clx-btn-accent" onClick={openCreate}>
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
      ) : isMobile ? (
        filtered.length === 0 ? (
          <div className="empty-state">
            <IconSearch size={32} />
            <h4>{search ? 'Nenhum serviço encontrado' : 'Nenhum serviço cadastrado'}</h4>
            <p>{search ? 'Tente outros termos de busca.' : 'Clique em "Novo serviço" para começar.'}</p>
          </div>
        ) : (
          <div className="mob-card-list">
            {filtered.map((s) => (
              <div key={s.id} className="mob-card" onClick={() => openEdit(s)} style={{ cursor: 'pointer' }}>
                <div className="mob-card-top">
                  <div className="mob-card-meta">
                    <div className="mob-card-title">{s.nome}</div>
                    {s.descricao && <div className="mob-card-sub">{s.descricao}</div>}
                  </div>
                  <div className="mob-card-badge">
                    <button
                      className={`clx-chip ${s.ativo ? 'clx-chip-success' : 'clx-chip-error'}`}
                      style={{ cursor: 'pointer' }}
                      onClick={(e) => { e.stopPropagation(); toggleAtivo(s) }}
                      title={s.ativo ? 'Clique para inativar' : 'Clique para ativar'}
                    >
                      {s.ativo ? 'Ativo' : 'Inativo'}
                    </button>
                  </div>
                </div>
                <div className="mob-card-rows">
                  <div className="mob-card-row">
                    <span className="mob-card-row-icon"><IconDollar size={14} /></span>
                    <span style={{ fontWeight: 700, color: 'var(--clx-ink)', fontSize: '1rem' }}>
                      {formatCurrency(s.preco_base)}
                    </span>
                  </div>
                </div>
                <div className="mob-card-actions">
                  <span style={{ color: 'var(--clx-ink-3)', display: 'flex', alignItems: 'center' }}>
                    <IconChevronRight size={16} />
                  </span>
                </div>
              </div>
            ))}
          </div>
        )
      ) : (
        <div className="table-wrap">
          <div className="table-scroll">
            <table className="clx-table">
              <thead>
                <tr>
                  <th>Nome</th>
                  <th>Descrição</th>
                  <th>Preço base</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={4}>
                      <div className="empty-state">
                        <IconSearch size={32} />
                        <h4>
                          {search ? 'Nenhum serviço encontrado' : 'Nenhum serviço cadastrado'}
                        </h4>
                        <p>
                          {search
                            ? 'Tente outros termos de busca.'
                            : 'Clique em "Novo serviço" para começar.'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  filtered.map((s) => (
                    <tr
                      key={s.id}
                      onClick={() => openEdit(s)}
                      onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openEdit(s) } }}
                      tabIndex={0}
                      style={{ cursor: 'pointer' }}
                    >
                      <td data-label="Nome"><strong>{s.nome}</strong></td>
                      <td data-label="Descrição">
                        <span
                          title={s.descricao || undefined}
                          style={{
                            display: 'inline-block',
                            maxWidth: 220,
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                            verticalAlign: 'bottom',
                          }}
                        >
                          {s.descricao || '—'}
                        </span>
                      </td>
                      <td data-label="Preço">{formatCurrency(s.preco_base)}</td>
                      <td data-label="Status">
                        <button
                          className={`clx-chip ${s.ativo ? 'clx-chip-success' : 'clx-chip-error'}`}
                          style={{ cursor: 'pointer' }}
                          onClick={(e) => { e.stopPropagation(); toggleAtivo(s) }}
                          title={s.ativo ? 'Clique para inativar' : 'Clique para ativar'}
                        >
                          {s.ativo ? 'Ativo' : 'Inativo'}
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Modal criar/editar */}
      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editing ? 'Editar serviço' : 'Novo serviço'}
        footer={
          <>
            {isAdmin && editing && (
              <button
                className="clx-btn clx-btn-danger clx-btn-sm"
                style={{ marginRight: 'auto' }}
                onClick={() => { setModalOpen(false); setDeleteTarget(editing) }}
                disabled={saving}
                title="Excluir serviço"
              >
                <IconTrash size={14} /> Excluir
              </button>
            )}
            <button className="clx-btn clx-btn-ghost" onClick={() => setModalOpen(false)} disabled={saving}>
              Cancelar
            </button>
            <button className="clx-btn clx-btn-accent" onClick={handleSave} disabled={saving}>
              {saving ? <><Spinner size={14} /> Salvando…</> : 'Salvar'}
            </button>
          </>
        }
      >
        {saveErr && (
          <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
            <IconAlertCircle size={15} /> {saveErr}
          </div>
        )}

        <div className="form-grid form-grid-2">
          <Field label="Nome" required err={formErrs.nome} className="form-col-span-2">
            <input
              type="text"
              value={form.nome}
              onChange={(e) => setField('nome', e.target.value)}
              placeholder="Limpeza residencial completa"
              className={formErrs.nome ? 'err' : ''}
              autoFocus
            />
          </Field>

          <Field label="Descrição" err={formErrs.descricao} className="form-col-span-2">
            <textarea
              value={form.descricao}
              onChange={(e) => setField('descricao', e.target.value)}
              placeholder="Descreva o serviço (opcional)…"
              rows={3}
            />
          </Field>

          <Field label="Preço base (R$)" required err={formErrs.preco_base_str}>
            <input
              type="text"
              inputMode="decimal"
              value={form.preco_base_str}
              onChange={(e) => setField('preco_base_str', e.target.value)}
              placeholder="150,00"
              className={formErrs.preco_base_str ? 'err' : ''}
            />
          </Field>

          <div style={{ display: 'flex', alignItems: 'flex-end', paddingBottom: 4 }}>
            <div className="toggle-row">
              <label className="toggle" htmlFor="servico-ativo">
                <input
                  id="servico-ativo"
                  type="checkbox"
                  checked={form.ativo}
                  onChange={(e) => setField('ativo', e.target.checked)}
                />
                <span className="toggle-track" />
              </label>
              <label htmlFor="servico-ativo" style={{ fontSize: '0.875rem', color: 'var(--clx-ink-2)' }}>
                Serviço ativo
              </label>
            </div>
          </div>
        </div>
      </Modal>

      {/* Modal confirmação exclusão */}
      <Modal
        open={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        title="Excluir serviço"
        size="sm"
        footer={
          <>
            <button className="clx-btn clx-btn-ghost" onClick={() => setDeleteTarget(null)} disabled={deleting}>
              Cancelar
            </button>
            <button className="clx-btn clx-btn-danger" onClick={handleDelete} disabled={deleting}>
              {deleting ? <><Spinner size={14} /> Excluindo…</> : 'Excluir'}
            </button>
          </>
        }
      >
        <p style={{ fontSize: '0.9rem', color: 'var(--clx-ink-2)', lineHeight: 1.6 }}>
          Tem certeza que deseja excluir o serviço <strong>{deleteTarget?.nome}</strong>?
          Esta ação não pode ser desfeita. Considere <strong>inativar</strong> o serviço
          se ele ainda estiver associado a ordens de serviço existentes.
        </p>
      </Modal>
    </div>
  )
}

/* ---- Helper component ---- */
function Field({
  label,
  required,
  err,
  children,
  className,
}: {
  label: string
  required?: boolean
  err?: string
  children: React.ReactNode
  className?: string
}) {
  return (
    <div className={`form-field${className ? ` ${className}` : ''}`}>
      <label>
        {label}{required && <span className="req">*</span>}
      </label>
      {children}
      {err && <span className="field-err">{err}</span>}
    </div>
  )
}
