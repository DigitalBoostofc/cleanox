/**
 * ObservacoesProfissionalSection — Observações do profissional na OS.
 *
 * Componente 100% standalone e CONTROLADO: a lista de observações vive no pai e chega
 * por `observacoes`; toda mutação é propagada por `onChange`. Permite adicionar, editar
 * e excluir observações, classificá-las por tipo, marcar quais ficam visíveis ao cliente
 * e vincular fotos (evidências) já anexadas à OS. Sem backend.
 */

import { useState } from 'react'
import type {
  EvidenciaFoto,
  ObservacaoProfissional,
  ObservacaoTipo,
} from '../../lib/servicos/types'
import { IconPlus, IconEdit, IconTrash, IconCheck, IconAlertCircle } from '../ui/Icon'

export interface ObservacoesProfissionalSectionProps {
  observacoes: ObservacaoProfissional[]
  onChange: (obs: ObservacaoProfissional[]) => void
  fotos?: EvidenciaFoto[]
  criadoPor?: string
}

// ── constantes ────────────────────────────────────────────────────────
const MAX_TEXTO = 2000

const TIPOS: ObservacaoTipo[] = [
  'geral',
  'ponto',
  'limitacao',
  'recomendacao',
  'intercorrencia',
  'revisao',
]

const TIPO_LABELS: Record<ObservacaoTipo, string> = {
  geral: 'Observação geral',
  ponto: 'Pontos encontrados no local',
  limitacao: 'Limitações do serviço',
  recomendacao: 'Recomendação ao cliente',
  intercorrencia: 'Intercorrências',
  revisao: 'Necessidade de revisão futura',
}

// ── helpers ───────────────────────────────────────────────────────────

let _seq = 0
function genId(prefix: string): string {
  _seq += 1
  return `${prefix}_${Date.now().toString(36)}${_seq.toString(36)}${Math.random()
    .toString(36)
    .slice(2, 6)}`
}

function formatData(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

interface Draft {
  texto: string
  tipo: ObservacaoTipo
  visivelCliente: boolean
  fotosIds: string[]
}

// ── formulário (add/edit) ─────────────────────────────────────────────

interface ObsFormProps {
  initial?: ObservacaoProfissional
  fotos: EvidenciaFoto[]
  submitLabel: string
  onSubmit: (draft: Draft) => void
  onCancel: () => void
}

function ObsForm({ initial, fotos, submitLabel, onSubmit, onCancel }: ObsFormProps) {
  const [texto, setTexto] = useState(initial?.texto ?? '')
  const [tipo, setTipo] = useState<ObservacaoTipo>(initial?.tipo ?? 'geral')
  const [visivel, setVisivel] = useState(initial?.visivelCliente ?? false)
  const [fotosIds, setFotosIds] = useState<string[]>(initial?.fotosIds ?? [])
  const [error, setError] = useState<string | null>(null)

  function toggleFoto(id: string) {
    setFotosIds((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    )
  }

  function submit() {
    const t = texto.trim()
    if (!t) {
      setError('Escreva a observação antes de salvar.')
      return
    }
    // mantém só fotos que ainda existem
    const validIds = fotosIds.filter((id) => fotos.some((f) => f.id === id))
    onSubmit({ texto: t, tipo, visivelCliente: visivel, fotosIds: validIds })
  }

  const restante = MAX_TEXTO - texto.length

  return (
    <div className="clx-card" style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 14 }}>
      {error && (
        <div role="alert" className="error-banner" style={{ margin: 0 }}>
          <IconAlertCircle size={15} />
          {error}
        </div>
      )}

      <div className="form-field">
        <label htmlFor="obs-tipo">Tipo</label>
        <select
          id="obs-tipo"
          value={tipo}
          onChange={(e) => setTipo(e.target.value as ObservacaoTipo)}
        >
          {TIPOS.map((t) => (
            <option key={t} value={t}>
              {TIPO_LABELS[t]}
            </option>
          ))}
        </select>
      </div>

      <div className="form-field">
        <label htmlFor="obs-texto">
          Observação <span className="req">*</span>
        </label>
        <textarea
          id="obs-texto"
          rows={4}
          maxLength={MAX_TEXTO}
          placeholder="Descreva o que foi observado…"
          value={texto}
          onChange={(e) => {
            setTexto(e.target.value)
            if (error) setError(null)
          }}
          className={error ? 'err' : undefined}
          aria-invalid={error ? true : undefined}
        />
        <span
          style={{
            alignSelf: 'flex-end',
            fontSize: '0.7rem',
            color: restante <= 50 ? 'var(--clx-warning)' : 'var(--clx-ink-3)',
          }}
        >
          {texto.length}/{MAX_TEXTO}
        </span>
      </div>

      {/* Toggle Visível ao cliente (verde) */}
      <label style={{ display: 'inline-flex', alignItems: 'center', gap: 10, cursor: 'pointer', alignSelf: 'flex-start' }}>
        <span className="toggle">
          <input
            type="checkbox"
            checked={visivel}
            onChange={(e) => setVisivel(e.target.checked)}
          />
          <span className="toggle-track" aria-hidden="true" />
        </span>
        <span style={{ fontSize: '0.875rem', color: 'var(--clx-ink-2)' }}>
          Visível ao cliente
        </span>
      </label>

      {/* Vincular fotos */}
      {fotos.length > 0 && (
        <div className="form-field">
          <label>Vincular fotos (opcional)</label>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {fotos.map((f) => {
              const sel = fotosIds.includes(f.id)
              return (
                <button
                  key={f.id}
                  type="button"
                  onClick={() => toggleFoto(f.id)}
                  aria-pressed={sel}
                  aria-label={`${sel ? 'Desvincular' : 'Vincular'} foto${f.legenda ? `: ${f.legenda}` : ''}`}
                  title={f.legenda ?? 'Evidência'}
                  style={{
                    position: 'relative',
                    width: 56,
                    height: 56,
                    minWidth: 44,
                    minHeight: 44,
                    borderRadius: 'var(--clx-r-md)',
                    overflow: 'hidden',
                    border: sel
                      ? '2px solid var(--clx-primary)'
                      : '2px solid var(--clx-line)',
                    padding: 0,
                  }}
                >
                  <img
                    src={f.url}
                    alt={f.legenda ?? 'Evidência do serviço'}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  />
                  {sel && (
                    <span
                      aria-hidden="true"
                      style={{
                        position: 'absolute',
                        inset: 0,
                        background: 'rgba(0,194,184,0.30)',
                        display: 'grid',
                        placeItems: 'center',
                        color: '#fff',
                      }}
                    >
                      <IconCheck size={18} />
                    </span>
                  )}
                </button>
              )
            })}
          </div>
        </div>
      )}

      <div style={{ display: 'flex', gap: 8 }}>
        <button type="button" className="clx-btn clx-btn-ghost" style={{ flex: 1 }} onClick={onCancel}>
          Cancelar
        </button>
        <button type="button" className="clx-btn clx-btn-primary" style={{ flex: 2 }} onClick={submit}>
          <IconCheck size={15} />
          {submitLabel}
        </button>
      </div>
    </div>
  )
}

// ── componente ────────────────────────────────────────────────────────

export default function ObservacoesProfissionalSection({
  observacoes,
  onChange,
  fotos = [],
  criadoPor,
}: ObservacoesProfissionalSectionProps) {
  const [adding, setAdding] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [confirmId, setConfirmId] = useState<string | null>(null)

  const ordenadas = [...observacoes].sort((a, b) => b.criadoEm.localeCompare(a.criadoEm))

  function handleAdd(draft: Draft) {
    const nova: ObservacaoProfissional = {
      id: genId('obs'),
      texto: draft.texto,
      visivelCliente: draft.visivelCliente,
      tipo: draft.tipo,
      criadoPor,
      criadoEm: new Date().toISOString(),
      fotosIds: draft.fotosIds.length > 0 ? draft.fotosIds : undefined,
    }
    onChange([nova, ...observacoes])
    setAdding(false)
  }

  function handleEditSave(id: string, draft: Draft) {
    onChange(
      observacoes.map((o) =>
        o.id === id
          ? {
              ...o,
              texto: draft.texto,
              tipo: draft.tipo,
              visivelCliente: draft.visivelCliente,
              fotosIds: draft.fotosIds.length > 0 ? draft.fotosIds : undefined,
            }
          : o,
      ),
    )
    setEditingId(null)
  }

  function handleDelete(id: string) {
    onChange(observacoes.filter((o) => o.id !== id))
    setConfirmId(null)
  }

  return (
    <section aria-labelledby="obs-titulo">
      <div style={headerRowStyle}>
        <div>
          <h2 id="obs-titulo" style={titleStyle}>
            Observações do profissional
          </h2>
          <p style={subtitleStyle}>
            Pontos, limitações e recomendações registrados durante o serviço.
          </p>
        </div>
        {!adding && (
          <button
            type="button"
            className="clx-btn clx-btn-accent clx-btn-sm"
            style={{ minHeight: 44 }}
            onClick={() => {
              setAdding(true)
              setEditingId(null)
            }}
          >
            <IconPlus size={15} />
            Adicionar
          </button>
        )}
      </div>

      {adding && (
        <div style={{ marginTop: 12 }}>
          <ObsForm
            fotos={fotos}
            submitLabel="Salvar observação"
            onSubmit={handleAdd}
            onCancel={() => setAdding(false)}
          />
        </div>
      )}

      {ordenadas.length === 0 && !adding ? (
        <div className="empty-state">
          <IconEdit size={30} />
          <h4>Nenhuma observação registrada</h4>
          <p>Adicione observações sobre pontos encontrados, limitações ou recomendações.</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 12 }}>
          {ordenadas.map((o) => {
            if (editingId === o.id) {
              return (
                <ObsForm
                  key={o.id}
                  initial={o}
                  fotos={fotos}
                  submitLabel="Salvar alterações"
                  onSubmit={(draft) => handleEditSave(o.id, draft)}
                  onCancel={() => setEditingId(null)}
                />
              )
            }

            const linkadas = (o.fotosIds ?? [])
              .map((id) => fotos.find((f) => f.id === id))
              .filter((f): f is EvidenciaFoto => Boolean(f))
            const confirming = confirmId === o.id

            return (
              <div key={o.id} className="clx-card" style={{ padding: 14 }}>
                <div style={cardTopStyle}>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
                    <span className="clx-chip">{o.tipo ? TIPO_LABELS[o.tipo] : 'Observação geral'}</span>
                    {o.visivelCliente && (
                      <span className="clx-chip clx-chip-success">Visível ao cliente</span>
                    )}
                  </div>
                  <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                    <button
                      type="button"
                      className="icon-btn"
                      aria-label="Editar observação"
                      title="Editar"
                      onClick={() => {
                        setEditingId(o.id)
                        setAdding(false)
                        setConfirmId(null)
                      }}
                      style={iconBtn44}
                    >
                      <IconEdit size={16} />
                    </button>
                    <button
                      type="button"
                      className="icon-btn"
                      aria-label="Excluir observação"
                      title="Excluir"
                      onClick={() => setConfirmId(o.id)}
                      style={{ ...iconBtn44, color: 'var(--clx-error)' }}
                    >
                      <IconTrash size={16} />
                    </button>
                  </div>
                </div>

                <p style={textoStyle}>{o.texto}</p>

                {linkadas.length > 0 && (
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
                    {linkadas.map((f) => (
                      <span key={f.id} style={fotoChipStyle} title={f.legenda ?? 'Evidência'}>
                        <img
                          src={f.url}
                          alt={f.legenda ?? 'Evidência do serviço'}
                          style={{ width: 22, height: 22, objectFit: 'cover', borderRadius: 4 }}
                        />
                        <span style={chipEllipsis}>{f.legenda ?? 'Evidência'}</span>
                      </span>
                    ))}
                  </div>
                )}

                <div style={cardFooterStyle}>
                  <span>
                    {o.criadoPor ? `${o.criadoPor} · ` : ''}
                    {formatData(o.criadoEm)}
                  </span>
                </div>

                {confirming && (
                  <div role="group" aria-label="Confirmar exclusão" style={confirmRowStyle}>
                    <span style={{ flex: 1, fontSize: '0.8rem', color: 'var(--clx-ink-2)' }}>
                      Excluir esta observação?
                    </span>
                    <button
                      type="button"
                      className="clx-btn clx-btn-ghost clx-btn-sm"
                      style={{ minHeight: 40 }}
                      onClick={() => setConfirmId(null)}
                    >
                      Cancelar
                    </button>
                    <button
                      type="button"
                      className="clx-btn clx-btn-danger clx-btn-sm"
                      style={{ minHeight: 40 }}
                      onClick={() => handleDelete(o.id)}
                    >
                      <IconTrash size={14} />
                      Excluir
                    </button>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </section>
  )
}

// ── estilos ───────────────────────────────────────────────────────────

const headerRowStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'flex-start',
  justifyContent: 'space-between',
  gap: 12,
  flexWrap: 'wrap',
}
const titleStyle: React.CSSProperties = {
  fontFamily: 'var(--clx-font-display)',
  fontWeight: 700,
  fontSize: '1.05rem',
  color: 'var(--clx-ink)',
  letterSpacing: '-0.01em',
}
const subtitleStyle: React.CSSProperties = {
  fontSize: '0.82rem',
  color: 'var(--clx-ink-3)',
  marginTop: 4,
  lineHeight: 1.45,
}
const cardTopStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'flex-start',
  justifyContent: 'space-between',
  gap: 8,
  marginBottom: 8,
}
const textoStyle: React.CSSProperties = {
  fontSize: '0.9rem',
  color: 'var(--clx-ink)',
  lineHeight: 1.5,
  whiteSpace: 'pre-wrap',
  wordBreak: 'break-word',
}
const cardFooterStyle: React.CSSProperties = {
  marginTop: 10,
  fontSize: '0.72rem',
  color: 'var(--clx-ink-3)',
}
const fotoChipStyle: React.CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 6,
  maxWidth: 160,
  padding: '3px 8px 3px 3px',
  borderRadius: 'var(--clx-r-pill)',
  border: '1px solid var(--clx-line-2)',
  background: 'var(--clx-bg-2)',
  fontSize: '0.72rem',
  color: 'var(--clx-ink-2)',
}
const chipEllipsis: React.CSSProperties = {
  overflow: 'hidden',
  textOverflow: 'ellipsis',
  whiteSpace: 'nowrap',
}
const iconBtn44: React.CSSProperties = {
  minWidth: 44,
  minHeight: 44,
  display: 'grid',
  placeItems: 'center',
}
const confirmRowStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  marginTop: 12,
  paddingTop: 12,
  borderTop: '1px solid var(--clx-line)',
  flexWrap: 'wrap',
}
