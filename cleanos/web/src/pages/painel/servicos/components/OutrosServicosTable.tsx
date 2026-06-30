/**
 * OutrosServicosTable — tabela enxuta "Outros serviços cadastrados" exibida no
 * editor (read-only, com link de edição). Em mobile vira lista de cards.
 */

import { useNavigate } from 'react-router-dom'
import type { Servico } from '../../../../lib/servicos/types'
import {
  formatTempoMedio,
  formatValorServico,
  servicoStatusLabel,
  tipoValorLabel,
} from '../../../../lib/servicos/labels'
import { IconEdit } from '../../../../components/ui/Icon'
import { useIsMobile } from '../../../../hooks/useIsMobile'
import { CategoriaGrupo, CategoriaIcon } from './GrupoChip'

export function OutrosServicosTable({ servicos }: { servicos: Servico[] }) {
  const navigate = useNavigate()
  const isMobile = useIsMobile()

  if (servicos.length === 0) {
    return (
      <p className="svc-muted" style={{ padding: '8px 2px' }}>
        Nenhum outro serviço cadastrado ainda.
      </p>
    )
  }

  if (isMobile) {
    return (
      <div className="mob-card-list">
        {servicos.map((s) => (
          <div
            key={s.id}
            className="mob-card"
            onClick={() => navigate(`/painel/servicos/${s.id}`)}
            style={{ cursor: 'pointer' }}
          >
            <div className="mob-card-top">
              <CategoriaIcon categoria={s.categoria} />
              <div className="mob-card-meta">
                <div className="mob-card-title">{s.nome}</div>
                <div className="mob-card-sub">{formatValorServico(s)}</div>
              </div>
              <div className="mob-card-badge">
                <span className={`svc-status svc-status-${s.status}`}>
                  {servicoStatusLabel(s.status)}
                </span>
              </div>
            </div>
            <div className="mob-card-rows">
              <div className="mob-card-row">
                <CategoriaGrupo categoria={s.categoria} grupo={s.grupo} />
              </div>
            </div>
          </div>
        ))}
      </div>
    )
  }

  return (
    <div className="table-scroll">
      <table className="clx-table svc-table">
        <thead>
          <tr>
            <th>Serviço</th>
            <th>Categoria / Grupo</th>
            <th>Valor</th>
            <th>Tipo de valor</th>
            <th>Tempo médio</th>
            <th>Status</th>
            <th aria-label="Ações" />
          </tr>
        </thead>
        <tbody>
          {servicos.map((s) => (
            <tr
              key={s.id}
              onClick={() => navigate(`/painel/servicos/${s.id}`)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault()
                  navigate(`/painel/servicos/${s.id}`)
                }
              }}
              tabIndex={0}
              style={{ cursor: 'pointer' }}
            >
              <td data-label="Serviço">
                <span className="svc-row-name">
                  <CategoriaIcon categoria={s.categoria} size={16} />
                  <strong>{s.nome}</strong>
                </span>
              </td>
              <td data-label="Categoria / Grupo">
                <CategoriaGrupo categoria={s.categoria} grupo={s.grupo} />
              </td>
              <td data-label="Valor">{formatValorServico(s)}</td>
              <td data-label="Tipo de valor">
                <span className="clx-chip">{tipoValorLabel(s.tipoValor)}</span>
              </td>
              <td data-label="Tempo médio">{formatTempoMedio(s.tempoMedioMin, s.tempoMedioLabel)}</td>
              <td data-label="Status">
                <span className={`svc-status svc-status-${s.status}`}>
                  {servicoStatusLabel(s.status)}
                </span>
              </td>
              <td data-label="Ações" className="svc-actions-cell">
                <button
                  type="button"
                  className="icon-btn"
                  onClick={(e) => {
                    e.stopPropagation()
                    navigate(`/painel/servicos/${s.id}`)
                  }}
                  aria-label={`Editar ${s.nome}`}
                  title="Editar"
                >
                  <IconEdit size={15} />
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
