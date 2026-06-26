import { useState, useEffect, useRef, useCallback } from 'react'
import { Navigate } from 'react-router-dom'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../../lib/pb'
import { useAuth } from '../../contexts/AuthContext'
import { Spinner } from '../../components/ui/Spinner'
import {
  IconWhatsApp,
  IconAlertCircle,
  IconCheckCircle,
  IconRefresh,
  IconX,
} from '../../components/ui/Icon'

type WAStatus = 'disconnected' | 'connecting' | 'connected'

interface WAStatusResponse {
  configured: boolean
  status: WAStatus
  instanceName?: string
  profileName?: string
}

interface WAConnectResponse {
  status: string
  qrcode?: string
  paircode?: string
}

function extractWAError(err: unknown): string {
  if (err instanceof ClientResponseError) {
    if (err.status === 0) return 'Sem conexão com o servidor.'
    const data = err.data as Record<string, unknown> | undefined
    if (typeof data?.message === 'string' && data.message) return data.message
    if (typeof data?.error === 'string' && data.error) return data.error
    return `Erro ${err.status}. Tente novamente.`
  }
  if (err instanceof Error) return err.message
  return 'Erro desconhecido.'
}

function toDataUri(qr: string): string {
  if (qr.startsWith('data:')) return qr
  return `data:image/png;base64,${qr}`
}

const STATUS_LABEL: Record<WAStatus, string> = {
  disconnected: 'Desconectado',
  connecting: 'Aguardando conexão…',
  connected: 'Conectado',
}

const STATUS_COLOR: Record<WAStatus, string> = {
  disconnected: 'var(--clx-error)',
  connecting: '#f59e0b',
  connected: 'var(--clx-success)',
}

export default function WhatsAppAdmin() {
  const { role } = useAuth()

  const [status, setStatus] = useState<WAStatus | null>(null)
  const [profileName, setProfileName] = useState<string | undefined>()
  const [qrcode, setQrcode] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const pollingRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const stopPolling = useCallback(() => {
    if (pollingRef.current !== null) {
      clearInterval(pollingRef.current)
      pollingRef.current = null
    }
  }, [])

  const startPolling = useCallback(() => {
    stopPolling()
    pollingRef.current = setInterval(async () => {
      try {
        const data = await pb.send<WAStatusResponse>('/api/cleanos/whatsapp/status', { method: 'GET' })
        setStatus(data.status)
        setProfileName(data.profileName)
        if (data.status === 'connected') {
          stopPolling()
          setQrcode(null)
          setActionLoading(false)
        }
      } catch {
        // ignore polling errors silently
      }
    }, 3000)
  }, [stopPolling])

  const loadStatus = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await pb.send<WAStatusResponse>('/api/cleanos/whatsapp/status', { method: 'GET' })
      setStatus(data.status)
      setProfileName(data.profileName)
      if (data.status === 'connecting') {
        setActionLoading(true)
        startPolling()
      }
    } catch (err) {
      setError(extractWAError(err))
    } finally {
      setLoading(false)
    }
  }, [startPolling])

  useEffect(() => {
    loadStatus()
    return stopPolling
  }, [loadStatus, stopPolling])

  const handleConnect = async () => {
    setActionLoading(true)
    setError(null)
    setQrcode(null)
    try {
      const res = await pb.send<WAConnectResponse>('/api/cleanos/whatsapp/connect', { method: 'POST' })
      setStatus('connecting')
      if (res.qrcode) setQrcode(res.qrcode)
      startPolling()
    } catch (err) {
      setActionLoading(false)
      setError(extractWAError(err))
    }
  }

  const handleDisconnect = async () => {
    setActionLoading(true)
    setError(null)
    stopPolling()
    try {
      await pb.send('/api/cleanos/whatsapp/disconnect', { method: 'POST' })
      setStatus('disconnected')
      setProfileName(undefined)
      setQrcode(null)
    } catch (err) {
      setError(extractWAError(err))
    } finally {
      setActionLoading(false)
    }
  }

  // Guard after all hooks
  if (role !== 'admin') {
    return <Navigate to="/painel" replace />
  }

  const showConnect = !loading && (status === 'disconnected' || (status === 'connecting' && !qrcode))
  const showDisconnect = !loading && status === 'connected'
  const showQr = !loading && status === 'connecting' && !!qrcode

  return (
    <div style={{ maxWidth: 560 }}>
      {/* Painel principal de status */}
      <div className="clx-card clx-card-p" style={{ marginBottom: 20 }}>
        <div className="section-header" style={{ marginBottom: 16 }}>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <IconWhatsApp size={18} />
            WhatsApp da empresa
          </h2>
          <button
            className="icon-btn"
            onClick={loadStatus}
            disabled={loading || actionLoading}
            aria-label="Atualizar status"
          >
            <IconRefresh size={16} />
          </button>
        </div>

        {/* Nota */}
        <div
          style={{
            padding: '10px 14px',
            background: 'rgba(0,194,184,0.06)',
            border: '1px solid rgba(0,194,184,0.18)',
            borderRadius: 'var(--clx-r-md)',
            fontSize: '0.82rem',
            color: 'var(--clx-ink-2)',
            lineHeight: 1.5,
            marginBottom: 20,
          }}
        >
          Este é o número da empresa pelo qual os avisos de chegada são enviados aos clientes.
          Os profissionais nunca veem ou usam o próprio telefone para contato.
        </div>

        {/* Loading inicial */}
        {loading && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0' }}>
            <Spinner size={18} />
            <span style={{ fontSize: '0.88rem', color: 'var(--clx-ink-2)' }}>
              Verificando status…
            </span>
          </div>
        )}

        {/* Erro */}
        {!loading && error && (
          <div className="error-banner" style={{ marginBottom: 16 }}>
            <IconAlertCircle size={14} />
            {error}
            <button
              className="clx-btn clx-btn-ghost clx-btn-sm"
              onClick={loadStatus}
              style={{ marginLeft: 'auto' }}
            >
              Tentar novamente
            </button>
          </div>
        )}

        {/* Badge de status */}
        {!loading && status && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20 }}>
            <span
              style={{
                display: 'inline-block',
                width: 10,
                height: 10,
                borderRadius: '50%',
                background: STATUS_COLOR[status],
                flexShrink: 0,
              }}
            />
            <span style={{ fontWeight: 600, fontSize: '0.92rem', color: STATUS_COLOR[status] }}>
              {STATUS_LABEL[status]}
            </span>
            {status === 'connected' && profileName && (
              <span style={{ fontSize: '0.82rem', color: 'var(--clx-ink-2)' }}>
                — {profileName}
              </span>
            )}
            {status === 'connecting' && (
              <Spinner size={14} />
            )}
          </div>
        )}

        {/* Botão conectar (disconnected ou connecting sem QR) */}
        {showConnect && (
          <button
            className="clx-btn clx-btn-primary"
            onClick={handleConnect}
            disabled={actionLoading}
          >
            {actionLoading ? <Spinner size={15} /> : <IconWhatsApp size={15} />}
            {status === 'connecting' ? 'Gerar novo QR code' : 'Conectar WhatsApp'}
          </button>
        )}

        {/* Botão desconectar (connected) */}
        {showDisconnect && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
            <button
              className="clx-btn clx-btn-ghost"
              onClick={handleDisconnect}
              disabled={actionLoading}
              style={{ color: 'var(--clx-error)' }}
            >
              {actionLoading ? <Spinner size={15} /> : <IconX size={15} />}
              Desconectar
            </button>
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                fontSize: '0.82rem',
                color: 'var(--clx-success)',
              }}
            >
              <IconCheckCircle size={14} />
              Avisos ativos
            </div>
          </div>
        )}
      </div>

      {/* Card do QR code */}
      {showQr && (
        <div className="clx-card clx-card-p">
          <h3 style={{ fontSize: '0.95rem', fontWeight: 700, marginBottom: 14 }}>
            Escaneie o QR code
          </h3>

          <ol
            style={{
              paddingLeft: 20,
              fontSize: '0.84rem',
              color: 'var(--clx-ink-2)',
              lineHeight: 1.8,
              marginBottom: 20,
            }}
          >
            <li>Abra o WhatsApp da empresa no celular</li>
            <li>Toque em <strong>Aparelhos conectados</strong></li>
            <li>Toque em <strong>Conectar aparelho</strong></li>
            <li>Aponte a câmera para o código abaixo</li>
          </ol>

          <div
            style={{
              display: 'flex',
              justifyContent: 'center',
              padding: 16,
              background: '#fff',
              borderRadius: 'var(--clx-r-md)',
              border: '1px solid var(--clx-line)',
            }}
          >
            <img
              src={toDataUri(qrcode)}
              alt="QR code para conectar o WhatsApp"
              width={220}
              height={220}
              style={{ imageRendering: 'pixelated' }}
            />
          </div>

          <div
            style={{
              marginTop: 14,
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              fontSize: '0.82rem',
              color: 'var(--clx-ink-3)',
            }}
          >
            <Spinner size={14} />
            Aguardando leitura do QR code…
          </div>
        </div>
      )}
    </div>
  )
}
