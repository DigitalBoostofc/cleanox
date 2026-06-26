import { useState } from 'react'
import { ClientResponseError } from 'pocketbase'
import { useNavigate } from 'react-router-dom'
import { pb } from '../../lib/pb'
import { useAuth } from '../../contexts/AuthContext'
import { Spinner } from '../../components/ui/Spinner'
import { IconAlertCircle, IconCheckCircle, IconUser, IconLock } from '../../components/ui/Icon'
import { userDisplayName } from '../../lib/collections'

function pbPasswordError(err: unknown): string {
  if (err instanceof ClientResponseError) {
    if (err.status === 400) {
      const msg = (err.response as { message?: string })?.message ?? ''
      if (msg.toLowerCase().includes('authenticate') || msg.toLowerCase().includes('failed')) {
        return 'Senha atual incorreta.'
      }
      const data = err.data as Record<string, { message?: string }> | undefined
      if (data?.oldPassword?.message) return 'Senha atual incorreta.'
      if (data?.password?.message) return `Nova senha inválida: ${data.password.message}`
      if (data?.passwordConfirm?.message) return 'As senhas não coincidem.'
      return 'Dados inválidos. Verifique o formulário.'
    }
    if (err.status === 0) return 'Sem conexão com o servidor.'
  }
  return 'Ocorreu um erro inesperado.'
}

const ROLE_LABELS: Record<string, string> = {
  admin: 'Admin',
  gerente: 'Gerente',
  profissional: 'Profissional',
}

export default function Conta() {
  const { user, role, logout } = useAuth()
  const navigate = useNavigate()

  const [oldPassword, setOldPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [saving, setSaving] = useState(false)
  const [err, setErr] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)
  const [fieldErrs, setFieldErrs] = useState<Record<string, string>>({})

  function validate(): boolean {
    const errs: Record<string, string> = {}
    if (!oldPassword) errs.oldPassword = 'Informe a senha atual'
    if (!newPassword) errs.newPassword = 'Informe a nova senha'
    else if (newPassword.length < 8) errs.newPassword = 'Mínimo 8 caracteres'
    if (newPassword !== confirmPassword) errs.confirmPassword = 'As senhas não coincidem'
    setFieldErrs(errs)
    return Object.keys(errs).length === 0
  }

  function clearField(key: string) {
    setFieldErrs((p) => { const n = { ...p }; delete n[key]; return n })
  }

  async function handleSave() {
    if (!validate() || !user) return
    try {
      setSaving(true)
      setErr(null)
      await pb.collection('users').update(user.id, {
        oldPassword,
        password: newPassword,
        passwordConfirm: confirmPassword,
      })
      setSuccess(true)
      setOldPassword('')
      setNewPassword('')
      setConfirmPassword('')
      setTimeout(() => {
        logout()
        navigate('/login', { replace: true })
      }, 2500)
    } catch (e) {
      setErr(pbPasswordError(e))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div style={{ maxWidth: 560 }}>
      {/* Dados do usuário */}
      <div className="clx-card clx-card-p" style={{ marginBottom: 20 }}>
        <div className="section-header" style={{ marginBottom: 14 }}>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <IconUser size={16} /> Minha conta
          </h2>
        </div>
        <dl>
          <div className="detail-row">
            <dt>Nome</dt>
            <dd>{userDisplayName(user)}</dd>
          </div>
          <div className="detail-row">
            <dt>E-mail</dt>
            <dd>{user?.email}</dd>
          </div>
          <div className="detail-row">
            <dt>Papel</dt>
            <dd>
              <span className="clx-chip">{ROLE_LABELS[role ?? ''] ?? role}</span>
            </dd>
          </div>
        </dl>
      </div>

      {/* Alterar senha */}
      <div className="clx-card clx-card-p">
        <div className="section-header" style={{ marginBottom: 14 }}>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <IconLock size={16} /> Alterar senha
          </h2>
        </div>

        {success ? (
          <div className="success-banner">
            <IconCheckCircle size={16} />
            Senha alterada com sucesso! Você será redirecionado para o login…
          </div>
        ) : (
          <>
            {err && (
              <div className="error-banner" style={{ marginBottom: 14 }}>
                <IconAlertCircle size={15} /> {err}
              </div>
            )}

            <div className="form-grid">
              <div className="form-field">
                <label>Senha atual <span className="req">*</span></label>
                <input
                  type="password"
                  value={oldPassword}
                  onChange={(e) => { setOldPassword(e.target.value); clearField('oldPassword') }}
                  placeholder="Sua senha atual"
                  className={fieldErrs.oldPassword ? 'err' : ''}
                  autoComplete="current-password"
                />
                {fieldErrs.oldPassword && <span className="field-err">{fieldErrs.oldPassword}</span>}
              </div>

              <div className="form-field">
                <label>Nova senha <span className="req">*</span></label>
                <input
                  type="password"
                  value={newPassword}
                  onChange={(e) => { setNewPassword(e.target.value); clearField('newPassword') }}
                  placeholder="Mínimo 8 caracteres"
                  className={fieldErrs.newPassword ? 'err' : ''}
                  autoComplete="new-password"
                />
                {fieldErrs.newPassword && <span className="field-err">{fieldErrs.newPassword}</span>}
              </div>

              <div className="form-field">
                <label>Confirmar nova senha <span className="req">*</span></label>
                <input
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => { setConfirmPassword(e.target.value); clearField('confirmPassword') }}
                  placeholder="Repita a nova senha"
                  className={fieldErrs.confirmPassword ? 'err' : ''}
                  autoComplete="new-password"
                />
                {fieldErrs.confirmPassword && <span className="field-err">{fieldErrs.confirmPassword}</span>}
              </div>
            </div>

            <div style={{ marginTop: 16 }}>
              <button className="clx-btn clx-btn-accent" onClick={handleSave} disabled={saving}>
                {saving ? <><Spinner size={14} /> Salvando…</> : 'Alterar senha'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
