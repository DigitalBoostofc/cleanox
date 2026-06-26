import { useCallback, useEffect, useState } from 'react'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../../lib/pb'
import { COLLECTIONS, type User, type Role, userDisplayName } from '../../lib/collections'
import { Spinner } from '../../components/ui/Spinner'
import { Modal } from '../../components/ui/Modal'
import {
  IconPlus,
  IconEdit,
  IconTrash,
  IconAlertCircle,
} from '../../components/ui/Icon'
import { useAuth } from '../../contexts/AuthContext'

function pbError(err: unknown): string {
  if (err instanceof ClientResponseError) {
    if (err.status === 403) return 'Sem permissão para esta ação.'
    if (err.status === 400) {
      const data = err.data as Record<string, { message?: string }> | undefined
      if (data) {
        const first = Object.values(data)[0]
        if (first?.message) return first.message
      }
      const msg = (err.response as { message?: string })?.message
      if (msg) return msg
      return 'Dados inválidos. Verifique o formulário.'
    }
    if (err.status === 0) return 'Sem conexão com o servidor.'
  }
  return 'Ocorreu um erro inesperado.'
}

interface UserForm {
  name: string
  email: string
  role: Role
  password: string
  passwordConfirm: string
}

function emptyForm(): UserForm {
  return { name: '', email: '', role: 'profissional', password: '', passwordConfirm: '' }
}

function validateForm(f: UserForm, editing: boolean): Record<string, string> {
  const errs: Record<string, string> = {}
  if (!f.name.trim()) errs.name = 'Nome é obrigatório'
  if (!editing) {
    if (!f.email.trim()) errs.email = 'E-mail é obrigatório'
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email)) errs.email = 'E-mail inválido'
    if (!f.password) errs.password = 'Senha é obrigatória'
    else if (f.password.length < 8) errs.password = 'Mínimo 8 caracteres'
    if (f.password !== f.passwordConfirm) errs.passwordConfirm = 'Senhas não coincidem'
  }
  return errs
}

const ROLE_LABELS: Record<Role, string> = {
  admin: 'Admin',
  gerente: 'Gerente',
  profissional: 'Profissional',
}

export default function Usuarios() {
  const { role: myRole, user: myUser } = useAuth()

  const [users, setUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [modalOpen, setModalOpen] = useState(false)
  const [editing, setEditing] = useState<User | null>(null)
  const [form, setForm] = useState<UserForm>(emptyForm())
  const [formErrs, setFormErrs] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState(false)
  const [saveErr, setSaveErr] = useState<string | null>(null)

  const [deleteTarget, setDeleteTarget] = useState<User | null>(null)
  const [deleting, setDeleting] = useState(false)

  const load = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const list = await pb.collection(COLLECTIONS.USERS).getFullList<User>({ sort: 'name' })
      setUsers(list)
    } catch {
      setError('Não foi possível carregar os usuários.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  function openCreate() {
    setEditing(null)
    setForm(emptyForm())
    setFormErrs({})
    setSaveErr(null)
    setModalOpen(true)
  }

  function openEdit(u: User) {
    setEditing(u)
    setForm({ name: u.name ?? '', email: u.email, role: u.role, password: '', passwordConfirm: '' })
    setFormErrs({})
    setSaveErr(null)
    setModalOpen(true)
  }

  function setField<K extends keyof UserForm>(k: K, v: UserForm[K]) {
    setForm((p) => ({ ...p, [k]: v }))
    setFormErrs((p) => { const n = { ...p }; delete n[k as string]; return n })
  }

  async function handleSave() {
    const errs = validateForm(form, !!editing)
    if (Object.keys(errs).length > 0) { setFormErrs(errs); return }
    // Impede o admin de rebaixar o próprio papel
    if (editing && myUser && editing.id === myUser.id && form.role !== editing.role) {
      setSaveErr('Não é possível alterar o próprio papel. Peça a outro administrador.')
      return
    }
    try {
      setSaving(true)
      setSaveErr(null)
      if (editing) {
        await pb.collection(COLLECTIONS.USERS).update(editing.id, {
          name: form.name.trim(),
          role: form.role,
        })
      } else {
        await pb.collection(COLLECTIONS.USERS).create({
          name: form.name.trim(),
          email: form.email.trim(),
          role: form.role,
          password: form.password,
          passwordConfirm: form.passwordConfirm,
          emailVisibility: true,
        })
      }
      setModalOpen(false)
      await load()
    } catch (err) {
      setSaveErr(pbError(err))
    } finally {
      setSaving(false)
    }
  }

  function openDeleteConfirm(u: User) {
    if (myUser && u.id === myUser.id) {
      setError('Não é possível excluir a própria conta de administrador.')
      return
    }
    setDeleteTarget(u)
  }

  async function handleDelete() {
    if (!deleteTarget) return
    try {
      setDeleting(true)
      await pb.collection(COLLECTIONS.USERS).delete(deleteTarget.id)
      setDeleteTarget(null)
      await load()
    } catch (err) {
      setError(pbError(err))
      setDeleteTarget(null)
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div>
      <div className="page-toolbar">
        <button className="clx-btn clx-btn-accent" onClick={openCreate}>
          <IconPlus size={15} /> Novo usuário
        </button>
        <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load} style={{ marginLeft: 'auto' }}>
          Atualizar
        </button>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {error}
        </div>
      )}

      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando usuários…</div>
      ) : (
        <div className="table-wrap">
          <div className="table-scroll">
            <table className="clx-table">
              <thead>
                <tr>
                  <th>Nome</th>
                  <th>E-mail</th>
                  <th>Papel</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {users.length === 0 ? (
                  <tr>
                    <td colSpan={4}>
                      <div className="empty-state">
                        <h4>Nenhum usuário cadastrado</h4>
                        <p>Clique em "Novo usuário" para adicionar.</p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  users.map((u) => (
                    <tr key={u.id}>
                      <td><strong>{userDisplayName(u)}</strong></td>
                      <td>{u.email}</td>
                      <td>
                        <span className="clx-chip">
                          {ROLE_LABELS[u.role] ?? u.role}
                        </span>
                        {u.role === 'profissional' && (
                          <span style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)', marginLeft: 6 }}>
                            (app profissional)
                          </span>
                        )}
                      </td>
                      <td>
                        <div className="td-actions">
                          <button className="icon-btn" onClick={() => openEdit(u)} title="Editar">
                            <IconEdit size={15} />
                          </button>
                          {myRole === 'admin' && (
                            <button
                              className="icon-btn danger"
                              onClick={() => openDeleteConfirm(u)}
                              title={myUser && u.id === myUser.id ? 'Não é possível excluir a própria conta' : 'Excluir'}
                              disabled={!!(myUser && u.id === myUser.id)}
                            >
                              <IconTrash size={15} />
                            </button>
                          )}
                        </div>
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
        title={editing ? 'Editar usuário' : 'Novo usuário'}
        footer={
          <>
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
          <Field label="Nome" required err={formErrs.name} className="form-col-span-2">
            <input
              type="text"
              value={form.name}
              onChange={(e) => setField('name', e.target.value)}
              placeholder="Pedro Santos"
              className={formErrs.name ? 'err' : ''}
            />
          </Field>

          {!editing && (
            <Field label="E-mail" required err={formErrs.email} className="form-col-span-2">
              <input
                type="email"
                value={form.email}
                onChange={(e) => setField('email', e.target.value)}
                placeholder="pedro@empresa.com"
                className={formErrs.email ? 'err' : ''}
                autoComplete="off"
              />
            </Field>
          )}

          <Field label="Papel" required err={formErrs.role} className="form-col-span-2">
            <select
              value={form.role}
              onChange={(e) => setField('role', e.target.value as Role)}
              disabled={!!(editing && myUser && editing.id === myUser.id)}
            >
              <option value="admin">Admin — acesso total ao painel</option>
              <option value="gerente">Gerente — acesso total exceto marcar repasse</option>
              <option value="profissional">Profissional — acessa o app do profissional</option>
            </select>
            {editing && myUser && editing.id === myUser.id && (
              <span style={{ fontSize: '0.75rem', color: 'var(--clx-warning)' }}>
                Não é possível alterar o próprio papel.
              </span>
            )}
          </Field>

          {!editing && (
            <>
              <Field label="Senha" required err={formErrs.password}>
                <input
                  type="password"
                  value={form.password}
                  onChange={(e) => setField('password', e.target.value)}
                  placeholder="Mínimo 8 caracteres"
                  className={formErrs.password ? 'err' : ''}
                  autoComplete="new-password"
                />
              </Field>
              <Field label="Confirmar senha" required err={formErrs.passwordConfirm}>
                <input
                  type="password"
                  value={form.passwordConfirm}
                  onChange={(e) => setField('passwordConfirm', e.target.value)}
                  placeholder="Repita a senha"
                  className={formErrs.passwordConfirm ? 'err' : ''}
                  autoComplete="new-password"
                />
              </Field>
            </>
          )}

          {editing && (
            <div
              className="form-col-span-2"
              style={{
                padding: '10px 12px',
                background: 'rgba(245,158,11,0.06)',
                border: '1px solid rgba(245,158,11,0.22)',
                borderRadius: 'var(--clx-r-md)',
                fontSize: '0.8rem',
                color: 'var(--clx-warning)',
              }}
            >
              Para redefinir a senha deste usuário, use o{' '}
              <strong>Admin UI do PocketBase</strong> (<code>/_/</code>). Apenas o próprio
              usuário pode trocar a própria senha pelo painel.
            </div>
          )}
        </div>
      </Modal>

      {/* Modal confirmação exclusão */}
      <Modal
        open={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        title="Excluir usuário"
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
          Tem certeza que deseja excluir o usuário <strong>{userDisplayName(deleteTarget)}</strong>?
          Esta ação não pode ser desfeita.
        </p>
      </Modal>
    </div>
  )
}

function Field({
  label, required, err, children, className,
}: {
  label: string; required?: boolean; err?: string; children: React.ReactNode; className?: string
}) {
  return (
    <div className={`form-field${className ? ` ${className}` : ''}`}>
      <label>{label}{required && <span className="req">*</span>}</label>
      {children}
      {err && <span className="field-err">{err}</span>}
    </div>
  )
}
