import { useState, useEffect, useCallback } from 'react'
import { pb } from '../../lib/pb'
import { useAuth } from '../../contexts/AuthContext'
import { Spinner } from '../../components/ui/Spinner'
import {
  type OrdemServico,
  COLLECTIONS,
  formatCurrency,
} from '../../lib/collections'
import { IconMap, IconAlertCircle } from '../../components/ui/Icon'

function mapsUrl(address: string): string {
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`
}

function formatHour(iso: string): string {
  if (!iso) return '--:--'
  return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
}

function getUtcDayBounds() {
  const now = new Date()
  const p = (n: number) => String(n).padStart(2, '0')
  const y = now.getUTCFullYear()
  const m = p(now.getUTCMonth() + 1)
  const d = p(now.getUTCDate())
  const tom = new Date(Date.UTC(y, now.getUTCMonth(), now.getUTCDate() + 1))
  return {
    todayStart: `${y}-${m}-${d} 00:00:00`,
    tomorrowStart: `${tom.getUTCFullYear()}-${p(tom.getUTCMonth() + 1)}-${p(tom.getUTCDate())} 00:00:00`,
  }
}

export default function Mapa() {
  const { user } = useAuth()
  const [activeOS, setActiveOS] = useState<OrdemServico | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchActive = useCallback(async () => {
    if (!user?.id) return
    setLoading(true)
    setError(null)

    const { todayStart, tomorrowStart } = getUtcDayBounds()

    try {
      const result = await pb
        .collection(COLLECTIONS.ORDENS_SERVICO)
        .getList<OrdemServico>(1, 5, {
          filter: `profissional = '${user.id}' && status = 'em_andamento' && data_hora >= '${todayStart}' && data_hora < '${tomorrowStart}'`,
          sort: '-updated',
        })
      setActiveOS(result.items[0] ?? null)
    } catch {
      setError('Não foi possível carregar o mapa.')
    } finally {
      setLoading(false)
    }
  }, [user?.id])

  useEffect(() => {
    fetchActive()
  }, [fetchActive])

  return (
    <>
      <div className="profapp-page-header">
        <h1>Mapa</h1>
      </div>

      <div className="profapp-page-body">
        {loading && (
          <div className="loading-overlay">
            <Spinner size={22} />
            Verificando serviço ativo…
          </div>
        )}

        {!loading && error && (
          <div className="error-banner">
            <IconAlertCircle size={14} />
            {error}
          </div>
        )}

        {!loading && !error && activeOS && activeOS.endereco_liberado ? (
          <div>
            {/* Info do serviço ativo */}
            <div
              className="clx-card"
              style={{
                padding: '18px 20px',
                marginBottom: 16,
                borderLeft: '3px solid var(--clx-status-em_andamento)',
              }}
            >
              <div
                style={{
                  fontSize: '0.72rem',
                  fontWeight: 700,
                  letterSpacing: '0.07em',
                  textTransform: 'uppercase',
                  color: 'var(--clx-status-em_andamento)',
                  marginBottom: 8,
                }}
              >
                Serviço em andamento
              </div>

              <div
                style={{
                  fontFamily: 'var(--clx-font-display)',
                  fontSize: '1.1rem',
                  fontWeight: 800,
                  color: 'var(--clx-ink)',
                  letterSpacing: '-0.02em',
                  marginBottom: 4,
                }}
              >
                {formatHour(activeOS.data_hora)} — {activeOS.nome_curto}
              </div>

              {activeOS.tipo_servico_nome && (
                <div style={{ fontSize: '0.85rem', color: 'var(--clx-ink-2)', marginBottom: 2 }}>
                  {activeOS.tipo_servico_nome}
                </div>
              )}

              <div style={{ fontSize: '0.85rem', color: 'var(--clx-ink-3)', marginBottom: 14 }}>
                {activeOS.bairro} · {formatCurrency(activeOS.valor_servico ?? 0)}
              </div>

              {/* Endereço */}
              <div
                style={{
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: 8,
                  padding: '10px 14px',
                  background: 'rgba(0,194,184,0.07)',
                  border: '1px solid rgba(0,194,184,0.20)',
                  borderRadius: 'var(--clx-r-md)',
                  marginBottom: 16,
                }}
              >
                <span style={{ marginTop: 2, flexShrink: 0, color: 'var(--clx-primary-2)', display: 'flex' }}>
                  <IconMap size={16} />
                </span>
                <span style={{ fontSize: '0.9rem', color: 'var(--clx-ink)', lineHeight: 1.45 }}>
                  {activeOS.endereco_liberado}
                </span>
              </div>

              {/* Botão principal */}
              <a
                href={mapsUrl(activeOS.endereco_liberado)}
                target="_blank"
                rel="noopener noreferrer"
                className="clx-btn clx-btn-accent clx-btn-block clx-btn-lg"
                style={{ textDecoration: 'none' }}
              >
                <IconMap size={18} />
                Abrir no Google Maps
              </a>
            </div>

            <p
              style={{
                fontSize: '0.78rem',
                color: 'var(--clx-ink-3)',
                textAlign: 'center',
                lineHeight: 1.5,
              }}
            >
              O endereço é liberado apenas enquanto o serviço está em andamento.
            </p>
          </div>
        ) : (
          !loading &&
          !error && (
            <div className="empty-state" style={{ paddingTop: 80 }}>
              <IconMap size={40} />
              <h4>Nenhum serviço ativo</h4>
              <p>
                O mapa é liberado quando você toca em "Iniciar serviço" na tela de Serviços.
              </p>
            </div>
          )
        )}
      </div>
    </>
  )
}
