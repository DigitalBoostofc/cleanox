/**
 * LancamentoDetailPanel — painel lateral direito (bottom-sheet no mobile) com os
 * detalhes de um lançamento e as ações: Repetir, Editar, Copiar, Excluir.
 *
 * Usa as classes .fin-detail-* / .fin-detail-overlay do CSS de infra. Em telas largas
 * é um painel fixo à direita (não-modal); no mobile vira um bottom-sheet com
 * backdrop. Fecha com Esc, no botão "Fechar", no X do cabeçalho ou (no mobile) no
 * backdrop.
 *
 * O componente é "burro": recebe o lançamento + categoria/conta resolvidas e
 * dispara callbacks. Quem persiste (store), mostra toast e recarrega é o parent.
 */

import { useEffect } from 'react'
import { IconX, IconEdit, IconTrash } from '../../../../components/ui/Icon'
import { IconCopy, IconExternalLink, IconRepeat } from './icons'
import { CategoriaIcon } from '../components/CategoriaIcon'
import { StatusChip } from '../components/StatusChip'
import { ContaBadge } from '../components/ContaBadge'
import { formatLongDateBR } from './dates'
import { formatCurrency } from '../../../../lib/collections'
import { recorrenciaLabel, tipoLancamentoLabel } from '../../../../lib/financeiro/labels'
import type { Categoria, Conta, Lancamento } from '../../../../lib/financeiro/types'

export interface LancamentoDetailPanelProps {
  lancamento: Lancamento
  categoria?: Categoria
  subcategoria?: Categoria
  conta?: Conta
  onClose: () => void
  onEdit: (l: Lancamento) => void
  onRepeat: (l: Lancamento) => void
  onDuplicate: (l: Lancamento) => void
  onDelete: (l: Lancamento) => void
  /** Abre a OS vinculada (stub) — só aparece quando há vínculo. */
  onVerOs?: (l: Lancamento) => void
  /** Mostra o backdrop e o formato bottom-sheet (mobile). */
  isMobile?: boolean
  /** Desabilita as ações enquanto uma operação está em andamento. */
  busy?: boolean
}

/** Texto descritivo da recorrência para a seção "Recorrência". */
function recorrenciaDescricao(l: Lancamento): string {
  switch (l.recorrencia) {
    case 'unica':
      return 'Não se aplica'
    case 'fixa':
      return 'Mensal (fixa, até cancelar)'
    case 'recorrente':
      return 'Repete periodicamente'
    case 'parcelada':
      return `Parcelada em ${l.parcelasTotal ?? '—'}x`
  }
}

export function LancamentoDetailPanel({
  lancamento,
  categoria,
  subcategoria,
  conta,
  onClose,
  onEdit,
  onRepeat,
  onDuplicate,
  onDelete,
  onVerOs,
  isMobile = false,
  busy = false,
}: LancamentoDetailPanelProps) {
  const l = lancamento
  const isReceita = l.tipo === 'receita'

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])

  const temVinculoOs = l.origem === 'via_os' || !!l.osId || !!l.osNumero
  const parcelaTexto =
    l.recorrencia === 'parcelada'
      ? `${l.parcelaAtual ?? 1} de ${l.parcelasTotal ?? 1}`
      : '1 de 1'

  return (
    <>
      {isMobile && (
        <div className="fin-detail-overlay" onClick={onClose} aria-hidden="true" />
      )}

      <aside
        className="fin-detail-panel"
        role="complementary"
        aria-label={`Detalhes do lançamento: ${l.descricao}`}
      >
        {/* Cabeçalho */}
        <div className="fin-detail-header">
          <span className={`fin-detail-badge ${isReceita ? 'income' : 'expense'}`}>
            {tipoLancamentoLabel(l.tipo)}
          </span>
          <span className="fin-detail-title">{l.descricao}</span>
          <button className="icon-btn" onClick={onClose} aria-label="Fechar painel">
            <IconX size={16} />
          </button>
        </div>

        <div className="fin-detail-content">
          {/* Categoria */}
          <div className="fin-detail-section">
            <h4>Categoria</h4>
            <div className="fin-detail-row">
              <CategoriaIcon categoria={categoria} size={28} />
              <span className="fin-detail-row-label">
                <span className="fin-detail-row-value">{categoria?.nome ?? 'Sem categoria'}</span>
                {subcategoria && (
                  <span style={{ display: 'block', color: 'var(--clx-ink-3)', fontSize: '0.75rem' }}>
                    {subcategoria.nome}
                  </span>
                )}
              </span>
            </div>
          </div>

          {/* Valor */}
          <div className="fin-detail-section">
            <h4>Valor</h4>
            <div className={`fin-detail-row-value amount${isReceita ? '' : ' expense'}`}>
              {formatCurrency(l.valor)}
            </div>
          </div>

          {/* Conta */}
          <div className="fin-detail-section">
            <h4>Conta</h4>
            <div className="fin-detail-row">
              {conta ? (
                <ContaBadge conta={conta} />
              ) : (
                <span className="fin-detail-row-value">—</span>
              )}
            </div>
          </div>

          {/* Data */}
          <div className="fin-detail-section">
            <h4>Data</h4>
            <div className="fin-detail-row">
              <span className="fin-detail-row-value">{formatLongDateBR(l.data)}</span>
            </div>
            {l.vencimento && (
              <div className="fin-detail-row" style={{ color: 'var(--clx-ink-3)' }}>
                Vencimento: {formatLongDateBR(l.vencimento)}
              </div>
            )}
          </div>

          {/* Tipo / Recorrência / Parcelas */}
          <div className="fin-detail-section">
            <h4>Tipo</h4>
            <div className="fin-detail-row">
              <span className="fin-detail-chip">{recorrenciaLabel(l.recorrencia)}</span>
            </div>
          </div>

          <div className="fin-detail-section">
            <h4>Recorrência</h4>
            <div className="fin-detail-row">
              <span className="fin-detail-row-label">{recorrenciaDescricao(l)}</span>
            </div>
          </div>

          <div className="fin-detail-section">
            <h4>Parcelas</h4>
            <div className="fin-detail-row">
              <span className="fin-detail-row-value">{parcelaTexto}</span>
            </div>
          </div>

          {/* Status */}
          <div className="fin-detail-section">
            <h4>Status</h4>
            <div className="fin-detail-row">
              <StatusChip status={l.status} />
            </div>
          </div>

          {/* Vínculo com OS */}
          {temVinculoOs && (
            <div className="fin-detail-section">
              <h4>Vínculo com OS</h4>
              <div className="fin-detail-row" style={{ justifyContent: 'space-between' }}>
                <span className="fin-detail-row-label">
                  {l.osNumero ? `OS #${l.osNumero}` : 'OS vinculada'}
                  {l.servicoNome ? ` · ${l.servicoNome}` : l.clienteNome ? ` · ${l.clienteNome}` : ''}
                </span>
                <button
                  className="fin-detail-link"
                  onClick={() => onVerOs?.(l)}
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: 'none', border: 'none', cursor: 'pointer' }}
                >
                  Ver OS <IconExternalLink size={13} />
                </button>
              </div>
            </div>
          )}

          {/* Observação */}
          {l.observacao && (
            <div className="fin-detail-section">
              <h4>Observação</h4>
              <p className="fin-detail-text">{l.observacao}</p>
            </div>
          )}

          {/* Anexos */}
          {l.anexos && l.anexos.length > 0 && (
            <div className="fin-detail-section">
              <h4>Anexos</h4>
              {l.anexos.map((a) => (
                <div key={a.id} className="fin-detail-attachment" title={a.nome}>
                  <span aria-hidden="true">📄</span>
                  <span style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {a.nome}
                  </span>
                  {a.tamanho != null && (
                    <span style={{ color: 'var(--clx-ink-3)' }}>
                      {a.tamanho < 1024 * 1024
                        ? `${Math.round(a.tamanho / 1024)} KB`
                        : `${(a.tamanho / (1024 * 1024)).toFixed(1)} MB`}
                    </span>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* Tags */}
          {l.tags && l.tags.length > 0 && (
            <div className="fin-detail-section">
              <h4>Tags</h4>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {l.tags.map((t) => (
                  <span key={t} className="clx-chip">
                    {t}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Rodapé: ações + fechar */}
        <div className="fin-detail-footer">
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              gap: 6,
            }}
          >
            <ActionItem
              label="Repetir"
              icon={<IconRepeat size={16} />}
              onClick={() => onRepeat(l)}
              disabled={busy}
            />
            <ActionItem
              label="Editar"
              icon={<IconEdit size={16} />}
              onClick={() => onEdit(l)}
              disabled={busy}
            />
            <ActionItem
              label="Copiar"
              icon={<IconCopy size={16} />}
              onClick={() => onDuplicate(l)}
              disabled={busy}
            />
            <ActionItem
              label="Excluir"
              icon={<IconTrash size={16} />}
              onClick={() => onDelete(l)}
              disabled={busy}
              danger
            />
          </div>
          <button className="clx-btn clx-btn-ghost clx-btn-block" onClick={onClose}>
            Fechar
          </button>
        </div>
      </aside>
    </>
  )
}

interface ActionItemProps {
  label: string
  icon: React.ReactNode
  onClick: () => void
  disabled?: boolean
  danger?: boolean
}

/** Ação do rodapé: ícone circular (.fin-detail-action-btn) + rótulo abaixo. */
function ActionItem({ label, icon, onClick, disabled, danger }: ActionItemProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      title={label}
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 4,
        flex: 1,
        background: 'none',
        border: 'none',
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.5 : 1,
        color: danger ? 'var(--clx-error)' : 'var(--clx-ink-2)',
      }}
    >
      <span className={`fin-detail-action-btn${danger ? ' danger' : ''}`} aria-hidden="true">
        {icon}
      </span>
      <span style={{ fontSize: '0.68rem', fontWeight: 600 }}>{label}</span>
    </button>
  )
}

export default LancamentoDetailPanel
