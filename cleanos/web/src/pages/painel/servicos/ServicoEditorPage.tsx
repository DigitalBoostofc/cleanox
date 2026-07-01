/**
 * ServicoEditorPage — editor full-page do serviço (criar/editar).
 * Rotas: /painel/servicos/novo e /painel/servicos/:id.
 * Replica o miolo do mockup: informações principais, observação, checklist,
 * orientações pré/pós, regras na OS e pré-visualização AO VIVO, além da tabela
 * "Outros serviços cadastrados" (read-only).
 */

import {
  cloneElement,
  isValidElement,
  useCallback,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
} from 'react'
import type { ReactElement, ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import {
  createServico,
  duplicateServico,
  getServico,
  listServicos,
  updateServico,
} from '../../../lib/servicos/store'
import type {
  Categoria,
  ChecklistTemplateItem,
  Grupo,
  Servico,
  ServicoInput,
  ServicoStatus,
  TipoValor,
} from '../../../lib/servicos/types'
import {
  categoriaLabel,
  grupoLabel,
  parseTempoMedio,
  tipoValorLabel,
} from '../../../lib/servicos/labels'
import { Spinner } from '../../../components/ui/Spinner'
import { Modal } from '../../../components/ui/Modal'
import { IconAlertCircle, IconCheck, IconCheckCircle } from '../../../components/ui/Icon'
import { IconCopy, IconInfo } from './components/icons'
import { ChecklistEditor } from './components/ChecklistEditor'
import { PreviewOS } from './components/PreviewOS'
import { OutrosServicosTable } from './components/OutrosServicosTable'

const CATEGORIAS: Categoria[] = ['veicular', 'residencial']
const GRUPOS: Grupo[] = ['plano', 'promocao', 'adicional', 'avulsos', 'sofa', 'colchao', 'outros']
const TIPOS_VALOR: TipoValor[] = ['fixo', 'faixa', 'variavel']

/** Itens que a OS carrega automaticamente ao selecionar o serviço (card de regras). */
const REGRAS_OS = [
  'Valor do serviço',
  'Tempo médio',
  'Checklist padrão',
  'Observações técnicas',
  'Orientações ao cliente',
]

/* ---- Estado do formulário (valores monetários em centavos) ---- */
interface EditorForm {
  categoria: Categoria
  grupo: Grupo
  nome: string
  valorBaseCents: number
  valorBaseMaxCents: number
  tipoValor: TipoValor
  tempoMedioLabel: string
  status: ServicoStatus
  observacao: string
  checklistPadrao: ChecklistTemplateItem[]
  orientacoesPre: string
  orientacoesPos: string
  adicionaisRelacionados: string[]
}

function emptyForm(): EditorForm {
  return {
    categoria: 'veicular',
    grupo: 'plano',
    nome: '',
    valorBaseCents: 0,
    valorBaseMaxCents: 0,
    tipoValor: 'fixo',
    tempoMedioLabel: '',
    status: 'ativo',
    observacao: '',
    checklistPadrao: [],
    orientacoesPre: '',
    orientacoesPos: '',
    adicionaisRelacionados: [],
  }
}

function servicoToForm(s: Servico): EditorForm {
  return {
    categoria: s.categoria,
    grupo: s.grupo,
    nome: s.nome,
    valorBaseCents: Math.round(s.valorBase * 100),
    valorBaseMaxCents: Math.round((s.valorBaseMax ?? 0) * 100),
    tipoValor: s.tipoValor,
    tempoMedioLabel: s.tempoMedioLabel ?? '',
    status: s.status,
    observacao: s.observacao ?? '',
    checklistPadrao: s.checklistPadrao.map((c) => ({ ...c })),
    orientacoesPre: s.orientacoesPre ?? '',
    orientacoesPos: s.orientacoesPos ?? '',
    adicionaisRelacionados: [...s.adicionaisRelacionados],
  }
}

/* ---- Máscara monetária ---- */
function centsToDisplay(cents: number): string {
  return `R$ ${(cents / 100).toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`
}

function rawToCents(raw: string): number {
  const digits = raw.replace(/\D/g, '').slice(0, 9)
  return digits ? parseInt(digits, 10) : 0
}

export default function ServicoEditorPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const isEdit = !!id

  const [form, setForm] = useState<EditorForm>(emptyForm)
  const [original, setOriginal] = useState<Servico | null>(null)
  const [outros, setOutros] = useState<Servico[]>([])

  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState<string | null>(null)

  const [fieldErrs, setFieldErrs] = useState<Record<string, string>>({})
  const [saveError, setSaveError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const dirtyRef = useRef(false)
  const [dirty, setDirty] = useState(false)
  const [confirmLeave, setConfirmLeave] = useState<null | (() => void)>(null)

  /* ---- Carga ---- */
  const load = useCallback(async () => {
    setLoading(true)
    setLoadError(null)
    setFieldErrs({})
    setSaveError(null)
    dirtyRef.current = false
    setDirty(false)
    try {
      const all = await listServicos()
      if (id) {
        const found = await getServico(id)
        if (!found) {
          setLoadError('Serviço não encontrado.')
          setLoading(false)
          return
        }
        setOriginal(found)
        setForm(servicoToForm(found))
        setOutros(all.filter((s) => s.id !== id))
      } else {
        setOriginal(null)
        setForm(emptyForm())
        setOutros(all)
      }
    } catch {
      setLoadError('Não foi possível carregar o serviço.')
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    load()
  }, [load])

  /* ---- Helpers de campo ---- */
  function setField<K extends keyof EditorForm>(key: K, value: EditorForm[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
    if (!dirtyRef.current) {
      dirtyRef.current = true
      setDirty(true)
    }
    setFieldErrs((prev) => {
      // F-009: a validação de faixa (mín/máx) só se aplica quando tipoValor === 'faixa';
      // o erro fica sob a chave `valorBaseMaxCents`. Ao trocar o Tipo de valor para algo
      // que não usa máximo (variável/fixo), limpamos esse erro órfão junto, senão a
      // mensagem "valor máximo deve ser maior que o mínimo" persiste stale sob o campo.
      const dropMax = key === 'tipoValor' && value !== 'faixa' && !!prev.valorBaseMaxCents
      if (!prev[key as string] && !dropMax) return prev
      const next = { ...prev }
      delete next[key as string]
      if (dropMax) delete next.valorBaseMaxCents
      return next
    })
  }

  /* ---- Draft AO VIVO para a pré-visualização ---- */
  const draft = useMemo<Servico>(() => ({
    id: original?.id ?? 'preview',
    categoria: form.categoria,
    grupo: form.grupo,
    nome: form.nome,
    valorBase: form.valorBaseCents / 100,
    valorBaseMax: form.tipoValor === 'faixa' ? form.valorBaseMaxCents / 100 : undefined,
    tipoValor: form.tipoValor,
    tempoMedioMin: parseTempoMedio(form.tempoMedioLabel),
    tempoMedioLabel: form.tempoMedioLabel,
    status: form.status,
    observacao: form.observacao || undefined,
    checklistPadrao: form.checklistPadrao,
    orientacoesPre: form.orientacoesPre || undefined,
    orientacoesPos: form.orientacoesPos || undefined,
    adicionaisRelacionados: form.adicionaisRelacionados,
    created: original?.created ?? '',
    updated: original?.updated ?? '',
  }), [form, original])

  /* ---- Validação + montagem ---- */
  function validate(): Record<string, string> {
    const errs: Record<string, string> = {}
    if (!form.nome.trim()) errs.nome = 'Nome é obrigatório.'
    if (form.valorBaseCents < 0) errs.valorBaseCents = 'O valor não pode ser negativo.'
    if (form.tipoValor === 'faixa' && form.valorBaseMaxCents <= form.valorBaseCents) {
      errs.valorBaseMaxCents = 'O valor máximo deve ser maior que o mínimo.'
    }
    return errs
  }

  function buildInput(): ServicoInput {
    const checklist = form.checklistPadrao
      .map((c) => ({ ...c, titulo: c.titulo.trim() }))
      .filter((c) => c.titulo)
      // Normaliza IDs temporários (chktmp_*) para estáveis ao salvar.
      .map((c, i) => ({ ...c, id: `chk_${id ?? 'new'}_${i + 1}`, ordem: i + 1 }))
    const tempoLabel = form.tempoMedioLabel.trim()
    return {
      categoria: form.categoria,
      grupo: form.grupo,
      nome: form.nome.trim(),
      valorBase: form.valorBaseCents / 100,
      valorBaseMax: form.tipoValor === 'faixa' ? form.valorBaseMaxCents / 100 : undefined,
      tipoValor: form.tipoValor,
      tempoMedioMin: parseTempoMedio(tempoLabel),
      tempoMedioLabel: tempoLabel,
      status: form.status,
      observacao: form.observacao.trim() || undefined,
      checklistPadrao: checklist,
      orientacoesPre: form.orientacoesPre.trim() || undefined,
      orientacoesPos: form.orientacoesPos.trim() || undefined,
      adicionaisRelacionados: form.adicionaisRelacionados,
    }
  }

  async function handleSave() {
    const errs = validate()
    if (Object.keys(errs).length > 0) {
      setFieldErrs(errs)
      setSaveError('Verifique os campos destacados antes de salvar.')
      return
    }
    setSaving(true)
    setSaveError(null)
    try {
      const input = buildInput()
      if (isEdit && id) {
        await updateServico(id, input)
      } else {
        await createServico(input)
      }
      dirtyRef.current = false
      setDirty(false)
      navigate('/painel/servicos')
    } catch {
      setSaveError('Não foi possível salvar o serviço. Tente novamente.')
    } finally {
      setSaving(false)
    }
  }

  function handleCancel() {
    if (dirty) {
      setConfirmLeave(() => () => navigate('/painel/servicos'))
    } else {
      navigate('/painel/servicos')
    }
  }

  async function doDuplicate() {
    if (!id) return
    try {
      const novo = await duplicateServico(id)
      dirtyRef.current = false
      setDirty(false)
      navigate(`/painel/servicos/${novo.id}`)
    } catch {
      setSaveError('Não foi possível duplicar o serviço.')
    }
  }

  function handleDuplicate() {
    if (!id) return
    if (dirty) {
      setConfirmLeave(() => () => doDuplicate())
    } else {
      doDuplicate()
    }
  }

  /* ---- Render ---- */
  if (loading) {
    return <div className="loading-overlay"><Spinner size={22} /> Carregando serviço…</div>
  }

  if (loadError) {
    return (
      <div>
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {loadError}
        </div>
        <button type="button" className="clx-btn clx-btn-ghost" onClick={() => navigate('/painel/servicos')}>
          Voltar para Serviços
        </button>
      </div>
    )
  }

  return (
    <div className="svc-editor">
      {/* Header */}
      <header className="svc-editor-header">
        <div className="svc-editor-head-text">
          <nav className="svc-breadcrumb" aria-label="Trilha de navegação">
            <Link to="/painel/servicos">Serviços</Link>
            <span className="svc-breadcrumb-sep">/</span>
            <span aria-current="page">{isEdit ? 'Editar serviço' : 'Novo serviço'}</span>
          </nav>
          <h1 className="svc-editor-title">Cadastro de Serviço</h1>
          <p className="svc-editor-subtitle">
            Cadastre e gerencie um serviço que será usado em orçamento, agendamento e OS.
          </p>
        </div>

        <div className="svc-editor-actions">
          {isEdit && (
            <button type="button" className="clx-btn clx-btn-ghost" onClick={handleDuplicate} disabled={saving}>
              <IconCopy size={15} /> Duplicar serviço
            </button>
          )}
          <button type="button" className="clx-btn clx-btn-ghost" onClick={handleCancel} disabled={saving}>
            Cancelar
          </button>
          <button type="button" className="clx-btn clx-btn-accent" onClick={handleSave} disabled={saving}>
            {saving ? <><Spinner size={14} /> Salvando…</> : <><IconCheck size={15} /> Salvar alterações</>}
          </button>
        </div>
      </header>

      {saveError && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {saveError}
        </div>
      )}

      <div className="svc-stack">
        {/* Informações principais */}
        <section className="svc-card">
          <h2 className="svc-card-title">Informações principais</h2>

          <div className="svc-info-grid">
            <Field label="Categoria" className="svc-f-sm">
              <select
                value={form.categoria}
                onChange={(e) => setField('categoria', e.target.value as Categoria)}
              >
                {CATEGORIAS.map((c) => (
                  <option key={c} value={c}>{categoriaLabel(c)}</option>
                ))}
              </select>
            </Field>

            <Field label="Grupo" className="svc-f-sm">
              <select
                value={form.grupo}
                onChange={(e) => setField('grupo', e.target.value as Grupo)}
              >
                {GRUPOS.map((g) => (
                  <option key={g} value={g}>{grupoLabel(g)}</option>
                ))}
              </select>
            </Field>

            <Field label="Nome do serviço" required err={fieldErrs.nome} className="svc-f-nome">
              <input
                type="text"
                value={form.nome}
                onChange={(e) => setField('nome', e.target.value)}
                placeholder="Cleanox Premium"
                className={fieldErrs.nome ? 'err' : ''}
              />
            </Field>

            <Field
              label={form.tipoValor === 'faixa' ? 'Valor base (mín. / máx.)' : 'Valor base'}
              err={fieldErrs.valorBaseCents || fieldErrs.valorBaseMaxCents}
              className="svc-f-valor"
            >
              {form.tipoValor === 'faixa' ? (
                <div className="money-range">
                  <input
                    type="text"
                    inputMode="numeric"
                    value={centsToDisplay(form.valorBaseCents)}
                    onChange={(e) => setField('valorBaseCents', rawToCents(e.target.value))}
                    aria-label="Valor mínimo"
                    className={fieldErrs.valorBaseCents ? 'err' : ''}
                  />
                  <span className="money-range-sep">a</span>
                  <input
                    type="text"
                    inputMode="numeric"
                    value={centsToDisplay(form.valorBaseMaxCents)}
                    onChange={(e) => setField('valorBaseMaxCents', rawToCents(e.target.value))}
                    aria-label="Valor máximo"
                    className={fieldErrs.valorBaseMaxCents ? 'err' : ''}
                  />
                </div>
              ) : (
                <input
                  type="text"
                  inputMode="numeric"
                  value={centsToDisplay(form.valorBaseCents)}
                  onChange={(e) => setField('valorBaseCents', rawToCents(e.target.value))}
                  aria-label="Valor base"
                />
              )}
            </Field>

            <Field label="Tipo de valor" className="svc-f-sm">
              <select
                value={form.tipoValor}
                onChange={(e) => setField('tipoValor', e.target.value as TipoValor)}
              >
                {TIPOS_VALOR.map((t) => (
                  <option key={t} value={t}>{tipoValorLabel(t)}</option>
                ))}
              </select>
            </Field>

            <Field label="Tempo médio" className="svc-f-sm" hint="Ex.: 3h a 4h, 40min a 1h, Variável">
              <input
                type="text"
                value={form.tempoMedioLabel}
                onChange={(e) => setField('tempoMedioLabel', e.target.value)}
                placeholder="3h a 4h"
              />
            </Field>
          </div>

          {/* Status */}
          <div className="svc-status-row">
            <span className="svc-status-row-label">Status do serviço</span>
            <label className="toggle" htmlFor="svc-status-toggle">
              <input
                id="svc-status-toggle"
                type="checkbox"
                checked={form.status === 'ativo'}
                onChange={(e) => setField('status', e.target.checked ? 'ativo' : 'inativo')}
              />
              <span className="toggle-track" />
            </label>
            <label htmlFor="svc-status-toggle" className="svc-status-row-text">
              {form.status === 'ativo'
                ? 'Serviço ativo e disponível para orçamento e OS.'
                : 'Serviço inativo — não aparece em novos orçamentos e OS.'}
            </label>
          </div>
        </section>

        {/* Observação + Checklist */}
        <div className="svc-grid-2">
          <section className="svc-card">
            <h2 className="svc-card-title">Observação comercial / técnica</h2>
            <textarea
              className="svc-textarea"
              value={form.observacao}
              onChange={(e) => setField('observacao', e.target.value)}
              placeholder="Descreva detalhes comerciais ou técnicos que ajudam a equipe e o cliente…"
              rows={5}
            />
          </section>

          <section className="svc-card">
            <div className="svc-card-head">
              <h2 className="svc-card-title svc-card-title-inline">Checklist padrão do serviço</h2>
              <span className="svc-card-hint">Arraste para reordenar</span>
            </div>
            <ChecklistEditor
              items={form.checklistPadrao}
              onChange={(items) => setField('checklistPadrao', items)}
            />
          </section>
        </div>

        {/* Orientações pré / pós */}
        <div className="svc-grid-2">
          <section className="svc-card orientation-card">
            <div className="orientation-head">
              <span className="orientation-icon"><IconInfo size={18} /></span>
              <h2 className="svc-card-title svc-card-title-inline">Orientações pré-serviço</h2>
            </div>
            <textarea
              className="svc-textarea orientation-text"
              value={form.orientacoesPre}
              onChange={(e) => setField('orientacoesPre', e.target.value)}
              placeholder="Ex.: Garantir ponto de energia e água no local. Remover objetos pessoais…"
              rows={4}
            />
          </section>

          <section className="svc-card orientation-card">
            <div className="orientation-head">
              <span className="orientation-icon"><IconInfo size={18} /></span>
              <h2 className="svc-card-title svc-card-title-inline">Orientações pós-serviço</h2>
            </div>
            <textarea
              className="svc-textarea orientation-text"
              value={form.orientacoesPos}
              onChange={(e) => setField('orientacoesPos', e.target.value)}
              placeholder="Ex.: Tempo de secagem de 2 a 6 horas. Prazo de até 3 dias para intercorrências…"
              rows={4}
            />
          </section>
        </div>

        {/* Regras na OS + Pré-visualização */}
        <div className="svc-grid-2">
          <section className="svc-card">
            <h2 className="svc-card-title">Regras do serviço na OS</h2>
            <p className="svc-card-desc">
              Quando este serviço é selecionado em uma OS, o sistema carrega automaticamente:
            </p>
            <ul className="rules-list">
              {REGRAS_OS.map((r) => (
                <li key={r} className="rule-chip">
                  <IconCheckCircle size={15} /> {r}
                </li>
              ))}
            </ul>
          </section>

          <section className="svc-card">
            <h2 className="svc-card-title">Pré-visualização na OS</h2>
            <p className="svc-card-desc">
              Assim este serviço será exibido na Ordem de Serviço para o cliente e para a equipe.
            </p>
            <PreviewOS servico={draft} />
          </section>
        </div>

        {/* Outros serviços cadastrados */}
        <section className="svc-card">
          <h2 className="svc-card-title">Outros serviços cadastrados</h2>
          <OutrosServicosTable servicos={outros} />
        </section>
      </div>

      {/* Confirmação de saída com alterações não salvas */}
      <Modal
        open={confirmLeave !== null}
        onClose={() => setConfirmLeave(null)}
        title="Alterações não salvas"
        size="sm"
        footer={
          <>
            <button type="button" className="clx-btn clx-btn-ghost" onClick={() => setConfirmLeave(null)}>
              Continuar editando
            </button>
            <button
              type="button"
              className="clx-btn clx-btn-danger"
              onClick={() => {
                const fn = confirmLeave
                setConfirmLeave(null)
                fn?.()
              }}
            >
              Descartar alterações
            </button>
          </>
        }
      >
        <p style={{ fontSize: '0.9rem', color: 'var(--clx-ink-2)', lineHeight: 1.6 }}>
          Você tem alterações não salvas neste serviço. Se sair agora, elas serão perdidas.
        </p>
      </Modal>
    </div>
  )
}

/* ---- Helper de campo ---- */
function Field({
  label,
  required,
  err,
  hint,
  className,
  children,
}: {
  label: string
  required?: boolean
  err?: string
  hint?: string
  className?: string
  children: ReactNode
}) {
  // Associa o <label> ao controle (htmlFor + id) para que clicar no rótulo foque o
  // campo (WCAG 1.3.1). O id é injetado no único filho de controle via cloneElement.
  const fieldId = useId()
  const control = isValidElement(children)
    ? cloneElement(children as ReactElement<{ id?: string }>, { id: fieldId })
    : children
  return (
    <div className={`form-field${className ? ` ${className}` : ''}`}>
      <label htmlFor={fieldId}>
        {label}{required && <span className="req">*</span>}
      </label>
      {control}
      {err ? (
        <span className="field-err">{err}</span>
      ) : hint ? (
        <span className="svc-field-hint">{hint}</span>
      ) : null}
    </div>
  )
}
