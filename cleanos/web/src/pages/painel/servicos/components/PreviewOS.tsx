/**
 * PreviewOS — mini-card que mostra, AO VIVO, como o serviço aparecerá dentro da
 * Ordem de Serviço (para o cliente e para a equipe). Atualiza conforme o formulário.
 */

import type { Servico } from '../../../../lib/servicos/types'
import { formatTempoMedio, formatValorServico } from '../../../../lib/servicos/labels'
import { formatCurrency } from '../../../../lib/collections'
import { CategoriaIcon } from './GrupoChip'

/** Quantos itens do checklist mostrar antes de resumir em "+N itens". */
const PREVIEW_CHECKLIST_LIMIT = 3

/**
 * Valor exibido no preview. Em 'faixa', só mostra o intervalo quando o máximo já foi
 * preenchido e é maior que o mínimo — evita o transitório "R$ 300,00 a R$ 0,00".
 */
function previewValor(s: Servico): string {
  if (
    s.tipoValor === 'faixa' &&
    s.valorBaseMax !== undefined &&
    s.valorBaseMax > s.valorBase
  ) {
    return formatValorServico(s)
  }
  return formatCurrency(s.valorBase)
}

export function PreviewOS({ servico }: { servico: Servico }) {
  const nome = servico.nome.trim() || 'Nome do serviço'
  const descricao =
    servico.observacao?.trim() ||
    'A observação comercial/técnica do serviço aparece aqui para orientar o cliente e a equipe.'

  const itens = servico.checklistPadrao
    .filter((c) => c.titulo.trim())
    .sort((a, b) => a.ordem - b.ordem)
  const visiveis = itens.slice(0, PREVIEW_CHECKLIST_LIMIT)
  const restantes = itens.length - visiveis.length

  return (
    <div className="preview-os">
      <div className="preview-os-card">
        <div className="preview-icon">
          <CategoriaIcon categoria={servico.categoria} size={24} />
        </div>

        <div className="preview-body">
          <div className="preview-name">{nome}</div>
          <p className="preview-desc">{descricao}</p>

          <div className="preview-meta">
            <div className="preview-meta-item">
              <span className="preview-meta-label">Valor</span>
              <span className="preview-meta-value">{previewValor(servico)}</span>
            </div>
            <div className="preview-meta-item">
              <span className="preview-meta-label">Tempo</span>
              <span className="preview-meta-value">
                {formatTempoMedio(servico.tempoMedioMin, servico.tempoMedioLabel)}
              </span>
            </div>
          </div>
        </div>

        <div className="preview-inclui">
          <span className="preview-inclui-title">Inclui</span>
          {visiveis.length === 0 ? (
            <span className="preview-inclui-empty">Sem itens no checklist</span>
          ) : (
            <ul className="preview-inclui-list">
              {visiveis.map((it) => (
                <li key={it.id}>{it.titulo}</li>
              ))}
              {restantes > 0 && (
                <li className="preview-inclui-more">+{restantes} {restantes === 1 ? 'item' : 'itens'}</li>
              )}
            </ul>
          )}
        </div>
      </div>
    </div>
  )
}
