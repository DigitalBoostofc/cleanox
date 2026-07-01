import { useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate, useParams, useLocation } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import {
  type OSStatus,
  osStatusLabel,
  formatDateTime,
  formatCurrency,
  userDisplayName,
} from '../../lib/collections'
import {
  loadOSExec,
  saveOSExecPatch,
  listEvidencias,
  describeOSError,
  type OSExecPatch,
} from '../../lib/os/osStore'
import { buildRelatorioOS } from '../../lib/os/relatorioOS'
import type {
  ChecklistExecItem,
  EvidenciaFoto,
  RelatorioOS,
  ServiceSnapshot,
} from '../../lib/servicos/types'
import { Spinner } from '../../components/ui/Spinner'
import {
  IconChevronLeft,
  IconCheckCircle,
  IconMapPin,
  IconCalendar,
  IconAlertCircle,
  IconRefresh,
  IconUser,
} from '../../components/ui/Icon'
import ChecklistExecucao from '../../components/os/ChecklistExecucao'
import EvidenciasSection from '../../components/os/EvidenciasSection'
import RelatorioOSModal from '../../components/os/RelatorioOSModal'
import SnapshotResumo from '../../components/os/SnapshotResumo'

// ── tipos ────────────────────────────────────────────────────────────────

interface OSHeader {
  numeroOS: string
  clienteNome: string
  bairro?: string
  enderecoLiberado?: string
  dataHora: string
  profissionalNome?: string
  status?: OSStatus
}

interface Toast {
  id: number
  text: string
  type: 'success' | 'error' | 'info'
}

type SaveState = 'idle' | 'saving' | 'saved' | 'error'

let toastSeq = 0

function numeroFromId(id: string): string {
  return `#${id.slice(-6).toUpperCase()}`
}

function serializeChecklist(items: ChecklistExecItem[]): string {
  return JSON.stringify(items)
}

// ── Wrapper: garante remount (state limpo) ao trocar de OS ───────────────

export default function OSExecucaoApp() {
  const { osId } = useParams<{ osId: string }>()
  const key = osId ?? ''
  return <OSExecucaoAppInner key={key} osId={key} />
}

// ── Componente principal ──────────────────────────────────────────────────

function OSExecucaoAppInner({ osId }: { osId: string }) {
  const navigate = useNavigate()
  const location = useLocation()
  const { user } = useAuth()
  const obrigatoriosPendentesBanner =
    (location.state as { obrigatoriosPendentes?: boolean } | null)?.obrigatoriosPendentes ?? false

  const [header, setHeader] = useState<OSHeader | null>(null)
  const [snapshot, setSnapshot] = useState<ServiceSnapshot | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState<string | null>(null)

  const [checklist, setChecklist] = useState<ChecklistExecItem[]>([])
  const [fotos, setFotos] = useState<EvidenciaFoto[]>([])
  const [fotosLoading, setFotosLoading] = useState(true)

  const [relatorioOpen, setRelatorioOpen] = useState(false)
  const [relatorio, setRelatorio] = useState<RelatorioOS | null>(null)

  const [saveState, setSaveState] = useState<SaveState>('idle')
  const [saveError, setSaveError] = useState<string | null>(null)

  const hydratedRef = useRef(false)
  const lastSavedRef = useRef<string | null>(null)
  const saveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const savedTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const [toasts, setToasts] = useState<Toast[]>([])
  const showToast = useCallback((text: string, type: Toast['type'] = 'info') => {
    const id = ++toastSeq
    setToasts((prev) => [...prev, { id, text, type }])
    setTimeout(() => setToasts((prev) => prev.filter((t) => t.id !== id)), 3600)
  }, [])

  // ── Carrega OS + checklist ─────────────────────────────────────────────

  const loadOS = useCallback(async () => {
    if (!osId) return
    setLoading(true)
    setLoadError(null)
    try {
      const rec = await loadOSExec(osId)
      if (rec.profissional && rec.profissional !== user?.id) {
        setLoadError('Você não tem permissão para esta OS.')
        return
      }
      setHeader({
        numeroOS: numeroFromId(rec.id),
        clienteNome: rec.nome_curto || 'Cliente',
        bairro: rec.bairro,
        enderecoLiberado: rec.endereco_liberado,
        dataHora: rec.data_hora,
        profissionalNome: rec.expand?.profissional
          ? userDisplayName(rec.expand.profissional)
          : undefined,
        status: rec.status,
      })
      const snap = rec.service_snapshot ?? null
      setSnapshot(snap)
      const ck = rec.checklist_exec ?? []
      setChecklist(ck)
      lastSavedRef.current = serializeChecklist(ck)
      hydratedRef.current = true
    } catch (err) {
      const info = describeOSError(err)
      setLoadError(info.message)
    } finally {
      setLoading(false)
    }
  }, [osId, user])

  useEffect(() => {
    void loadOS()
  }, [loadOS])

  // ── Carrega evidências ─────────────────────────────────────────────────

  useEffect(() => {
    if (!osId) return
    let cancelled = false
    setFotosLoading(true)
    listEvidencias(osId)
      .then((list) => { if (!cancelled) setFotos(list) })
      .catch(() => { if (!cancelled) setFotos([]) })
      .finally(() => { if (!cancelled) setFotosLoading(false) })
    return () => { cancelled = true }
  }, [osId])

  // ── Save debounced do checklist ────────────────────────────────────────

  const doSave = useCallback(
    async (patch: OSExecPatch, serialized: string) => {
      setSaveState('saving')
      setSaveError(null)
      try {
        await saveOSExecPatch(osId, patch)
        lastSavedRef.current = serialized
        setSaveState('saved')
        if (savedTimerRef.current) clearTimeout(savedTimerRef.current)
        savedTimerRef.current = setTimeout(() => setSaveState('idle'), 2200)
      } catch (err) {
        const info = describeOSError(err)
        setSaveState('error')
        const msg = info.isPermission
          ? 'Sem permissão para salvar alterações nesta OS.'
          : info.message
        setSaveError(msg)
        showToast(msg, 'error')
      }
    },
    [osId, showToast],
  )

  useEffect(() => {
    if (!osId || !hydratedRef.current) return
    const serialized = serializeChecklist(checklist)
    if (serialized === lastSavedRef.current) return
    if (saveTimerRef.current) clearTimeout(saveTimerRef.current)
    saveTimerRef.current = setTimeout(() => {
      if (serialized === lastSavedRef.current) return
      void doSave({ checklist_exec: checklist }, serialized)
    }, 800)
    return () => {
      if (saveTimerRef.current) clearTimeout(saveTimerRef.current)
    }
  }, [checklist, osId, doSave])

  useEffect(() => {
    return () => {
      if (saveTimerRef.current) clearTimeout(saveTimerRef.current)
      if (savedTimerRef.current) clearTimeout(savedTimerRef.current)
    }
  }, [])

  // ── Gerar laudo ────────────────────────────────────────────────────────

  async function handleGerarLaudo() {
    if (!snapshot) {
      showToast('OS sem serviço definido — laudo indisponível.', 'error')
      return
    }
    // Renova tokens das fotos antes de gerar o PDF (tokens expiram em ~2min)
    let evidencias = fotos
    try {
      const freshFotos = await listEvidencias(osId)
      setFotos(freshFotos)
      evidencias = freshFotos
    } catch {
      // usa fotos em cache se o refresh falhar
    }
    const rel = buildRelatorioOS({
      osId,
      numeroOS: header?.numeroOS,
      clienteNome: header?.clienteNome ?? 'Cliente',
      enderecoCompleto: header?.enderecoLiberado,
      bairro: header?.bairro,
      profissionalNome: header?.profissionalNome,
      dataHora: header?.dataHora ?? new Date().toISOString(),
      snapshot,
      adicionais: [],
      checklist,
      evidencias,
      observacoes: [],
    })
    setRelatorio(rel)
    setRelatorioOpen(true)
  }

  const profissionalNome =
    header?.profissionalNome ??
    (user ? userDisplayName(user) : 'Profissional')

  const checklistDone = checklist.filter((i) => i.status === 'concluido').length

  // ── Render ─────────────────────────────────────────────────────────────

  return (
    <>
      {/* Toasts */}
      <div
        style={{
          position: 'fixed',
          bottom: 80,
          left: '50%',
          transform: 'translateX(-50%)',
          zIndex: 200,
          display: 'flex',
          flexDirection: 'column',
          gap: 8,
          alignItems: 'center',
          pointerEvents: 'none',
          width: '90vw',
          maxWidth: 360,
        }}
      >
        {toasts.map((t) => (
          <div
            key={t.id}
            style={{
              padding: '10px 16px',
              borderRadius: 'var(--clx-r-pill)',
              fontSize: '0.85rem',
              fontWeight: 600,
              color: '#fff',
              background:
                t.type === 'success'
                  ? 'var(--clx-success)'
                  : t.type === 'error'
                  ? 'var(--clx-error)'
                  : 'var(--clx-accent)',
              boxShadow: 'var(--clx-shadow-md)',
              textAlign: 'center',
              pointerEvents: 'auto',
            }}
          >
            {t.text}
          </div>
        ))}
      </div>

      {/* Cabeçalho fixo */}
      <div className="profapp-page-header">
        <button
          type="button"
          className="icon-btn"
          onClick={() => navigate('/app')}
          aria-label="Voltar para Meus serviços"
          style={{ minWidth: 44, minHeight: 44 }}
        >
          <IconChevronLeft size={20} />
        </button>
        <h1 style={{ flex: 1, fontSize: '1rem' }}>
          {header ? `OS ${header.numeroOS}` : 'Execução da OS'}
        </h1>
        {header?.status && (
          <span className={`clx-status clx-status-${header.status}`} style={{ whiteSpace: 'nowrap', fontSize: '0.75rem' }}>
            {osStatusLabel(header.status)}
          </span>
        )}
      </div>

      <div className="profapp-page-body">
        {/* Erro de carregamento */}
        {loadError && !loading && (
          <section className="clx-card" style={{ padding: '20px 16px', marginBottom: 16 }}>
            <div className="error-banner" style={{ marginBottom: 14 }}>
              <IconAlertCircle size={15} />
              <span style={{ flex: 1 }}>{loadError}</span>
            </div>
            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <button
                type="button"
                className="clx-btn clx-btn-ghost clx-btn-sm"
                onClick={() => void loadOS()}
                style={{ minHeight: 44 }}
              >
                <IconRefresh size={15} /> Tentar novamente
              </button>
              <button
                type="button"
                className="clx-btn clx-btn-ghost clx-btn-sm"
                onClick={() => navigate('/app')}
                style={{ minHeight: 44 }}
              >
                <IconChevronLeft size={15} /> Voltar
              </button>
            </div>
          </section>
        )}

        {loading && (
          <div className="loading-overlay">
            <Spinner size={22} />
            Carregando OS…
          </div>
        )}

        {!loading && !loadError && header && (
          <>
            {/* Banner: itens obrigatórios pendentes (vindo de MeusServicos via state) */}
            {obrigatoriosPendentesBanner && (
              <div className="error-banner" style={{ marginBottom: 12 }}>
                <IconAlertCircle size={15} />
                <span style={{ flex: 1 }}>
                  Há itens obrigatórios pendentes — conclua-os para finalizar a OS.
                </span>
              </div>
            )}

            {/* (a) Cabeçalho da OS */}
            <section className="clx-card" style={{ padding: '16px', marginBottom: 12 }}>
              <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--clx-ink)', marginBottom: 4 }}>
                {header.clienteNome}
              </div>

              <div
                style={{
                  display: 'flex',
                  flexWrap: 'wrap',
                  gap: '4px 14px',
                  fontSize: '0.82rem',
                  color: 'var(--clx-ink-2)',
                  marginTop: 6,
                }}
              >
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                  <IconCalendar size={13} /> {formatDateTime(header.dataHora)}
                </span>
                {header.bairro && (
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                    <IconMapPin size={13} /> {header.bairro}
                  </span>
                )}
                {header.profissionalNome && (
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                    <IconUser size={13} /> {header.profissionalNome}
                  </span>
                )}
              </div>

              {/* Endereço completo — só em andamento */}
              {header.status === 'em_andamento' && header.enderecoLiberado && (
                <div
                  style={{
                    marginTop: 12,
                    padding: '10px 12px',
                    background: 'var(--clx-primary-bg)',
                    border: '1px solid var(--clx-primary-border)',
                    borderRadius: 'var(--clx-r-md)',
                    fontSize: '0.85rem',
                    color: 'var(--clx-ink)',
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: 6,
                  }}
                >
                  <span style={{ flexShrink: 0, marginTop: 2, color: 'var(--clx-primary-2)', display: 'flex' }}>
                    <IconMapPin size={14} />
                  </span>
                  {header.enderecoLiberado}
                </div>
              )}

              {/* Indicador de save automático */}
              {saveState !== 'idle' && (
                <div
                  style={{
                    marginTop: 10,
                    fontSize: '0.76rem',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 5,
                    color: saveState === 'error' ? 'var(--clx-error)' : 'var(--clx-ink-3)',
                  }}
                  role="status"
                  aria-live="polite"
                >
                  {saveState === 'saving' && <><Spinner size={12} /> Salvando…</>}
                  {saveState === 'saved' && <><IconCheckCircle size={12} /> Salvo</>}
                  {saveState === 'error' && <><IconAlertCircle size={12} /> {saveError ?? 'Erro ao salvar'}</>}
                </div>
              )}
            </section>

            {/* (b) Snapshot do serviço */}
            {snapshot ? (
              <section className="clx-card" style={{ padding: '14px 16px', marginBottom: 12 }}>
                <div
                  style={{
                    fontSize: '0.75rem',
                    fontWeight: 700,
                    textTransform: 'uppercase',
                    letterSpacing: '0.04em',
                    color: 'var(--clx-ink-3)',
                    marginBottom: 8,
                  }}
                >
                  Serviço
                </div>
                <SnapshotResumo snapshot={snapshot} />
              </section>
            ) : (
              <section className="clx-card" style={{ padding: '14px 16px', marginBottom: 12 }}>
                <div className="empty-state" style={{ padding: '12px 0' }}>
                  <h4>Serviço não definido</h4>
                  <p>O administrador ainda não configurou o serviço desta OS.</p>
                </div>
              </section>
            )}

            {/* (c) Checklist */}
            <div style={{ marginBottom: 12 }}>
              <ChecklistExecucao
                items={checklist}
                onChange={setChecklist}
                concluidoPor={profissionalNome}
              />
            </div>

            {/* (d) Evidências */}
            <div style={{ marginBottom: 12 }}>
              <EvidenciasSection
                osId={osId}
                fotos={fotos}
                onChange={setFotos}
                checklistItems={checklist}
                enviadoPor={profissionalNome}
                disabled={loading || fotosLoading}
                onNotify={showToast}
              />
            </div>

            {/* (e) Gerar laudo */}
            <section className="clx-card" style={{ padding: '14px 16px' }}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: 10,
                  flexWrap: 'wrap',
                }}
              >
                <div style={{ fontSize: '0.82rem', color: 'var(--clx-ink-2)' }}>
                  {checklist.length > 0
                    ? `${checklistDone} de ${checklist.length} itens concluídos · ${fotos.length} foto${fotos.length !== 1 ? 's' : ''}`
                    : `${fotos.length} foto${fotos.length !== 1 ? 's' : ''}`}
                </div>
                <button
                  type="button"
                  className="clx-btn clx-btn-primary"
                  onClick={() => { void handleGerarLaudo() }}
                  disabled={!snapshot || fotosLoading}
                  style={{ minHeight: 44 }}
                  title={fotosLoading ? 'Aguardando fotos…' : !snapshot ? 'OS sem serviço definido' : undefined}
                >
                  <IconCheckCircle size={15} /> Gerar laudo (PDF)
                </button>
              </div>
            </section>
          </>
        )}
      </div>

      {/* Modal do relatório */}
      {relatorio && (
        <RelatorioOSModal
          open={relatorioOpen}
          onClose={() => setRelatorioOpen(false)}
          relatorio={relatorio}
        />
      )}
    </>
  )
}
