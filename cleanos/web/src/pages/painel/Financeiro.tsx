import { useCallback, useEffect, useState } from 'react'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../../lib/pb'
import {
  COLLECTIONS,
  type OrdemServico,
  type User,
  formatCurrency,
  formatDateTime,
  formaPagamentoLabel,
} from '../../lib/collections'
import { Spinner } from '../../components/ui/Spinner'
import { Modal } from '../../components/ui/Modal'
import { IconAlertCircle, IconCheckCircle } from '../../components/ui/Icon'
import { useAuth } from '../../contexts/AuthContext'

function pbError(err: unknown): string {
  if (err instanceof ClientResponseError) {
    if (err.status === 403)
      return 'Sem permissão. Apenas admin pode marcar como repassado.'
    if (err.status === 0) return 'Sem conexão com o servidor.'
  }
  return 'Ocorreu um erro inesperado.'
}

function getMonthBounds(year: number, month: number) {
  const pad = (n: number) => String(n).padStart(2, '0')
  const start = `${year}-${pad(month + 1)}-01 00:00:00`
  const next = new Date(year, month + 1, 1)
  const end = `${next.getFullYear()}-${pad(next.getMonth() + 1)}-01 00:00:00`
  return { start, end }
}

export default function Financeiro() {
  const { role } = useAuth()

  const now = new Date()
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth())

  const [osAll, setOsAll] = useState<OrdemServico[]>([])
  const [profissionais, setProfissionais] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [repasseModal, setRepasseModal] = useState<OrdemServico | null>(null)
  const [repasseValor, setRepasseValor] = useState('')
  const [savingRepasse, setSavingRepasse] = useState(false)
  const [repasseErr, setRepasseErr] = useState<string | null>(null)

  const load = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const { start, end } = getMonthBounds(year, month)
      const [os, profs] = await Promise.all([
        pb.collection(COLLECTIONS.ORDENS_SERVICO).getFullList<OrdemServico>({
          filter: `status = 'concluida' && data_hora >= '${start}' && data_hora < '${end}'`,
          sort: '-data_hora',
          expand: 'profissional',
        }),
        pb.collection(COLLECTIONS.USERS).getFullList<User>({
          filter: "role = 'profissional'",
          sort: 'name',
        }),
      ])
      setOsAll(os)
      setProfissionais(profs)
    } catch {
      setError('Não foi possível carregar os dados financeiros.')
    } finally {
      setLoading(false)
    }
  }, [year, month])

  useEffect(() => { load() }, [load])

  const recebidoMes = osAll.reduce((sum, o) => sum + (o.valor_pago ?? 0), 0)
  const ticketMedio = osAll.length > 0 ? recebidoMes / osAll.length : 0
  const pendentes = osAll.filter((o) => o.repasse_status === 'pendente')
  const totalRepassar = pendentes.reduce((sum, o) => sum + (o.valor_pago ?? 0), 0)

  function prevMonth() {
    if (month === 0) { setMonth(11); setYear((y) => y - 1) }
    else setMonth((m) => m - 1)
  }
  function nextMonth() {
    if (month === 11) { setMonth(0); setYear((y) => y + 1) }
    else setMonth((m) => m + 1)
  }

  const monthLabel = new Date(year, month, 1).toLocaleDateString('pt-BR', {
    month: 'long', year: 'numeric',
  })

  function openRepasse(os: OrdemServico) {
    setRepasseModal(os)
    setRepasseValor(String(os.valor_pago ?? 0))
    setRepasseErr(null)
  }

  async function handleMarcarRepassado() {
    if (!repasseModal) return
    const valor = Number(repasseValor)
    if (isNaN(valor) || valor < 0) { setRepasseErr('Valor inválido'); return }
    try {
      setSavingRepasse(true)
      setRepasseErr(null)
      await pb.collection(COLLECTIONS.ORDENS_SERVICO).update(repasseModal.id, {
        repasse_status: 'pago',
        repasse_valor: valor,
      })
      setRepasseModal(null)
      await load()
    } catch (err) {
      setRepasseErr(pbError(err))
    } finally {
      setSavingRepasse(false)
    }
  }

  interface ProfGroup { prof: User | null; os: OrdemServico[]; total: number }
  const profGroupMap = new Map<string, ProfGroup>()
  pendentes.forEach((o) => {
    const key = o.profissional ?? ''
    if (!profGroupMap.has(key)) {
      profGroupMap.set(key, {
        prof: profissionais.find((p) => p.id === key) ?? null,
        os: [],
        total: 0,
      })
    }
    const g = profGroupMap.get(key)!
    g.os.push(o)
    g.total += o.valor_pago ?? 0
  })
  const profGroups = Array.from(profGroupMap.values())

  return (
    <div>
      {/* Period toolbar */}
      <div className="page-toolbar">
        <div className="agenda-nav">
          <button className="agenda-nav-btn" onClick={prevMonth} title="Mês anterior">‹</button>
          <span className="agenda-period-label">{monthLabel}</span>
          <button className="agenda-nav-btn" onClick={nextMonth} title="Próximo mês">›</button>
        </div>
        <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load}>
          Atualizar
        </button>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {error}
        </div>
      )}

      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando…</div>
      ) : (
        <>
          {/* KPI cards */}
          <div className="fin-grid">
            <div className="kpi-card">
              <div className="kpi-card-label">Recebido no mês</div>
              <div className="kpi-card-value accent" style={{ fontSize: '1.45rem' }}>
                {formatCurrency(recebidoMes)}
              </div>
              <div style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)', marginTop: 4 }}>
                {osAll.length} OS concluída{osAll.length !== 1 ? 's' : ''}
              </div>
            </div>
            <div className="kpi-card">
              <div className="kpi-card-label">Ticket médio</div>
              <div className="kpi-card-value" style={{ fontSize: '1.45rem' }}>
                {formatCurrency(ticketMedio)}
              </div>
            </div>
            <div className="kpi-card">
              <div className="kpi-card-label">A repassar</div>
              <div className="kpi-card-value warning" style={{ fontSize: '1.45rem' }}>
                {formatCurrency(totalRepassar)}
              </div>
              <div style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)', marginTop: 4 }}>
                {pendentes.length} OS pendente{pendentes.length !== 1 ? 's' : ''}
              </div>
            </div>
          </div>

          {/* Lançamentos */}
          <div className="section-header">
            <h2>Lançamentos — {monthLabel}</h2>
          </div>
          <div className="table-wrap">
            <div className="table-scroll">
              <table className="clx-table">
                <thead>
                  <tr>
                    <th>Cliente / Serviço</th>
                    <th>Profissional</th>
                    <th>Data</th>
                    <th>Forma</th>
                    <th>Valor pago</th>
                    <th>Repasse</th>
                  </tr>
                </thead>
                <tbody>
                  {osAll.length === 0 ? (
                    <tr>
                      <td colSpan={6}>
                        <div className="empty-state">
                          <h4>Nenhuma OS concluída em {monthLabel}</h4>
                          <p>Selecione outro período ou conclua ordens de serviço.</p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    osAll.map((o) => {
                      const prof = o.expand?.profissional
                      return (
                        <tr key={o.id}>
                          <td>
                            <strong>{o.nome_curto}</strong>
                            {o.tipo_servico_nome && <><br /><small>{o.tipo_servico_nome}</small></>}
                          </td>
                          <td>
                            {prof
                              ? (prof.nome ?? prof.name)
                              : <span style={{ color: 'var(--clx-ink-3)' }}>—</span>}
                          </td>
                          <td style={{ whiteSpace: 'nowrap' }}>{formatDateTime(o.data_hora)}</td>
                          <td>{o.forma_pagamento ? formaPagamentoLabel(o.forma_pagamento) : '—'}</td>
                          <td style={{ whiteSpace: 'nowrap', fontWeight: 600 }}>
                            {formatCurrency(o.valor_pago ?? 0)}
                          </td>
                          <td>
                            {o.repasse_status === 'pago' ? (
                              <span className="clx-chip" style={{ background: 'rgba(34,197,94,0.10)', color: 'var(--clx-success)', border: 'none' }}>
                                Repassado
                              </span>
                            ) : o.repasse_status === 'pendente' ? (
                              <span className="clx-chip" style={{ background: 'rgba(245,158,11,0.10)', color: 'var(--clx-warning)', border: 'none' }}>
                                Pendente
                              </span>
                            ) : (
                              <span style={{ color: 'var(--clx-ink-3)' }}>—</span>
                            )}
                          </td>
                        </tr>
                      )
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* A repassar ao profissional */}
          {pendentes.length > 0 && (
            <div className="repasse-section">
              <div className="section-header">
                <h2>A repassar ao profissional</h2>
                {role !== 'admin' && (
                  <span style={{ fontSize: '0.78rem', color: 'var(--clx-ink-3)' }}>
                    Apenas admin pode marcar como repassado
                  </span>
                )}
              </div>

              {profGroups.map((g, i) => (
                <div key={i} className="table-wrap" style={{ marginBottom: 14 }}>
                  <div
                    style={{
                      padding: '12px 16px',
                      borderBottom: '1px solid var(--clx-line)',
                      fontWeight: 700,
                      fontSize: '0.875rem',
                      background: 'var(--clx-bg-2)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <span>{g.prof ? (g.prof.nome ?? g.prof.name) : 'Sem profissional atribuído'}</span>
                    <span style={{ color: 'var(--clx-warning)', fontFamily: 'var(--clx-font-display)' }}>
                      Total: {formatCurrency(g.total)}
                    </span>
                  </div>
                  <div className="table-scroll">
                    <table className="clx-table">
                      <tbody>
                        {g.os.map((o) => (
                          <tr key={o.id}>
                            <td>
                              <strong>{o.nome_curto}</strong>
                              <br /><small>{formatDateTime(o.data_hora)}</small>
                            </td>
                            <td>{o.tipo_servico_nome ?? '—'}</td>
                            <td style={{ whiteSpace: 'nowrap', fontWeight: 600 }}>
                              {formatCurrency(o.valor_pago ?? 0)}
                            </td>
                            <td>
                              {role === 'admin' ? (
                                <button
                                  className="clx-btn clx-btn-sm clx-btn-primary"
                                  onClick={() => openRepasse(o)}
                                >
                                  <IconCheckCircle size={13} /> Marcar repassado
                                </button>
                              ) : (
                                <span
                                  style={{ fontSize: '0.75rem', color: 'var(--clx-ink-3)' }}
                                  title="Apenas admin pode marcar como repassado"
                                >
                                  Apenas admin
                                </span>
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {/* Modal repasse */}
      <Modal
        open={!!repasseModal}
        onClose={() => setRepasseModal(null)}
        title="Marcar como repassado"
        size="sm"
        footer={
          <>
            <button className="clx-btn clx-btn-ghost" onClick={() => setRepasseModal(null)} disabled={savingRepasse}>
              Cancelar
            </button>
            <button className="clx-btn clx-btn-accent" onClick={handleMarcarRepassado} disabled={savingRepasse}>
              {savingRepasse ? <><Spinner size={14} /> Salvando…</> : 'Confirmar repasse'}
            </button>
          </>
        }
      >
        {repasseErr && (
          <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
            <IconAlertCircle size={15} /> {repasseErr}
          </div>
        )}
        <div className="form-grid">
          <div className="form-field">
            <label>OS</label>
            <input
              type="text"
              value={repasseModal?.nome_curto ?? ''}
              readOnly
              style={{ background: 'var(--clx-bg-3)' }}
            />
          </div>
          <div className="form-field">
            <label>Valor de referência (pago pelo cliente)</label>
            <input
              type="text"
              value={formatCurrency(repasseModal?.valor_pago ?? 0)}
              readOnly
              style={{ background: 'var(--clx-bg-3)' }}
            />
          </div>
          <div className="form-field">
            <label>Valor a repassar (R$) <span className="req">*</span></label>
            <input
              type="number"
              min="0"
              step="0.01"
              value={repasseValor}
              onChange={(e) => setRepasseValor(e.target.value)}
              placeholder="0,00"
            />
            <span style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)' }}>
              Padrão: valor pago integral. Ajuste conforme o combinado.
            </span>
          </div>
        </div>
      </Modal>
    </div>
  )
}
