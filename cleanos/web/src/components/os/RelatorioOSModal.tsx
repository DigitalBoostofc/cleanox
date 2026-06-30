/**
 * RelatorioOSModal — Pré-visualização do RELATÓRIO FINAL da OS ao cliente.
 *
 * Mostra, num modal grande e legível, tudo que o cliente vê: dados do atendimento,
 * serviço contratado, adicionais, resumo financeiro, checklist executado, evidências
 * (antes/depois), observações visíveis, orientações pós-serviço, o texto padrão com o
 * prazo de intercorrência e um bloco de avaliação por estrelas (mock, estado local).
 *
 * Rodapé com 3 ações: enviar por WhatsApp, gerar relatório/imprimir e gerar PDF.
 * Quando não há handler de envio, faz um mock que copia a mensagem pronta para o
 * WhatsApp. Indisponibilidade de envio é tratada com mensagem amigável, espelhando o
 * tratamento do 409 ("WhatsApp não conectado") em MeusServicos.
 */

import {
  useEffect,
  useMemo,
  useState,
  type CSSProperties,
  type ReactNode,
} from 'react'
import { Modal } from '../ui/Modal'
import { Spinner } from '../ui/Spinner'
import { IconWhatsApp, IconOrdens, IconCheck, IconAlertCircle } from '../ui/Icon'
import type {
  AprovacaoStatus,
  FaseFoto,
  RelatorioOS,
} from '../../lib/servicos/types'
import {
  aprovacaoLabel,
  faseFotoLabel,
  formatTempoMedio,
} from '../../lib/servicos/labels'
import { formatCurrency, formatDateTime } from '../../lib/collections'
import { buildWhatsAppMessage } from '../../lib/os/relatorioOS'
import { gerarPDFOS } from '../../lib/os/pdfOS'

export interface RelatorioOSModalProps {
  open: boolean
  onClose: () => void
  relatorio: RelatorioOS
  /** Handler real de envio (dono do POST + tratamento de erros). Sem ele, usa mock. */
  onEnviarWhatsApp?: () => void
  /** Handler de geração de PDF. Sem ele, usa {@link gerarPDFOS}. */
  onGerarPDF?: () => void
}

/** Mensagem amigável quando o WhatsApp da empresa não está conectado (espelha o 409). */
const WHATSAPP_NAO_CONECTADO =
  'WhatsApp da empresa não está conectado. Avise o administrador.'

const FASES: FaseFoto[] = ['antes', 'durante', 'depois']

const APROVACAO_CHIP: Record<AprovacaoStatus, string> = {
  aprovado: 'clx-chip clx-chip-success',
  recusado: 'clx-chip clx-chip-error',
  aguardando: 'clx-chip clx-chip-warning',
  nao_requer: 'clx-chip clx-chip-primary',
}

/* ---- estilos reaproveitados ---- */

const sectionStyle: CSSProperties = { marginBottom: 22 }
const sectionTitleStyle: CSSProperties = {
  fontSize: '0.78rem',
  fontWeight: 700,
  textTransform: 'uppercase',
  letterSpacing: '0.05em',
  color: 'var(--clx-accent)',
  margin: '0 0 10px',
  paddingBottom: 6,
  borderBottom: '1px solid var(--clx-line)',
}
const infoRowStyle: CSSProperties = {
  display: 'flex',
  gap: 8,
  padding: '4px 0',
  borderBottom: '1px dotted var(--clx-line)',
}

/* ---- helpers de UI ---- */

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section style={sectionStyle}>
      <h4 style={sectionTitleStyle}>{title}</h4>
      {children}
    </section>
  )
}

function InfoRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div style={infoRowStyle}>
      <span style={{ color: 'var(--clx-ink-3)', fontWeight: 600, minWidth: 104 }}>
        {label}
      </span>
      <span style={{ color: 'var(--clx-ink)', flex: 1 }}>{value}</span>
    </div>
  )
}

/** Copia texto para a área de transferência, com fallback para navegadores antigos. */
async function copyToClipboard(text: string): Promise<void> {
  if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text)
    return
  }
  const ta = document.createElement('textarea')
  ta.value = text
  ta.style.position = 'fixed'
  ta.style.left = '-9999px'
  ta.style.opacity = '0'
  ta.setAttribute('readonly', '')
  document.body.appendChild(ta)
  ta.select()
  try {
    const ok = document.execCommand('copy')
    if (!ok) throw new Error('copy command failed')
  } finally {
    ta.remove()
  }
}

export default function RelatorioOSModal({
  open,
  onClose,
  relatorio,
  onEnviarWhatsApp,
  onGerarPDF,
}: RelatorioOSModalProps) {
  const [nota, setNota] = useState(relatorio.avaliacaoNota ?? 0)
  const [hoverNota, setHoverNota] = useState(0)
  const [confirmado, setConfirmado] = useState(false)
  const [sendingWhats, setSendingWhats] = useState(false)
  const [printing, setPrinting] = useState(false)
  const [generatingPdf, setGeneratingPdf] = useState(false)
  const [toast, setToast] = useState<{
    text: string
    type: 'success' | 'error' | 'info'
  } | null>(null)

  /* Reinicia o estado local ao (re)abrir ou trocar a OS. */
  useEffect(() => {
    if (!open) return
    setNota(relatorio.avaliacaoNota ?? 0)
    setHoverNota(0)
    setConfirmado(false)
    setToast(null)
  }, [open, relatorio.osId, relatorio.avaliacaoNota])

  /* Auto-dismiss do toast. */
  useEffect(() => {
    if (!toast) return
    const t = setTimeout(() => setToast(null), 3800)
    return () => clearTimeout(t)
  }, [toast])

  const showToast = (text: string, type: 'success' | 'error' | 'info') =>
    setToast({ text, type })

  const evidenciasPorFase = useMemo(
    () =>
      FASES.map((fase) => ({
        fase,
        fotos: relatorio.evidencias.filter((e) => e.fase === fase),
      })).filter((g) => g.fotos.length > 0),
    [relatorio.evidencias],
  )

  const checklistConcluidos = relatorio.checklist.filter(
    (c) => c.status === 'concluido',
  ).length

  async function handleWhatsApp() {
    if (sendingWhats) return
    setSendingWhats(true)
    try {
      if (onEnviarWhatsApp) {
        // Envio real é do pai (inclui o tratamento de 409). Pequeno respiro visual.
        onEnviarWhatsApp()
        await new Promise((r) => setTimeout(r, 150))
      } else {
        // Mock: copia a mensagem pronta para colar no WhatsApp do cliente.
        const msg = buildWhatsAppMessage(relatorio)
        await copyToClipboard(msg)
        showToast('Resumo copiado! Cole no WhatsApp do cliente ✓', 'success')
      }
    } catch {
      // Falha de entrega → mensagem amigável (mesmo padrão do 409 em MeusServicos).
      showToast(WHATSAPP_NAO_CONECTADO, 'error')
    } finally {
      setSendingWhats(false)
    }
  }

  function handlePrint() {
    if (printing) return
    setPrinting(true)
    try {
      gerarPDFOS(relatorio)
    } finally {
      setTimeout(() => setPrinting(false), 600)
    }
  }

  function handlePdf() {
    if (generatingPdf) return
    setGeneratingPdf(true)
    try {
      if (onGerarPDF) onGerarPDF()
      else gerarPDFOS(relatorio)
    } finally {
      setTimeout(() => setGeneratingPdf(false), 600)
    }
  }

  function handleConfirmar() {
    setConfirmado(true)
    showToast(
      nota > 0
        ? `Recebimento confirmado. Obrigado pela avaliação de ${nota} ${
            nota === 1 ? 'estrela' : 'estrelas'
          }!`
        : 'Recebimento confirmado. Obrigado!',
      'success',
    )
  }

  const footer = (
    <>
      <button
        type="button"
        className="clx-btn clx-btn-ghost"
        onClick={handlePrint}
        disabled={printing}
      >
        {printing ? <Spinner size={16} /> : <IconOrdens size={16} />}
        Imprimir
      </button>
      <button
        type="button"
        className="clx-btn clx-btn-accent"
        onClick={handlePdf}
        disabled={generatingPdf}
      >
        {generatingPdf ? <Spinner size={16} /> : <IconOrdens size={16} />}
        Gerar PDF
      </button>
      <button
        type="button"
        className="clx-btn clx-btn-primary"
        onClick={handleWhatsApp}
        disabled={sendingWhats}
      >
        {sendingWhats ? <Spinner size={16} /> : <IconWhatsApp size={16} />}
        Enviar por WhatsApp
      </button>
    </>
  )

  const tempoMedio = formatTempoMedio(
    relatorio.snapshot.tempoMedioMin,
    relatorio.snapshot.tempoMedioLabel,
  )

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={`Relatório do serviço${
        relatorio.numeroOS ? ` — Nº ${relatorio.numeroOS}` : ''
      }`}
      size="lg"
      footer={footer}
    >
      {/* Toast local (acima do backdrop do modal) */}
      {toast && (
        <div
          role="status"
          aria-live="polite"
          style={{
            position: 'fixed',
            top: 24,
            left: '50%',
            transform: 'translateX(-50%)',
            zIndex: 300,
            maxWidth: '90vw',
            padding: '10px 18px',
            borderRadius: 'var(--clx-r-pill)',
            fontSize: '0.85rem',
            fontWeight: 600,
            color: '#fff',
            textAlign: 'center',
            boxShadow: 'var(--clx-shadow-md)',
            background:
              toast.type === 'success'
                ? 'var(--clx-success)'
                : toast.type === 'error'
                ? 'var(--clx-error)'
                : 'var(--clx-accent)',
          }}
        >
          {toast.text}
        </div>
      )}

      {/* Dados do atendimento */}
      <Section title="Dados do atendimento">
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
            gap: '2px 24px',
          }}
        >
          <InfoRow label="Nº da OS" value={relatorio.numeroOS ?? relatorio.osId} />
          <InfoRow label="Data e hora" value={formatDateTime(relatorio.dataHora)} />
          <InfoRow label="Cliente" value={relatorio.clienteNome} />
          {relatorio.clienteTelefone && (
            <InfoRow label="Telefone" value={relatorio.clienteTelefone} />
          )}
          {relatorio.enderecoCompleto && (
            <InfoRow label="Endereço" value={relatorio.enderecoCompleto} />
          )}
          {relatorio.bairro && <InfoRow label="Bairro" value={relatorio.bairro} />}
          {relatorio.profissionalNome && (
            <InfoRow label="Profissional" value={relatorio.profissionalNome} />
          )}
        </div>
      </Section>

      {/* Serviço contratado */}
      <Section title="Serviço contratado">
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'flex-start',
            gap: 16,
            flexWrap: 'wrap',
          }}
        >
          <div style={{ minWidth: 200 }}>
            <div style={{ fontWeight: 700, fontSize: '1.02rem', color: 'var(--clx-ink)' }}>
              {relatorio.snapshot.nome}
            </div>
            {tempoMedio && (
              <div style={{ color: 'var(--clx-ink-3)', fontSize: '0.85rem', marginTop: 2 }}>
                Tempo médio: {tempoMedio}
              </div>
            )}
            {relatorio.snapshot.observacaoTecnica && (
              <div style={{ color: 'var(--clx-ink-2)', fontSize: '0.85rem', marginTop: 4 }}>
                {relatorio.snapshot.observacaoTecnica}
              </div>
            )}
          </div>
          <div
            style={{
              fontWeight: 800,
              fontSize: '1.1rem',
              color: 'var(--clx-accent)',
              whiteSpace: 'nowrap',
            }}
          >
            {formatCurrency(relatorio.valorPrincipal)}
          </div>
        </div>
      </Section>

      {/* Serviços adicionais */}
      {relatorio.adicionais.length > 0 && (
        <Section title="Serviços adicionais">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {relatorio.adicionais.map((a) => (
              <div
                key={a.id}
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  gap: 12,
                  padding: '8px 12px',
                  background: 'var(--clx-bg-2)',
                  borderRadius: 'var(--clx-r-md)',
                }}
              >
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontWeight: 600, color: 'var(--clx-ink)' }}>
                    {a.nome}
                    {a.quantidade > 1 && (
                      <span style={{ color: 'var(--clx-ink-3)', fontWeight: 500 }}>
                        {' '}
                        ×{a.quantidade}
                      </span>
                    )}
                  </div>
                  {a.motivo && (
                    <div style={{ color: 'var(--clx-ink-3)', fontSize: '0.8rem' }}>
                      {a.motivo}
                    </div>
                  )}
                  <span
                    className={APROVACAO_CHIP[a.aprovacao]}
                    style={{ marginTop: 4 }}
                  >
                    {aprovacaoLabel(a.aprovacao)}
                  </span>
                </div>
                <div
                  style={{
                    fontWeight: 700,
                    color: 'var(--clx-ink)',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {formatCurrency(a.valor * a.quantidade)}
                </div>
              </div>
            ))}
          </div>
        </Section>
      )}

      {/* Resumo financeiro */}
      <Section title="Resumo financeiro">
        <div
          style={{
            border: '1px solid var(--clx-line)',
            borderRadius: 'var(--clx-r-md)',
            overflow: 'hidden',
          }}
        >
          <FinRow label="Serviço principal" value={formatCurrency(relatorio.valorPrincipal)} />
          {relatorio.valorAdicionais > 0 && (
            <FinRow
              label="Serviços adicionais"
              value={formatCurrency(relatorio.valorAdicionais)}
            />
          )}
          {relatorio.descontos && relatorio.descontos > 0 ? (
            <FinRow label="Descontos" value={`- ${formatCurrency(relatorio.descontos)}`} />
          ) : null}
          <FinRow label="Total" value={formatCurrency(relatorio.valorTotal)} total />
        </div>
      </Section>

      {/* Checklist executado */}
      {relatorio.checklist.length > 0 && (
        <Section
          title={`Checklist executado (${checklistConcluidos}/${relatorio.checklist.length})`}
        >
          <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
            {relatorio.checklist.map((item) => {
              const ok = item.status === 'concluido'
              return (
                <li
                  key={item.id}
                  style={{
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: 8,
                    color: ok ? 'var(--clx-ink)' : 'var(--clx-ink-3)',
                  }}
                >
                  <span
                    aria-hidden="true"
                    style={{
                      flexShrink: 0,
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      width: 20,
                      height: 20,
                      borderRadius: '50%',
                      marginTop: 1,
                      color: ok ? '#fff' : 'var(--clx-ink-3)',
                      background: ok ? 'var(--clx-success)' : 'transparent',
                      border: ok ? 'none' : '1.5px solid var(--clx-line-2)',
                    }}
                  >
                    {ok ? <IconCheck size={13} /> : null}
                  </span>
                  <span>
                    {item.titulo}
                    {!ok && (
                      <span style={{ fontSize: '0.78rem' }}> (pendente)</span>
                    )}
                    {item.observacao && (
                      <span style={{ color: 'var(--clx-ink-3)', fontSize: '0.8rem' }}>
                        {' '}
                        — {item.observacao}
                      </span>
                    )}
                  </span>
                </li>
              )
            })}
          </ul>
        </Section>
      )}

      {/* Evidências */}
      {evidenciasPorFase.length > 0 && (
        <Section title="Evidências (antes / depois)">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {evidenciasPorFase.map((grupo) => (
              <div key={grupo.fase}>
                <div
                  style={{
                    fontWeight: 700,
                    fontSize: '0.85rem',
                    color: 'var(--clx-ink-2)',
                    marginBottom: 6,
                  }}
                >
                  {faseFotoLabel(grupo.fase)}
                </div>
                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))',
                    gap: 10,
                  }}
                >
                  {grupo.fotos.map((foto) => (
                    <figure
                      key={foto.id}
                      style={{
                        margin: 0,
                        border: '1px solid var(--clx-line)',
                        borderRadius: 'var(--clx-r-md)',
                        overflow: 'hidden',
                        background: 'var(--clx-bg-2)',
                      }}
                    >
                      <img
                        src={foto.url}
                        alt={foto.legenda ?? faseFotoLabel(foto.fase)}
                        loading="lazy"
                        style={{
                          width: '100%',
                          aspectRatio: '4 / 3',
                          objectFit: 'cover',
                          display: 'block',
                        }}
                      />
                      {foto.legenda && (
                        <figcaption
                          style={{
                            fontSize: '0.75rem',
                            color: 'var(--clx-ink-3)',
                            padding: '4px 8px',
                          }}
                        >
                          {foto.legenda}
                        </figcaption>
                      )}
                    </figure>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </Section>
      )}

      {/* Observações visíveis ao cliente */}
      {relatorio.observacoesVisiveis.length > 0 && (
        <Section title="Observações">
          <ul style={{ margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 4 }}>
            {relatorio.observacoesVisiveis.map((obs) => (
              <li key={obs.id} style={{ color: 'var(--clx-ink-2)' }}>
                {obs.texto}
              </li>
            ))}
          </ul>
        </Section>
      )}

      {/* Orientações pós-serviço */}
      {relatorio.orientacoesPos && relatorio.orientacoesPos.trim() && (
        <Section title="Orientações pós-serviço">
          <p style={{ margin: 0, color: 'var(--clx-ink-2)', whiteSpace: 'pre-line' }}>
            {relatorio.orientacoesPos.trim()}
          </p>
        </Section>
      )}

      {/* Texto padrão + prazo */}
      <div
        style={{
          display: 'flex',
          gap: 10,
          padding: '14px 16px',
          background: 'var(--clx-primary-bg)',
          border: '1px solid var(--clx-primary-border)',
          borderRadius: 'var(--clx-r-md)',
          marginBottom: 22,
        }}
      >
        <span style={{ color: 'var(--clx-primary)', flexShrink: 0, marginTop: 1 }}>
          <IconAlertCircle size={18} />
        </span>
        <div style={{ fontSize: '0.85rem', color: 'var(--clx-ink-2)', lineHeight: 1.5 }}>
          {relatorio.textoPadrao}
          <div style={{ marginTop: 8, fontWeight: 600, color: 'var(--clx-ink)' }}>
            Prazo de até {relatorio.prazoIntercorrenciaDias} dias para relatar qualquer
            falha ou intercorrência.
          </div>
        </div>
      </div>

      {/* Avaliação por estrelas + confirmação (mock) */}
      <div
        style={{
          textAlign: 'center',
          padding: '18px 16px',
          background: 'var(--clx-bg-2)',
          borderRadius: 'var(--clx-r-lg)',
        }}
      >
        <div style={{ fontWeight: 700, color: 'var(--clx-ink)', marginBottom: 4 }}>
          Como você avalia o atendimento?
        </div>
        <div
          role="group"
          aria-label="Avaliação por estrelas"
          style={{ display: 'inline-flex', gap: 2, marginBottom: 10 }}
        >
          {[1, 2, 3, 4, 5].map((n) => {
            const active = n <= (hoverNota || nota)
            return (
              <button
                key={n}
                type="button"
                aria-label={`${n} ${n === 1 ? 'estrela' : 'estrelas'}`}
                aria-pressed={n === nota}
                onClick={() => setNota(n)}
                onMouseEnter={() => setHoverNota(n)}
                onMouseLeave={() => setHoverNota(0)}
                onFocus={() => setHoverNota(n)}
                onBlur={() => setHoverNota(0)}
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  fontSize: 30,
                  lineHeight: 1,
                  padding: '0 2px',
                  color: active ? 'var(--clx-warning)' : 'var(--clx-ink-3)',
                  transition: 'color 0.12s',
                }}
              >
                {active ? '★' : '☆'}
              </button>
            )
          })}
        </div>
        <div>
          <button
            type="button"
            className="clx-btn clx-btn-primary clx-btn-sm"
            onClick={handleConfirmar}
            disabled={confirmado}
          >
            {confirmado ? (
              <>
                <IconCheck size={16} /> Recebimento confirmado
              </>
            ) : (
              'Confirmar recebimento'
            )}
          </button>
        </div>
      </div>
    </Modal>
  )
}

/** Linha do resumo financeiro. */
function FinRow({
  label,
  value,
  total = false,
}: {
  label: string
  value: string
  total?: boolean
}) {
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: '10px 14px',
        borderTop: total ? '2px solid var(--clx-accent)' : 'none',
        background: total ? 'var(--clx-bg-2)' : 'transparent',
        fontWeight: total ? 800 : 500,
        fontSize: total ? '1.05rem' : '0.92rem',
        color: total ? 'var(--clx-accent)' : 'var(--clx-ink-2)',
      }}
    >
      <span>{label}</span>
      <span>{value}</span>
    </div>
  )
}
