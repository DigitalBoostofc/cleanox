import { useCallback, useEffect, useState } from 'react'
import { ClientResponseError } from 'pocketbase'
import { pb } from '../../lib/pb'
import {
  COLLECTIONS,
  type Cliente,
  type ConfigAtuacao,
  type ConfigAtuacaoCidade,
  type Servico,
  type User,
  maskPhoneBR,
  maskCEP,
  onlyDigitsPhone,
  localInputToPBDate,
  userDisplayName,
  splitNome,
} from '../../lib/collections'
import {
  OSFormSection,
  type OSFields,
  emptyOSFields,
  validateOSFields,
} from '../../components/ui/OSFormSection'
import { useAuth } from '../../contexts/AuthContext'
import { Spinner } from '../../components/ui/Spinner'
import { Modal } from '../../components/ui/Modal'
import {
  IconPlus,
  IconAlertCircle,
  IconSearch,
  IconPhone,
  IconMapPin,
  IconChevronRight,
  IconSettings,
  IconX,
  IconTrash,
  IconCheckCircle,
} from '../../components/ui/Icon'
import { useIsMobile } from '../../hooks/useIsMobile'
import { CardAvatar } from '../../components/ui/MobileCards'

/* ---- Types ---- */
type ClienteForm = {
  nomeCompleto: string
  telefone: string
  email: string
  endereco_rua: string
  endereco_complemento: string
  endereco_bairro: string
  endereco_cidade: string
  endereco_estado: string
  endereco_cep: string
  ativo: boolean
  observacoes: string
}

function emptyForm(): ClienteForm {
  return {
    nomeCompleto: '',
    telefone: '',
    email: '',
    endereco_rua: '',
    endereco_complemento: '',
    endereco_bairro: '',
    endereco_cidade: '',
    endereco_estado: '',
    endereco_cep: '',
    ativo: true,
    observacoes: '',
  }
}

function validateForm(f: ClienteForm): Record<string, string> {
  const errs: Record<string, string> = {}
  if (!f.nomeCompleto.trim()) errs.nomeCompleto = 'Nome é obrigatório'
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

/* ---- ViaCEP response shape ---- */
interface ViaCEPResponse {
  logradouro?: string
  bairro?: string
  localidade?: string
  uf?: string
  erro?: boolean
}

export default function Clientes() {
  const isMobile = useIsMobile()
  const { role } = useAuth()
  const canManageConfig = role === 'admin' || role === 'gerente'

  const [clientes, setClientes] = useState<Cliente[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')

  /* Modal criar/editar state */
  const [modalOpen, setModalOpen] = useState(false)
  const [editing, setEditing] = useState<Cliente | null>(null)
  const [form, setForm] = useState<ClienteForm>(emptyForm())
  const [formErrs, setFormErrs] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState(false)
  const [saveErr, setSaveErr] = useState<string | null>(null)

  /* CEP autofill state */
  const [cepLoading, setCepLoading] = useState(false)
  const [cepWarning, setCepWarning] = useState<string | null>(null)

  /* OS inline state — only in create mode */
  const [gerarOS, setGerarOS] = useState(false)
  const [osForm, setOSForm] = useState<OSFields>(emptyOSFields())
  const [osFormErrs, setOSFormErrs] = useState<Record<string, string>>({})
  const [servicos, setServicos] = useState<Servico[]>([])
  const [profissionais, setProfissionais] = useState<User[]>([])
  const [loadingLookups, setLoadingLookups] = useState(false)

  /* Config atuação state */
  const [configAtuacao, setConfigAtuacao] = useState<ConfigAtuacao | null>(null)
  const [configModalOpen, setConfigModalOpen] = useState(false)
  const [configEdit, setConfigEdit] = useState<{ estado: string; cidades: ConfigAtuacaoCidade[] }>({ estado: '', cidades: [] })
  const [configSaving, setConfigSaving] = useState(false)
  const [configErr, setConfigErr] = useState<string | null>(null)
  const [configSucc, setConfigSucc] = useState(false)
  const [newCidadeInput, setNewCidadeInput] = useState('')
  const [newBairroInputs, setNewBairroInputs] = useState<Record<number, string>>({})

  /* ---- Load clientes ---- */
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

  /* ---- Load config_atuacao ---- */
  const loadConfigAtuacao = useCallback(async () => {
    try {
      const list = await pb.collection(COLLECTIONS.CONFIG_ATUACAO).getFullList<ConfigAtuacao>()
      setConfigAtuacao(list[0] ?? null)
    } catch {
      setConfigAtuacao(null)
    }
  }, [])

  useEffect(() => {
    load()
    loadConfigAtuacao()
  }, [load, loadConfigAtuacao])

  /* ---- Load lookup data for OS selects ---- */
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

  /* ---- Filtered list ---- */
  const searchLower = search.toLowerCase()
  const filtered = clientes.filter((c) => {
    if (!search) return true
    const fullName = [c.nome, c.sobrenome].filter(Boolean).join(' ')
    return (
      fullName.toLowerCase().includes(searchLower) ||
      c.telefone.includes(search) ||
      c.endereco_bairro.toLowerCase().includes(searchLower)
    )
  })

  /* ---- Open create ---- */
  function openCreate() {
    const cidadePrincipal = configAtuacao?.cidades?.find((c) => c.principal) ?? null
    setEditing(null)
    setForm({
      ...emptyForm(),
      endereco_cidade: cidadePrincipal?.nome ?? '',
      endereco_estado: configAtuacao?.estado ?? '',
    })
    setFormErrs({})
    setSaveErr(null)
    setCepWarning(null)
    setGerarOS(false)
    setOSForm(emptyOSFields())
    setOSFormErrs({})
    setModalOpen(true)
    loadLookups()
  }

  /* ---- Open edit ---- */
  function openEdit(c: Cliente) {
    setEditing(c)
    setForm({
      nomeCompleto: [c.nome, c.sobrenome].filter(Boolean).join(' '),
      telefone: maskPhoneBR(c.telefone),
      email: c.email ?? '',
      endereco_rua: c.endereco_rua ?? '',
      endereco_complemento: c.endereco_complemento ?? '',
      endereco_bairro: c.endereco_bairro,
      endereco_cidade: c.endereco_cidade ?? '',
      endereco_estado: c.endereco_estado ?? '',
      endereco_cep: maskCEP(c.endereco_cep ?? ''),
      ativo: c.ativo,
      observacoes: c.observacoes ?? '',
    })
    setFormErrs({})
    setSaveErr(null)
    setCepWarning(null)
    setModalOpen(true)
  }

  /* ---- Field helpers ---- */
  function setField<K extends keyof ClienteForm>(k: K, v: ClienteForm[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
    setFormErrs((prev) => { const n = { ...prev }; delete n[k as string]; return n })
  }

  /* ---- CEP autofill ---- */
  async function handleCEPChange(rawValue: string) {
    const masked = maskCEP(rawValue)
    setField('endereco_cep', masked)
    setCepWarning(null)
    const digits = rawValue.replace(/\D/g, '')
    if (digits.length !== 8) return

    try {
      setCepLoading(true)
      const res = await fetch(`https://viacep.com.br/ws/${digits}/json/`)
      if (!res.ok) throw new Error('HTTP error')
      const data = await res.json() as ViaCEPResponse
      if (data.erro) {
        setCepWarning('CEP não encontrado.')
        return
      }
      setField('endereco_rua', data.logradouro ?? '')
      setField('endereco_bairro', data.bairro ?? '')
      setField('endereco_cidade', data.localidade ?? '')
      setField('endereco_estado', data.uf ?? '')
    } catch {
      setCepWarning('Não foi possível consultar o CEP.')
    } finally {
      setCepLoading(false)
    }
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

  /* ---- Save cliente ---- */
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
      const { nome, sobrenome } = splitNome(form.nomeCompleto)
      const payload = {
        nome,
        sobrenome,
        telefone: form.telefone.trim(),
        email: form.email?.trim() ?? '',
        endereco_rua: form.endereco_rua?.trim() ?? '',
        endereco_numero: '',
        endereco_complemento: form.endereco_complemento?.trim() ?? '',
        endereco_bairro: form.endereco_bairro.trim(),
        endereco_cidade: form.endereco_cidade?.trim() ?? '',
        endereco_estado: form.endereco_estado?.trim() ?? '',
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

  /* ---- Toggle ativo ---- */
  async function toggleAtivo(c: Cliente) {
    try {
      await pb.collection(COLLECTIONS.CLIENTES).update(c.id, { ativo: !c.ativo })
      setClientes((prev) => prev.map((x) => x.id === c.id ? { ...x, ativo: !c.ativo } : x))
    } catch (err) {
      setError(pbError(err))
    }
  }

  /* ---- Config atuação ---- */
  function openConfigModal() {
    setConfigEdit({
      estado: configAtuacao?.estado ?? '',
      cidades: configAtuacao?.cidades
        ? JSON.parse(JSON.stringify(configAtuacao.cidades)) as ConfigAtuacaoCidade[]
        : [],
    })
    setNewCidadeInput('')
    setNewBairroInputs({})
    setConfigErr(null)
    setConfigSucc(false)
    setConfigModalOpen(true)
  }

  function addCidade() {
    const nome = newCidadeInput.trim()
    if (!nome) return
    setConfigEdit((prev) => ({
      ...prev,
      cidades: [
        ...prev.cidades,
        { nome, principal: prev.cidades.length === 0, bairros: [] },
      ],
    }))
    setNewCidadeInput('')
  }

  function removeCidade(idx: number) {
    setConfigEdit((prev) => {
      const cidades = prev.cidades.filter((_, i) => i !== idx)
      if (prev.cidades[idx]?.principal && cidades.length > 0) {
        cidades[0] = { ...cidades[0], principal: true }
      }
      return { ...prev, cidades }
    })
    setNewBairroInputs((prev) => {
      const next: Record<number, string> = {}
      Object.entries(prev).forEach(([k, v]) => {
        const ki = Number(k)
        if (ki < idx) next[ki] = v
        else if (ki > idx) next[ki - 1] = v
      })
      return next
    })
  }

  function setPrincipal(idx: number) {
    setConfigEdit((prev) => ({
      ...prev,
      cidades: prev.cidades.map((c, i) => ({ ...c, principal: i === idx })),
    }))
  }

  function addBairro(cidadeIdx: number) {
    const bairro = (newBairroInputs[cidadeIdx] ?? '').trim()
    if (!bairro) return
    setConfigEdit((prev) => ({
      ...prev,
      cidades: prev.cidades.map((c, i) =>
        i === cidadeIdx ? { ...c, bairros: [...c.bairros, bairro] } : c
      ),
    }))
    setNewBairroInputs((prev) => ({ ...prev, [cidadeIdx]: '' }))
  }

  function removeBairro(cidadeIdx: number, bairroIdx: number) {
    setConfigEdit((prev) => ({
      ...prev,
      cidades: prev.cidades.map((c, i) =>
        i === cidadeIdx
          ? { ...c, bairros: c.bairros.filter((_, bi) => bi !== bairroIdx) }
          : c
      ),
    }))
  }

  async function handleSaveConfig() {
    try {
      setConfigSaving(true)
      setConfigErr(null)
      const payload = {
        estado: configEdit.estado.trim().toUpperCase().slice(0, 2),
        cidades: configEdit.cidades,
      }
      if (configAtuacao?.id) {
        const updated = await pb.collection(COLLECTIONS.CONFIG_ATUACAO).update<ConfigAtuacao>(configAtuacao.id, payload)
        setConfigAtuacao(updated)
      } else {
        const created = await pb.collection(COLLECTIONS.CONFIG_ATUACAO).create<ConfigAtuacao>(payload)
        setConfigAtuacao(created)
      }
      setConfigSucc(true)
      setTimeout(() => {
        setConfigModalOpen(false)
        setConfigSucc(false)
      }, 800)
    } catch (err) {
      setConfigErr(pbError(err))
    } finally {
      setConfigSaving(false)
    }
  }

  /* ---- Derived values for form ---- */
  const configCidades = configAtuacao?.cidades ?? []
  const hasCidades = configCidades.length > 0
  const bairrosSugeridos =
    configCidades.find((c) => c.nome === form.endereco_cidade)?.bairros ?? []
  const clienteNomeCompleto = (c: Cliente) => [c.nome, c.sobrenome].filter(Boolean).join(' ')

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
        {canManageConfig && (
          <button
            className="clx-btn clx-btn-ghost clx-btn-sm"
            onClick={openConfigModal}
            title="Área de atuação"
            aria-label="Área de atuação"
            style={{ padding: '10px 12px' }}
          >
            <IconSettings size={16} />
          </button>
        )}
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
                    <div className="mob-card-title">{clienteNomeCompleto(c)}</div>
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
                        <h4>{search ? 'Nenhum cliente encontrado' : 'Nenhum cliente cadastrado'}</h4>
                        <p>{search ? 'Tente outros termos de busca.' : 'Clique em "Novo cliente" para começar.'}</p>
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
                        <strong>{clienteNomeCompleto(c)}</strong>
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

      {/* ---- Modal criar/editar ---- */}
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
          {/* Nome único (campo único, split em nome+sobrenome no save) */}
          <Field label="Nome" required err={formErrs.nomeCompleto} className="form-col-span-2">
            <input
              type="text"
              value={form.nomeCompleto}
              onChange={(e) => setField('nomeCompleto', e.target.value)}
              placeholder="Carlos Silva"
              className={formErrs.nomeCompleto ? 'err' : ''}
              autoComplete="name"
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
              value={form.email}
              onChange={(e) => setField('email', e.target.value)}
              placeholder="cliente@email.com"
              className={formErrs.email ? 'err' : ''}
            />
          </Field>

          {/* CEP com autofill */}
          <div className="form-field">
            <label>
              CEP
              {cepLoading && (
                <span style={{ marginLeft: 8, color: 'var(--clx-ink-3)', fontWeight: 400 }}>
                  <Spinner size={11} /> buscando…
                </span>
              )}
            </label>
            <input
              type="text"
              inputMode="numeric"
              value={form.endereco_cep}
              onChange={(e) => handleCEPChange(e.target.value)}
              placeholder="00000-000"
              maxLength={9}
            />
            {cepWarning && (
              <span className="field-err">{cepWarning}</span>
            )}
          </div>
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

          {/* Rua e número (campo único) */}
          <Field label="Rua e número" err={formErrs.endereco_rua} className="form-col-span-2">
            <input
              type="text"
              value={form.endereco_rua}
              onChange={(e) => setField('endereco_rua', e.target.value)}
              placeholder="Rua das Flores, 123"
            />
          </Field>

          <Field label="Complemento" err={formErrs.endereco_complemento}>
            <input
              type="text"
              value={form.endereco_complemento}
              onChange={(e) => setField('endereco_complemento', e.target.value)}
              placeholder="Apto 4B"
            />
          </Field>

          {/* Bairro com autocomplete (datalist) */}
          <div className="form-field">
            <label>Bairro <span className="req">*</span></label>
            <input
              type="text"
              list="bairros-datalist"
              value={form.endereco_bairro}
              onChange={(e) => setField('endereco_bairro', e.target.value)}
              placeholder="Centro"
              className={formErrs.endereco_bairro ? 'err' : ''}
            />
            {bairrosSugeridos.length > 0 && (
              <datalist id="bairros-datalist">
                {bairrosSugeridos.map((b) => <option key={b} value={b} />)}
              </datalist>
            )}
            {formErrs.endereco_bairro && <span className="field-err">{formErrs.endereco_bairro}</span>}
          </div>

          {/* Cidade: select quando há config, input livre caso contrário */}
          <div className="form-field">
            <label>Cidade</label>
            {hasCidades ? (
              <select
                value={form.endereco_cidade}
                onChange={(e) => {
                  setField('endereco_cidade', e.target.value)
                }}
                className={formErrs.endereco_cidade ? 'err' : ''}
              >
                <option value="">— Selecionar —</option>
                {configCidades.map((c) => (
                  <option key={c.nome} value={c.nome}>{c.nome}</option>
                ))}
                {form.endereco_cidade && !configCidades.find((c) => c.nome === form.endereco_cidade) && (
                  <option value={form.endereco_cidade}>{form.endereco_cidade}</option>
                )}
              </select>
            ) : (
              <input
                type="text"
                value={form.endereco_cidade}
                onChange={(e) => setField('endereco_cidade', e.target.value)}
                placeholder="São Paulo"
                className={formErrs.endereco_cidade ? 'err' : ''}
              />
            )}
            {formErrs.endereco_cidade && <span className="field-err">{formErrs.endereco_cidade}</span>}
          </div>

          <Field label="Observações" err={formErrs.observacoes} className="form-col-span-2">
            <textarea
              value={form.observacoes}
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

      {/* ---- Modal Área de Atuação ---- */}
      <Modal
        open={configModalOpen}
        onClose={() => setConfigModalOpen(false)}
        title="Área de atuação"
        size="md"
        footer={
          <>
            <button className="clx-btn clx-btn-ghost" onClick={() => setConfigModalOpen(false)} disabled={configSaving}>
              Cancelar
            </button>
            <button className="clx-btn clx-btn-accent" onClick={handleSaveConfig} disabled={configSaving}>
              {configSaving ? <><Spinner size={14} /> Salvando…</> : configSucc ? <><IconCheckCircle size={14} /> Salvo!</> : 'Salvar'}
            </button>
          </>
        }
      >
        {configErr && (
          <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
            <IconAlertCircle size={15} /> {configErr}
          </div>
        )}

        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          {/* Estado */}
          <div className="form-field">
            <label>Estado (UF)</label>
            <input
              type="text"
              value={configEdit.estado}
              onChange={(e) => setConfigEdit((prev) => ({ ...prev, estado: e.target.value.toUpperCase().slice(0, 2) }))}
              placeholder="SP"
              maxLength={2}
              style={{ textTransform: 'uppercase', maxWidth: 80 }}
            />
          </div>

          {/* Lista de cidades */}
          <div>
            <div style={{
              fontSize: '0.72rem',
              fontWeight: 700,
              letterSpacing: '0.07em',
              textTransform: 'uppercase',
              color: 'var(--clx-ink-2)',
              marginBottom: 10,
            }}>
              Cidades atendidas
            </div>

            {configEdit.cidades.length === 0 && (
              <p style={{ fontSize: '0.85rem', color: 'var(--clx-ink-3)', marginBottom: 12 }}>
                Nenhuma cidade cadastrada.
              </p>
            )}

            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {configEdit.cidades.map((cidade, ci) => (
                <div key={ci} style={{
                  background: 'var(--clx-bg-2)',
                  border: '1px solid var(--clx-line)',
                  borderRadius: 'var(--clx-r-md)',
                  padding: '12px 14px',
                }}>
                  {/* Cidade header */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
                    <span style={{ fontWeight: 600, fontSize: '0.9rem', flex: 1 }}>{cidade.nome}</span>
                    <label style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 5,
                      fontSize: '0.78rem',
                      color: 'var(--clx-ink-2)',
                      cursor: 'pointer',
                      userSelect: 'none',
                      whiteSpace: 'nowrap',
                    }}>
                      <input
                        type="radio"
                        name="cidade-principal"
                        checked={cidade.principal}
                        onChange={() => setPrincipal(ci)}
                        style={{ accentColor: 'var(--clx-primary)', cursor: 'pointer' }}
                      />
                      Principal
                    </label>
                    <button
                      className="icon-btn danger"
                      onClick={() => removeCidade(ci)}
                      title="Remover cidade"
                      style={{ width: 28, height: 28 }}
                    >
                      <IconTrash size={14} />
                    </button>
                  </div>

                  {/* Bairros chips */}
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 8 }}>
                    {cidade.bairros.map((bairro, bi) => (
                      <span key={bi} className="clx-chip" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                        {bairro}
                        <button
                          onClick={() => removeBairro(ci, bi)}
                          style={{ display: 'inline-flex', alignItems: 'center', background: 'none', border: 'none', cursor: 'pointer', padding: 0, color: 'inherit', opacity: 0.7 }}
                          title="Remover bairro"
                        >
                          <IconX size={11} />
                        </button>
                      </span>
                    ))}
                    {cidade.bairros.length === 0 && (
                      <span style={{ fontSize: '0.78rem', color: 'var(--clx-ink-3)' }}>Nenhum bairro cadastrado.</span>
                    )}
                  </div>

                  {/* Add bairro */}
                  <div style={{ display: 'flex', gap: 6 }}>
                    <input
                      type="text"
                      value={newBairroInputs[ci] ?? ''}
                      onChange={(e) => setNewBairroInputs((prev) => ({ ...prev, [ci]: e.target.value }))}
                      onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addBairro(ci) } }}
                      placeholder="Adicionar bairro…"
                      style={{
                        flex: 1,
                        padding: '7px 10px',
                        background: 'var(--clx-bg)',
                        border: '1.5px solid var(--clx-line)',
                        borderRadius: 'var(--clx-r-md)',
                        fontSize: '0.82rem',
                        color: 'var(--clx-ink)',
                        outline: 'none',
                      }}
                    />
                    <button
                      className="clx-btn clx-btn-ghost clx-btn-sm"
                      onClick={() => addBairro(ci)}
                      type="button"
                    >
                      <IconPlus size={14} />
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {/* Add cidade */}
            <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
              <input
                type="text"
                value={newCidadeInput}
                onChange={(e) => setNewCidadeInput(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addCidade() } }}
                placeholder="Nome da nova cidade…"
                style={{
                  flex: 1,
                  padding: '9px 12px',
                  background: 'var(--clx-bg)',
                  border: '1.5px solid var(--clx-line)',
                  borderRadius: 'var(--clx-r-md)',
                  fontSize: '0.875rem',
                  color: 'var(--clx-ink)',
                  outline: 'none',
                }}
              />
              <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={addCidade} type="button">
                <IconPlus size={14} /> Cidade
              </button>
            </div>
          </div>
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
