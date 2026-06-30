/**
 * financeiro/labels.ts — Rótulos PT-BR + helpers de exibição do módulo Financeiro.
 *
 * Reaproveita formatCurrency do contrato canônico (../collections). As cores
 * (verde p/ receita, vermelho p/ despesa, chips de status) são decididas pela UI;
 * aqui só produzimos texto/sinal e um "tone" semântico para a UI escolher o chip.
 */

import { formatCurrency } from '../collections'
import type {
  ContaTipo,
  Lancamento,
  LancamentoStatus,
  OrigemLancamento,
  RecorrenciaTipo,
  TipoLancamento,
} from './types'

/* ---- Rótulos de unions ---- */

export function tipoLancamentoLabel(t: TipoLancamento): string {
  const labels: Record<TipoLancamento, string> = {
    receita: 'Receita',
    despesa: 'Despesa',
  }
  return labels[t]
}

export function recorrenciaLabel(r: RecorrenciaTipo): string {
  const labels: Record<RecorrenciaTipo, string> = {
    unica: 'Única',
    fixa: 'Fixa',
    recorrente: 'Recorrente',
    parcelada: 'Parcelada',
  }
  return labels[r]
}

export function statusLabel(s: LancamentoStatus): string {
  const labels: Record<LancamentoStatus, string> = {
    pago: 'Pago',
    pendente: 'Pendente',
    previsto: 'Previsto',
    em_atraso: 'Em atraso',
  }
  return labels[s]
}

export function origemLabel(o: OrigemLancamento): string {
  const labels: Record<OrigemLancamento, string> = {
    manual: 'Manual',
    via_os: 'Via OS',
  }
  return labels[o]
}

export function contaTipoLabel(t: ContaTipo): string {
  const labels: Record<ContaTipo, string> = {
    carteira: 'Carteira',
    banco: 'Banco',
    cartao: 'Cartão',
    caixa: 'Caixa',
  }
  return labels[t]
}

/* ---- Valor com sinal ---- */

/** Valor COM sinal a partir do tipo: receita → +valor, despesa → −valor. */
export function signedValue(l: Lancamento): number {
  return l.tipo === 'receita' ? l.valor : -l.valor
}

/**
 * Formata o valor JÁ com sinal explícito (+/−) em moeda BRL.
 * A COR (verde/vermelho) é responsabilidade da UI — aqui só vai o sinal e o texto.
 * Ex.: receita 300 → "+R$ 300,00" · despesa 980 → "−R$ 980,00".
 */
export function formatSigned(l: Lancamento): string {
  const sinal = l.tipo === 'receita' ? '+' : '−'
  return `${sinal}${formatCurrency(l.valor)}`
}

/* ---- Tom semântico do status (a UI escolhe o chip) ---- */

/** Tom semântico do chip de status, para a UI escolher a cor. */
export type StatusTone = 'success' | 'warning' | 'info' | 'error'

/**
 * Mapeia o status do lançamento ao tom do chip:
 *   pago → success · pendente → warning · previsto → info · em_atraso → error.
 */
export function statusTone(status: LancamentoStatus): StatusTone {
  const tones: Record<LancamentoStatus, StatusTone> = {
    pago: 'success',
    pendente: 'warning',
    previsto: 'info',
    em_atraso: 'error',
  }
  return tones[status]
}
