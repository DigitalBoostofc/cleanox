/**
 * ContaRow — linha de "conta a pagar" ou "a receber" (PANE FIN-B4).
 * Renderiza ícone da categoria, descrição+subtítulo, vencimento, chip de tipo
 * (recorrência p/ pagar · origem p/ receber), valor, status e kebab com a ação
 * "Marcar como pago".
 */

import { useState } from 'react'
import type { Categoria, Conta, ContaPendente } from '../../../../lib/financeiro/types'
import { formatCurrency, formatDate } from '../../../../lib/collections'
import { Spinner } from '../../../../components/ui/Spinner'
import { IconCheckCircle } from '../../../../components/ui/Icon'
import { CategoriaIcon, ContaBadge, OrigemChip, StatusChip, TipoChip } from '../components'
import { IconMore } from './atoms'

export type ContaKind = 'payable' | 'receivable'

interface ContaRowProps {
  item: ContaPendente
  kind: ContaKind
  categoria?: Categoria
  conta?: Conta
  saving: boolean
  onMarcarPago: () => void
}

export function ContaRow({ item, kind, categoria, conta, saving, onMarcarPago }: ContaRowProps) {
  const [menuOpen, setMenuOpen] = useState(false)
  const l = item.lancamento

  const subtitle =
    l.origem === 'via_os' && l.clienteNome
      ? `Cliente: ${l.clienteNome}`
      : categoria?.nome ?? (kind === 'payable' ? 'Despesa' : 'Receita')

  const vencTexto = l.vencimento ? formatDate(l.vencimento) : formatDate(l.data)
  const valueColor = kind === 'payable' ? 'var(--clx-error)' : 'var(--clx-success)'

  function handleMarcar() {
    setMenuOpen(false)
    onMarcarPago()
  }

  return (
    <div
      className="fin-payable-row"
      style={{
        display: 'flex',
        alignItems: 'flex-start',
        gap: 12,
        padding: '12px 16px',
        borderBottom: '1px solid var(--clx-line)',
      }}
    >
      <CategoriaIcon categoria={categoria} />

      <div className="fin-payable-meta" style={{ flex: 1, minWidth: 0 }}>
        <div
          className="fin-payable-title"
          style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--clx-ink)', overflow: 'hidden', textOverflow: 'ellipsis' }}
        >
          {l.descricao}
        </div>
        <div className="fin-payable-sub" style={{ fontSize: '0.78rem', color: 'var(--clx-ink-3)', marginTop: 2 }}>
          {subtitle}
        </div>
        <div className="fin-payable-badges" style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 6 }}>
          {kind === 'payable' ? (
            <>
              <TipoChip recorrencia={l.recorrencia} />
              {l.recorrencia === 'parcelada' && l.parcelaAtual && l.parcelasTotal && (
                <span style={{ fontSize: '0.68rem', fontWeight: 600, color: 'var(--clx-ink-3)', alignSelf: 'center' }}>
                  {l.parcelaAtual}/{l.parcelasTotal}
                </span>
              )}
            </>
          ) : (
            <OrigemChip origem={l.origem} />
          )}
          {conta && <ContaBadge conta={conta} />}
          {item.emAtraso && (
            <span style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--clx-error)' }}>⚠ Em atraso</span>
          )}
          {item.vencendoHoje && !item.emAtraso && (
            <span style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--clx-warning)' }}>Vence hoje</span>
          )}
        </div>
      </div>

      <div
        className="fin-payable-due"
        style={{ fontSize: '0.78rem', color: 'var(--clx-ink-3)', whiteSpace: 'nowrap', flexShrink: 0, paddingTop: 2 }}
      >
        {vencTexto}
      </div>

      <div
        className="fin-payable-value"
        style={{ fontSize: '0.9rem', fontWeight: 700, color: valueColor, whiteSpace: 'nowrap', flexShrink: 0, paddingTop: 1 }}
      >
        {formatCurrency(l.valor)}
      </div>

      <div style={{ flexShrink: 0, paddingTop: 1 }}>
        <StatusChip status={l.status} />
      </div>

      {/* Kebab + menu */}
      <div style={{ position: 'relative', flexShrink: 0 }}>
        <button
          type="button"
          className="icon-btn"
          aria-label="Ações"
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          disabled={saving}
          onClick={() => setMenuOpen((o) => !o)}
          style={{ width: 28, height: 28 }}
        >
          {saving ? <Spinner size={14} /> : <IconMore size={16} />}
        </button>

        {menuOpen && (
          <>
            <div
              onClick={() => setMenuOpen(false)}
              style={{ position: 'fixed', inset: 0, zIndex: 40 }}
              aria-hidden="true"
            />
            <div
              role="menu"
              style={{
                position: 'absolute',
                right: 0,
                top: 32,
                zIndex: 41,
                minWidth: 190,
                background: 'var(--clx-bg)',
                border: '1px solid var(--clx-line)',
                borderRadius: 'var(--clx-r-md, 8px)',
                boxShadow: 'var(--clx-shadow-md, 0 8px 24px rgba(0,0,0,0.12))',
                padding: 4,
              }}
            >
              <button
                type="button"
                role="menuitem"
                onClick={handleMarcar}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  width: '100%',
                  padding: '8px 10px',
                  background: 'transparent',
                  border: 'none',
                  borderRadius: 6,
                  cursor: 'pointer',
                  fontSize: '0.82rem',
                  color: 'var(--clx-ink)',
                  textAlign: 'left',
                }}
              >
                <IconCheckCircle size={15} /> Marcar como pago
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
