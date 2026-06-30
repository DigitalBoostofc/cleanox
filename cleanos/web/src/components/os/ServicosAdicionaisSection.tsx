/**
 * ServicosAdicionaisSection — adicionais cobrados DENTRO da OS.
 *
 * Permite adicionar um extra a partir do catálogo (grupos adicional/avulsos/outros)
 * ou um item avulso digitado manualmente. Cada adicional carrega motivo, quantidade,
 * observação e um status de aprovação editável — só 'aprovado'/'nao_requer' entram
 * no total da OS (ver calcTotalOS).
 */

import { useMemo, useState } from 'react'
import type {
  AprovacaoStatus,
  Grupo,
  Servico,
  ServicoAdicionalOS,
} from '../../lib/servicos/types'
import {
  aprovacaoLabel,
  categoriaLabel,
  grupoLabel,
} from '../../lib/servicos/labels'
import { formatCurrency } from '../../lib/collections'
import { Modal } from '../ui/Modal'
import { IconPlus, IconTrash, IconAlertCircle } from '../ui/Icon'

interface ServicosAdicionaisSectionProps {
  adicionais: ServicoAdicionalOS[]
  onChange: (adicionais: ServicoAdicionalOS[]) => void
  /** Catálogo de serviços; usado para sugerir adicionais do catálogo. */
  servicos: Servico[]
}

/** Grupos elegíveis a virar adicional de OS. */
const GRUPOS_ADICIONAIS: Grupo[] = ['adicional', 'avulsos', 'outros']

const APROVACAO_OPCOES: AprovacaoStatus[] = [
  'nao_requer',
  'aguardando',
  'aprovado',
  'recusado',
]

function uid(): string {
  return `adi_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`
}

function aprovacaoChipClass(a: AprovacaoStatus): string {
  switch (a) {
    case 'aprovado':
      return 'clx-chip clx-chip-success'
    case 'aguardando':
      return 'clx-chip clx-chip-warning'
    case 'recusado':
      return 'clx-chip clx-chip-error'
    case 'nao_requer':
    default:
      return 'clx-chip clx-chip-primary'
  }
}

/** Conta para o total apenas adicionais aprovados / que não requerem aprovação. */
function entraNoTotal(a: AprovacaoStatus): boolean {
  return a === 'aprovado' || a === 'nao_requer'
}

type DraftMode = 'catalogo' | 'avulso'

interface Draft {
  mode: DraftMode
  serviceId: string
  nome: string
  valor: string
  quantidade: string
  motivo: string
  observacao: string
  aprovacao: AprovacaoStatus
}

function emptyDraft(): Draft {
  return {
    mode: 'catalogo',
    serviceId: '',
    nome: '',
    valor: '',
    quantidade: '1',
    motivo: '',
    observacao: '',
    aprovacao: 'aguardando',
  }
}

export default function ServicosAdicionaisSection({
  adicionais,
  onChange,
  servicos,
}: ServicosAdicionaisSectionProps) {
  const [modalOpen, setModalOpen] = useState(false)
  const [draft, setDraft] = useState<Draft>(emptyDraft())
  const [erro, setErro] = useState<string | null>(null)

  /** Serviços do catálogo elegíveis, agrupados por categoria → grupo. */
  const catalogo = useMemo(() => {
    const elegiveis = servicos.filter(
      (s) => GRUPOS_ADICIONAIS.includes(s.grupo) && s.status === 'ativo',
    )
    const grupos = new Map<string, { categoria: Servico['categoria']; grupo: Grupo; itens: Servico[] }>()
    for (const s of elegiveis) {
      const key = `${s.categoria}|${s.grupo}`
      const bucket = grupos.get(key)
      if (bucket) bucket.itens.push(s)
      else grupos.set(key, { categoria: s.categoria, grupo: s.grupo, itens: [s] })
    }
    return [...grupos.values()].sort(
      (a, b) =>
        a.categoria.localeCompare(b.categoria) || a.grupo.localeCompare(b.grupo),
    )
  }, [servicos])

  const totalEntra = adicionais
    .filter((a) => entraNoTotal(a.aprovacao))
    .reduce((sum, a) => sum + a.valor * a.quantidade, 0)

  function openModal() {
    setDraft(emptyDraft())
    setErro(null)
    setModalOpen(true)
  }

  function onPickCatalogo(id: string) {
    const svc = servicos.find((s) => s.id === id)
    setDraft((d) => ({
      ...d,
      serviceId: id,
      ...(svc
        ? {
            nome: svc.nome,
            valor: String(svc.valorBase),
          }
        : {}),
    }))
    setErro(null)
  }

  function handleAdd() {
    if (draft.mode === 'catalogo' && !draft.serviceId) {
      setErro('Selecione um serviço do catálogo.')
      return
    }
    const nome = draft.nome.trim()
    if (!nome) {
      setErro('Informe o nome do adicional.')
      return
    }
    const valor = parseFloat(draft.valor.replace(',', '.'))
    if (Number.isNaN(valor) || valor < 0) {
      setErro('Informe um valor válido.')
      return
    }
    const quantidade = Math.max(1, parseInt(draft.quantidade, 10) || 1)

    const fromCatalogo = draft.mode === 'catalogo' ? servicos.find((s) => s.id === draft.serviceId) : undefined

    const novo: ServicoAdicionalOS = {
      id: uid(),
      serviceId: fromCatalogo?.id,
      nome,
      categoria: fromCatalogo?.categoria,
      grupo: fromCatalogo?.grupo,
      valor,
      tipoValor: fromCatalogo?.tipoValor ?? 'variavel',
      quantidade,
      motivo: draft.motivo.trim() || undefined,
      observacao: draft.observacao.trim() || undefined,
      aprovacao: draft.aprovacao,
    }
    onChange([...adicionais, novo])
    setModalOpen(false)
  }

  function setAprovacao(id: string, aprovacao: AprovacaoStatus) {
    onChange(adicionais.map((a) => (a.id === id ? { ...a, aprovacao } : a)))
  }

  function remove(id: string) {
    onChange(adicionais.filter((a) => a.id !== id))
  }

  return (
    <section className="clx-card" style={{ padding: '16px 18px' }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
          marginBottom: 14,
        }}
      >
        <h3
          style={{
            margin: 0,
            fontFamily: 'var(--clx-font-display)',
            fontSize: '1rem',
            fontWeight: 700,
            color: 'var(--clx-ink)',
          }}
        >
          Serviços adicionais
        </h3>
        <button type="button" className="clx-btn clx-btn-accent clx-btn-sm" onClick={openModal}>
          <IconPlus size={14} /> Adicionar
        </button>
      </div>

      {adicionais.length === 0 ? (
        <div className="empty-state" style={{ padding: '24px 12px' }}>
          <h4>Nenhum serviço adicional</h4>
          <p>Adicione extras do catálogo (adicional, avulsos, outros) ou um item avulso.</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {adicionais.map((a) => {
            const conta = entraNoTotal(a.aprovacao)
            return (
              <div
                key={a.id}
                style={{
                  border: '1px solid var(--clx-line)',
                  borderRadius: 'var(--clx-r-md)',
                  background: 'var(--clx-bg-2)',
                  padding: '12px 14px',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12 }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--clx-ink)' }}>
                      {a.nome}
                    </div>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '2px 8px', marginTop: 4 }}>
                      {a.categoria && (
                        <span style={{ fontSize: '0.78rem', color: 'var(--clx-ink-3)' }}>
                          {categoriaLabel(a.categoria)}
                          {a.grupo ? ` · ${grupoLabel(a.grupo)}` : ''}
                        </span>
                      )}
                      {!a.serviceId && (
                        <span style={{ fontSize: '0.78rem', color: 'var(--clx-ink-3)' }}>Avulso</span>
                      )}
                    </div>
                  </div>
                  <div style={{ textAlign: 'right', flexShrink: 0 }}>
                    <div style={{ fontSize: '0.92rem', fontWeight: 700, color: 'var(--clx-ink)' }}>
                      {formatCurrency(a.valor * a.quantidade)}
                    </div>
                    {a.quantidade > 1 && (
                      <div style={{ fontSize: '0.74rem', color: 'var(--clx-ink-3)' }}>
                        {a.quantidade} × {formatCurrency(a.valor)}
                      </div>
                    )}
                  </div>
                </div>

                {(a.motivo || a.observacao) && (
                  <div style={{ marginTop: 8, fontSize: '0.82rem', color: 'var(--clx-ink-2)', lineHeight: 1.45 }}>
                    {a.motivo && (
                      <div>
                        <strong style={{ color: 'var(--clx-ink)' }}>Motivo:</strong> {a.motivo}
                      </div>
                    )}
                    {a.observacao && (
                      <div>
                        <strong style={{ color: 'var(--clx-ink)' }}>Obs.:</strong> {a.observacao}
                      </div>
                    )}
                  </div>
                )}

                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    marginTop: 10,
                    paddingTop: 10,
                    borderTop: '1px solid var(--clx-line)',
                  }}
                >
                  <span className={aprovacaoChipClass(a.aprovacao)} style={{ whiteSpace: 'nowrap' }}>
                    {aprovacaoLabel(a.aprovacao)}
                  </span>
                  {!conta && (
                    <span style={{ fontSize: '0.72rem', color: 'var(--clx-ink-3)' }}>
                      não entra no total
                    </span>
                  )}
                  <label htmlFor={`aprov-${a.id}`} style={{ position: 'absolute', width: 1, height: 1, overflow: 'hidden', clip: 'rect(0 0 0 0)' }}>
                    Status de aprovação de {a.nome}
                  </label>
                  <select
                    id={`aprov-${a.id}`}
                    value={a.aprovacao}
                    onChange={(e) => setAprovacao(a.id, e.target.value as AprovacaoStatus)}
                    style={{
                      marginLeft: 'auto',
                      padding: '5px 8px',
                      fontSize: '0.8rem',
                      background: 'var(--clx-bg)',
                      border: '1.5px solid var(--clx-line)',
                      borderRadius: 'var(--clx-r-md)',
                      color: 'var(--clx-ink)',
                      outline: 'none',
                    }}
                  >
                    {APROVACAO_OPCOES.map((opt) => (
                      <option key={opt} value={opt}>
                        {aprovacaoLabel(opt)}
                      </option>
                    ))}
                  </select>
                  <button
                    type="button"
                    className="icon-btn danger"
                    onClick={() => remove(a.id)}
                    title="Remover adicional"
                    aria-label={`Remover ${a.nome}`}
                  >
                    <IconTrash size={15} />
                  </button>
                </div>
              </div>
            )
          })}

          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              fontSize: '0.85rem',
              color: 'var(--clx-ink-2)',
              paddingTop: 6,
            }}
          >
            <span>Σ adicionais que entram no total</span>
            <strong style={{ color: 'var(--clx-ink)' }}>{formatCurrency(totalEntra)}</strong>
          </div>
        </div>
      )}

      {/* Modal de adição */}
      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title="Adicionar serviço adicional"
        size="sm"
        footer={
          <div style={{ display: 'flex', gap: 8, width: '100%' }}>
            <button
              type="button"
              className="clx-btn clx-btn-ghost"
              onClick={() => setModalOpen(false)}
              style={{ flex: 1 }}
            >
              Cancelar
            </button>
            <button type="button" className="clx-btn clx-btn-accent" onClick={handleAdd} style={{ flex: 2 }}>
              <IconPlus size={15} /> Adicionar
            </button>
          </div>
        }
      >
        {erro && (
          <div className="error-banner" style={{ marginBottom: 14 }}>
            <IconAlertCircle size={14} /> {erro}
          </div>
        )}

        {/* Toggle de origem */}
        <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
          {(['catalogo', 'avulso'] as DraftMode[]).map((m) => (
            <button
              key={m}
              type="button"
              className={`clx-btn clx-btn-sm ${draft.mode === m ? 'clx-btn-primary' : 'clx-btn-ghost'}`}
              style={{ flex: 1 }}
              onClick={() =>
                setDraft((d) => ({
                  ...d,
                  mode: m,
                  // ao trocar de modo, limpa os campos que não se aplicam
                  serviceId: '',
                  ...(m === 'avulso' ? {} : { nome: '', valor: '' }),
                }))
              }
            >
              {m === 'catalogo' ? 'Do catálogo' : 'Avulso'}
            </button>
          ))}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {draft.mode === 'catalogo' ? (
            <div className="form-field">
              <label htmlFor="adi-catalogo">Serviço do catálogo</label>
              <select
                id="adi-catalogo"
                value={draft.serviceId}
                onChange={(e) => onPickCatalogo(e.target.value)}
              >
                <option value="">Selecione…</option>
                {catalogo.map((bucket) => (
                  <optgroup
                    key={`${bucket.categoria}-${bucket.grupo}`}
                    label={`${categoriaLabel(bucket.categoria)} · ${grupoLabel(bucket.grupo)}`}
                  >
                    {bucket.itens.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.nome} — {formatCurrency(s.valorBase)}
                      </option>
                    ))}
                  </optgroup>
                ))}
              </select>
            </div>
          ) : (
            <div className="form-field">
              <label htmlFor="adi-nome">
                Nome do adicional <span className="req">*</span>
              </label>
              <input
                id="adi-nome"
                type="text"
                placeholder="Ex.: Remoção de mancha específica"
                value={draft.nome}
                onChange={(e) => setDraft((d) => ({ ...d, nome: e.target.value }))}
              />
            </div>
          )}

          <div style={{ display: 'flex', gap: 12 }}>
            <div className="form-field" style={{ flex: 2 }}>
              <label htmlFor="adi-valor">
                Valor unitário (R$) <span className="req">*</span>
              </label>
              <input
                id="adi-valor"
                type="number"
                step="0.01"
                min="0"
                placeholder="0,00"
                value={draft.valor}
                onChange={(e) => setDraft((d) => ({ ...d, valor: e.target.value }))}
              />
            </div>
            <div className="form-field" style={{ flex: 1 }}>
              <label htmlFor="adi-qtd">Qtd.</label>
              <input
                id="adi-qtd"
                type="number"
                min="1"
                step="1"
                value={draft.quantidade}
                onChange={(e) => setDraft((d) => ({ ...d, quantidade: e.target.value }))}
              />
            </div>
          </div>

          <div className="form-field">
            <label htmlFor="adi-motivo">Motivo</label>
            <input
              id="adi-motivo"
              type="text"
              placeholder="Ex.: Excesso de sujeira"
              value={draft.motivo}
              onChange={(e) => setDraft((d) => ({ ...d, motivo: e.target.value }))}
            />
          </div>

          <div className="form-field">
            <label htmlFor="adi-obs">Observação</label>
            <textarea
              id="adi-obs"
              rows={2}
              placeholder="Detalhes opcionais…"
              value={draft.observacao}
              onChange={(e) => setDraft((d) => ({ ...d, observacao: e.target.value }))}
              style={{ resize: 'vertical', fontFamily: 'inherit' }}
            />
          </div>

          <div className="form-field">
            <label htmlFor="adi-aprov">Status de aprovação</label>
            <select
              id="adi-aprov"
              value={draft.aprovacao}
              onChange={(e) => setDraft((d) => ({ ...d, aprovacao: e.target.value as AprovacaoStatus }))}
            >
              {APROVACAO_OPCOES.map((opt) => (
                <option key={opt} value={opt}>
                  {aprovacaoLabel(opt)}
                </option>
              ))}
            </select>
          </div>
        </div>
      </Modal>
    </section>
  )
}
