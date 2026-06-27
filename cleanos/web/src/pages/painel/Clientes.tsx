import { useCallback, useEffect, useState } from 'react'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../../lib/pb'
import {
  COLLECTIONS,
  type Cliente,
  type Servico,
  type User,
  maskPhoneBR,
  onlyDigitsPhone,
  localInputToPBDate,
  userDisplayName,
} from '../../lib/collections'
import {
  OSFormSection,
  type OSFields,
  emptyOSFields,
  validateOSFields,
} from '../../components/ui/OSFormSection'
import { Spinner } from '../../components/ui/Spinner'
import { Modal } from '../../components/ui/Modal'
import {
  IconPlus,
  IconAlertCircle,
  IconSearch,
  IconPhone,
  IconMapPin,
  IconChevronRight,
} from '../../components/ui/Icon'
import { useIsMobile } from '../../hooks/useIsMobile'
import { CardAvatar } from '../../components/ui/MobileCards'

/* ---- Types ---- */
type ClienteForm = Omit<Cliente, 'id' | 'created' | 'updated'>

function emptyForm(): ClienteForm {
  return {
    nome: '',
    sobrenome: '',
    telefone: '',
    email: '',
    endereco_rua: '',
    endereco_numero: '',
    endereco_complemento: '',
    endereco_bairro: '',
    endereco_cidade: '',
    endereco_cep: '',
    ativo: true,
    observacoes: '',
  }
}

function validateForm(f: ClienteForm): Record<string, string> {
  const errs: Record<string, string> = {}
  if (!f.nome.trim()) errs.nome = 'Nome é obrigatório'
  const telDigits = onlyDigitsPhone(f.telefone)
  if (telDigits.length < 10) errs.telefone = telDigits.length === 0 ? 'Telefone é obrigatório' : 'Telefone incompleto — informe DDD + número'
  if (!f.endereco_bairro.trim()) errs.endereco_bairro = 'Bairro é obrigatório'
  if (f.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email)) {
    errs.email = 'E-mail inválido'
  }
  return errs
}

function validateOSInlineForm(f: OSFields): Record<string, string> {
  const errs = { ...validateOSFields(f) }
  if (!f.servicoId) errs.servicoId = 'Selecione um serviço'
  return errs
}

function pbError(err: unknown): string {
  if (err instanceof ClientResponseError) {
    if (err.status === 403) return 'Sem permissão para esta ação.'
    if (err.status === 400) {
      const data = err.data as Record<string, { message?: string }> | undefined
      if (data) {
        const first = Object.values(data)[0]
        if (first?.message) return first.message
      }
      return 'Dados inválidos. Verifique o formulário.'
    }
    if (err.status === 0) return 'Sem conexão com o servidor.'
  }
  return 'Ocorreu um erro inesperado.'
}

export default function Clientes() {
  const isMobile = useIsMobile()
  const [clientes, setClientes] = useState<Cliente[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')

  const [modalOpen, setModalOpen] = useState(false)
  const [editing, setEditing] = useState<Cliente | null>(null)
  const [form, setForm] = useState<ClienteForm>(emptyForm())
  const [formErrs, setFormErrs] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState(false)
  const [saveErr, setSaveErr] = useState<string | null>(null)

  /* OS inline state — only used in create mode */
  const [gerarOS, setGerarOS] = useState(false)
  const [osForm, setOSForm] = useState<OSFields>(emptyOSFields())
  const [osFormErrs, setOSFormErrs] = useState<Record<string, string>>({})
  const [servicos, setServicos] = useState<Servico[]>([])
  const [profissionais, setProfissionais] = useState<User[]>([])
  const [loadingLookups, setLoadingLookups] = useState(false)

  const load = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const list = await pb.collection(COLLECTIONS.CLIENTES).getFullList<Cliente>({
        sort: 'nome,sobrenome',
      })
      setClientes(list)
    } catch {
      setError('Não foi possível carregar os clientes.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  async function loadLookups() {
    try {
      setLoadingLookups(true)
      const [svcs, profs] = await Promise.all([
        pb.collection(COLLECTIONS.SERVICOS).getFullList<Servico>({
          filter: 'ativo = true',
          sort: 'nome',
        }),
        pb.collection(COLLECTIONS.USERS).getFullList<User>({
          filter: "role = 'profissional'",
          sort: 'nome,name',
        }),
      ])
      setServicos(svcs)
      setProfissionais(profs)
    } catch {
      /* selects ficam vazios; usuário pode retentar desligando e ligando o toggle */
    } finally {
      setLoadingLookups(false)
    }
  }

  const searchLower = search.toLowerCase()
  const filtered = clientes.filter((c) => {
    if (!search) return true
    return (
      c.nome.toLowerCase().includes(searchLower) ||
      (c.sobrenome ?? '').toLowerCase().includes(searchLower) ||
      c.telefone.includes(search) ||
      c.endereco_bairro.toLowerCase().includes(searchLower)
    )
  })

  function openCreate() {
    setEditing(null)
    setForm(emptyForm())
    setFormErrs({})
    setSaveErr(null)
    setGerarOS(false)
    setOSForm(emptyOSFields())
    setOSFormErrs({})
    setModalOpen(true)
    loadLookups()
  }

  function openEdit(c: Cliente) {
    setEditing(c)
    setForm({
      nome: c.nome,
      sobrenome: c.sobrenome ?? '',
      telefone: maskPhoneBR(c.telefone),
      email: c.email ?? '',
      endereco_rua: c.endereco_rua ?? '',
      endereco_numero: c.endereco_numero ?? '',
      endereco_complemento: c.endereco_complemento ?? '',
      endereco_bairro: c.endereco_bairro,
      endereco_cidade: c.endereco_cidade ?? '',
      endereco_cep: c.endereco_cep ?? '',
      ativo: c.ativo,
      observacoes: c.observacoes ?? '',
    })
    setFormErrs({})
    setSaveErr(null)
    setModalOpen(true)
  }

  function setField<K extends keyof ClienteForm>(k: K, v: ClienteForm[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
    setFormErrs((prev) => { const n = { ...prev }; delete n[k as string]; return n })
  }

  /* Always prefill nome and valor when a service is selected */
  function onOSServicoChange(id: string) {
    const svc = id ? servicos.find((s) => s.id === id) : undefined
    setOSForm((prev) => ({
      ...prev,
      servicoId: id,
      ...(svc ? { tipo_servico_nome: svc.nome, valor_servico: String(svc.preco_base) } : {}),
    }))
    setOSFormErrs((prev) => { const n = { ...prev }; delete n.servicoId; return n })
  }

  async function handleSave() {
    const errs = validateForm(form)
    const osErrs = (gerarOS && !editing) ? validateOSInlineForm(osForm) : {}
    if (Object.keys(errs).length > 0 || Object.keys(osErrs).length > 0) {
      setFormErrs(errs)
      setOSFormErrs(osErrs)
      return
    }
    try {
      setSaving(true)
      setSaveErr(null)
      const payload = {
        nome: form.nome.trim(),
        sobrenome: form.sobrenome?.trim() ?? '',
        telefone: form.telefone.trim(),
        email: form.email?.trim() ?? '',
        endereco_rua: form.endereco_rua?.trim() ?? '',
        endereco_numero: form.endereco_numero?.trim() ?? '',
        endereco_complemento: form.endereco_complemento?.trim() ?? '',
        endereco_bairro: form.endereco_bairro.trim(),
        endereco_cidade: form.endereco_cidade?.trim() ?? '',
        endereco_cep: form.endereco_cep?.trim() ?? '',
        ativo: form.ativo,
        observacoes: form.observacoes?.trim() ?? '',
      }
      if (editing) {
        await pb.collection(COLLECTIONS.CLIENTES).update(editing.id, payload)
        setModalOpen(false)
        await load()
        return
      }

      const novoCliente = await pb.collection(COLLECTIONS.CLIENTES).create<Cliente>(payload)

      if (gerarOS) {
        try {
          const hasProfissional = osForm.profissionalId !== ''
          const combinedDT = `${osForm.data_date}T${osForm.data_time_h}:${osForm.data_time_m}`
          await pb.collection(COLLECTIONS.ORDENS_SERVICO).create({
            cliente: novoCliente.id,
            servico: osForm.servicoId || null,
            tipo_servico_nome: osForm.tipo_servico_nome.trim(),
            data_hora: localInputToPBDate(combinedDT),
            valor_servico: Number(osForm.valor_servico),
            profissional: hasProfissional ? osForm.profissionalId : null,
            status: hasProfissional ? 'atribuida' : 'agendada',
            observacoes: osForm.observacoes.trim(),
          })
          setModalOpen(false)
          await load()
        } catch (osErr) {
          setSaveErr(`Cliente criado, mas houve um erro ao gerar a OS: ${pbError(osErr)}`)
          await load()
        }
      } else {
        setModalOpen(false)
        await load()
      }
    } catch (err) {
      setSaveErr(pbError(err))
    } finally {
      setSaving(false)
    }
  }

  async function toggleAtivo(c: Cliente) {
    try {
      await pb.collection(COLLECTIONS.CLIENTES).update(c.id, { ativo: !c.ativo })
      setClientes((prev) => prev.map((x) => x.id === c.id ? { ...x, ativo: !c.ativo } : x))
    } catch (err) {
      setError(pbError(err))
    }
  }

  /* ---- Render ---- */
  return (
    <div>
      <div className="page-toolbar">
        <div className="page-toolbar-search">
          <input
            type="search"
            placeholder="Buscar por nome, telefone ou bairro…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            aria-label="Buscar clientes"
          />
        </div>
        <button className="clx-btn clx-btn-accent" onClick={openCreate}>
          <IconPlus size={15} /> Novo cliente
        </button>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {error}
        </div>
      )}

      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando clientes…</div>
      ) : isMobile ? (
        filtered.length === 0 ? (
          <div className="empty-state">
            <IconSearch size={32} />
            <h4>{search ? 'Nenhum cliente encontrado' : 'Nenhum cliente cadastrado'}</h4>
            <p>{search ? 'Tente outros termos de busca.' : 'Clique em "Novo cliente" para começar.'}</p>
          </div>
        ) : (
          <div className="mob-card-list">
            {filtered.map((c) => (
              <div key={c.id} className="mob-card" onClick={() => openEdit(c)} style={{ cursor: 'pointer' }}>
                <div className="mob-card-top">
                  <CardAvatar name={c.nome} />
                  <div className="mob-card-meta">
                    <div className="mob-card-title">{c.nome} {c.sobrenome}</div>
                    {c.email && <div className="mob-card-sub">{c.email}</div>}
                  </div>
                  <div className="mob-card-badge">
                    <button
                      className={`clx-chip ${c.ativo ? 'clx-chip-success' : 'clx-chip-error'}`}
                      style={{ cursor: 'pointer' }}
                      onClick={(e) => { e.stopPropagation(); toggleAtivo(c) }}
                      title={c.ativo ? 'Clique para desativar' : 'Clique para ativar'}
                    >
                      {c.ativo ? 'Ativo' : 'Inativo'}
                    </button>
                  </div>
                </div>
                <div className="mob-card-rows">
                  <div className="mob-card-row">
                    <span className="mob-card-row-icon"><IconPhone size={14} /></span>
                    <span>{maskPhoneBR(c.telefone)}</span>
                  </div>
                  {(c.endereco_bairro || c.endereco_cidade) && (
                    <div className="mob-card-row">
                      <span className="mob-card-row-icon"><IconMapPin size={14} /></span>
                      <span>{[c.endereco_bairro, c.endereco_cidade].filter(Boolean).join(', ')}</span>
                    </div>
                  )}
                </div>
                <div className="mob-card-actions">
                  <span style={{ color: 'var(--clx-ink-3)', display: 'flex', alignItems: 'center' }}>
                    <IconChevronRight size={16} />
                  </span>
                </div>
              </div>
            ))}
          </div>
        )
      ) : (
        <div className="table-wrap">
          <div className="table-scroll">
            <table className="clx-table">
              <thead>
                <tr>
                  <th>Nome</th>
                  <th>Telefone</th>
                  <th>Bairro</th>
                  <th>Cidade</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={5}>
                      <div className="empty-state">
                        <IconSearch size={32} />
                        <h4>
                          {search ? 'Nenhum cliente encontrado' : 'Nenhum cliente cadastrado'}
                        </h4>
                        <p>
                          {search
                            ? 'Tente outros termos de busca.'
                            : 'Clique em "Novo cliente" para começar.'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  filtered.map((c) => (
                    <tr
                      key={c.id}
                      onClick={() => openEdit(c)}
                      onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openEdit(c) } }}
                      tabIndex={0}
                      style={{ cursor: 'pointer' }}
                    >
                      <td data-label="Nome">
                        <strong>{c.nome} {c.sobrenome}</strong>
                        {c.email && <><br /><small>{c.email}</small></>}
                      </td>
                      <td data-label="Telefone">{maskPhoneBR(c.telefone)}</td>
                      <td data-label="Bairro">{c.endereco_bairro}</td>
                      <td data-label="Cidade">{c.endereco_cidade || '—'}</td>
                      <td data-label="Status">
                        <button
                          className={`clx-chip ${c.ativo ? 'clx-chip-success' : 'clx-chip-error'}`}
                          style={{ cursor: 'pointer' }}
                          onClick={(e) => { e.stopPropagation(); toggleAtivo(c) }}
                          title={c.ativo ? 'Clique para desativar' : 'Clique para ativar'}
                        >
                          {c.ativo ? 'Ativo' : 'Inativo'}
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Modal criar/editar */}
      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editing ? 'Editar cliente' : 'Novo cliente'}
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

        <div className="form-grid form-grid-2">
          <Field label="Nome" required err={formErrs.nome}>
            <input
              type="text"
              value={form.nome}
              onChange={(e) => setField('nome', e.target.value)}
              placeholder="Carlos"
              className={formErrs.nome ? 'err' : ''}
            />
          </Field>
          <Field label="Sobrenome" err={formErrs.sobrenome}>
            <input
              type="text"
              value={form.sobrenome ?? ''}
              onChange={(e) => setField('sobrenome', e.target.value)}
              placeholder="Silva"
            />
          </Field>

          <Field label="Telefone" required err={formErrs.telefone}>
            <input
              type="tel"
              inputMode="tel"
              value={form.telefone}
              onChange={(e) => setField('telefone', maskPhoneBR(e.target.value))}
              placeholder="(85) 99999-9999"
              maxLength={15}
              className={formErrs.telefone ? 'err' : ''}
            />
          </Field>
          <Field label="E-mail" err={formErrs.email}>
            <input
              type="email"
              value={form.email ?? ''}
              onChange={(e) => setField('email', e.target.value)}
              placeholder="cliente@email.com"
              className={formErrs.email ? 'err' : ''}
            />
          </Field>

          <Field label="Rua" err={formErrs.endereco_rua} className="form-col-span-2">
            <input
              type="text"
              value={form.endereco_rua ?? ''}
              onChange={(e) => setField('endereco_rua', e.target.value)}
              placeholder="Rua das Flores"
            />
          </Field>

          <Field label="Número" err={formErrs.endereco_numero}>
            <input
              type="text"
              value={form.endereco_numero ?? ''}
              onChange={(e) => setField('endereco_numero', e.target.value)}
              placeholder="123"
            />
          </Field>
          <Field label="Complemento" err={formErrs.endereco_complemento}>
            <input
              type="text"
              value={form.endereco_complemento ?? ''}
              onChange={(e) => setField('endereco_complemento', e.target.value)}
              placeholder="Apto 4B"
            />
          </Field>

          <Field label="Bairro" required err={formErrs.endereco_bairro}>
            <input
              type="text"
              value={form.endereco_bairro}
              onChange={(e) => setField('endereco_bairro', e.target.value)}
              placeholder="Centro"
              className={formErrs.endereco_bairro ? 'err' : ''}
            />
          </Field>
          <Field label="Cidade" err={formErrs.endereco_cidade}>
            <input
              type="text"
              value={form.endereco_cidade ?? ''}
              onChange={(e) => setField('endereco_cidade', e.target.value)}
              placeholder="São Paulo"
            />
          </Field>

          <Field label="CEP" err={formErrs.endereco_cep}>
            <input
              type="text"
              value={form.endereco_cep ?? ''}
              onChange={(e) => setField('endereco_cep', e.target.value)}
              placeholder="01310-100"
            />
          </Field>
          <div style={{ display: 'flex', alignItems: 'flex-end', paddingBottom: 4 }}>
            <div className="toggle-row">
              <label className="toggle" htmlFor="cliente-ativo">
                <input
                  id="cliente-ativo"
                  type="checkbox"
                  checked={form.ativo}
                  onChange={(e) => setField('ativo', e.target.checked)}
                />
                <span className="toggle-track" />
              </label>
              <label htmlFor="cliente-ativo" style={{ fontSize: '0.875rem', color: 'var(--clx-ink-2)' }}>
                Cliente ativo
              </label>
            </div>
          </div>

          <Field label="Observações" err={formErrs.observacoes} className="form-col-span-2">
            <textarea
              value={form.observacoes ?? ''}
              onChange={(e) => setField('observacoes', e.target.value)}
              placeholder="Informações adicionais sobre o cliente…"
              rows={3}
            />
          </Field>

          {/* Toggle Gerar OS — apenas em modo criação */}
          {!editing && (
            <div className="form-col-span-2" style={{ display: 'flex', alignItems: 'center', gap: 10, paddingTop: 2 }}>
              <div className="toggle-row">
                <label className="toggle" htmlFor="gerar-os">
                  <input
                    id="gerar-os"
                    type="checkbox"
                    checked={gerarOS}
                    onChange={(e) => {
                      setGerarOS(e.target.checked)
                      if (!e.target.checked) setOSFormErrs({})
                    }}
                  />
                  <span className="toggle-track" />
                </label>
                <label htmlFor="gerar-os" style={{ fontSize: '0.875rem', color: 'var(--clx-ink-2)', fontWeight: 500 }}>
                  Gerar OS
                </label>
              </div>
            </div>
          )}

          {/* Seção OS — revelada quando o toggle está ativo */}
          {!editing && gerarOS && (
            <>
              <div className="form-col-span-2" style={{
                borderTop: '1.5px solid var(--clx-line)',
                paddingTop: 14,
                marginTop: 4,
              }}>
                <span style={{
                  fontSize: '0.72rem',
                  fontWeight: 700,
                  letterSpacing: '0.08em',
                  textTransform: 'uppercase',
                  color: 'var(--clx-ink-3)',
                }}>
                  Ordem de Serviço
                </span>
              </div>

              {/* Campos de OS — compartilhados com OrdensServico via OSFormSection */}
              <OSFormSection
                servicos={servicos}
                profissionais={profissionais}
                fields={osForm}
                errs={osFormErrs}
                onChange={(k, v) => {
                  setOSForm((prev) => ({ ...prev, [k]: v }))
                  setOSFormErrs((prev) => { const n = { ...prev }; delete n[k as string]; return n })
                }}
                onServicoChange={onOSServicoChange}
                loadingLookups={loadingLookups}
              />
            </>
          )}
        </div>
      </Modal>
    </div>
  )
}

/* ---- Helper component ---- */
function Field({
  label,
  required,
  err,
  children,
  className,
}: {
  label: string
  required?: boolean
  err?: string
  children: React.ReactNode
  className?: string
}) {
  return (
    <div className={`form-field${className ? ` ${className}` : ''}`}>
      <label>
        {label}{required && <span className="req">*</span>}
      </label>
      {children}
      {err && <span className="field-err">{err}</span>}
    </div>
  )
}
