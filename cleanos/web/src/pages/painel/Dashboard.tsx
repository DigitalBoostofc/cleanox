import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { pb } from '../../lib/pb'
import {
  COLLECTIONS,
  type OrdemServico,
  osStatusLabel,
  formatCurrency,
  formatDateTime,
  getBrtDayBounds,
  userDisplayName,
} from '../../lib/collections'
import { Spinner } from '../../components/ui/Spinner'
import { IconAlertCircle } from '../../components/ui/Icon'

interface KPIs {
  agendada: number
  atribuida: number
  em_andamento: number
  concluida: number
  faturamento_dia: number
}


export default function Dashboard() {
  const navigate = useNavigate()
  const [kpis, setKpis] = useState<KPIs | null>(null)
  const [upcoming, setUpcoming] = useState<OrdemServico[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    async function load() {
      try {
        setLoading(true)
        setError(null)
        const { todayStart, tomorrowStart } = getBrtDayBounds()

        const [todayOS, upcomingOS] = await Promise.all([
          pb.collection(COLLECTIONS.ORDENS_SERVICO).getFullList<OrdemServico>({
            filter: `data_hora >= '${todayStart}' && data_hora < '${tomorrowStart}'`,
          }),
          pb.collection(COLLECTIONS.ORDENS_SERVICO).getFullList<OrdemServico>({
            filter: `status != 'concluida' && status != 'cancelada' && data_hora >= '${todayStart}'`,
            sort: 'data_hora',
            expand: 'profissional',
          }),
        ])

        if (cancelled) return

        setKpis({
          agendada: todayOS.filter((o) => o.status === 'agendada').length,
          atribuida: todayOS.filter((o) => o.status === 'atribuida').length,
          em_andamento: todayOS.filter((o) => o.status === 'em_andamento').length,
          concluida: todayOS.filter((o) => o.status === 'concluida').length,
          faturamento_dia: todayOS
            .filter((o) => o.status === 'concluida')
            .reduce((sum, o) => sum + (o.valor_pago ?? 0), 0),
        })
        setUpcoming(upcomingOS.slice(0, 20))
      } catch {
        if (!cancelled) setError('Não foi possível carregar o dashboard. Tente novamente.')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return (
      <div className="loading-overlay">
        <Spinner size={22} /> Carregando…
      </div>
    )
  }

  if (error) {
    return (
      <div className="error-banner" role="alert">
        <IconAlertCircle size={16} /> {error}
      </div>
    )
  }

  return (
    <div>
      {/* KPIs do dia */}
      <div className="section-header">
        <h2>Hoje</h2>
        <span style={{ fontSize: '0.82rem', color: 'var(--clx-ink-3)' }}>
          {new Date().toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long' })}
        </span>
      </div>

      <div className="kpi-grid">
        <div className="kpi-card">
          <div className="kpi-card-label">Agendadas</div>
          <div className="kpi-card-value info">{kpis?.agendada ?? 0}</div>
        </div>
        <div className="kpi-card">
          <div className="kpi-card-label">Atribuídas</div>
          <div className="kpi-card-value" style={{ color: 'var(--clx-status-atribuida)' }}>
            {kpis?.atribuida ?? 0}
          </div>
        </div>
        <div className="kpi-card">
          <div className="kpi-card-label">Em andamento</div>
          <div className="kpi-card-value warning">{kpis?.em_andamento ?? 0}</div>
        </div>
        <div className="kpi-card">
          <div className="kpi-card-label">Concluídas</div>
          <div className="kpi-card-value success">{kpis?.concluida ?? 0}</div>
        </div>
        <div className="kpi-card" style={{ gridColumn: 'span 1' }}>
          <div className="kpi-card-label">Faturamento hoje</div>
          <div className="kpi-card-value accent" style={{ fontSize: '1.35rem' }}>
            {formatCurrency(kpis?.faturamento_dia ?? 0)}
          </div>
        </div>
      </div>

      {/* Próximos atendimentos */}
      <div className="section-header" style={{ marginTop: 8 }}>
        <h2>Próximos atendimentos</h2>
        <button
          className="clx-btn clx-btn-ghost clx-btn-sm"
          onClick={() => navigate('/painel/ordens')}
        >
          Ver todos
        </button>
      </div>

      <div className="dash-upcoming">
        <div className="dash-upcoming-header">
          Ordens abertas — {upcoming.length} registro{upcoming.length !== 1 ? 's' : ''}
        </div>

        {upcoming.length === 0 ? (
          <div className="empty-state" style={{ padding: '32px 24px' }}>
            <h4>Nenhum atendimento pendente</h4>
            <p>Todas as ordens de serviço estão concluídas ou canceladas.</p>
          </div>
        ) : (
          upcoming.map((os) => {
            const prof = os.expand?.profissional
            return (
              <div
                key={os.id}
                className="dash-upcoming-item"
                style={{ cursor: 'pointer' }}
                onClick={() => navigate('/painel/ordens')}
              >
                <div className="dash-upcoming-time">
                  {new Date(os.data_hora).toLocaleTimeString('pt-BR', {
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                  <br />
                  <span style={{ fontSize: '0.68rem', color: 'var(--clx-ink-3)' }}>
                    {new Date(os.data_hora).toLocaleDateString('pt-BR', {
                      day: '2-digit',
                      month: '2-digit',
                    })}
                  </span>
                </div>

                <div className="dash-upcoming-info">
                  <strong>{os.nome_curto} — {os.bairro}</strong>
                  <span>
                    {os.tipo_servico_nome ?? '—'}
                    {prof ? ` · ${userDisplayName(prof)}` : ''}
                  </span>
                </div>

                <div className="dash-upcoming-badge">
                  <span className={`clx-status clx-status-${os.status}`}>
                    {osStatusLabel(os.status)}
                  </span>
                </div>
              </div>
            )
          })
        )}
      </div>

      {/* Acesso rápido */}
      <div className="section-header" style={{ marginTop: 24 }}>
        <h2>Acesso rápido</h2>
      </div>
      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
        <button
          className="clx-btn clx-btn-accent"
          onClick={() => navigate('/painel/ordens')}
        >
          + Nova OS
        </button>
        <button
          className="clx-btn clx-btn-ghost"
          onClick={() => navigate('/painel/clientes')}
        >
          + Novo Cliente
        </button>
        <button
          className="clx-btn clx-btn-ghost"
          onClick={() => navigate('/painel/agenda')}
        >
          Ver Agenda
        </button>
        <button
          className="clx-btn clx-btn-ghost"
          onClick={() => navigate('/painel/financeiro')}
        >
          Financeiro
        </button>
      </div>
    </div>
  )
}
