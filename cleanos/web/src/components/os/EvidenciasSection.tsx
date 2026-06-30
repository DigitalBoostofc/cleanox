/**
 * EvidenciasSection — Evidências do serviço (fotos antes/durante/depois) da OS.
 *
 * Componente 100% standalone e CONTROLADO: o estado das fotos vive no pai e chega
 * por `fotos`; toda mutação é propagada por `onChange`. Não há backend — o upload é
 * mockado com URL.createObjectURL. As fotos podem ser vinculadas opcionalmente a um
 * item do checklist, a uma observação do profissional ou a um serviço adicional.
 */

import { useEffect, useRef, useState, type ChangeEvent } from 'react'
import type {
  ChecklistExecItem,
  EvidenciaFoto,
  FaseFoto,
  ObservacaoProfissional,
  ServicoAdicionalOS,
} from '../../lib/servicos/types'
import { faseFotoLabel } from '../../lib/servicos/labels'
import { IconPlus, IconTrash, IconAlertCircle, IconX, IconCheck } from '../ui/Icon'

export interface EvidenciasSectionProps {
  fotos: EvidenciaFoto[]
  onChange: (fotos: EvidenciaFoto[]) => void
  checklistItems?: ChecklistExecItem[]
  adicionais?: ServicoAdicionalOS[]
  observacoes?: ObservacaoProfissional[]
  enviadoPor?: string
}

// ── constantes ────────────────────────────────────────────────────────
const FASES: FaseFoto[] = ['antes', 'durante', 'depois']
const MAX_SIZE_MB = 5

// ── helpers ───────────────────────────────────────────────────────────

let _seq = 0
/** ID único mock (o PB geraria no servidor). */
function genId(prefix: string): string {
  _seq += 1
  return `${prefix}_${Date.now().toString(36)}${_seq.toString(36)}${Math.random()
    .toString(36)
    .slice(2, 6)}`
}

type VinculoKind = 'checklist' | 'obs' | 'adicional'
interface Vinculo {
  kind: VinculoKind
  id: string
}

function getVinculo(f: EvidenciaFoto): Vinculo | null {
  if (f.checklistItemId) return { kind: 'checklist', id: f.checklistItemId }
  if (f.observacaoId) return { kind: 'obs', id: f.observacaoId }
  if (f.adicionalId) return { kind: 'adicional', id: f.adicionalId }
  return null
}

/** Devolve uma cópia da foto com exatamente um (ou nenhum) vínculo setado. */
function applyVinculo(f: EvidenciaFoto, v: Vinculo | null): EvidenciaFoto {
  const next: EvidenciaFoto = {
    ...f,
    checklistItemId: undefined,
    observacaoId: undefined,
    adicionalId: undefined,
  }
  if (!v) return next
  if (v.kind === 'checklist') next.checklistItemId = v.id
  else if (v.kind === 'obs') next.observacaoId = v.id
  else next.adicionalId = v.id
  return next
}

function parseVinculo(raw: string): Vinculo | null {
  const idx = raw.indexOf(':')
  if (idx === -1) return null
  const kind = raw.slice(0, idx)
  const id = raw.slice(idx + 1)
  if (!id) return null
  if (kind === 'checklist' || kind === 'obs' || kind === 'adicional') {
    return { kind, id }
  }
  return null
}

function truncate(s: string, n = 42): string {
  const t = s.trim()
  return t.length > n ? `${t.slice(0, n - 1)}…` : t
}

// ── componente ────────────────────────────────────────────────────────

export default function EvidenciasSection({
  fotos,
  onChange,
  checklistItems = [],
  adicionais = [],
  observacoes = [],
  enviadoPor,
}: EvidenciasSectionProps) {
  // URLs criadas por este componente (para revogar no remover e evitar leak).
  const createdUrls = useRef<Set<string>>(new Set())
  const [warning, setWarning] = useState<string | null>(null)
  const [confirmId, setConfirmId] = useState<string | null>(null)

  // Revoga no unmount qualquer blob URL ainda viva (evita memory leak).
  useEffect(() => {
    const urls = createdUrls.current
    return () => {
      for (const u of urls) URL.revokeObjectURL(u)
    }
  }, [])

  const linkable =
    checklistItems.length > 0 || observacoes.length > 0 || adicionais.length > 0

  // Mapa id→rótulo para exibir o vínculo como chip legível.
  function vinculoLabel(v: Vinculo): string {
    if (v.kind === 'checklist') {
      const it = checklistItems.find((c) => c.id === v.id)
      return it ? `Checklist: ${truncate(it.titulo, 28)}` : 'Item do checklist'
    }
    if (v.kind === 'obs') {
      const o = observacoes.find((x) => x.id === v.id)
      return o ? `Observação: ${truncate(o.texto, 28)}` : 'Observação'
    }
    const a = adicionais.find((x) => x.id === v.id)
    return a ? `Adicional: ${truncate(a.nome, 28)}` : 'Adicional'
  }

  function handleFiles(fase: FaseFoto, e: ChangeEvent<HTMLInputElement>) {
    const files = e.target.files
    if (!files || files.length === 0) return

    const novas: EvidenciaFoto[] = []
    const grandes: string[] = []

    for (const file of Array.from(files)) {
      if (!file.type.startsWith('image/')) continue
      if (file.size > MAX_SIZE_MB * 1024 * 1024) grandes.push(file.name)
      const url = URL.createObjectURL(file)
      createdUrls.current.add(url)
      novas.push({
        id: genId('ev'),
        url,
        fase,
        legenda: file.name.replace(/\.[^.]+$/, '') || undefined,
        criadoEm: new Date().toISOString(),
        enviadoPor,
      })
    }

    if (novas.length > 0) onChange([...fotos, ...novas])
    setWarning(
      grandes.length > 0
        ? `${grandes.length} arquivo(s) acima de ${MAX_SIZE_MB} MB (${grandes
            .map((n) => truncate(n, 20))
            .join(', ')}). Foram adicionados, mas considere otimizar antes de enviar.`
        : null,
    )
    // permite reescolher o mesmo arquivo em seguida
    e.target.value = ''
  }

  function handleRemove(id: string) {
    const f = fotos.find((x) => x.id === id)
    if (f && f.url.startsWith('blob:') && createdUrls.current.has(f.url)) {
      URL.revokeObjectURL(f.url)
      createdUrls.current.delete(f.url)
    }
    onChange(fotos.filter((x) => x.id !== id))
    setConfirmId(null)
  }

  function handleLegenda(id: string, value: string) {
    onChange(
      fotos.map((f) => (f.id === id ? { ...f, legenda: value || undefined } : f)),
    )
  }

  function handleVinculo(id: string, raw: string) {
    const v = raw ? parseVinculo(raw) : null
    onChange(fotos.map((f) => (f.id === id ? applyVinculo(f, v) : f)))
  }

  return (
    <section aria-labelledby="evidencias-titulo">
      <h2 id="evidencias-titulo" style={titleStyle}>
        Evidências do serviço
      </h2>
      <p style={subtitleStyle}>
        Registre fotos do antes, durante e depois. Toque em uma foto para legendar
        ou vincular a um item do serviço.
      </p>

      {warning && (
        <div
          role="alert"
          className="error-banner"
          style={{
            marginTop: 12,
            background: 'rgba(245,158,11,0.07)',
            borderColor: 'rgba(245,158,11,0.30)',
            color: 'var(--clx-warning)',
          }}
        >
          <IconAlertCircle size={15} />
          <span style={{ flex: 1 }}>{warning}</span>
          <button
            type="button"
            className="icon-btn"
            aria-label="Fechar aviso"
            onClick={() => setWarning(null)}
            style={{ color: 'inherit' }}
          >
            <IconX size={14} />
          </button>
        </div>
      )}

      {FASES.map((fase) => {
        const doGrupo = fotos.filter((f) => f.fase === fase)
        return (
          <div key={fase} style={{ marginTop: 18 }}>
            <div style={groupHeaderStyle}>
              <span style={groupTitleStyle}>
                {faseFotoLabel(fase)}
                {doGrupo.length > 0 && (
                  <span className="clx-chip clx-chip-primary" style={{ marginLeft: 8 }}>
                    {doGrupo.length}
                  </span>
                )}
              </span>

              <label
                className="clx-btn clx-btn-ghost clx-btn-sm"
                style={{ cursor: 'pointer', minHeight: 44 }}
              >
                <IconPlus size={15} />
                Adicionar foto
                <input
                  type="file"
                  accept="image/*"
                  multiple
                  onChange={(e) => handleFiles(fase, e)}
                  style={{ display: 'none' }}
                  aria-label={`Adicionar fotos da fase ${faseFotoLabel(fase)}`}
                />
              </label>
            </div>

            {doGrupo.length === 0 ? (
              <div style={emptyGroupStyle}>Nenhuma foto de {faseFotoLabel(fase).toLowerCase()}</div>
            ) : (
              <div style={gridStyle}>
                {doGrupo.map((foto) => {
                  const v = getVinculo(foto)
                  const confirming = confirmId === foto.id
                  return (
                    <div key={foto.id} className="clx-card" style={cardStyle}>
                      <div style={thumbWrapStyle}>
                        <img
                          src={foto.url}
                          alt={
                            foto.legenda
                              ? `Evidência (${faseFotoLabel(foto.fase)}): ${foto.legenda}`
                              : `Evidência do serviço — ${faseFotoLabel(foto.fase)}`
                          }
                          style={thumbStyle}
                          loading="lazy"
                        />
                        {!confirming ? (
                          <button
                            type="button"
                            aria-label="Remover foto"
                            title="Remover foto"
                            onClick={() => setConfirmId(foto.id)}
                            style={removeBtnStyle}
                          >
                            <IconTrash size={15} />
                          </button>
                        ) : (
                          <div style={confirmBarStyle} role="group" aria-label="Confirmar remoção">
                            <span style={{ flex: 1, fontSize: '0.72rem', fontWeight: 600 }}>
                              Remover?
                            </span>
                            <button
                              type="button"
                              aria-label="Confirmar remoção"
                              onClick={() => handleRemove(foto.id)}
                              style={{ ...confirmIconBtn, color: '#fff', background: 'var(--clx-error)' }}
                            >
                              <IconCheck size={14} />
                            </button>
                            <button
                              type="button"
                              aria-label="Cancelar remoção"
                              onClick={() => setConfirmId(null)}
                              style={{ ...confirmIconBtn, color: 'var(--clx-ink-2)', background: 'var(--clx-bg-3)' }}
                            >
                              <IconX size={14} />
                            </button>
                          </div>
                        )}
                      </div>

                      <div style={{ padding: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
                        <div className="form-field">
                          <label htmlFor={`leg-${foto.id}`} style={{ fontSize: '0.65rem' }}>
                            Legenda
                          </label>
                          <input
                            id={`leg-${foto.id}`}
                            type="text"
                            placeholder="Descreva a foto…"
                            value={foto.legenda ?? ''}
                            onChange={(e) => handleLegenda(foto.id, e.target.value)}
                            style={{ fontSize: '0.82rem' }}
                          />
                        </div>

                        {linkable && (
                          <div className="form-field">
                            <label htmlFor={`vinc-${foto.id}`} style={{ fontSize: '0.65rem' }}>
                              Vincular a
                            </label>
                            <select
                              id={`vinc-${foto.id}`}
                              value={v ? `${v.kind}:${v.id}` : ''}
                              onChange={(e) => handleVinculo(foto.id, e.target.value)}
                              style={{ fontSize: '0.82rem' }}
                            >
                              <option value="">Sem vínculo</option>
                              {checklistItems.length > 0 && (
                                <optgroup label="Itens do checklist">
                                  {checklistItems.map((c) => (
                                    <option key={c.id} value={`checklist:${c.id}`}>
                                      {truncate(c.titulo, 38)}
                                    </option>
                                  ))}
                                </optgroup>
                              )}
                              {observacoes.length > 0 && (
                                <optgroup label="Observações">
                                  {observacoes.map((o) => (
                                    <option key={o.id} value={`obs:${o.id}`}>
                                      {truncate(o.texto, 38)}
                                    </option>
                                  ))}
                                </optgroup>
                              )}
                              {adicionais.length > 0 && (
                                <optgroup label="Serviços adicionais">
                                  {adicionais.map((a) => (
                                    <option key={a.id} value={`adicional:${a.id}`}>
                                      {truncate(a.nome, 38)}
                                    </option>
                                  ))}
                                </optgroup>
                              )}
                            </select>
                          </div>
                        )}

                        {v && (
                          <span
                            className="clx-chip clx-chip-primary"
                            style={{ alignSelf: 'flex-start', maxWidth: '100%' }}
                            title={vinculoLabel(v)}
                          >
                            <span style={chipEllipsis}>{vinculoLabel(v)}</span>
                          </span>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        )
      })}
    </section>
  )
}

// ── estilos ───────────────────────────────────────────────────────────

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
const groupHeaderStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 12,
  marginBottom: 10,
  flexWrap: 'wrap',
}
const groupTitleStyle: React.CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  fontFamily: 'var(--clx-font-display)',
  fontWeight: 700,
  fontSize: '0.9rem',
  color: 'var(--clx-ink-2)',
}
const emptyGroupStyle: React.CSSProperties = {
  padding: '18px 14px',
  textAlign: 'center',
  fontSize: '0.8rem',
  color: 'var(--clx-ink-3)',
  background: 'var(--clx-bg-2)',
  border: '1px dashed var(--clx-line-2)',
  borderRadius: 'var(--clx-r-md)',
}
const gridStyle: React.CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))',
  gap: 12,
}
const cardStyle: React.CSSProperties = {
  overflow: 'hidden',
  display: 'flex',
  flexDirection: 'column',
}
const thumbWrapStyle: React.CSSProperties = {
  position: 'relative',
  width: '100%',
  aspectRatio: '4 / 3',
  background: 'var(--clx-bg-3)',
}
const thumbStyle: React.CSSProperties = {
  width: '100%',
  height: '100%',
  objectFit: 'cover',
}
const removeBtnStyle: React.CSSProperties = {
  position: 'absolute',
  top: 6,
  right: 6,
  width: 44,
  height: 44,
  display: 'grid',
  placeItems: 'center',
  borderRadius: 'var(--clx-r-md)',
  background: 'rgba(0,0,0,0.55)',
  color: '#fff',
}
const confirmBarStyle: React.CSSProperties = {
  position: 'absolute',
  left: 6,
  right: 6,
  bottom: 6,
  display: 'flex',
  alignItems: 'center',
  gap: 6,
  padding: '6px 8px',
  borderRadius: 'var(--clx-r-md)',
  background: 'rgba(0,0,0,0.72)',
  color: '#fff',
}
const confirmIconBtn: React.CSSProperties = {
  width: 36,
  height: 36,
  display: 'grid',
  placeItems: 'center',
  borderRadius: 'var(--clx-r-sm, 8px)',
  flexShrink: 0,
}
const chipEllipsis: React.CSSProperties = {
  overflow: 'hidden',
  textOverflow: 'ellipsis',
  whiteSpace: 'nowrap',
  display: 'block',
}
