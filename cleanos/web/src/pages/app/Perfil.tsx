import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { pb } from '../../lib/pb'
import { useAuth } from '../../contexts/AuthContext'
import { Spinner } from '../../components/ui/Spinner'
import { COLLECTIONS, type OrdemServico, getUtcDayBounds } from '../../lib/collections'
import { IconLogOut } from '../../components/ui/Icon'

interface Stats {
  totalHoje: number
  concluidasHoje: number
}


export default function Perfil() {
  const { user, role, logout } = useAuth()
  const navigate = useNavigate()

  const [stats, setStats] = useState<Stats | null>(null)
  const [loadingStats, setLoadingStats] = useState(true)

  const fetchStats = useCallback(async () => {
    if (!user?.id) return
    const { todayStart, tomorrowStart } = getUtcDayBounds()
    try {
      const result = await pb
        .collection(COLLECTIONS.ORDENS_SERVICO)
        .getList<OrdemServico>(1, 100, {
          filter: `profissional = '${user.id}' && data_hora >= '${todayStart}' && data_hora < '${tomorrowStart}'`,
        })
      const totalHoje = result.totalItems
      const concluidasHoje = result.items.filter((o) => o.status === 'concluida').length
      setStats({ totalHoje, concluidasHoje })
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
