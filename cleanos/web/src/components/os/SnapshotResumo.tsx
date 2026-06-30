/**
 * SnapshotResumo — exibe o SNAPSHOT IMUTÁVEL do serviço principal dentro da OS.
 *
 * O snapshot é uma cópia congelada do serviço no instante da seleção: alterações
 * futuras no cadastro do serviço NÃO afetam esta OS. Este componente deixa esse
 * contrato explícito ao profissional/atendente.
 */

import type { ServiceSnapshot } from '../../lib/servicos/types'
import {
  categoriaLabel,
  grupoLabel,
  tipoValorLabel,
  formatTempoMedio,
} from '../../lib/servicos/labels'
import { formatCurrency, formatDateTime } from '../../lib/collections'
import { IconLock } from '../ui/Icon'

interface SnapshotResumoProps {
  snapshot: ServiceSnapshot
}

/** Formata o valor do snapshot (faixa quando aplicável). */
function valorSnapshot(s: ServiceSnapshot): string {
  if (s.tipoValor === 'faixa' && s.valorBaseMax !== undefined) {
    return `${formatCurrency(s.valorBase)} a ${formatCurrency(s.valorBaseMax)}`
  }
  return formatCurrency(s.valorBase)
}

function Campo({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div
        style={{
          fontSize: '0.72rem',
          textTransform: 'uppercase',
          letterSpacing: '0.04em',
          color: 'var(--clx-ink-3)',
          fontWeight: 700,
          marginBottom: 3,
        }}
      >
        {label}
      </div>
      <div style={{ fontSize: '0.9rem', color: 'var(--clx-ink)', lineHeight: 1.45 }}>
        {children}
      </div>
    </div>
  )
}

export default function SnapshotResumo({ snapshot }: SnapshotResumoProps) {
  return (
    <div
      style={{
        border: '1.5px solid var(--clx-line)',
        borderRadius: 'var(--clx-r-lg)',
        background: 'var(--clx-bg-2)',
        overflow: 'hidden',
      }}
    >
      {/* Faixa de imutabilidade */}
      <div
        style={{
          display: 'flex',
          alignItems: 'flex-start',
          gap: 8,
          padding: '8px 14px',
          background: 'var(--clx-warning-bg)',
          borderBottom: '1px solid var(--clx-line)',
          color: 'var(--clx-warning)',
        }}
      >
        <span style={{ display: 'flex', marginTop: 1, flexShrink: 0 }}>
          <IconLock size={14} />
        </span>
        <span style={{ fontSize: '0.78rem', lineHeight: 1.4, fontWeight: 600 }}>
          Cópia do serviço no momento da seleção — alterações futuras no cadastro não
          afetam esta OS.
          <span style={{ fontWeight: 500, color: 'var(--clx-ink-3)' }}>
            {' '}Capturado em {formatDateTime(snapshot.capturedAt)}.
          </span>
        </span>
      </div>

      <div style={{ padding: '14px 16px' }}>
        {/* Nome + taxonomia */}
        <div style={{ marginBottom: 14 }}>
          <div
            style={{
              fontFamily: 'var(--clx-font-display)',
              fontSize: '1.05rem',
              fontWeight: 800,
              color: 'var(--clx-ink)',
              letterSpacing: '-0.01em',
            }}
          >
            {snapshot.nome}
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
            <span className="clx-chip clx-chip-primary">
              {categoriaLabel(snapshot.categoria)}
            </span>
            <span className="clx-chip">{grupoLabel(snapshot.grupo)}</span>
            <span className="clx-chip">{tipoValorLabel(snapshot.tipoValor)}</span>
          </div>
        </div>

        {/* Valor + tempo */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: 14,
            paddingBottom: 14,
            borderBottom: '1px solid var(--clx-line)',
          }}
        >
          <Campo label="Valor base">
            <span style={{ fontWeight: 700 }}>{valorSnapshot(snapshot)}</span>
          </Campo>
          <Campo label="Tempo médio">
            {formatTempoMedio(snapshot.tempoMedioMin, snapshot.tempoMedioLabel)}
          </Campo>
        </div>

        {/* Observação técnica + orientações */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, paddingTop: 14 }}>
          {snapshot.observacaoTecnica ? (
            <Campo label="Observação técnica">{snapshot.observacaoTecnica}</Campo>
          ) : null}
          {snapshot.orientacoesPreServico ? (
            <Campo label="Orientações pré-serviço">{snapshot.orientacoesPreServico}</Campo>
          ) : null}
          {snapshot.orientacoesPosServico ? (
            <Campo label="Orientações pós-serviço">{snapshot.orientacoesPosServico}</Campo>
          ) : null}
          {!snapshot.observacaoTecnica &&
            !snapshot.orientacoesPreServico &&
            !snapshot.orientacoesPosServico && (
              <div style={{ fontSize: '0.82rem', color: 'var(--clx-ink-3)' }}>
                Sem observações técnicas ou orientações cadastradas.
              </div>
            )}
        </div>
      </div>
    </div>
  )
}
