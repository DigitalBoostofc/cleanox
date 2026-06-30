/**
 * LancamentoFormModal — criar / editar um lançamento financeiro.
 *
 * Campos: Tipo (Receita/Despesa), Descrição, Categoria + Subcategoria (dependente),
 * Valor, Conta, Data, Vencimento, Status, Recorrência (Única/Fixa/Recorrente/
 * Parcelada — Parcelada revela nº de parcelas), Origem (Manual/Via OS), campos da
 * OS (read-only quando o lançamento veio de uma OS), Observação, Anexo (mock) e Tags.
 *
 * Validações: descrição obrigatória, valor > 0, categoria e conta obrigatórias,
 * data obrigatória e, para Parcelada, nº de parcelas ≥ 1 com parcela atual coerente.
 *
 * Comportamento VIA OS (mock): quando o lançamento JÁ EXISTE e tem origem 'via_os'
 * (nasceu de uma OS), os campos derivados da OS ficam READ-ONLY — valor, categoria,
 * conta, data, descrição, forma e recorrência. Permanecem editáveis: vencimento,
 * status, observação, anexos e tags (ver MAPA §9). Ao CRIAR um via_os (atalho mock),
 * os campos da OS são editáveis e um aviso explica que normalmente eles vêm da OS.
 *
 * Parcelada (mock): grava parcelaAtual/parcelasTotal no PRÓPRIO registro. NÃO gera
 * os N filhos agora — a geração das parcelas/lançamentos previstos fica como TODO
 * para a camada de store quando virar PocketBase.
 */

import { useEffect, useMemo, useState } from 'react'
import { Modal } from '../../../../components/ui/Modal'
import { Spinner } from '../../../../components/ui/Spinner'
import { IconAlertCircle, IconLock, IconX } from '../../../../components/ui/Icon'
import { IconPaperclip } from './icons'
import { toDateInputValue } from '../../../../lib/collections'
import { recorrenciaLabel, statusLabel } from '../../../../lib/financeiro/labels'
import type {
  Anexo,
  Categoria,
  Conta,
  Lancamento,
  LancamentoInput,
  LancamentoStatus,
  OrigemLancamento,
  RecorrenciaTipo,
  TipoLancamento,
} from '../../../../lib/financeiro/types'

/** Estilo das mensagens de erro de campo (não há classe global `field-error`). */
const FIELD_ERR_STYLE: React.CSSProperties = {
  fontSize: '0.72rem',
  color: 'var(--clx-error)',
  marginTop: 4,
}

const STATUS_OPTIONS: LancamentoStatus[] = ['pago', 'pendente', 'previsto', 'em_atraso']
const RECORRENCIA_OPTIONS: RecorrenciaTipo[] = ['unica', 'fixa', 'recorrente', 'parcelada']

export interface LancamentoFormModalProps {
  open: boolean
  /** Lançamento sendo editado; ausente/`null` = criação. */
  initial?: Lancamento | null
  categorias: Categoria[]
  contas: Conta[]
  /** Persiste (parent chama o store, mostra toast e fecha em caso de sucesso). */
  onSubmit: (input: LancamentoInput, id?: string) => Promise<void>
  onClose: () => void
}

interface FieldErrors {
  descricao?: string
  valor?: string
  categoriaId?: string
  contaId?: string
  data?: string
  parcelas?: string
}

function todayInput(): string {
  return toDateInputValue(new Date().toISOString())
}

function formatBytes(bytes?: number): string {
  if (bytes == null) return ''
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

export function LancamentoFormModal({
  open,
  initial,
  categorias,
  contas,
  onSubmit,
  onClose,
}: LancamentoFormModalProps) {
  const isEditing = !!initial

  /* ---- estado dos campos ---- */
  const [tipo, setTipo] = useState<TipoLancamento>('despesa')
  const [descricao, setDescricao] = useState('')
  const [categoriaId, setCategoriaId] = useState('')
  const [subcategoriaId, setSubcategoriaId] = useState('')
  const [valorStr, setValorStr] = useState('')
  const [contaId, setContaId] = useState('')
  const [dataStr, setDataStr] = useState(todayInput())
  const [vencimentoStr, setVencimentoStr] = useState('')
  const [status, setStatus] = useState<LancamentoStatus>('pendente')
  const [recorrencia, setRecorrencia] = useState<RecorrenciaTipo>('unica')
  const [parcelaAtualStr, setParcelaAtualStr] = useState('1')
  const [parcelasTotalStr, setParcelasTotalStr] = useState('2')
  const [origem, setOrigem] = useState<OrigemLancamento>('manual')
  const [osNumero, setOsNumero] = useState('')
  const [clienteNome, setClienteNome] = useState('')
  const [servicoNome, setServicoNome] = useState('')
  const [formaPagamento, setFormaPagamento] = useState('')
  const [observacao, setObservacao] = useState('')
  const [anexos, setAnexos] = useState<Anexo[]>([])
  const [tagsStr, setTagsStr] = useState('')

  const [saving, setSaving] = useState(false)
  const [submitErr, setSubmitErr] = useState<string | null>(null)
  const [errors, setErrors] = useState<FieldErrors>({})

  /* ---- (re)inicializa ao abrir / trocar de registro ---- */
  useEffect(() => {
    if (!open) return
    setErrors({})
    setSubmitErr(null)
    setSaving(false)
    if (initial) {
      setTipo(initial.tipo)
      setDescricao(initial.descricao)
      setCategoriaId(initial.categoriaId)
      setSubcategoriaId(initial.subcategoriaId ?? '')
      setValorStr(String(initial.valor))
      setContaId(initial.contaId)
      setDataStr(toDateInputValue(initial.data))
      setVencimentoStr(initial.vencimento ? toDateInputValue(initial.vencimento) : '')
      setStatus(initial.status)
      setRecorrencia(initial.recorrencia)
      setParcelaAtualStr(String(initial.parcelaAtual ?? 1))
      setParcelasTotalStr(String(initial.parcelasTotal ?? 2))
      setOrigem(initial.origem)
      setOsNumero(initial.osNumero ?? '')
      setClienteNome(initial.clienteNome ?? '')
      setServicoNome(initial.servicoNome ?? '')
      setFormaPagamento(initial.formaPagamento ?? '')
      setObservacao(initial.observacao ?? '')
      setAnexos(initial.anexos ? [...initial.anexos] : [])
      setTagsStr((initial.tags ?? []).join(', '))
    } else {
      setTipo('despesa')
      setDescricao('')
      setCategoriaId('')
      setSubcategoriaId('')
      setValorStr('')
      setContaId('')
      setDataStr(todayInput())
      setVencimentoStr('')
      setStatus('pendente')
      setRecorrencia('unica')
      setParcelaAtualStr('1')
      setParcelasTotalStr('2')
      setOrigem('manual')
      setOsNumero('')
      setClienteNome('')
      setServicoNome('')
      setFormaPagamento('')
      setObservacao('')
      setAnexos([])
      setTagsStr('')
    }
  }, [open, initial])

  const isViaOs = origem === 'via_os'
  /** Campos derivados da OS travam SÓ em lançamento já existente nascido de OS. */
  const osLocked = isViaOs && isEditing

  /* ---- opções de categoria/subcategoria dependentes ---- */
  const categoriasRaiz = useMemo(
    () => categorias.filter((c) => c.tipo === tipo && !c.parentId && !c.arquivada),
    [categorias, tipo],
  )
  const subcategorias = useMemo(
    () => categorias.filter((c) => c.parentId === categoriaId && !c.arquivada),
    [categorias, categoriaId],
  )
  const contasAtivas = useMemo(
    () => contas.filter((c) => c.ativo || c.id === contaId),
    [contas, contaId],
  )

  function handleTipoChange(next: TipoLancamento) {
    if (osLocked) return
    setTipo(next)
    setCategoriaId('')
    setSubcategoriaId('')
  }

  function handleCategoriaChange(next: string) {
    setCategoriaId(next)
    setSubcategoriaId('')
  }

  const tags = useMemo(
    () => tagsStr.split(',').map((t) => t.trim()).filter(Boolean),
    [tagsStr],
  )

  function addMockAnexo() {
    const n = anexos.length + 1
    setAnexos((prev) => [
      ...prev,
      { id: `anx_${Date.now()}_${n}`, nome: `comprovante_${n}.pdf`, url: '#mock', tamanho: 102400 },
    ])
  }

  function removeAnexo(id: string) {
    setAnexos((prev) => prev.filter((a) => a.id !== id))
  }

  function validate(): FieldErrors {
    const e: FieldErrors = {}
    if (!descricao.trim()) e.descricao = 'Informe uma descrição.'
    const valor = Number(valorStr.replace(',', '.'))
    if (!valorStr.trim() || !Number.isFinite(valor) || valor <= 0)
      e.valor = 'Valor deve ser maior que zero.'
    if (!categoriaId) e.categoriaId = 'Selecione uma categoria.'
    if (!contaId) e.contaId = 'Selecione uma conta.'
    if (!dataStr) e.data = 'Informe a data.'
    if (recorrencia === 'parcelada') {
      const total = Number(parcelasTotalStr)
      const atual = Number(parcelaAtualStr)
      if (!Number.isInteger(total) || total < 1) {
        e.parcelas = 'Nº de parcelas deve ser um inteiro ≥ 1.'
      } else if (!Number.isInteger(atual) || atual < 1 || atual > total) {
        e.parcelas = `Parcela atual deve estar entre 1 e ${total}.`
      }
    }
    return e
  }

  function buildInput(): LancamentoInput {
    const valor = Number(valorStr.replace(',', '.'))
    const sameData = initial && toDateInputValue(initial.data) === dataStr
    const data = osLocked && initial ? initial.data : sameData && initial ? initial.data : `${dataStr}T12:00:00.000Z`
    const parcelada = recorrencia === 'parcelada'
    return {
      tipo,
      descricao: descricao.trim(),
      categoriaId,
      subcategoriaId: subcategoriaId || undefined,
      valor,
      contaId,
      data,
      vencimento: vencimentoStr || undefined,
      status,
      recorrencia,
      parcelaAtual: parcelada ? Number(parcelaAtualStr) : undefined,
      parcelasTotal: parcelada ? Number(parcelasTotalStr) : undefined,
      origem,
      osId: initial?.osId,
      osNumero: isViaOs ? osNumero.trim() || undefined : undefined,
      clienteNome: isViaOs ? clienteNome.trim() || undefined : undefined,
      servicoNome: isViaOs ? servicoNome.trim() || undefined : undefined,
      formaPagamento: formaPagamento.trim() || undefined,
      observacao: observacao.trim() || undefined,
      anexos: anexos.length ? anexos : undefined,
      tags: tags.length ? tags : undefined,
    }
  }

  async function handleSubmit() {
    const e = validate()
    setErrors(e)
    if (Object.keys(e).length > 0) return
    setSaving(true)
    setSubmitErr(null)
    try {
      await onSubmit(buildInput(), initial?.id)
      // sucesso → o parent fecha o modal
    } catch {
      setSubmitErr('Não foi possível salvar o lançamento. Tente novamente.')
      setSaving(false)
    }
  }

  return (
    <Modal
      open={open}
      onClose={saving ? () => {} : onClose}
      title={isEditing ? 'Editar lançamento' : 'Novo lançamento'}
      size="lg"
      footer={
        <>
          <button className="clx-btn clx-btn-ghost" onClick={onClose} disabled={saving}>
            Cancelar
          </button>
          <button className="clx-btn clx-btn-primary" onClick={handleSubmit} disabled={saving}>
            {saving ? (
              <>
                <Spinner size={14} /> Salvando…
              </>
            ) : isEditing ? (
              'Salvar alterações'
            ) : (
              'Criar lançamento'
            )}
          </button>
        </>
      }
    >
      {submitErr && (
        <div className="error-banner" role="alert" style={{ marginBottom: 14 }}>
          <IconAlertCircle size={15} /> {submitErr}
        </div>
      )}

      {osLocked && (
        <div
          className="clx-chip clx-chip-info"
          style={{ marginBottom: 14, display: 'inline-flex', gap: 6 }}
        >
          <IconLock size={13} /> Lançamento gerado pela OS #{osNumero || '—'} — alguns campos
          são somente leitura.
        </div>
      )}

      <div className="form-grid">
        {/* Tipo */}
        <div className="form-field">
          <label>Tipo</label>
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              type="button"
              className={`clx-btn clx-btn-sm ${tipo === 'receita' ? 'clx-btn-primary' : 'clx-btn-ghost'}`}
              style={{ flex: 1 }}
              onClick={() => handleTipoChange('receita')}
              disabled={osLocked}
              aria-pressed={tipo === 'receita'}
            >
              Receita
            </button>
            <button
              type="button"
              className={`clx-btn clx-btn-sm ${tipo === 'despesa' ? 'clx-btn-danger' : 'clx-btn-ghost'}`}
              style={{ flex: 1 }}
              onClick={() => handleTipoChange('despesa')}
              disabled={osLocked}
              aria-pressed={tipo === 'despesa'}
            >
              Despesa
            </button>
          </div>
        </div>

        {/* Origem */}
        <div className="form-field">
          <label>Origem</label>
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              type="button"
              className={`clx-btn clx-btn-sm ${origem === 'manual' ? 'clx-btn-accent' : 'clx-btn-ghost'}`}
              style={{ flex: 1 }}
              onClick={() => !isEditing && setOrigem('manual')}
              disabled={isEditing}
              aria-pressed={origem === 'manual'}
            >
              Manual
            </button>
            <button
              type="button"
              className={`clx-btn clx-btn-sm ${origem === 'via_os' ? 'clx-btn-accent' : 'clx-btn-ghost'}`}
              style={{ flex: 1 }}
              onClick={() => !isEditing && setOrigem('via_os')}
              disabled={isEditing}
              aria-pressed={origem === 'via_os'}
            >
              Via OS
            </button>
          </div>
        </div>

        {/* Descrição */}
        <div className="form-field" style={{ gridColumn: '1 / -1' }}>
          <label>
            Descrição <span className="req">*</span>
          </label>
          <input
            type="text"
            value={descricao}
            onChange={(e) => setDescricao(e.target.value)}
            placeholder="Ex.: Compra de produtos de limpeza"
            disabled={osLocked}
            aria-invalid={!!errors.descricao}
          />
          {errors.descricao && <span style={FIELD_ERR_STYLE}>{errors.descricao}</span>}
        </div>

        {/* Categoria */}
        <div className="form-field">
          <label>
            Categoria <span className="req">*</span>
          </label>
          <select
            value={categoriaId}
            onChange={(e) => handleCategoriaChange(e.target.value)}
            disabled={osLocked}
            aria-invalid={!!errors.categoriaId}
          >
            <option value="">Selecione…</option>
            {categoriasRaiz.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nome}
              </option>
            ))}
          </select>
          {errors.categoriaId && <span style={FIELD_ERR_STYLE}>{errors.categoriaId}</span>}
        </div>

        {/* Subcategoria */}
        <div className="form-field">
          <label>Subcategoria</label>
          <select
            value={subcategoriaId}
            onChange={(e) => setSubcategoriaId(e.target.value)}
            disabled={osLocked || subcategorias.length === 0}
          >
            <option value="">
              {subcategorias.length === 0 ? 'Sem subcategorias' : 'Nenhuma'}
            </option>
            {subcategorias.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nome}
              </option>
            ))}
          </select>
        </div>

        {/* Valor */}
        <div className="form-field">
          <label>
            Valor (R$) <span className="req">*</span>
          </label>
          <input
            type="number"
            min="0"
            step="0.01"
            value={valorStr}
            onChange={(e) => setValorStr(e.target.value)}
            placeholder="0,00"
            disabled={osLocked}
            aria-invalid={!!errors.valor}
          />
          {errors.valor && <span style={FIELD_ERR_STYLE}>{errors.valor}</span>}
        </div>

        {/* Conta */}
        <div className="form-field">
          <label>
            Conta <span className="req">*</span>
          </label>
          <select
            value={contaId}
            onChange={(e) => setContaId(e.target.value)}
            disabled={osLocked}
            aria-invalid={!!errors.contaId}
          >
            <option value="">Selecione…</option>
            {contasAtivas.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nome}
              </option>
            ))}
          </select>
          {errors.contaId && <span style={FIELD_ERR_STYLE}>{errors.contaId}</span>}
        </div>

        {/* Data */}
        <div className="form-field">
          <label>
            Data <span className="req">*</span>
          </label>
          <input
            type="date"
            value={dataStr}
            onChange={(e) => setDataStr(e.target.value)}
            disabled={osLocked}
            aria-invalid={!!errors.data}
          />
          {errors.data && <span style={FIELD_ERR_STYLE}>{errors.data}</span>}
        </div>

        {/* Vencimento */}
        <div className="form-field">
          <label>Vencimento</label>
          <input
            type="date"
            value={vencimentoStr}
            onChange={(e) => setVencimentoStr(e.target.value)}
          />
        </div>

        {/* Status */}
        <div className="form-field">
          <label>Status</label>
          <select value={status} onChange={(e) => setStatus(e.target.value as LancamentoStatus)}>
            {STATUS_OPTIONS.map((s) => (
              <option key={s} value={s}>
                {statusLabel(s)}
              </option>
            ))}
          </select>
        </div>

        {/* Recorrência */}
        <div className="form-field">
          <label>Recorrência</label>
          <select
            value={recorrencia}
            onChange={(e) => setRecorrencia(e.target.value as RecorrenciaTipo)}
            disabled={osLocked}
          >
            {RECORRENCIA_OPTIONS.map((r) => (
              <option key={r} value={r}>
                {recorrenciaLabel(r)}
              </option>
            ))}
          </select>
        </div>

        {/* Parcelas (somente Parcelada) */}
        {recorrencia === 'parcelada' && (
          <div className="form-field" style={{ gridColumn: '1 / -1' }}>
            <label>Parcelas</label>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <input
                type="number"
                min="1"
                step="1"
                value={parcelaAtualStr}
                onChange={(e) => setParcelaAtualStr(e.target.value)}
                style={{ width: 90 }}
                aria-label="Parcela atual"
                disabled={osLocked}
              />
              <span style={{ color: 'var(--clx-ink-3)' }}>de</span>
              <input
                type="number"
                min="1"
                step="1"
                value={parcelasTotalStr}
                onChange={(e) => setParcelasTotalStr(e.target.value)}
                style={{ width: 90 }}
                aria-label="Total de parcelas"
                disabled={osLocked}
              />
              <span style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)' }}>
                As parcelas seguintes não são geradas neste mock.
              </span>
            </div>
            {errors.parcelas && <span style={FIELD_ERR_STYLE}>{errors.parcelas}</span>}
          </div>
        )}

        {/* Campos da OS */}
        {isViaOs && (
          <div className="form-field" style={{ gridColumn: '1 / -1' }}>
            <label>Vínculo com a OS</label>
            {!osLocked && (
              <span style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)', marginBottom: 6 }}>
                Normalmente lançamentos via OS são gerados automaticamente pela Ordem de Serviço.
              </span>
            )}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
              <input
                type="text"
                value={osNumero}
                onChange={(e) => setOsNumero(e.target.value)}
                placeholder="Nº da OS"
                readOnly={osLocked}
                aria-label="Número da OS"
                style={osLocked ? { background: 'var(--clx-bg-3)' } : undefined}
              />
              <input
                type="text"
                value={clienteNome}
                onChange={(e) => setClienteNome(e.target.value)}
                placeholder="Cliente"
                readOnly={osLocked}
                aria-label="Cliente da OS"
                style={osLocked ? { background: 'var(--clx-bg-3)' } : undefined}
              />
              <input
                type="text"
                value={servicoNome}
                onChange={(e) => setServicoNome(e.target.value)}
                placeholder="Serviço"
                readOnly={osLocked}
                aria-label="Serviço da OS"
                style={osLocked ? { background: 'var(--clx-bg-3)' } : undefined}
              />
            </div>
          </div>
        )}

        {/* Forma de pagamento */}
        <div className="form-field">
          <label>Forma de pagamento</label>
          <input
            type="text"
            value={formaPagamento}
            onChange={(e) => setFormaPagamento(e.target.value)}
            placeholder="Pix, Crédito, Dinheiro…"
            disabled={osLocked}
          />
        </div>

        {/* Tags */}
        <div className="form-field">
          <label>Tags</label>
          <input
            type="text"
            value={tagsStr}
            onChange={(e) => setTagsStr(e.target.value)}
            placeholder="separe, por, vírgulas"
          />
          {tags.length > 0 && (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 6 }}>
              {tags.map((t) => (
                <span key={t} className="clx-chip">
                  {t}
                </span>
              ))}
            </div>
          )}
        </div>

        {/* Observação */}
        <div className="form-field" style={{ gridColumn: '1 / -1' }}>
          <label>Observação</label>
          <textarea
            value={observacao}
            onChange={(e) => setObservacao(e.target.value)}
            rows={3}
            placeholder="Detalhes adicionais do lançamento"
          />
        </div>

        {/* Anexos (mock) */}
        <div className="form-field" style={{ gridColumn: '1 / -1' }}>
          <label>Anexos</label>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {anexos.map((a) => (
              <div
                key={a.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '8px 10px',
                  background: 'var(--clx-bg-2)',
                  borderRadius: 'var(--clx-r-md)',
                  fontSize: '0.8rem',
                }}
              >
                <IconPaperclip size={15} />
                <span style={{ flex: 1, minWidth: 0 }}>{a.nome}</span>
                {a.tamanho != null && (
                  <span style={{ color: 'var(--clx-ink-3)' }}>{formatBytes(a.tamanho)}</span>
                )}
                <button
                  type="button"
                  className="icon-btn"
                  onClick={() => removeAnexo(a.id)}
                  aria-label={`Remover ${a.nome}`}
                >
                  <IconX size={14} />
                </button>
              </div>
            ))}
            <button
              type="button"
              className="clx-btn clx-btn-ghost clx-btn-sm"
              onClick={addMockAnexo}
              style={{ alignSelf: 'flex-start' }}
            >
              <IconPaperclip size={14} /> Adicionar anexo (mock)
            </button>
          </div>
        </div>
      </div>
    </Modal>
  )
}

export default LancamentoFormModal
