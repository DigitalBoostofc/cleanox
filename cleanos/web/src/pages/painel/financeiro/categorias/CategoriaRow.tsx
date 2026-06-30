/**
 * CategoriaRow — linha de categoria (ou subcategoria indentada) (PANE FIN-B4).
 * Ícone + nome + contagem de lançamentos + ações (editar · arquivar/desarquivar ·
 * adicionar subcategoria).
 */

import type { Categoria } from '../../../../lib/financeiro/types'
import { Spinner } from '../../../../components/ui/Spinner'
import { IconEdit, IconPlus } from '../../../../components/ui/Icon'
import { CategoriaIcon } from '../components'
import { IconArchive, IconArchiveRestore } from './atoms'

interface Props {
  categoria: Categoria
  count: number
  indent?: boolean
  busy?: boolean
  onEditar: () => void
  onArquivar: () => void
  onAddSub?: () => void
}

function ActionBtn({
  title,
  onClick,
  children,
  danger,
}: {
  title: string
  onClick: () => void
  children: React.ReactNode
  danger?: boolean
}) {
  return (
    <button
      type="button"
      className="icon-btn"
      title={title}
      aria-label={title}
      onClick={onClick}
      style={{ width: 28, height: 28, color: danger ? 'var(--clx-warning)' : 'var(--clx-ink-3)' }}
    >
      {children}
    </button>
  )
}

export function CategoriaRow({
  categoria,
  count,
  indent,
  busy,
  onEditar,
  onArquivar,
  onAddSub,
}: Props) {
  return (
    <div
      className={`fin-cat-row${indent ? ' indented' : ''}`}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        padding: indent ? '10px 16px 10px 44px' : '12px 16px',
        borderBottom: '1px solid var(--clx-line)',
        opacity: categoria.arquivada ? 0.6 : 1,
      }}
    >
      <CategoriaIcon categoria={categoria} size={indent ? 26 : 32} />

      <div className="fin-cat-meta" style={{ flex: 1, minWidth: 0 }}>
        <div
          className="fin-cat-name"
          style={{
            fontSize: indent ? '0.85rem' : '0.9rem',
            fontWeight: 600,
            color: 'var(--clx-ink)',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {categoria.nome}
          {categoria.arquivada && (
            <span style={{ fontSize: '0.68rem', fontWeight: 600, color: 'var(--clx-ink-3)', marginLeft: 8 }}>
              · Arquivada
            </span>
          )}
        </div>
      </div>

      <span
        className="fin-cat-count"
        style={{ fontSize: '0.78rem', color: 'var(--clx-ink-3)', whiteSpace: 'nowrap', flexShrink: 0 }}
      >
        {count} {count === 1 ? 'lançamento' : 'lançamentos'}
      </span>

      <div className="fin-cat-actions" style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
        {busy ? (
          <span style={{ width: 28, height: 28, display: 'grid', placeItems: 'center' }}>
            <Spinner size={14} />
          </span>
        ) : (
          <>
            <ActionBtn title="Editar" onClick={onEditar}>
              <IconEdit size={15} />
            </ActionBtn>
            <ActionBtn
              title={categoria.arquivada ? 'Desarquivar' : 'Arquivar'}
              onClick={onArquivar}
            >
              {categoria.arquivada ? <IconArchiveRestore size={15} /> : <IconArchive size={15} />}
            </ActionBtn>
            {onAddSub && !categoria.arquivada && (
              <ActionBtn title="Nova subcategoria" onClick={onAddSub}>
                <IconPlus size={15} />
              </ActionBtn>
            )}
          </>
        )}
      </div>
    </div>
  )
}
