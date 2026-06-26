import { useState, type FormEvent } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { Logo } from '../components/ui/Logo'
import { Spinner } from '../components/ui/Spinner'
import { IconAlertCircle } from '../components/ui/Icon'

interface LocationState {
  from?: { pathname: string }
}

export default function Login() {
  const { user, role, login, isLoading } = useAuth()
  const location = useLocation()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)

  // Redireciona usuário já autenticado para o ambiente correto
  if (user) {
    const from = (location.state as LocationState)?.from?.pathname
    if (from && from !== '/login') return <Navigate to={from} replace />
    return <Navigate to={role === 'profissional' ? '/app' : '/painel'} replace />
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!email.trim() || !password) {
      setError('Preencha o e-mail e a senha.')
      return
    }

    try {
      await login(email.trim(), password)
      // O redirect acontece no próximo render via o bloco acima (user !== null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro inesperado.')
    }
  }

  return (
    <div className="login-root">
      <div className="login-wrap">
        {/* Marca */}
        <div className="login-brand">
          <Logo size={52} showText showSub />
          <span className="login-tagline">Sistema de Gestão Interno</span>
        </div>

        {/* Card */}
        <div className="login-card">
          <h2>Acessar</h2>
          <p className="login-sub">Entre com suas credenciais para continuar.</p>

          <form className="login-form" onSubmit={handleSubmit} noValidate>
            {/* E-mail */}
            <div className="login-field">
              <label htmlFor="login-email" className="login-label">
                E-mail
              </label>
              <input
                id="login-email"
                type="email"
                className={`login-input${error ? ' has-error' : ''}`}
                placeholder="seuemail@cleanox.com"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value)
                  setError(null)
                }}
                autoComplete="email"
                autoFocus
                disabled={isLoading}
              />
            </div>

            {/* Senha */}
            <div className="login-field">
              <label htmlFor="login-password" className="login-label">
                Senha
              </label>
              <input
                id="login-password"
                type="password"
                className={`login-input${error ? ' has-error' : ''}`}
                placeholder="••••••••"
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value)
                  setError(null)
                }}
                autoComplete="current-password"
                disabled={isLoading}
              />
            </div>

            {/* Mensagem de erro */}
            {error && (
              <div className="login-error-msg" role="alert">
                <IconAlertCircle size={16} />
                {error}
              </div>
            )}

            {/* Submit */}
            <button
              type="submit"
              className="login-btn"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Spinner size={16} />
                  Entrando…
                </>
              ) : (
                'Entrar'
              )}
            </button>
          </form>
        </div>

        <p className="login-footer">
          Cleanox &copy; {new Date().getFullYear()} — Uso interno
        </p>
      </div>
    </div>
  )
}
