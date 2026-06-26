import { useCallback, useEffect, useState } from 'react'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../../lib/pb'
import {
  COLLECTIONS,
  type OrdemServico,
  type Cliente,
  type Servico,
  type User,
  type OSStatus,
  OS_STATUS_LIST,
  osStatusLabel,
  formatCurrency,
  formatDateTime,
  pbDateToLocalInput,
  localInputToPBDate,
  userDisplayName,
} from '../../lib/collections'
import { Spinner } from '../../components/ui/Spinner'
import { StarRating } from '../../components/ui/StarRating'
import { Modal } from '../../components/ui/Modal'
import {
  IconPlus,
  IconEdit,
  IconEye,
  IconAlertCircle,
  IconXCircle,
  IconCheckCircle,
  IconArrowRight,
  IconCalendar,
  IconDollar,
  IconUser,
  IconChevronRight,
} from '../../components/ui/Icon'
import { useAuth } from '../../contexts/AuthContext'
import { useIsMobile } from '../../hooks/useIsMobile'
import { CardAvatar } from '../../components/ui/MobileCards'

/* ---- Helpers ---- */
function pbError(err: unknown): string {
  if (err instanceof ClientResponseError) {
    if (err.status === 403) return 'Sem permissão para esta ação.'
    if (err.status === 400) {
      const msg = (err.response as { message?: string })?.message
      if (msg) return msg
      return 'Dados inválidos. Verifique o formulário.'
    }
    if (err.status === 0) return 'Sem conexão com o servidor.'
  }
  return 'Ocorreu um erro inesperado.'
}

/* ---- OS Form ---- */
interface OSForm {
  clienteId: string
  clienteSearch: string
  servicoId: string
  tipo_servico_nome: string
  data_hora: string
  valor_servico: string
  profissionalId: string
  observacoes: string
}

function emptyOSForm(): OSForm {
  return {
    clienteId: '',
    clienteSearch: '',
    servicoId: '',
    tipo_servico_nome: '',
    data_hora: '',
    valor_servico: '',
    profissionalId: '',
    observacoes: '',
  }
}

function validateOSForm(f: OSForm): Record<string, string> {
  const errs: Record<string, string> = {}
  if (!f.clienteId) errs.clienteId = 'Selecione um cliente'
  if (!f.data_hora) errs.data_hora = 'Data e hora são obrigatórios'
  if (!f.valor_servico || Number(f.valor_servico) <= 0) errs.valor_servico = 'Informe o valor'
  return errs
}

/* ---- Detail modal state ---- */
type ModalMode = 'view' | 'create' | 'edit'

export default function OrdensServico() {
  const { role } = useAuth()
  const isMobile = useIsMobile()

  const [ordens, setOrdens] = useState<OrdemServico[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<OSStatus | 'todas'>('todas')

  /* Lookup data */
  const [clientes, setClientes] = useState<Cliente[]>([])
  const [servicos, setServicos] = useState<Servico[]>([])
  const [profissionais, setProfissionais] = useState<User[]>([])

  /* Modal */
  const [modalMode, setModalMode] = useState<ModalMode>('view')
  const [modalOpen, setModalOpen] = useState(false)
  const [selectedOS, setSelectedOS] = useState<OrdemServico | null>(null)
  const [osForm, setOSForm] = useState<OSForm>(emptyOSForm())
  const [formErrs, setFormErrs] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState(false)
  const [saveErr, setSaveErr] = useState<string | null>(null)

  /* Client search dropdown */
  const [clienteDropdown, setClienteDropdown] = useState(false)

  /* Load data — retorna as OS carregadas para permitir sync pós-ação */
  const load = useCallback(async (): Promise<OrdemServico[] | undefined> => {
    try {
      setLoading(true)
      setError(null)
      const [os, cls, svcs, profs] = await Promise.all([
        pb.collection(COLLECTIONS.ORDENS_SERVICO).getFullList<OrdemServico>({
          sort: '-data_hora',
          expand: 'profissional,servico',
        }),
        pb.collection(COLLECTIONS.CLIENTES).getFullList<Cliente>({ sort: 'nome' }),
        pb.collection(COLLECTIONS.SERVICOS).getFullList<Servico>({
          filter: 'ativo = true',
          sort: 'nome',
        }),
        pb.collection(COLLECTIONS.USERS).getFullList<User>({
          filter: "role = 'profissional'",
          sort: 'nome,name',
        }),
      ])
      setOrdens(os)
      setClientes(cls)
      setServicos(svcs)
      setProfissionais(profs)
      return os
    } catch {
      setError('Não foi possível carregar as ordens de serviço.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  /* Filtered by tab */
  const filtered =
    activeTab === 'todas'
      ? ordens
      : ordens.filter((o) => o.status === activeTab)

  function countByStatus(s: OSStatus) {
    return ordens.filter((o) => o.status === s).length
  }

  /* Open create modal */
  function openCreate() {
    setModalMode('create')
    setOSForm(emptyOSForm())
    setFormErrs({})
    setSaveErr(null)
    setSelectedOS(null)
    setModalOpen(true)
  }

  /* Open edit modal */
  function openEdit(os: OrdemServico) {
    setModalMode('edit')
    setSelectedOS(os)
    const cli = clientes.find((c) => c.id === os.cliente)
    setOSForm({
      clienteId: os.cliente,
      clienteSearch: cli ? `${cli.nome} ${cli.sobrenome ?? ''}`.trim() : os.nome_curto,
      servicoId: os.servico ?? '',
      tipo_servico_nome: os.tipo_servico_nome ?? '',
      data_hora: pbDateToLocalInput(os.data_hora),
      valor_servico: String(os.valor_servico),
      profissionalId: os.profissional ?? '',
      observacoes: os.observacoes ?? '',
    })
    setFormErrs({})
    setSaveErr(null)
    setModalOpen(true)
  }

  /* Open view modal */
  function openView(os: OrdemServico) {
    setModalMode('view')
    setSelectedOS(os)
    setSaveErr(null)
    setModalOpen(true)
  }

  /* Form field update */
  function setField<K extends keyof OSForm>(k: K, v: OSForm[K]) {
    setOSForm((prev) => ({ ...prev, [k]: v }))
    setFormErrs((prev) => { const n = { ...prev }; delete n[k as string]; return n })
  }

  /* Serviço change → prefill nome and valor */
  function onServicoChange(id: string) {
    const svc = servicos.find((s) => s.id === id)
    setField('servicoId', id)
    if (svc) {
      setField('tipo_servico_nome', svc.nome)
      if (!osForm.valor_servico || osForm.valor_servico === '0') {
        setField('valor_servico', String(svc.preco_base))
      }
    }
  }

  /* Save OS */
  async function handleSave() {
    const errs = validateOSForm(osForm)
    if (Object.keys(errs).length > 0) { setFormErrs(errs); return }
    try {
      setSaving(true)
      setSaveErr(null)
      const hasProfissional = osForm.profissionalId !== ''
      const payload: Record<string, unknown> = {
        cliente: osForm.clienteId,
        servico: osForm.servicoId || null,
        tipo_servico_nome: osForm.tipo_servico_nome.trim(),
        data_hora: localInputToPBDate(osForm.data_hora),
        valor_servico: Number(osForm.valor_servico),
        profissional: hasProfissional ? osForm.profissionalId : null,
        observacoes: osForm.observacoes.trim(),
      }
      if (modalMode === 'create') {
        payload.status = hasProfissional ? 'atribuida' : 'agendada'
      } else if (modalMode === 'edit' && selectedOS) {
        if (hasProfissional && selectedOS.status === 'agendada') {
          payload.status = 'atribuida'
        } else if (!hasProfissional && selectedOS.status === 'atribuida') {
          payload.status = 'agendada'
        }
      }
      if (modalMode === 'create') {
        await pb.collection(COLLECTIONS.ORDENS_SERVICO).create(payload)
      } else if (selectedOS) {
        await pb.collection(COLLECTIONS.ORDENS_SERVICO).update(selectedOS.id, payload)
      }
      setModalOpen(false)
      await load()
    } catch (err) {
      setSaveErr(pbError(err))
    } finally {
      setSaving(false)
    }
  }

  /* Cancel OS */
  async function handleCancel(os: OrdemServico) {
    if (!window.confirm('Cancelar esta ordem de serviço?')) return
    try {
      await pb.collection(COLLECTIONS.ORDENS_SERVICO).update(os.id, { status: 'cancelada' })
      await load()
      if (selectedOS?.id === os.id) setModalOpen(false)
    } catch (err) {
      // Erro visível na barra de página (não no modal de formulário)
      setError(pbError(err))
    }
  }

  /* Atribuir profissional inline */
  async function handleAtribuir(os: OrdemServico, profId: string) {
    try {
      await pb.collection(COLLECTIONS.ORDENS_SERVICO).update(os.id, {
        profissional: profId || null,
        status: profId ? 'atribuida' : 'agendada',
      })
      const freshOrdens = await load()
      const freshOS = freshOrdens?.find((o) => o.id === os.id)
      if (freshOS) setSelectedOS(freshOS)
    } catch (err) {
      const msg = pbError(err)
      setError(msg)
      throw new Error(msg)  // re-lança para o OSDetail exibir localmente
    }
  }

  /* ---- Render ---- */
  return (
    <div>
      {/* Toolbar */}
      <div className="page-toolbar">
        <button className="clx-btn clx-btn-accent" onClick={openCreate}>
          <IconPlus size={15} /> Nova OS
        </button>
        {error && (
          <span style={{ color: 'var(--clx-error)', fontSize: '0.875rem' }}>
            <IconAlertCircle size={14} /> {error}
          </span>
        )}
        <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load} style={{ marginLeft: 'auto' }}>
          Atualizar
        </button>
      </div>

      {/* Status tabs */}
      <div className="tab-bar">
        <button
          className={`tab-item${activeTab === 'todas' ? ' active' : ''}`}
          onClick={() => setActiveTab('todas')}
        >
          Todas <span className="tab-badge">{ordens.length}</span>
        </button>
        {OS_STATUS_LIST.map((s) => (
          <button
            key={s}
            className={`tab-item${activeTab === s ? ' active' : ''}`}
            onClick={() => setActiveTab(s)}
          >
            {osStatusLabel(s)}
            {countByStatus(s) > 0 && (
              <span className="tab-badge">{countByStatus(s)}</span>
            )}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando ordens…</div>
      ) : isMobile ? (
        filtered.length === 0 ? (
          <div className="empty-state">
            <h4>Nenhuma OS{activeTab !== 'todas' ? ` com status "${osStatusLabel(activeTab as OSStatus)}"` : ''}</h4>
            <p>Clique em "Nova OS" para criar a primeira ordem de serviço.</p>
          </div>
        ) : (
          <div className="mob-card-list">
            {filtered.map((os) => {
              const prof = os.expand?.profissional
              return (
                <div key={os.id} className="mob-card" onClick={() => openView(os)} style={{ cursor: 'pointer' }}>
                  <div className="mob-card-top">
                    <CardAvatar name={os.nome_curto} />
                    <div className="mob-card-meta">
                      <div className="mob-card-title">{os.tipo_servico_nome ?? '—'}</div>
                      <div className="mob-card-sub">{os.nome_curto} · {os.bairro}</div>
                    </div>
                    <div className="mob-card-badge">
                      <span className={`clx-status clx-status-${os.status}`}>
                        {osStatusLabel(os.status)}
                      </span>
                    </div>
                  </div>
                  <div className="mob-card-rows">
                    <div className="mob-card-row">
                      <span className="mob-card-row-icon"><IconCalendar size={14} /></span>
                      <span>{formatDateTime(os.data_hora)}</span>
                    </div>
                    <div className="mob-card-row">
                      <span className="mob-card-row-icon"><IconDollar size={14} /></span>
                      <span style={{ fontWeight: 600 }}>{formatCurrency(os.valor_servico ?? 0)}</span>
                      {prof && (
                        <span style={{ marginLeft: 'auto', color: 'var(--clx-ink-3)', fontSize: '0.78rem', display: 'flex', alignItems: 'center', gap: 4 }}>
                          <IconUser size={12} />{userDisplayName(prof)}
                        </span>
                      )}
                    </div>
                    {os.avaliacao_nota != null && (
                      <div className="mob-card-row">
                        <StarRating nota={os.avaliacao_nota} size={13} />
                      </div>
                    )}
                  </div>
                  <div className="mob-card-actions">
                    <button className="icon-btn" onClick={(e) => { e.stopPropagation(); openView(os) }} title="Ver detalhes">
                      <IconEye size={15} />
                    </button>
                    {os.status !== 'concluida' && os.status !== 'cancelada' && (
                      <button className="icon-btn" onClick={(e) => { e.stopPropagation(); openEdit(os) }} title="Editar">
                        <IconEdit size={15} />
                      </button>
                    )}
                    {os.status !== 'concluida' && os.status !== 'cancelada' && (
                      <button className="icon-btn danger" onClick={(e) => { e.stopPropagation(); handleCancel(os) }} title="Cancelar OS">
                        <IconXCircle size={15} />
                      </button>
                    )}
                    <span style={{ color: 'var(--clx-ink-3)', display: 'flex', alignItems: 'center' }}>
                      <IconChevronRight size={16} />
                    </span>
                  </div>
                </div>
              )
            })}
          </div>
        )
      ) : (
        <div className="table-wrap">
          <div className="table-scroll">
            <table className="clx-table">
              <thead>
                <tr>
                  <th>Cliente</th>
                  <th>Serviço</th>
                  <th>Data / Hora</th>
                  <th>Profissional</th>
                  <th>Valor</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={7}>
                      <div className="empty-state">
                        <h4>Nenhuma OS{activeTab !== 'todas' ? ` com status "${osStatusLabel(activeTab as OSStatus)}"` : ''}</h4>
                        <p>Clique em "Nova OS" para criar a primeira ordem de serviço.</p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  filtered.map((os) => {
                    const prof = os.expand?.profissional
                    return (
                      <tr key={os.id}>
                        <td data-label="Cliente">
                          <strong>{os.nome_curto}</strong>
                          <br /><small>{os.bairro}</small>
                        </td>
                        <td data-label="Serviço">{os.tipo_servico_nome ?? '—'}</td>
                        <td data-label="Data/Hora" style={{ whiteSpace: 'nowrap' }}>{formatDateTime(os.data_hora)}</td>
                        <td data-label="Profissional">{prof ? userDisplayName(prof) : <span style={{ color: 'var(--clx-ink-3)' }}>—</span>}</td>
                        <td data-label="Valor" style={{ whiteSpace: 'nowrap' }}>{formatCurrency(os.valor_servico ?? 0)}</td>
                        <td data-label="Status">
                          <span className={`clx-status clx-status-${os.status}`}>
                            {osStatusLabel(os.status)}
                          </span>
                          {os.avaliacao_nota != null && (
                            <span style={{ marginLeft: 6 }}>
                              <StarRating nota={os.avaliacao_nota} size={12} />
                            </span>
                          )}
                        </td>
                        <td>
                          <div className="td-actions">
                            <button className="icon-btn" onClick={() => openView(os)} title="Ver detalhes">
                              <IconEye size={15} />
                            </button>
                            {os.status !== 'concluida' && os.status !== 'cancelada' && (
                              <button className="icon-btn" onClick={() => openEdit(os)} title="Editar">
                                <IconEdit size={15} />
                              </button>
                            )}
                            {os.status !== 'concluida' && os.status !== 'cancelada' && (
                              <button className="icon-btn danger" onClick={() => handleCancel(os)} title="Cancelar OS">
                                <IconXCircle size={15} />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ---- Modal criar/editar ---- */}
      {(modalMode === 'create' || modalMode === 'edit') && (
        <Modal
          open={modalOpen}
          onClose={() => setModalOpen(false)}
          title={modalMode === 'create' ? 'Nova Ordem de Serviço' : 'Editar OS'}
          size="lg"
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

          <div className="form-grid">
            {/* Cliente com busca */}
            <div className="form-field form-col-span-2">
              <label>Cliente <span className="req">*</span></label>
              <div className="select-search">
                <input
                  type="text"
                  placeholder="Digite para buscar cliente…"
                  value={osForm.clienteSearch}
                  className={formErrs.clienteId ? 'err' : ''}
                  onChange={(e) => {
                    setField('clienteSearch', e.target.value)
                    setField('clienteId', '')
                    setClienteDropdown(true)
                  }}
                  onFocus={() => setClienteDropdown(true)}
                  onBlur={() => setTimeout(() => setClienteDropdown(false), 150)}
                  autoComplete="off"
                />
                {clienteDropdown && osForm.clienteSearch.length > 0 && (
                  <div className="select-search-dropdown">
                    {clientes
                      .filter((c) =>
                        `${c.nome} ${c.sobrenome ?? ''}`.toLowerCase().includes(osForm.clienteSearch.toLowerCase())
                      )
                      .slice(0, 8)
                      .map((c) => (
                        <div
                          key={c.id}
                          className={`select-search-item${osForm.clienteId === c.id ? ' selected' : ''}`}
                          onMouseDown={() => {
                            setField('clienteId', c.id)
                            setField('clienteSearch', `${c.nome} ${c.sobrenome ?? ''}`.trim())
                            setClienteDropdown(false)
                          }}
                        >
                          <strong>{c.nome} {c.sobrenome}</strong>
                          <span style={{ color: 'var(--clx-ink-3)', fontSize: '0.78rem', marginLeft: 8 }}>
                            {c.endereco_bairro} · {c.telefone}
                          </span>
                        </div>
                      ))}
                    {clientes.filter((c) =>
                      `${c.nome} ${c.sobrenome ?? ''}`.toLowerCase().includes(osForm.clienteSearch.toLowerCase())
                    ).length === 0 && (
                      <div className="select-search-item" style={{ color: 'var(--clx-ink-3)' }}>
                        Nenhum cliente encontrado
                      </div>
                    )}
                  </div>
                )}
              </div>
              {formErrs.clienteId && <span className="field-err">{formErrs.clienteId}</span>}
            </div>

            {/* Serviço */}
            <div className="form-field">
              <label>Serviço</label>
              <select
                value={osForm.servicoId}
                onChange={(e) => onServicoChange(e.target.value)}
              >
                <option value="">— Selecionar —</option>
                {servicos.map((s) => (
                  <option key={s.id} value={s.id}>{s.nome}</option>
                ))}
              </select>
            </div>

            {/* Tipo serviço nome */}
            <div className="form-field">
              <label>Nome do serviço (snapshot)</label>
              <input
                type="text"
                value={osForm.tipo_servico_nome}
                onChange={(e) => setField('tipo_servico_nome', e.target.value)}
                placeholder="Ex: Sofá 3 lugares"
              />
            </div>

            {/* Data/hora */}
            <div className="form-field">
              <label>Data e hora <span className="req">*</span></label>
              <input
                type="datetime-local"
                value={osForm.data_hora}
                onChange={(e) => setField('data_hora', e.target.value)}
                className={formErrs.data_hora ? 'err' : ''}
              />
              {formErrs.data_hora && <span className="field-err">{formErrs.data_hora}</span>}
            </div>

            {/* Valor */}
            <div className="form-field">
              <label>Valor do serviço (R$) <span className="req">*</span></label>
              <input
                type="number"
                min="0"
                step="0.01"
                value={osForm.valor_servico}
                onChange={(e) => setField('valor_servico', e.target.value)}
                placeholder="0,00"
                className={formErrs.valor_servico ? 'err' : ''}
              />
              {formErrs.valor_servico && <span className="field-err">{formErrs.valor_servico}</span>}
            </div>

            {/* Profissional */}
            <div className="form-field form-col-span-2">
              <label>Profissional</label>
              <select
                value={osForm.profissionalId}
                onChange={(e) => setField('profissionalId', e.target.value)}
              >
                <option value="">— Não atribuído (status: Agendada) —</option>
                {profissionais.map((p) => (
                  <option key={p.id} value={p.id}>{userDisplayName(p)}</option>
                ))}
              </select>
              <span style={{ fontSize: '0.75rem', color: 'var(--clx-ink-3)' }}>
                Ao atribuir um profissional, o status passa para "Atribuída".
              </span>
            </div>

            {/* Observações */}
            <div className="form-field form-col-span-2">
              <label>Observações</label>
              <textarea
                value={osForm.observacoes}
                onChange={(e) => setField('observacoes', e.target.value)}
                placeholder="Detalhes adicionais para o serviço…"
                rows={3}
              />
            </div>
          </div>
        </Modal>
      )}

      {/* ---- Modal visualizar ---- */}
      {modalMode === 'view' && selectedOS && (
        <Modal
          open={modalOpen}
          onClose={() => setModalOpen(false)}
          title={`OS — ${selectedOS.nome_curto}`}
          size="md"
          footer={
            <div style={{ display: 'flex', gap: 8, width: '100%', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', gap: 8 }}>
                {selectedOS.status !== 'concluida' && selectedOS.status !== 'cancelada' && (
                  <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={() => { setModalOpen(false); openEdit(selectedOS) }}>
                    <IconEdit size={13} /> Editar
                  </button>
                )}
                {selectedOS.status !== 'concluida' && selectedOS.status !== 'cancelada' && (
                  <button className="clx-btn clx-btn-danger clx-btn-sm" onClick={() => handleCancel(selectedOS)}>
                    <IconXCircle size={13} /> Cancelar OS
                  </button>
                )}
              </div>
              <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={() => setModalOpen(false)}>
                Fechar
              </button>
            </div>
          }
        >
          <OSDetail os={selectedOS} profissionais={profissionais} role={role} onAtribuir={handleAtribuir} />
        </Modal>
      )}
    </div>
  )
}

/* ---- OS Detail sub-component ---- */
function OSDetail({
  os,
  profissionais,
  role,
  onAtribuir,
}: {
  os: OrdemServico
  profissionais: User[]
  role: string | null
  onAtribuir: (os: OrdemServico, profId: string) => Promise<void>
}) {
  const prof = os.expand?.profissional
  const [atribuindo, setAtribuindo] = useState(false)
  const [atribuirError, setAtribuirError] = useState<string | null>(null)
  const [selectedProf, setSelectedProf] = useState(os.profissional ?? '')

  async function doAtribuir() {
    setAtribuindo(true)
    setAtribuirError(null)
    try {
      await onAtribuir(os, selectedProf)
    } catch (err) {
      setAtribuirError(err instanceof Error ? err.message : 'Erro ao atribuir.')
    } finally {
      setAtribuindo(false)
    }
  }

  return (
    <div>
      <div className="detail-section">
        <h4>Identificação</h4>
        <dl>
          <div className="detail-row">
            <dt>Cliente</dt>
            <dd>{os.nome_curto}</dd>
          </div>
          <div className="detail-row">
            <dt>Bairro</dt>
            <dd>{os.bairro}</dd>
          </div>
          <div className="detail-row">
            <dt>Serviço</dt>
            <dd>{os.tipo_servico_nome ?? '—'}</dd>
          </div>
          <div className="detail-row">
            <dt>Data / Hora</dt>
            <dd>{formatDateTime(os.data_hora)}</dd>
          </div>
          <div className="detail-row">
            <dt>Status</dt>
            <dd>
              <span className={`clx-status clx-status-${os.status}`}>
                {osStatusLabel(os.status)}
              </span>
            </dd>
          </div>
          {os.observacoes && (
            <div className="detail-row">
              <dt>Observações</dt>
              <dd>{os.observacoes}</dd>
            </div>
          )}
        </dl>
      </div>

      {os.status === 'em_andamento' && os.endereco_liberado && (
        <div className="detail-section">
          <h4>Endereço (liberado)</h4>
          <div style={{ padding: '8px 0', fontSize: '0.875rem', color: 'var(--clx-ink)' }}>
            {os.endereco_liberado}
          </div>
        </div>
      )}

      <div className="detail-section">
        <h4>Profissional</h4>
        <div className="detail-row">
          <dt>Atribuído</dt>
          <dd>{prof ? userDisplayName(prof) : <span style={{ color: 'var(--clx-ink-3)' }}>—</span>}</dd>
        </div>
        {os.status !== 'concluida' && os.status !== 'cancelada' && (role === 'admin' || role === 'gerente') && (
          <>
            <div style={{ display: 'flex', gap: 8, marginTop: 10, alignItems: 'center' }}>
              <select
                value={selectedProf}
                onChange={(e) => setSelectedProf(e.target.value)}
                style={{
                  flex: 1,
                  padding: '8px 12px',
                  background: 'var(--clx-bg-2)',
                  border: '1.5px solid var(--clx-line)',
                  borderRadius: 'var(--clx-r-md)',
                  fontSize: '0.875rem',
                  color: 'var(--clx-ink)',
                  outline: 'none',
                }}
              >
                <option value="">— Remover atribuição —</option>
                {profissionais.map((p) => (
                  <option key={p.id} value={p.id}>{userDisplayName(p)}</option>
                ))}
              </select>
              <button
                className="clx-btn clx-btn-accent clx-btn-sm"
                onClick={doAtribuir}
                disabled={atribuindo}
              >
                {atribuindo ? <Spinner size={13} /> : <IconArrowRight size={13} />}
                {atribuindo ? 'Salvando…' : 'Atribuir'}
              </button>
            </div>
            {atribuirError && (
              <div className="error-banner" role="alert" style={{ marginTop: 8 }}>
                <IconAlertCircle size={14} /> {atribuirError}
              </div>
            )}
          </>
        )}
      </div>

      <div className="detail-section">
        <h4>Financeiro</h4>
        <dl>
          <div className="detail-row">
            <dt>Valor do serviço</dt>
            <dd>{os.valor_servico != null ? formatCurrency(os.valor_servico) : <span style={{ color: 'var(--clx-ink-3)' }}>—</span>}</dd>
          </div>
          <div className="detail-row">
            <dt>Valor pago</dt>
            <dd>
              {os.valor_pago != null
                ? formatCurrency(os.valor_pago)
                : <span style={{ color: 'var(--clx-ink-3)' }}>—</span>}
            </dd>
          </div>
          <div className="detail-row">
            <dt>Forma de pagamento</dt>
            <dd>
              {os.forma_pagamento
                ? ({ debito: 'Débito', credito: 'Crédito', pix_maquininha: 'Pix (maquininha)' } as const)[os.forma_pagamento]
                : <span style={{ color: 'var(--clx-ink-3)' }}>—</span>}
            </dd>
          </div>
          <div className="detail-row">
            <dt>Repasse</dt>
            <dd>
              {os.repasse_status === 'pago'
                ? <span className="clx-chip clx-chip-success">Repassado</span>
                : os.repasse_status === 'pendente'
                  ? <span className="clx-chip clx-chip-warning">Pendente</span>
                  : <span style={{ color: 'var(--clx-ink-3)' }}>—</span>}
              {os.repasse_valor != null && os.repasse_valor > 0 && (
                <span style={{ marginLeft: 6, fontSize: '0.82rem', color: 'var(--clx-ink-2)' }}>
                  {formatCurrency(os.repasse_valor)}
                </span>
              )}
            </dd>
          </div>
        </dl>
      </div>

      {os.status === 'concluida' && (
        <div className="detail-section">
          <h4>Avaliação</h4>
          {os.avaliacao_nota != null ? (
            <dl>
              <div className="detail-row">
                <dt>Nota</dt>
                <dd><StarRating nota={os.avaliacao_nota} size={16} /></dd>
              </div>
              {os.avaliacao_motivo && (
                <div className="detail-row">
                  <dt>Motivo</dt>
                  <dd>{os.avaliacao_motivo}</dd>
                </div>
              )}
              {os.avaliacao_em && (
                <div className="detail-row">
                  <dt>Data</dt>
                  <dd>{formatDateTime(os.avaliacao_em)}</dd>
                </div>
              )}
            </dl>
          ) : (
            <span style={{ fontSize: '0.85rem', color: 'var(--clx-ink-3)' }}>
              Avaliação pendente
            </span>
          )}
        </div>
      )}
    </div>
  )
}
