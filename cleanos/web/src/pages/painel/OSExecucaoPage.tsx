/**
 * OSExecucaoPage — superfície de EXECUÇÃO da Ordem de Serviço (pós-venda).
 *
 * Integração Serviço → OS via SNAPSHOT IMUTÁVEL: ao selecionar o serviço principal,
 * gravamos uma cópia congelada (buildSnapshot) dentro da OS; o checklist executável é
 * derivado desse snapshot. TODA a persistência é REAL no PocketBase (ver
 * ../../lib/os/osStore): os campos JSON da `ordens_servico`
 * (service_snapshot/checklist_exec/adicionais/observacoes_prof) e as fotos na coleção
 * `os_evidencias`.
 *
 * IMUTABILIDADE: o snapshot é enviado UMA vez (na seleção) — os saves de rotina
 * (checklist/adicionais/observações, com debounce) NÃO reenviam o snapshot, então
 * nunca colidem com a trava do hook do servidor (idempotente).
 *
 * NÃO substitui o funil de criação/edição de OS (OrdensServico/OSFormSection) — é uma
 * superfície nova e independente, acessível por /painel/ordens/:osId/execucao.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  type OSStatus,
  osStatusLabel,
  formatCurrency,
  formatDateTime,
  userDisplayName,
} from '../../lib/collections'
import {
  listServicos,
  buildSnapshot,
  snapshotToChecklistExec,
  calcTotalOS,
} from '../../lib/servicos/store'
import {
  loadOSExec,
  saveOSExecPatch,
  listEvidencias,
  describeOSError,
  type OSExecPatch,
} from '../../lib/os/osStore'
import type {
  Servico,
  ServiceSnapshot,
  ChecklistExecItem,
  ServicoAdicionalOS,
  EvidenciaFoto,
  ObservacaoProfissional,
  RelatorioOS,
} from '../../lib/servicos/types'
import {
  categoriaLabel,
  grupoLabel,
  formatValorServico,
} from '../../lib/servicos/labels'
import { Spinner } from '../../components/ui/Spinner'
import { Modal } from '../../components/ui/Modal'
import {
  IconChevronLeft,
  IconCheckCircle,
  IconUser,
  IconMapPin,
  IconCalendar,
  IconAlertCircle,
  IconRefresh,
} from '../../components/ui/Icon'

import SnapshotResumo from '../../components/os/SnapshotResumo'
import ChecklistExecucao from '../../components/os/ChecklistExecucao'
import ServicosAdicionaisSection from '../../components/os/ServicosAdicionaisSection'

// ── Dependências cross-pane (B3/B4) — programadas contra os contratos acordados.
import EvidenciasSection from '../../components/os/EvidenciasSection'
import ObservacoesProfissionalSection from '../../components/os/ObservacoesProfissionalSection'
import RelatorioOSModal from '../../components/os/RelatorioOSModal'
import { buildRelatorioOS } from '../../lib/os/relatorioOS'

// ── Tipos locais ──────────────────────────────────────────────────────

interface OSHeader {
  numeroOS: string
  clienteNome: string
  clienteTelefone?: string
  bairro?: string
  enderecoCompleto?: string
  dataHora: string
  profissionalNome?: string
  status?: OSStatus
}

interface Toast {
  id: number
  text: string
  type: 'success' | 'error' | 'info'
}

/** Estado do save automático dos campos JSON da execução. */
type SaveState = 'idle' | 'saving' | 'saved' | 'error'

let toastSeq = 0

// ── Helpers ───────────────────────────────────────────────────────────

function numeroFromId(id: string): string {
  return `#${id.slice(-6).toUpperCase()}`
}

function mockHeader(osId: string): OSHeader {
  return {
    numeroOS: osId && osId !== 'demo' ? numeroFromId(osId) : '#DEMO01',
    clienteNome: 'Cliente Demonstração',
    bairro: 'Centro',
    enderecoCompleto: 'Rua Exemplo, 123 — Centro',
    dataHora: new Date().toISOString(),
    profissionalNome: 'Profissional',
    status: 'em_andamento',
  }
}

/** Serializa o trio de rotina para comparar e evitar saves redundantes. */
function serializeRoutine(
  checklist: ChecklistExecItem[],
  adicionais: ServicoAdicionalOS[],
  observacoes: ObservacaoProfissional[],
): string {
  return JSON.stringify({
    checklist_exec: checklist,
    adicionais,
    observacoes_prof: observacoes,
  })
}

// ── Wrapper: garante remount (state limpo) ao trocar de OS ─────────────

export default function OSExecucaoPage() {
  const { osId } = useParams<{ osId: string }>()
  const key = osId ?? 'demo'
  return <OSExecucao key={key} osId={key} />
}

// ── Componente principal ──────────────────────────────────────────────

function OSExecucao({ osId }: { osId: string }) {
  const navigate = useNavigate()
  const isReal = !!osId && osId !== 'demo'

  const [header, setHeader] = useState<OSHeader | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState<string | null>(null)

  const [servicos, setServicos] = useState<Servico[]>([])
  const [servicosLoading, setServicosLoading] = useState(true)

  const [selectedServiceId, setSelectedServiceId] = useState('')
  const [snapshot, setSnapshot] = useState<ServiceSnapshot | null>(null)
  const [valorPrincipal, setValorPrincipal] = useState(0)
  const [checklist, setChecklist] = useState<ChecklistExecItem[]>([])
  const [adicionais, setAdicionais] = useState<ServicoAdicionalOS[]>([])
  // descontos não tem coluna no PB — permanece local (reinicia ao recarregar).
  const [descontos, setDescontos] = useState(0)
  const [fotos, setFotos] = useState<EvidenciaFoto[]>([])
  const [fotosLoading, setFotosLoading] = useState(true)
  const [observacoes, setObservacoes] = useState<ObservacaoProfissional[]>([])

  const [relatorioOpen, setRelatorioOpen] = useState(false)
  const [relatorio, setRelatorio] = useState<RelatorioOS | null>(null)

  // Save automático (debounce) dos campos JSON.
  const [saveState, setSaveState] = useState<SaveState>('idle')
  const [saveError, setSaveError] = useState<string | null>(null)
  const hydratedRef = useRef(false)
  const lastSavedRef = useRef<string | null>(null)
  const saveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const savedTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  // Troca de serviço principal com checklist em progresso (confirmação via Modal).
  const [pendingServiceId, setPendingServiceId] = useState<string | null>(null)

  // toasts
  const [toasts, setToasts] = useState<Toast[]>([])
  const showToast = useCallback((text: string, type: Toast['type'] = 'info') => {
    const id = ++toastSeq
    setToasts((prev) => [...prev, { id, text, type }])
    setTimeout(() => setToasts((prev) => prev.filter((t) => t.id !== id)), 3600)
  }, [])

  // ── Carrega a OS real (cabeçalho + campos JSON da execução) ──
  const loadOS = useCallback(async () => {
    if (!isReal) {
      setHeader(mockHeader(osId))
      setLoading(false)
      return
    }
    setLoading(true)
    setLoadError(null)
    try {
      const rec = await loadOSExec(osId)
      setHeader({
        numeroOS: numeroFromId(rec.id),
        clienteNome: rec.nome_curto || 'Cliente',
        bairro: rec.bairro,
        enderecoCompleto: rec.endereco_liberado,
        dataHora: rec.data_hora,
        profissionalNome: rec.expand?.profissional
          ? userDisplayName(rec.expand.profissional)
          : undefined,
        status: rec.status,
      })
      const snap = rec.service_snapshot ?? null
      setSnapshot(snap)
      setSelectedServiceId(snap?.serviceId ?? '')
      setValorPrincipal(snap?.valorBase ?? 0)
      const ck = rec.checklist_exec ?? []
      const ad = rec.adicionais ?? []
      const ob = rec.observacoes_prof ?? []
      setChecklist(ck)
      setAdicionais(ad)
      setObservacoes(ob)
      // marca o estado já persistido para o debounce não re-salvar a hidratação.
      lastSavedRef.current = serializeRoutine(ck, ad, ob)
      hydratedRef.current = true
    } catch (err) {
      const info = describeOSError(err)
      setLoadError(info.message)
    } finally {
      setLoading(false)
    }
  }, [osId, isReal])

  useEffect(() => {
    void loadOS()
  }, [loadOS])

  // ── Carrega evidências (fotos) da OS ──
  useEffect(() => {
    if (!isReal) {
      setFotosLoading(false)
      return
    }
    let cancelled = false
    setFotosLoading(true)
    listEvidencias(osId)
      .then((list) => {
        if (!cancelled) setFotos(list)
      })
      .catch(() => {
        if (!cancelled) setFotos([])
      })
      .finally(() => {
        if (!cancelled) setFotosLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [osId, isReal])

  // ── Carrega catálogo de serviços (mock store) ──
  useEffect(() => {
    let cancelled = false
    listServicos()
      .then((list) => {
        if (!cancelled) setServicos(list)
      })
      .catch(() => {
        if (!cancelled) setServicos([])
      })
      .finally(() => {
        if (!cancelled) setServicosLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [])

  // ── Persistência dos campos JSON (PB) ──
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

  // Debounce dos saves de rotina (checklist/adicionais/observações).
  useEffect(() => {
    if (!isReal || !hydratedRef.current) return
    const serialized = serializeRoutine(checklist, adicionais, observacoes)
    if (serialized === lastSavedRef.current) return
    if (saveTimerRef.current) clearTimeout(saveTimerRef.current)
    saveTimerRef.current = setTimeout(() => {
      // re-checa no disparo: o snapshot pode ter salvo o mesmo estado nesse meio-tempo.
      if (serialized === lastSavedRef.current) return
      void doSave(
        {
          checklist_exec: checklist,
          adicionais,
          observacoes_prof: observacoes,
        },
        serialized,
      )
    }, 800)
    return () => {
      if (saveTimerRef.current) clearTimeout(saveTimerRef.current)
    }
  }, [checklist, adicionais, observacoes, isReal, doSave])

  // Limpa timers ao desmontar.
  useEffect(() => {
    return () => {
      if (saveTimerRef.current) clearTimeout(saveTimerRef.current)
      if (savedTimerRef.current) clearTimeout(savedTimerRef.current)
    }
  }, [])

  // ── Serviços agrupados para o <select> do principal ──
  const servicosAgrupados = useMemo(() => {
    const map = new Map<
      string,
      { categoria: Servico['categoria']; grupo: Servico['grupo']; itens: Servico[] }
    >()
    for (const s of servicos.filter((s) => s.status === 'ativo')) {
      const k = `${s.categoria}|${s.grupo}`
      const bucket = map.get(k)
      if (bucket) bucket.itens.push(s)
      else map.set(k, { categoria: s.categoria, grupo: s.grupo, itens: [s] })
    }
    return [...map.values()].sort(
      (a, b) => a.categoria.localeCompare(b.categoria) || a.grupo.localeCompare(b.grupo),
    )
  }, [servicos])

  // ── Persiste o snapshot (gravação ÚNICA, na seleção do serviço) ──
  const persistSnapshot = useCallback(
    async (
      snap: ServiceSnapshot,
      newChecklist: ChecklistExecItem[],
      adic: ServicoAdicionalOS[],
      obs: ObservacaoProfissional[],
    ) => {
      if (!isReal) return
      setSaveState('saving')
      setSaveError(null)
      try {
        await saveOSExecPatch(osId, {
          service_snapshot: snap,
          checklist_exec: newChecklist,
        })
        // o trio de rotina passa a refletir o checklist recém-derivado.
        lastSavedRef.current = serializeRoutine(newChecklist, adic, obs)
        setSaveState('saved')
        if (savedTimerRef.current) clearTimeout(savedTimerRef.current)
        savedTimerRef.current = setTimeout(() => setSaveState('idle'), 2200)
      } catch (err) {
        const info = describeOSError(err)
        setSaveState('error')
        const msg = info.isPermission
          ? 'Sem permissão para gravar o serviço nesta OS.'
          : info.message
        setSaveError(msg)
        showToast(msg, 'error')
      }
    },
    [osId, isReal, showToast],
  )

  // ── Seleção do serviço principal → snapshot imutável + checklist derivado ──
  function applyServico(svc: Servico) {
    const snap = buildSnapshot(svc)
    const newChecklist = snapshotToChecklistExec(snap)
    setSelectedServiceId(svc.id)
    setSnapshot(snap)
    setValorPrincipal(snap.valorBase)
    setChecklist(newChecklist)
    // O checklist ganha novos IDs; desvincula (localmente) fotos que apontavam para o
    // checklist anterior. Obs.: vínculos já gravados no PB são raros aqui (troca de
    // serviço zera a execução) e ficam como chip genérico até nova edição.
    setFotos((prev) => prev.map((f) => ({ ...f, checklistItemId: undefined })))
    showToast(`Snapshot de "${svc.nome}" capturado.`, 'success')
    void persistSnapshot(snap, newChecklist, adicionais, observacoes)
  }

  function onSelectServico(id: string) {
    if (!id) return
    const svc = servicos.find((s) => s.id === id)
    if (!svc) return
    const temProgresso = checklist.some((i) => i.status === 'concluido')
    if (snapshot && snapshot.serviceId !== id && temProgresso) {
      // Confirma via Modal (sem window.confirm, que bloqueia automação).
      setPendingServiceId(id)
      return
    }
    applyServico(svc)
  }

  // ── Valores ──
  const valorAdicionais = calcTotalOS(0, adicionais)
  const total = calcTotalOS(valorPrincipal, adicionais, descontos)

  // ── Finalizar e gerar relatório ──
  function handleFinalizar() {
    if (!snapshot) {
      showToast('Selecione o serviço principal antes de finalizar.', 'error')
      return
    }
    const rel = buildRelatorioOS({
      osId,
      numeroOS: header?.numeroOS,
      clienteNome: header?.clienteNome ?? 'Cliente',
      clienteTelefone: header?.clienteTelefone,
      enderecoCompleto: header?.enderecoCompleto,
      bairro: header?.bairro,
      profissionalNome: header?.profissionalNome,
      dataHora: header?.dataHora ?? new Date().toISOString(),
      snapshot,
      adicionais,
      checklist,
      evidencias: fotos,
      observacoes,
      descontos: descontos > 0 ? descontos : undefined,
    })
    setRelatorio(rel)
    setRelatorioOpen(true)
  }

  const profissionalNome = header?.profissionalNome ?? 'Profissional'
  const checklistDone = checklist.filter((i) => i.status === 'concluido').length

  return (
    <div style={{ maxWidth: 880, margin: '0 auto', paddingBottom: 40 }}>
      {/* Toasts */}
      <div
        style={{
          position: 'fixed',
          bottom: 24,
          left: '50%',
          transform: 'translateX(-50%)',
          zIndex: 200,
          display: 'flex',
          flexDirection: 'column',
          gap: 8,
          alignItems: 'center',
          pointerEvents: 'none',
          width: '90vw',
          maxWidth: 380,
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

      {/* Voltar */}
      <button
        type="button"
        className="clx-btn clx-btn-ghost clx-btn-sm"
        onClick={() => navigate('/painel/ordens')}
        style={{ marginBottom: 14 }}
      >
        <IconChevronLeft size={15} /> Voltar para Ordens
      </button>

      {/* Erro de carregamento da OS */}
      {loadError && !loading ? (
        <section className="clx-card" style={{ padding: '20px 18px' }}>
          <div className="error-banner" style={{ marginBottom: 14 }}>
            <IconAlertCircle size={15} />
            <span style={{ flex: 1 }}>{loadError}</span>
          </div>
          <button type="button" className="clx-btn clx-btn-ghost clx-btn-sm" onClick={() => void loadOS()}>
            <IconRefresh size={15} /> Tentar novamente
          </button>
        </section>
      ) : (
        <>
          {/* (a) Cabeçalho da OS */}
          <section className="clx-card" style={{ padding: '16px 18px', marginBottom: 16 }}>
            {loading ? (
              <div className="loading-overlay" style={{ padding: '8px 0' }}>
                <Spinner size={18} /> Carregando OS…
              </div>
            ) : header ? (
              <>
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'flex-start',
                    justifyContent: 'space-between',
                    gap: 12,
                    flexWrap: 'wrap',
                  }}
                >
                  <div>
                    <div
                      style={{
                        fontFamily: 'var(--clx-font-display)',
                        fontSize: '1.25rem',
                        fontWeight: 800,
                        color: 'var(--clx-ink)',
                        letterSpacing: '-0.02em',
                      }}
                    >
                      Execução da OS {header.numeroOS}
                    </div>
                    <div style={{ fontSize: '0.95rem', fontWeight: 600, color: 'var(--clx-ink)', marginTop: 2 }}>
                      {header.clienteNome}
                    </div>
                  </div>
                  {header.status && (
                    <span className={`clx-status clx-status-${header.status}`} style={{ whiteSpace: 'nowrap' }}>
                      {osStatusLabel(header.status)}
                    </span>
                  )}
                </div>

                <div
                  style={{
                    display: 'flex',
                    flexWrap: 'wrap',
                    gap: '6px 18px',
                    marginTop: 12,
                    fontSize: '0.83rem',
                    color: 'var(--clx-ink-2)',
                  }}
                >
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                    <IconCalendar size={14} /> {formatDateTime(header.dataHora)}
                  </span>
                  {header.bairro && (
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                      <IconMapPin size={14} /> {header.bairro}
                    </span>
                  )}
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                    <IconUser size={14} /> {profissionalNome}
                  </span>
                </div>

                {/* Indicador de auto-save */}
                {isReal && saveState !== 'idle' && (
                  <div
                    style={{
                      marginTop: 10,
                      fontSize: '0.78rem',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 6,
                      color: saveState === 'error' ? 'var(--clx-error)' : 'var(--clx-ink-3)',
                    }}
                    role="status"
                    aria-live="polite"
                  >
                    {saveState === 'saving' && (
                      <>
                        <Spinner size={13} /> Salvando…
                      </>
                    )}
                    {saveState === 'saved' && (
                      <>
                        <IconCheckCircle size={13} /> Alterações salvas
                      </>
                    )}
                    {saveState === 'error' && (
                      <>
                        <IconAlertCircle size={13} /> {saveError ?? 'Erro ao salvar'}
                      </>
                    )}
                  </div>
                )}
              </>
            ) : null}
          </section>

          {/* (b) Serviço principal + snapshot */}
          <section className="clx-card" style={{ padding: '16px 18px', marginBottom: 16 }}>
            <h3
              style={{
                margin: '0 0 12px',
                fontFamily: 'var(--clx-font-display)',
                fontSize: '1rem',
                fontWeight: 700,
                color: 'var(--clx-ink)',
              }}
            >
              Serviço principal
            </h3>

            <div className="form-field" style={{ marginBottom: snapshot ? 16 : 0 }}>
              <label htmlFor="svc-principal">Selecione o serviço do catálogo</label>
              <select
                id="svc-principal"
                value={selectedServiceId}
                onChange={(e) => onSelectServico(e.target.value)}
                disabled={servicosLoading || loading}
              >
                <option value="">{servicosLoading ? 'Carregando serviços…' : 'Selecione…'}</option>
                {servicosAgrupados.map((bucket) => (
                  <optgroup
                    key={`${bucket.categoria}-${bucket.grupo}`}
                    label={`${categoriaLabel(bucket.categoria)} · ${grupoLabel(bucket.grupo)}`}
                  >
                    {bucket.itens.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.nome} — {formatValorServico(s)}
                      </option>
                    ))}
                  </optgroup>
                ))}
              </select>
            </div>

            {snapshot ? (
              <SnapshotResumo snapshot={snapshot} />
            ) : (
              <div className="empty-state" style={{ padding: '20px 12px', marginTop: 12 }}>
                <h4>Nenhum serviço selecionado</h4>
                <p>Escolha o serviço principal para capturar o snapshot e gerar o checklist.</p>
              </div>
            )}
          </section>

          {/* (c) Checklist de execução */}
          <div style={{ marginBottom: 16 }}>
            <ChecklistExecucao items={checklist} onChange={setChecklist} concluidoPor={profissionalNome} />
          </div>

          {/* (d) Serviços adicionais */}
          <div style={{ marginBottom: 16 }}>
            <ServicosAdicionaisSection adicionais={adicionais} onChange={setAdicionais} servicos={servicos} />
          </div>

          {/* (e) Resumo financeiro */}
          <section className="clx-card" style={{ padding: '16px 18px', marginBottom: 16 }}>
            <h3
              style={{
                margin: '0 0 14px',
                fontFamily: 'var(--clx-font-display)',
                fontSize: '1rem',
                fontWeight: 700,
                color: 'var(--clx-ink)',
              }}
            >
              Resumo financeiro
            </h3>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.9rem' }}>
                <span style={{ color: 'var(--clx-ink-2)' }}>Valor principal</span>
                <strong style={{ color: 'var(--clx-ink)' }}>{formatCurrency(valorPrincipal)}</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.9rem' }}>
                <span style={{ color: 'var(--clx-ink-2)' }}>
                  + Adicionais aprovados
                  <span style={{ color: 'var(--clx-ink-3)', fontSize: '0.78rem' }}>
                    {' '}(aprovado / não requer)
                  </span>
                </span>
                <strong style={{ color: 'var(--clx-ink)' }}>{formatCurrency(valorAdicionais)}</strong>
              </div>

              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: 12,
                  fontSize: '0.9rem',
                }}
              >
                <label htmlFor="descontos" style={{ color: 'var(--clx-ink-2)' }}>
                  − Descontos (R$)
                </label>
                <input
                  id="descontos"
                  type="number"
                  min="0"
                  step="0.01"
                  value={descontos === 0 ? '' : String(descontos)}
                  placeholder="0,00"
                  onChange={(e) => {
                    const v = parseFloat(e.target.value.replace(',', '.'))
                    setDescontos(Number.isNaN(v) || v < 0 ? 0 : v)
                  }}
                  style={{
                    width: 120,
                    textAlign: 'right',
                    padding: '6px 10px',
                    fontSize: '0.88rem',
                    background: 'var(--clx-bg-2)',
                    border: '1.5px solid var(--clx-line)',
                    borderRadius: 'var(--clx-r-md)',
                    color: 'var(--clx-ink)',
                    outline: 'none',
                  }}
                />
              </div>

              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  marginTop: 6,
                  paddingTop: 12,
                  borderTop: '1.5px solid var(--clx-line)',
                }}
              >
                <span style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--clx-ink)' }}>Total</span>
                <span
                  style={{
                    fontFamily: 'var(--clx-font-display)',
                    fontSize: '1.3rem',
                    fontWeight: 800,
                    color: 'var(--clx-accent)',
                    letterSpacing: '-0.02em',
                  }}
                >
                  {formatCurrency(total)}
                </span>
              </div>
            </div>
          </section>

          {/* (f) Evidências + Observações (componentes da pane B3) */}
          <div style={{ marginBottom: 16 }}>
            <EvidenciasSection
              osId={osId}
              fotos={fotos}
              onChange={setFotos}
              checklistItems={checklist}
              adicionais={adicionais}
              observacoes={observacoes}
              enviadoPor={profissionalNome}
              disabled={!isReal || loading || fotosLoading}
              onNotify={showToast}
            />
          </div>

          <div style={{ marginBottom: 16 }}>
            <ObservacoesProfissionalSection
              observacoes={observacoes}
              onChange={setObservacoes}
              fotos={fotos}
              criadoPor={profissionalNome}
            />
          </div>

          {/* (g) Finalizar */}
          <section className="clx-card" style={{ padding: '16px 18px' }}>
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                gap: 12,
                flexWrap: 'wrap',
              }}
            >
              <div style={{ fontSize: '0.84rem', color: 'var(--clx-ink-2)' }}>
                {snapshot ? (
                  <>
                    {checklistDone} de {checklist.length} itens concluídos · {adicionais.length} adicional(is) ·
                    Total {formatCurrency(total)}
                  </>
                ) : (
                  'Selecione o serviço principal para habilitar o relatório.'
                )}
              </div>
              <span title={!snapshot ? 'Selecione o serviço principal' : undefined}>
                <button
                  type="button"
                  className="clx-btn clx-btn-primary"
                  onClick={handleFinalizar}
                  disabled={!snapshot}
                >
                  <IconCheckCircle size={16} /> Finalizar e gerar relatório
                </button>
              </span>
            </div>
          </section>
        </>
      )}

      {/* Modal do relatório (pane B4) — o próprio modal gera o PDF A4 (gerarPDFOS). */}
      {relatorio && (
        <RelatorioOSModal
          open={relatorioOpen}
          onClose={() => setRelatorioOpen(false)}
          relatorio={relatorio}
          // OS REAL: NÃO passa handler → o modal cai na ramificação da rota real
          // (POST /api/cleanos/os/{id}/relatorio). Só em demo (osId vazio/'demo')
          // entregamos o handler-mock que apenas notifica.
          onEnviarWhatsApp={
            !isReal
              ? () => showToast('Relatório pronto para envio via WhatsApp (demo).', 'info')
              : undefined
          }
        />
      )}

      {/* Confirmação de troca do serviço principal (recria snapshot + checklist) */}
      <Modal
        open={pendingServiceId !== null}
        onClose={() => setPendingServiceId(null)}
        title="Trocar serviço principal"
        size="sm"
        footer={
          <>
            <button
              type="button"
              className="clx-btn clx-btn-ghost"
              onClick={() => setPendingServiceId(null)}
            >
              Manter serviço atual
            </button>
            <button
              type="button"
              className="clx-btn clx-btn-danger"
              onClick={() => {
                const svc = servicos.find((s) => s.id === pendingServiceId)
                setPendingServiceId(null)
                if (svc) applyServico(svc)
              }}
            >
              Trocar e recriar checklist
            </button>
          </>
        }
      >
        <p style={{ fontSize: '0.9rem', color: 'var(--clx-ink-2)', lineHeight: 1.6 }}>
          Trocar o serviço principal vai recriar o snapshot e zerar o checklist de
          execução já em andamento. Os itens concluídos serão perdidos. Continuar?
        </p>
      </Modal>
    </div>
  )
}
