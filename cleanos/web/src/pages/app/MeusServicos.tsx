import { useState, useEffect, useCallback, useRef } from 'react'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../../lib/pb'
import { useAuth } from '../../contexts/AuthContext'
import { Modal } from '../../components/ui/Modal'
import { Spinner } from '../../components/ui/Spinner'
import {
  type OrdemServico,
  type FormaPagamento,
  COLLECTIONS,
  osStatusLabel,
  formaPagamentoLabel,
  formatCurrency,
  getUtcDayBounds,
  formatHour,
} from '../../lib/collections'
import {
  IconServices,
  IconAlertCircle,
  IconRefresh,
  IconMap,
  IconCheckCircle,
  IconDollar,
} from '../../components/ui/Icon'

// ── helpers ──────────────────────────────────────────────────────────

function isOsToday(os: OrdemServico): boolean {
  const d = new Date(os.data_hora)
  const now = new Date()
  return (
    d.getUTCFullYear() === now.getUTCFullYear() &&
    d.getUTCMonth() === now.getUTCMonth() &&
    d.getUTCDate() === now.getUTCDate()
  )
}

function mapsUrl(address: string): string {
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`
}

function extractApiError(err: unknown): string {
  if (err instanceof ClientResponseError) {
    if (err.status === 0) return 'Sem conexão com o servidor.'
    const data = err.data as Record<string, unknown> | undefined
    if (typeof data?.message === 'string' && data.message) return data.message
    return `Erro ${err.status}: tente novamente.`
  }
  if (err instanceof Error) return err.message
  return 'Erro desconhecido.'
}

// ── types ─────────────────────────────────────────────────────────────

interface PayForm {
  valor_pago: string
  forma_pagamento: FormaPagamento | ''
}

interface Toast {
  id: number
  text: string
  type: 'success' | 'error' | 'info'
}

let toastId = 0

// ── OSCard ────────────────────────────────────────────────────────────

interface OSCardProps {
  os: OrdemServico
  onIniciar: (os: OrdemServico) => Promise<void>
  onAvisar: (os: OrdemServico) => void
  onPagar: (os: OrdemServico) => void
  onConcluir: (os: OrdemServico) => Promise<void>
  actionLoading: boolean
  actionError: string | null
}

function OSCard({ os, onIniciar, onAvisar, onPagar, onConcluir, actionLoading, actionError }: OSCardProps) {
  const hoje = isOsToday(os)
  const pagamentoRegistrado = (os.valor_pago ?? 0) > 0 && !!os.forma_pagamento

  return (
    <div
      className="clx-card"
      style={{
        marginBottom: 12,
        borderLeft: `3px solid var(--clx-status-${os.status})`,
        overflow: 'hidden',
      }}
    >
      {/* Cabeçalho do card */}
      <div
        style={{
          display: 'flex',
          alignItems: 'flex-start',
          justifyContent: 'space-between',
          gap: 12,
          padding: '14px 16px 10px',
        }}
      >
        {/* Horário + cliente */}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
            <span
              style={{
                fontFamily: 'var(--clx-font-display)',
                fontSize: '1.25rem',
                fontWeight: 800,
                color: 'var(--clx-accent)',
                letterSpacing: '-0.02em',
                flexShrink: 0,
              }}
            >
              {formatHour(os.data_hora)}
            </span>
            <span
              style={{
                fontWeight: 700,
                fontSize: '0.97rem',
                color: 'var(--clx-ink)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {os.nome_curto}
            </span>
          </div>

          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px 12px' }}>
            {os.tipo_servico_nome && (
              <span style={{ fontSize: '0.82rem', color: 'var(--clx-ink-2)' }}>
                {os.tipo_servico_nome}
              </span>
            )}
            {os.bairro && (
              <span style={{ fontSize: '0.82rem', color: 'var(--clx-ink-3)' }}>
                {os.bairro}
              </span>
            )}
          </div>
        </div>

        {/* Status + valor */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4, flexShrink: 0 }}>
          <span className={`clx-status clx-status-${os.status}`} style={{ whiteSpace: 'nowrap' }}>
            {osStatusLabel(os.status)}
          </span>
          <span
            style={{
              fontSize: '0.88rem',
              fontWeight: 700,
              color: 'var(--clx-ink-2)',
            }}
          >
            {formatCurrency(os.valor_servico ?? 0)}
          </span>
        </div>
      </div>

      {/* Endereço liberado (só em_andamento) */}
      {os.status === 'em_andamento' && os.endereco_liberado && (
        <div
          style={{
            margin: '0 16px 10px',
            padding: '10px 14px',
            background: 'rgba(0,194,184,0.07)',
            border: '1px solid rgba(0,194,184,0.20)',
            borderRadius: 'var(--clx-r-md)',
            display: 'flex',
            alignItems: 'flex-start',
            gap: 8,
          }}
        >
          <span style={{ marginTop: 2, flexShrink: 0, color: 'var(--clx-primary-2)', display: 'flex' }}>
                    <IconMap size={16} />
                  </span>
          <span style={{ fontSize: '0.87rem', color: 'var(--clx-ink)', lineHeight: 1.4 }}>
            {os.endereco_liberado}
          </span>
        </div>
      )}

      {/* Pagamento concluído (concluida) */}
      {os.status === 'concluida' && os.valor_pago && os.forma_pagamento && (
        <div
          style={{
            margin: '0 16px 10px',
            padding: '8px 12px',
            background: 'rgba(34,197,94,0.07)',
            border: '1px solid rgba(34,197,94,0.20)',
            borderRadius: 'var(--clx-r-md)',
            fontSize: '0.82rem',
            color: 'var(--clx-success)',
          }}
        >
          Pago: {formatCurrency(os.valor_pago)} via {formaPagamentoLabel(os.forma_pagamento)}
        </div>
      )}

      {/* Erro de ação */}
      {actionError && (
        <div className="error-banner" style={{ margin: '0 16px 10px' }}>
          <IconAlertCircle size={14} />
          {actionError}
        </div>
      )}

      {/* Ações */}
      <div
        style={{
          padding: '0 16px 14px',
          display: 'flex',
          flexDirection: 'column',
          gap: 8,
        }}
      >
        {/* atribuida → Iniciar */}
        {os.status === 'atribuida' && (
          <span
            title={!hoje ? 'Disponível apenas no dia do serviço' : undefined}
            style={{ display: 'block' }}
          >
            <button
              className="clx-btn clx-btn-accent clx-btn-block"
              disabled={!hoje || actionLoading}
              onClick={() => onIniciar(os)}
            >
              {actionLoading ? <Spinner size={16} /> : null}
              {hoje ? 'Iniciar serviço' : 'Iniciar (disponível no dia)'}
            </button>
          </span>
        )}

        {/* em_andamento → rotas + avisar + pagamento + concluir */}
        {os.status === 'em_andamento' && (
          <>
            {/* Ver rota + Avisar */}
            <div style={{ display: 'flex', gap: 8 }}>
              {os.endereco_liberado && (
                <a
                  href={mapsUrl(os.endereco_liberado)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="clx-btn clx-btn-ghost"
                  style={{ flex: 1, textDecoration: 'none' }}
                >
                  <IconMap size={15} />
                  Ver rota
                </a>
              )}
              <button
                className="clx-btn clx-btn-ghost"
                style={{ flex: 1 }}
                onClick={() => onAvisar(os)}
              >
                Avisar que estou a caminho
              </button>
            </div>

            {/* Registrar pagamento */}
            {!pagamentoRegistrado && (
              <button
                className="clx-btn clx-btn-ghost clx-btn-block"
                onClick={() => onPagar(os)}
                disabled={actionLoading}
              >
                <IconDollar size={15} />
                Registrar pagamento
              </button>
            )}

            {/* Pagamento já registrado — confirmar para concluir */}
            {pagamentoRegistrado && (
              <div
                style={{
                  padding: '8px 12px',
                  background: 'rgba(34,197,94,0.07)',
                  border: '1px solid rgba(34,197,94,0.20)',
                  borderRadius: 'var(--clx-r-md)',
                  fontSize: '0.82rem',
                  color: 'var(--clx-success)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                }}
              >
                <IconCheckCircle size={14} />
                Pagamento: {formatCurrency(os.valor_pago!)} via{' '}
                {formaPagamentoLabel(os.forma_pagamento!)}
              </div>
            )}

            {/* Concluir — habilitado apenas após pagamento */}
            <span
              title={!pagamentoRegistrado ? 'Registre o pagamento antes de concluir' : undefined}
              style={{ display: 'block' }}
            >
              <button
                className="clx-btn clx-btn-primary clx-btn-block"
                disabled={!pagamentoRegistrado || actionLoading}
                onClick={() => onConcluir(os)}
              >
                {actionLoading ? <Spinner size={16} /> : <IconCheckCircle size={15} />}
                Concluir serviço
              </button>
            </span>
          </>
        )}

        {/* cancelada — somente leitura */}
        {os.status === 'cancelada' && (
          <div
            style={{
              fontSize: '0.82rem',
              color: 'var(--clx-ink-3)',
              textAlign: 'center',
              padding: '4px 0',
            }}
          >
            Serviço cancelado.
          </div>
        )}
      </div>
    </div>
  )
}

// ── MeusServicos ──────────────────────────────────────────────────────

export default function MeusServicos() {
  const { user } = useAuth()

  const [todayOS, setTodayOS] = useState<OrdemServico[]>([])
  const [upcomingOS, setUpcomingOS] = useState<OrdemServico[]>([])
  const [loading, setLoading] = useState(true)
  const [fetchError, setFetchError] = useState<string | null>(null)

  // loading/error por OS id
  const [actionLoading, setActionLoading] = useState<Record<string, boolean>>({})
  const [actionError, setActionError] = useState<Record<string, string | null>>({})

  // modal de pagamento
  const [payModal, setPayModal] = useState<OrdemServico | null>(null)
  const [payForm, setPayForm] = useState<PayForm>({ valor_pago: '', forma_pagamento: '' })
  const [payLoading, setPayLoading] = useState(false)
  const [payError, setPayError] = useState<string | null>(null)

  // toasts
  const [toasts, setToasts] = useState<Toast[]>([])
  const showToast = useCallback((text: string, type: Toast['type'] = 'info') => {
    const id = ++toastId
    setToasts((prev) => [...prev, { id, text, type }])
    setTimeout(() => setToasts((prev) => prev.filter((t) => t.id !== id)), 3800)
  }, [])

  // controle de duplo clique no "avisar"
  const avisoSent = useRef<Set<string>>(new Set())

  // ── fetch ────────────────────────────────────────────────────────────

  const fetchOS = useCallback(async () => {
    if (!user?.id) return
    setLoading(true)
    setFetchError(null)

    const { todayStart, tomorrowStart } = getUtcDayBounds()

    try {
      const [todayRes, upcomingRes] = await Promise.all([
        pb.collection(COLLECTIONS.ORDENS_SERVICO).getList<OrdemServico>(1, 50, {
          filter: `profissional = '${user.id}' && data_hora >= '${todayStart}' && data_hora < '${tomorrowStart}'`,
          sort: 'data_hora',
        }),
        pb.collection(COLLECTIONS.ORDENS_SERVICO).getList<OrdemServico>(1, 20, {
          filter: `profissional = '${user.id}' && data_hora >= '${tomorrowStart}'`,
          sort: 'data_hora',
        }),
      ])

      setTodayOS(todayRes.items)
      setUpcomingOS(upcomingRes.items)
    } catch (err) {
      setFetchError(extractApiError(err))
    } finally {
      setLoading(false)
    }
  }, [user?.id])

  useEffect(() => {
    fetchOS()
  }, [fetchOS])

  // ── realtime ─────────────────────────────────────────────────────────

  useEffect(() => {
    if (!user?.id) return

    let cancelled = false
    let unsub: (() => void) | undefined

    pb.collection(COLLECTIONS.ORDENS_SERVICO)
      .subscribe<OrdemServico>('*', (event) => {
        const record = event.record

        if (event.action === 'update') {
          const updateList = (list: OrdemServico[]) =>
            list.map((o) => (o.id === record.id ? record : o))
          setTodayOS((prev) => updateList(prev))
          setUpcomingOS((prev) => updateList(prev))
        } else if (event.action === 'create') {
          if (record.profissional !== user?.id) return
          const { todayStart, tomorrowStart } = getUtcDayBounds()
          const byDate = (a: OrdemServico, b: OrdemServico) =>
            a.data_hora.localeCompare(b.data_hora)
          if (record.data_hora >= todayStart && record.data_hora < tomorrowStart) {
            setTodayOS((prev) => [...prev, record].sort(byDate))
          } else if (record.data_hora >= tomorrowStart) {
            setUpcomingOS((prev) => [...prev, record].sort(byDate))
          }
        } else if (event.action === 'delete') {
          setTodayOS((prev) => prev.filter((o) => o.id !== record.id))
          setUpcomingOS((prev) => prev.filter((o) => o.id !== record.id))
        }
      })
      .then((fn) => {
        if (cancelled) fn()
        else unsub = fn
      })
      .catch(() => {})

    return () => {
      cancelled = true
      unsub?.()
    }
  }, [user?.id])

  // ── actions ───────────────────────────────────────────────────────────

  function setOsLoading(id: string, val: boolean) {
    setActionLoading((prev) => ({ ...prev, [id]: val }))
  }
  function setOsError(id: string, msg: string | null) {
    setActionError((prev) => ({ ...prev, [id]: msg }))
  }

  function updateOsInState(updated: OrdemServico) {
    setTodayOS((prev) => prev.map((o) => (o.id === updated.id ? updated : o)))
    setUpcomingOS((prev) => prev.map((o) => (o.id === updated.id ? updated : o)))
  }

  const handleIniciar = useCallback(async (os: OrdemServico) => {
    setOsLoading(os.id, true)
    setOsError(os.id, null)
    try {
      const updated = await pb
        .collection(COLLECTIONS.ORDENS_SERVICO)
        .update<OrdemServico>(os.id, { status: 'em_andamento' })
      updateOsInState(updated)
      showToast('Serviço iniciado! Endereço liberado.', 'success')
    } catch (err) {
      const msg = extractApiError(err)
      setOsError(os.id, msg)
      showToast(msg, 'error')
    } finally {
      setOsLoading(os.id, false)
    }
  }, [showToast])

  const handleAvisar = useCallback((os: OrdemServico) => {
    if (avisoSent.current.has(os.id)) return
    avisoSent.current.add(os.id)
    // [INTEGRAÇÃO FUTURA] Aqui será feita uma chamada ao endpoint da Cleanox
    // que dispara o WhatsApp/SMS para o cliente. O profissional NÃO tem o
    // telefone do cliente — o backend enviará em nome da empresa.
    showToast('Cliente será avisado pelo sistema da Cleanox.', 'info')
    // Reabilita após 30s para evitar spam
    setTimeout(() => avisoSent.current.delete(os.id), 30_000)
  }, [showToast])

  const handlePagar = useCallback((os: OrdemServico) => {
    setPayModal(os)
    setPayForm({
      valor_pago: String(os.valor_servico ?? 0),
      forma_pagamento: os.forma_pagamento ?? '',
    })
    setPayError(null)
  }, [])

  const handlePaySubmit = useCallback(async () => {
    if (!payModal) return

    const valor = parseFloat(payForm.valor_pago.replace(',', '.'))
    if (!valor || valor <= 0) {
      setPayError('Informe o valor pago.')
      return
    }
    if (!payForm.forma_pagamento) {
      setPayError('Selecione a forma de pagamento.')
      return
    }

    setPayLoading(true)
    setPayError(null)
    try {
      const updated = await pb
        .collection(COLLECTIONS.ORDENS_SERVICO)
        .update<OrdemServico>(payModal.id, {
          valor_pago: valor,
          forma_pagamento: payForm.forma_pagamento,
        })
      updateOsInState(updated)
      setPayModal(null)
      showToast('Pagamento registrado. Agora você pode concluir o serviço.', 'success')
    } catch (err) {
      setPayError(extractApiError(err))
    } finally {
      setPayLoading(false)
    }
  }, [payModal, payForm, showToast])

  const handleConcluir = useCallback(async (os: OrdemServico) => {
    if (!(os.valor_pago && os.valor_pago > 0 && os.forma_pagamento)) {
      showToast('Registre o pagamento antes de concluir.', 'error')
      return
    }
    setOsLoading(os.id, true)
    setOsError(os.id, null)
    try {
      const updated = await pb
        .collection(COLLECTIONS.ORDENS_SERVICO)
        .update<OrdemServico>(os.id, { status: 'concluida' })
      updateOsInState(updated)
      showToast('Serviço concluído!', 'success')
    } catch (err) {
      const msg = extractApiError(err)
      setOsError(os.id, msg)
      showToast(msg, 'error')
    } finally {
      setOsLoading(os.id, false)
    }
  }, [showToast])

  // ── render ────────────────────────────────────────────────────────────

  const todayLabel = new Date().toLocaleDateString('pt-BR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  })

  return (
    <>
      {/* Toast container */}
      <div
        style={{
          position: 'fixed',
          bottom: 80,
          left: '50%',
          transform: 'translateX(-50%)',
          zIndex: 200,
          display: 'flex',
          flexDirection: 'column',
          gap: 8,
          alignItems: 'center',
          pointerEvents: 'none',
          width: '90vw',
          maxWidth: 360,
        }}
      >
        {toasts.map((t) => (
          <div
            key={t.id}
            style={{
              padding: '10px 16px',
              borderRadius: 'var(--clx-r-pill)',
              fontSize: '0.85rem',
              fontWeight: 600,
              color: '#fff',
              background:
                t.type === 'success'
                  ? 'var(--clx-success)'
                  : t.type === 'error'
                  ? 'var(--clx-error)'
                  : 'var(--clx-accent)',
              boxShadow: 'var(--clx-shadow-md)',
              textAlign: 'center',
              animation: 'modal-fade-in 0.2s ease',
              pointerEvents: 'auto',
            }}
          >
            {t.text}
          </div>
        ))}
      </div>

      <div className="profapp-page-header">
        <h1>Meus serviços</h1>
        <button
          className="icon-btn"
          onClick={fetchOS}
          aria-label="Atualizar"
          disabled={loading}
        >
          <IconRefresh size={16} />
        </button>
      </div>

      <div className="profapp-page-body">
        {/* Erro de carregamento */}
        {fetchError && (
          <div className="error-banner" style={{ marginBottom: 16 }}>
            <IconAlertCircle size={14} />
            {fetchError}
            <button
              className="clx-btn clx-btn-ghost clx-btn-sm"
              onClick={fetchOS}
              style={{ marginLeft: 'auto' }}
            >
              Tentar novamente
            </button>
          </div>
        )}

        {/* Loading */}
        {loading && (
          <div className="loading-overlay">
            <Spinner size={22} />
            Carregando seus serviços…
          </div>
        )}

        {!loading && (
          <>
            {/* ── Hoje ── */}
            <div style={{ marginBottom: 8 }}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  marginBottom: 12,
                }}
              >
                <div>
                  <div
                    style={{
                      fontFamily: 'var(--clx-font-display)',
                      fontWeight: 700,
                      fontSize: '0.95rem',
                      color: 'var(--clx-ink)',
                      letterSpacing: '-0.01em',
                    }}
                  >
                    Hoje
                  </div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--clx-ink-3)', textTransform: 'capitalize' }}>
                    {todayLabel}
                  </div>
                </div>
                {todayOS.length > 0 && (
                  <span className="clx-chip clx-chip-primary">
                    {todayOS.length} serviço{todayOS.length !== 1 ? 's' : ''}
                  </span>
                )}
              </div>

              {todayOS.length === 0 ? (
                <div className="empty-state">
                  <IconServices size={32} />
                  <h4>Nenhum serviço hoje</h4>
                  <p>Você não tem serviços agendados para hoje.</p>
                </div>
              ) : (
                todayOS.map((os) => (
                  <OSCard
                    key={os.id}
                    os={os}
                    onIniciar={handleIniciar}
                    onAvisar={handleAvisar}
                    onPagar={handlePagar}
                    onConcluir={handleConcluir}
                    actionLoading={actionLoading[os.id] ?? false}
                    actionError={actionError[os.id] ?? null}
                  />
                ))
              )}
            </div>

            {/* ── Próximos ── */}
            {upcomingOS.length > 0 && (
              <div style={{ marginTop: 24 }}>
                <div
                  style={{
                    fontFamily: 'var(--clx-font-display)',
                    fontWeight: 700,
                    fontSize: '0.95rem',
                    color: 'var(--clx-ink)',
                    letterSpacing: '-0.01em',
                    marginBottom: 12,
                    paddingTop: 12,
                    borderTop: '1px solid var(--clx-line)',
                  }}
                >
                  Próximos agendamentos
                </div>
                {upcomingOS.map((os) => (
                  <OSCard
                    key={os.id}
                    os={os}
                    onIniciar={handleIniciar}
                    onAvisar={handleAvisar}
                    onPagar={handlePagar}
                    onConcluir={handleConcluir}
                    actionLoading={actionLoading[os.id] ?? false}
                    actionError={actionError[os.id] ?? null}
                  />
                ))}
              </div>
            )}
          </>
        )}
      </div>

      {/* ── Modal de pagamento ── */}
      <Modal
        open={!!payModal}
        onClose={() => !payLoading && setPayModal(null)}
        title="Registrar pagamento"
        size="sm"
        footer={
          <div style={{ display: 'flex', gap: 8, width: '100%' }}>
            <button
              className="clx-btn clx-btn-ghost"
              onClick={() => setPayModal(null)}
              disabled={payLoading}
              style={{ flex: 1 }}
            >
              Cancelar
            </button>
            <button
              className="clx-btn clx-btn-primary"
              onClick={handlePaySubmit}
              disabled={payLoading}
              style={{ flex: 2 }}
            >
              {payLoading ? <Spinner size={16} /> : <IconDollar size={15} />}
              Salvar pagamento
            </button>
          </div>
        }
      >
        {payError && (
          <div className="error-banner" style={{ marginBottom: 14 }}>
            <IconAlertCircle size={14} />
            {payError}
          </div>
        )}

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="form-field">
            <label htmlFor="valor_pago">
              Valor pago (R$) <span className="req">*</span>
            </label>
            <input
              id="valor_pago"
              type="number"
              step="0.01"
              min="0.01"
              placeholder="0,00"
              value={payForm.valor_pago}
              onChange={(e) => setPayForm((f) => ({ ...f, valor_pago: e.target.value }))}
            />
          </div>

          <div className="form-field">
            <label htmlFor="forma_pagamento">
              Forma de pagamento <span className="req">*</span>
            </label>
            <select
              id="forma_pagamento"
              value={payForm.forma_pagamento}
              onChange={(e) =>
                setPayForm((f) => ({ ...f, forma_pagamento: e.target.value as FormaPagamento }))
              }
            >
              <option value="">Selecione…</option>
              <option value="debito">Débito</option>
              <option value="credito">Crédito</option>
              <option value="pix_maquininha">Pix (maquininha)</option>
            </select>
          </div>
        </div>
      </Modal>
    </>
  )
}
