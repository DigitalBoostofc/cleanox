import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../../lib/pb'
import { useAuth } from '../../contexts/AuthContext'
import { Spinner } from '../../components/ui/Spinner'
import { COLLECTIONS, type OrdemServico, getBrtDayBounds } from '../../lib/collections'
import { IconLogOut, IconAlertCircle, IconCheckCircle, IconLock } from '../../components/ui/Icon'
import { StarRating } from '../../components/ui/StarRating'

interface Stats {
  totalHoje: number
  concluidasHoje: number
}

interface RatingStats {
  media: number
  total: number
}

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


export default function Perfil() {
  const { user, role, logout } = useAuth()
  const navigate = useNavigate()

  const [stats, setStats] = useState<Stats | null>(null)
  const [loadingStats, setLoadingStats] = useState(true)
  const [ratingStats, setRatingStats] = useState<RatingStats | null>(null)

  const [oldPassword, setOldPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [savingPwd, setSavingPwd] = useState(false)
  const [pwdErr, setPwdErr] = useState<string | null>(null)
  const [pwdSuccess, setPwdSuccess] = useState(false)
  const [pwdFieldErrs, setPwdFieldErrs] = useState<Record<string, string>>({})
  const [pwdOpen, setPwdOpen] = useState(false)

  const fetchStats = useCallback(async () => {
    if (!user?.id) return
    const { todayStart, tomorrowStart } = getBrtDayBounds()
    try {
      const [result, osAvaliadas] = await Promise.all([
        pb.collection(COLLECTIONS.ORDENS_SERVICO).getList<OrdemServico>(1, 100, {
          filter: `profissional = '${user.id}' && data_hora >= '${todayStart}' && data_hora < '${tomorrowStart}'`,
        }),
        pb.collection(COLLECTIONS.ORDENS_SERVICO).getFullList<OrdemServico>({
          filter: `profissional = '${user.id}' && status = 'concluida' && avaliacao_nota >= 1`,
          fields: 'id,avaliacao_nota',
        }),
      ])
      const totalHoje = result.totalItems
      const concluidasHoje = result.items.filter((o) => o.status === 'concluida').length
      setStats({ totalHoje, concluidasHoje })
      if (osAvaliadas.length > 0) {
        const soma = osAvaliadas.reduce((acc, o) => acc + (o.avaliacao_nota ?? 0), 0)
        setRatingStats({ media: soma / osAvaliadas.length, total: osAvaliadas.length })
      }
    } catch {
      // stats são secundários — não bloquear a tela em caso de erro
    } finally {
      setLoadingStats(false)
    }
  }, [user?.id])

  useEffect(() => {
    fetchStats()
  }, [fetchStats])

  const handleLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  function validatePwd(): boolean {
    const errs: Record<string, string> = {}
    if (!oldPassword) errs.oldPassword = 'Informe a senha atual'
    if (!newPassword) errs.newPassword = 'Informe a nova senha'
    else if (newPassword.length < 8) errs.newPassword = 'Mínimo 8 caracteres'
    if (newPassword !== confirmPassword) errs.confirmPassword = 'As senhas não coincidem'
    setPwdFieldErrs(errs)
    return Object.keys(errs).length === 0
  }

  async function handleSavePwd() {
    if (!validatePwd() || !user) return
    try {
      setSavingPwd(true)
      setPwdErr(null)
      await pb.collection('users').update(user.id, {
        oldPassword,
        password: newPassword,
        passwordConfirm: confirmPassword,
      })
      setPwdSuccess(true)
      setOldPassword('')
      setNewPassword('')
      setConfirmPassword('')
      setTimeout(() => {
        logout()
        navigate('/login', { replace: true })
      }, 2500)
    } catch (e) {
      setPwdErr(pbPasswordError(e))
    } finally {
      setSavingPwd(false)
    }
  }

  const displayName = user?.nome ?? user?.name ?? 'Profissional'
  const avatarInitial = displayName.charAt(0).toUpperCase()

  return (
    <>
      <div className="profapp-page-header">
        <h1>Perfil</h1>
      </div>

      <div className="profapp-page-body">
        {/* Card do usuário */}
        <div
          className="clx-card"
          style={{ padding: '20px', marginBottom: 16, textAlign: 'center' }}
        >
          {/* Avatar */}
          <div
            className="painel-user-avatar"
            style={{
              width: 64,
              height: 64,
              fontSize: '1.5rem',
              margin: '0 auto 12px',
            }}
            aria-hidden="true"
          >
            {avatarInitial}
          </div>

          <div
            style={{
              fontFamily: 'var(--clx-font-display)',
              fontWeight: 800,
              fontSize: '1.15rem',
              color: 'var(--clx-ink)',
              letterSpacing: '-0.02em',
              marginBottom: 4,
            }}
          >
            {displayName}
          </div>

          <div style={{ fontSize: '0.82rem', color: 'var(--clx-ink-3)', marginBottom: 10 }}>
            {user?.email}
          </div>

          <span className="clx-chip clx-chip-primary">
            {role === 'profissional' ? 'Profissional' : role}
          </span>

          {role === 'profissional' && !loadingStats && (
            <div style={{ marginTop: 10, fontSize: '0.85rem', color: 'var(--clx-ink-2)' }}>
              {ratingStats ? (
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                  Sua avaliação:
                  <StarRating nota={Math.round(ratingStats.media)} size={14} />
                  <strong>{ratingStats.media.toFixed(1)}</strong>
                  <span style={{ color: 'var(--clx-ink-3)' }}>de {ratingStats.total} serviço{ratingStats.total !== 1 ? 's' : ''}</span>
                </span>
              ) : (
                <span style={{ color: 'var(--clx-ink-3)' }}>Nenhuma avaliação ainda</span>
              )}
            </div>
          )}
        </div>

        {/* Resumo do dia */}
        <div
          className="clx-card"
          style={{ marginBottom: 16, overflow: 'hidden' }}
        >
          <div
            style={{
              padding: '12px 16px 10px',
              fontSize: '0.72rem',
              fontWeight: 700,
              letterSpacing: '0.07em',
              textTransform: 'uppercase',
              color: 'var(--clx-ink-3)',
              borderBottom: '1px solid var(--clx-line)',
            }}
          >
            Resumo de hoje
          </div>

          {loadingStats ? (
            <div style={{ display: 'flex', justifyContent: 'center', padding: '20px' }}>
              <Spinner size={20} />
            </div>
          ) : (
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: '1fr 1fr',
                padding: '16px',
                gap: 12,
              }}
            >
              <div style={{ textAlign: 'center' }}>
                <div
                  style={{
                    fontFamily: 'var(--clx-font-display)',
                    fontSize: '2rem',
                    fontWeight: 800,
                    color: 'var(--clx-accent)',
                    letterSpacing: '-0.03em',
                    lineHeight: 1,
                    marginBottom: 4,
                  }}
                >
                  {stats?.totalHoje ?? 0}
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--clx-ink-3)', fontWeight: 600 }}>
                  Agendados
                </div>
              </div>

              <div style={{ textAlign: 'center' }}>
                <div
                  style={{
                    fontFamily: 'var(--clx-font-display)',
                    fontSize: '2rem',
                    fontWeight: 800,
                    color: 'var(--clx-success)',
                    letterSpacing: '-0.03em',
                    lineHeight: 1,
                    marginBottom: 4,
                  }}
                >
                  {stats?.concluidasHoje ?? 0}
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--clx-ink-3)', fontWeight: 600 }}>
                  Concluídos
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Alterar senha */}
        <div className="clx-card" style={{ marginBottom: 16, overflow: 'hidden' }}>
          <button
            className="clx-btn clx-btn-ghost clx-btn-block"
            onClick={() => { setPwdOpen((o) => !o); setPwdErr(null); setPwdSuccess(false) }}
            style={{ borderRadius: 0, border: 'none', justifyContent: 'flex-start', gap: 10 }}
          >
            <IconLock size={16} />
            Alterar senha
          </button>

          {pwdOpen && (
            <div style={{ padding: '16px', borderTop: '1px solid var(--clx-line)' }}>
              {pwdSuccess ? (
                <div className="success-banner" style={{ marginBottom: 0 }}>
                  <IconCheckCircle size={16} />
                  Senha alterada! Você será redirecionado para o login…
                </div>
              ) : (
                <>
                  {pwdErr && (
                    <div className="error-banner" style={{ marginBottom: 12 }}>
                      <IconAlertCircle size={15} /> {pwdErr}
                    </div>
                  )}
                  <div className="form-grid" style={{ gap: 10 }}>
                    <PwdField
                      label="Senha atual"
                      value={oldPassword}
                      onChange={(v) => { setOldPassword(v); setPwdFieldErrs((p) => ({ ...p, oldPassword: '' })) }}
                      err={pwdFieldErrs.oldPassword}
                      autoComplete="current-password"
                    />
                    <PwdField
                      label="Nova senha"
                      value={newPassword}
                      onChange={(v) => { setNewPassword(v); setPwdFieldErrs((p) => ({ ...p, newPassword: '' })) }}
                      err={pwdFieldErrs.newPassword}
                      autoComplete="new-password"
                      placeholder="Mínimo 8 caracteres"
                    />
                    <PwdField
                      label="Confirmar nova senha"
                      value={confirmPassword}
                      onChange={(v) => { setConfirmPassword(v); setPwdFieldErrs((p) => ({ ...p, confirmPassword: '' })) }}
                      err={pwdFieldErrs.confirmPassword}
                      autoComplete="new-password"
                    />
                  </div>
                  <button
                    className="clx-btn clx-btn-accent clx-btn-block"
                    style={{ marginTop: 12 }}
                    onClick={handleSavePwd}
                    disabled={savingPwd}
                  >
                    {savingPwd ? <><Spinner size={14} /> Salvando…</> : 'Alterar senha'}
                  </button>
                </>
              )}
            </div>
          )}
        </div>

        {/* Sair */}
        <button
          className="clx-btn clx-btn-ghost clx-btn-block"
          onClick={handleLogout}
          style={{ color: 'var(--clx-error)', borderColor: 'rgba(239,68,68,0.20)' }}
        >
          <IconLogOut size={16} />
          Sair do sistema
        </button>
      </div>
    </>
  )
}

function PwdField({
  label, value, onChange, err, autoComplete, placeholder,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  err?: string
  autoComplete?: string
  placeholder?: string
}) {
  return (
    <div className="form-field">
      <label>{label} <span className="req">*</span></label>
      <input
        type="password"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={err ? 'err' : ''}
        autoComplete={autoComplete}
        placeholder={placeholder ?? ''}
      />
      {err && <span className="field-err">{err}</span>}
    </div>
  )
}
