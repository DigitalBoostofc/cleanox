/**
 * EvidenciasSection — Evidências do serviço (fotos antes/durante/depois) da OS.
 *
 * Componente CONTROLADO com SIDE-EFFECTS de rede: a lista de fotos vive no pai
 * (`fotos` + `onChange`), mas as mutações são persistidas DE VERDADE no PocketBase
 * pela coleção `os_evidencias` (ver ../../lib/os/osStore):
 *   - upload  → createEvidencia (FormData com o arquivo). O preview local
 *     (objectURL) aparece OTIMISTA enquanto sobe; ao concluir, é trocado pela URL
 *     real do PB; em erro, o item é removido e o usuário avisado.
 *   - legenda → updateEvidencia (debounce).
 *   - vínculo → updateEvidencia (imediato; seta um e limpa os outros).
 *   - remover → deleteEvidencia.
 *
 * `enviado_por` é preenchido com o usuário atual (useAuth). As fotos podem ser
 * vinculadas opcionalmente a um item do checklist, observação ou serviço adicional.
 */

import { useEffect, useRef, useState, type ChangeEvent } from 'react'
import { useAuth } from '../../contexts/AuthContext'
import { userDisplayName } from '../../lib/collections'
import {
  createEvidencia,
  updateEvidencia,
  deleteEvidencia,
  describeOSError,
} from '../../lib/os/osStore'
import type {
  ChecklistExecItem,
  EvidenciaFoto,
  FaseFoto,
  ObservacaoProfissional,
  ServicoAdicionalOS,
} from '../../lib/servicos/types'
import { faseFotoLabel } from '../../lib/servicos/labels'
import { IconPlus, IconTrash, IconAlertCircle, IconX, IconCheck } from '../ui/Icon'
import { Spinner } from '../ui/Spinner'

export interface EvidenciasSectionProps {
  /** OS dona das evidências (obrigatória para persistir). */
  osId: string
  fotos: EvidenciaFoto[]
  /** Aceita updater funcional (compatível com o setState do pai) para updates sem corrida. */
  onChange: (
    updater: EvidenciaFoto[] | ((prev: EvidenciaFoto[]) => EvidenciaFoto[]),
  ) => void
  checklistItems?: ChecklistExecItem[]
  adicionais?: ServicoAdicionalOS[]
  observacoes?: ObservacaoProfissional[]
  /** Nome de exibição para o preview otimista; cai para o nome do usuário logado. */
  enviadoPor?: string
  /** Desabilita uploads (ex.: OS ainda carregando ou modo demonstração). */
  disabled?: boolean
  /** Notificação opcional ao pai (toast). */
  onNotify?: (text: string, type: 'success' | 'error' | 'info') => void
}

// ── constantes ────────────────────────────────────────────────────────
const FASES: FaseFoto[] = ['antes', 'durante', 'depois']
const MAX_SIZE_MB = 5
const LEGENDA_DEBOUNCE_MS = 700
/** Prefixo dos IDs temporários (otimistas) ainda não persistidos no PB. */
const TMP_PREFIX = 'tmp_'

// ── helpers ───────────────────────────────────────────────────────────

let _seq = 0
/** ID temporário local (substituído pelo ID real do PB ao concluir o upload). */
function genTmpId(): string {
  _seq += 1
  return `${TMP_PREFIX}${Date.now().toString(36)}${_seq.toString(36)}${Math.random()
    .toString(36)
    .slice(2, 6)}`
}

function isTmp(id: string): boolean {
  return id.startsWith(TMP_PREFIX)
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

/** Converte um vínculo de domínio nos campos PB (string vazia limpa o campo). */
function vinculoToPatch(v: Vinculo | null) {
  return {
    checklist_item_id: v?.kind === 'checklist' ? v.id : '',
    observacao_id: v?.kind === 'obs' ? v.id : '',
    adicional_id: v?.kind === 'adicional' ? v.id : '',
  }
}

function truncate(s: string, n = 42): string {
  const t = s.trim()
  return t.length > n ? `${t.slice(0, n - 1)}…` : t
}

// ── componente ────────────────────────────────────────────────────────

export default function EvidenciasSection({
  osId,
  fotos,
  onChange,
  checklistItems = [],
  adicionais = [],
  observacoes = [],
  enviadoPor,
  disabled = false,
  onNotify,
}: EvidenciasSectionProps) {
  const { user } = useAuth()

  // URLs blob: criadas por este componente (para revogar e evitar memory leak).
  const createdUrls = useRef<Set<string>>(new Set())
  // Timers de debounce de legenda por id.
  const legendaTimers = useRef<Record<string, ReturnType<typeof setTimeout>>>({})

  const [warning, setWarning] = useState<string | null>(null)
  const [confirmId, setConfirmId] = useState<string | null>(null)
  // IDs em upload (otimistas) e em remoção — para overlays/disable por card.
  const [pending, setPending] = useState<Set<string>>(new Set())
  const [deletingId, setDeletingId] = useState<string | null>(null)

  // Revoga no unmount qualquer blob URL ainda viva e limpa timers pendentes.
  useEffect(() => {
    const urls = createdUrls.current
    const timers = legendaTimers.current
    return () => {
      for (const u of urls) URL.revokeObjectURL(u)
      for (const t of Object.values(timers)) clearTimeout(t)
    }
  }, [])

  const displayName = enviadoPor || (user ? userDisplayName(user) : undefined)
  const canUpload = !disabled && !!osId

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

  // ── pending helpers ──
  function markPending(id: string, on: boolean) {
    setPending((prev) => {
      const next = new Set(prev)
      if (on) next.add(id)
      else next.delete(id)
      return next
    })
  }

  function revoke(url: string) {
    if (url.startsWith('blob:') && createdUrls.current.has(url)) {
      URL.revokeObjectURL(url)
      createdUrls.current.delete(url)
    }
  }

  function notifyError(msg: string) {
    setWarning(msg)
    onNotify?.(msg, 'error')
  }

  // ── upload (otimista) ──
  function handleFiles(fase: FaseFoto, e: ChangeEvent<HTMLInputElement>) {
    const files = e.target.files
    if (!files || files.length === 0) return
    // permite reescolher o mesmo arquivo em seguida
    e.target.value = ''

    if (!canUpload) {
      setWarning('Não é possível enviar fotos agora.')
      return
    }

    const grandes: string[] = []

    for (const file of Array.from(files)) {
      if (!file.type.startsWith('image/')) continue
      if (file.size > MAX_SIZE_MB * 1024 * 1024) {
        // O PB rejeita arquivos acima do limite; nem tenta subir.
        grandes.push(file.name)
        continue
      }

      const tmpId = genTmpId()
      const localUrl = URL.createObjectURL(file)
      createdUrls.current.add(localUrl)
      const legenda = file.name.replace(/\.[^.]+$/, '') || undefined

      // 1) Preview otimista imediato.
      const tmpFoto: EvidenciaFoto = {
        id: tmpId,
        url: localUrl,
        fase,
        legenda,
        criadoEm: new Date().toISOString(),
        enviadoPor: displayName,
      }
      onChange((prev) => [...prev, tmpFoto])
      markPending(tmpId, true)

      // 2) Upload real ao PB.
      createEvidencia(osId, {
        file,
        fase,
        legenda,
        enviadoPorId: user?.id,
      })
        .then((real) => {
          // Troca o item temporário pelo registro real (id + URL do PB).
          onChange((prev) => prev.map((f) => (f.id === tmpId ? real : f)))
          revoke(localUrl)
          markPending(tmpId, false)
        })
        .catch((err) => {
          // Remove o item otimista e avisa.
          onChange((prev) => prev.filter((f) => f.id !== tmpId))
          revoke(localUrl)
          markPending(tmpId, false)
          const { message } = describeOSError(err)
          notifyError(`Falha ao enviar a foto: ${message}`)
        })
    }

    setWarning(
      grandes.length > 0
        ? `${grandes.length} arquivo(s) acima de ${MAX_SIZE_MB} MB não enviado(s): ${grandes
            .map((n) => truncate(n, 20))
            .join(', ')}. Otimize e tente de novo.`
        : null,
    )
  }

  // ── remover ──
  async function handleRemove(id: string) {
    const f = fotos.find((x) => x.id === id)
    if (!f) {
      setConfirmId(null)
      return
    }
    // Itens temporários (upload em curso) não existem no PB — só remove local.
    if (isTmp(id)) {
      revoke(f.url)
      onChange((prev) => prev.filter((x) => x.id !== id))
      setConfirmId(null)
      return
    }

    setDeletingId(id)
    try {
      await deleteEvidencia(id)
      revoke(f.url)
      onChange((prev) => prev.filter((x) => x.id !== id))
      setConfirmId(null)
    } catch (err) {
      const { message } = describeOSError(err)
      notifyError(`Não foi possível remover a foto: ${message}`)
    } finally {
      setDeletingId(null)
    }
  }

  // ── legenda (debounce) ──
  function handleLegenda(id: string, value: string) {
    const legenda = value || undefined
    // Atualização local imediata (UI responsiva).
    onChange((prev) => prev.map((f) => (f.id === id ? { ...f, legenda } : f)))
    if (isTmp(id)) return // ainda subindo — persiste depois via vínculo/recarregar

    const timers = legendaTimers.current
    if (timers[id]) clearTimeout(timers[id])
    timers[id] = setTimeout(() => {
      delete timers[id]
      updateEvidencia(id, { legenda: value }).catch((err) => {
        const { message } = describeOSError(err)
        notifyError(`Não foi possível salvar a legenda: ${message}`)
      })
    }, LEGENDA_DEBOUNCE_MS)
  }

  // ── vínculo (imediato) ──
  function handleVinculo(id: string, raw: string) {
    const v = raw ? parseVinculo(raw) : null
    onChange((prev) => prev.map((f) => (f.id === id ? applyVinculo(f, v) : f)))
    if (isTmp(id)) return
    updateEvidencia(id, vinculoToPatch(v)).catch((err) => {
      const { message } = describeOSError(err)
      notifyError(`Não foi possível salvar o vínculo: ${message}`)
    })
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

      {disabled && (
        <div style={{ ...emptyGroupStyle, marginTop: 12 }}>
          As fotos ficam disponíveis após a OS carregar.
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

              {canUpload && (
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
              )}
            </div>

            {doGrupo.length === 0 ? (
              <div style={emptyGroupStyle}>Nenhuma foto de {faseFotoLabel(fase).toLowerCase()}</div>
            ) : (
              <div style={gridStyle}>
                {doGrupo.map((foto) => {
                  const v = getVinculo(foto)
                  const confirming = confirmId === foto.id
                  const uploading = pending.has(foto.id)
                  const removing = deletingId === foto.id
                  const busy = uploading || removing
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

                        {busy && (
                          <div style={busyOverlayStyle} role="status">
                            <Spinner size={20} />
                            <span style={{ fontSize: '0.72rem', fontWeight: 600 }}>
                              {uploading ? 'Enviando…' : 'Removendo…'}
                            </span>
                          </div>
                        )}

                        {!busy && !confirming && (
                          <button
                            type="button"
                            aria-label="Remover foto"
                            title="Remover foto"
                            onClick={() => setConfirmId(foto.id)}
                            style={removeBtnStyle}
                          >
                            <IconTrash size={15} />
                          </button>
                        )}
                        {!busy && confirming && (
                          <div style={confirmBarStyle} role="group" aria-label="Confirmar remoção">
                            <span style={{ flex: 1, fontSize: '0.72rem', fontWeight: 600 }}>
                              Remover?
                            </span>
                            <button
                              type="button"
                              aria-label="Confirmar remoção"
                              onClick={() => { void handleRemove(foto.id) }}
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
                            disabled={busy}
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
                              disabled={busy}
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
const busyOverlayStyle: React.CSSProperties = {
  position: 'absolute',
  inset: 0,
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  gap: 6,
  background: 'rgba(0,0,0,0.55)',
  color: '#fff',
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
