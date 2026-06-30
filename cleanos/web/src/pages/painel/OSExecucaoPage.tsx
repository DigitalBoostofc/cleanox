/**
 * OSExecucaoPage — superfície de EXECUÇÃO da Ordem de Serviço (pós-venda).
 *
 * Demonstra a integração Serviço → OS via SNAPSHOT IMUTÁVEL: ao selecionar o serviço
 * principal, gravamos uma cópia congelada (buildSnapshot) dentro da OS; o checklist
 * executável é derivado desse snapshot. O estado é mockado (useState + localStorage),
 * desenhado para depois virar gravação no PocketBase.
 *
 * NÃO substitui o funil de criação/edição de OS (OrdensServico/OSFormSection) — é uma
 * superfície nova e independente, acessível por /painel/ordens/:osId/execucao.
 */

import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { pb } from '../../lib/pb'
import {
  COLLECTIONS,
  type OrdemServico,
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
} from '../../components/ui/Icon'

import SnapshotResumo from '../../components/os/SnapshotResumo'
import ChecklistExecucao from '../../components/os/ChecklistExecucao'
import ServicosAdicionaisSection from '../../components/os/ServicosAdicionaisSection'

// ── Dependências cross-pane (B3/B4) — programadas contra os contratos acordados.
//    Podem ainda não existir no momento do typecheck desta pane (ver handoff).
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

/** Estado persistido da execução (localStorage por OS). */
interface ExecPersist {
  selectedServiceId: string
  snapshot: ServiceSnapshot | null
  valorPrincipal: number
  checklist: ChecklistExecItem[]
  adicionais: ServicoAdicionalOS[]
  descontos: number
  fotos: EvidenciaFoto[]
  observacoes: ObservacaoProfissional[]
}

interface Toast {
  id: number
  text: string
  type: 'success' | 'error' | 'info'
}

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

function loadPersist(key: string): ExecPersist | null {
  if (typeof localStorage === 'undefined') return null
  try {
    const raw = localStorage.getItem(key)
    if (!raw) return null
    const parsed = JSON.parse(raw) as ExecPersist
    return {
      ...parsed,
      // URLs blob: persistidas ficam inválidas após o reload (imagens quebradas) —
      // descarta fotos órfãs ao hidratar.
      fotos: (parsed.fotos ?? []).filter((f) => !f.url.startsWith('blob:')),
    }
  } catch {
    return null
  }
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
  const storageKey = `cleanox.os-exec.${osId}`

  // Hidratação síncrona (uma vez) a partir do localStorage.
  const initialRef = useRef<ExecPersist | null | undefined>(undefined)
  if (initialRef.current === undefined) initialRef.current = loadPersist(storageKey)
  const initial = initialRef.current

  const [header, setHeader] = useState<OSHeader | null>(null)
  const [headerLoading, setHeaderLoading] = useState(true)

  const [servicos, setServicos] = useState<Servico[]>([])
  const [servicosLoading, setServicosLoading] = useState(true)

  const [selectedServiceId, setSelectedServiceId] = useState(initial?.selectedServiceId ?? '')
  const [snapshot, setSnapshot] = useState<ServiceSnapshot | null>(initial?.snapshot ?? null)
  const [valorPrincipal, setValorPrincipal] = useState(initial?.valorPrincipal ?? 0)
  const [checklist, setChecklist] = useState<ChecklistExecItem[]>(initial?.checklist ?? [])
  const [adicionais, setAdicionais] = useState<ServicoAdicionalOS[]>(initial?.adicionais ?? [])
  const [descontos, setDescontos] = useState(initial?.descontos ?? 0)
  const [fotos, setFotos] = useState<EvidenciaFoto[]>(initial?.fotos ?? [])
  const [observacoes, setObservacoes] = useState<ObservacaoProfissional[]>(initial?.observacoes ?? [])

  const [relatorioOpen, setRelatorioOpen] = useState(false)
  const [relatorio, setRelatorio] = useState<RelatorioOS | null>(null)

  // Troca de serviço principal com checklist em progresso (confirmação via Modal).
  const [pendingServiceId, setPendingServiceId] = useState<string | null>(null)

  // toasts
  const [toasts, setToasts] = useState<Toast[]>([])
  function showToast(text: string, type: Toast['type'] = 'info') {
    const id = ++toastSeq
    setToasts((prev) => [...prev, { id, text, type }])
    setTimeout(() => setToasts((prev) => prev.filter((t) => t.id !== id)), 3600)
  }

  // ── Carrega cabeçalho da OS (PB com fallback mock) ──
  useEffect(() => {
    let cancelled = false
    async function loadHeader() {
      if (!osId || osId === 'demo') {
        if (!cancelled) {
          setHeader(mockHeader(osId))
          setHeaderLoading(false)
        }
        return
      }
      try {
        const rec = await pb
          .collection(COLLECTIONS.ORDENS_SERVICO)
          .getOne<OrdemServico>(osId, { expand: 'profissional' })
        if (cancelled) return
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
      } catch {
        if (!cancelled) setHeader(mockHeader(osId))
      } finally {
        if (!cancelled) setHeaderLoading(false)
      }
    }
    loadHeader()
    return () => {
      cancelled = true
    }
  }, [osId])

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

  // ── Persistência do estado de execução ──
  useEffect(() => {
    if (typeof localStorage === 'undefined') return
    const payload: ExecPersist = {
      selectedServiceId,
      snapshot,
      valorPrincipal,
      checklist,
      adicionais,
      descontos,
      fotos,
      observacoes,
    }
    try {
      localStorage.setItem(storageKey, JSON.stringify(payload))
    } catch {
      /* quota/serialização — ignorar no mock */
    }
  }, [
    storageKey,
    selectedServiceId,
    snapshot,
    valorPrincipal,
    checklist,
    adicionais,
    descontos,
    fotos,
    observacoes,
  ])

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

  // ── Seleção do serviço principal → snapshot imutável + checklist derivado ──
  function applyServico(svc: Servico) {
    const snap = buildSnapshot(svc)
    setSelectedServiceId(svc.id)
    setSnapshot(snap)
    setValorPrincipal(snap.valorBase)
    setChecklist(snapshotToChecklistExec(snap))
    // O checklist ganha novos IDs; desvincula fotos que apontavam para o checklist
    // anterior (evita checklistItemId dangling). Os demais vínculos seguem válidos.
    setFotos((prev) => prev.map((f) => ({ ...f, checklistItemId: undefined })))
    showToast(`Snapshot de "${svc.nome}" capturado.`, 'success')
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

      {/* (a) Cabeçalho da OS */}
      <section className="clx-card" style={{ padding: '16px 18px', marginBottom: 16 }}>
        {headerLoading ? (
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
            disabled={servicosLoading}
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
          fotos={fotos}
          onChange={setFotos}
          checklistItems={checklist}
          adicionais={adicionais}
          observacoes={observacoes}
          enviadoPor={profissionalNome}
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

      {/* Modal do relatório (pane B4) — o próprio modal gera o PDF A4 (gerarPDFOS). */}
      {relatorio && (
        <RelatorioOSModal
          open={relatorioOpen}
          onClose={() => setRelatorioOpen(false)}
          relatorio={relatorio}
          onEnviarWhatsApp={() => showToast('Relatório pronto para envio via WhatsApp (demo).', 'success')}
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
