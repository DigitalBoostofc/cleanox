/**
 * servicos/labels.ts — Rótulos PT-BR + helpers de formatação do módulo Serviços.
 * Reaproveita formatCurrency do contrato canônico (../collections).
 */

import { formatCurrency } from '../collections'
import type {
  AprovacaoStatus,
  Categoria,
  FaseFoto,
  Grupo,
  Servico,
  ServicoStatus,
  TipoValor,
} from './types'

/* ---- Rótulos ---- */

export function categoriaLabel(c: Categoria): string {
  const labels: Record<Categoria, string> = {
    veicular: 'Veicular',
    residencial: 'Residencial',
  }
  return labels[c]
}

export function grupoLabel(g: Grupo): string {
  const labels: Record<Grupo, string> = {
    plano: 'Plano',
    promocao: 'Promoção',
    adicional: 'Adicional',
    avulsos: 'Avulsos',
    sofa: 'Sofá',
    colchao: 'Colchão',
    outros: 'Outros',
  }
  return labels[g]
}

export function tipoValorLabel(t: TipoValor): string {
  const labels: Record<TipoValor, string> = {
    fixo: 'Fixo',
    faixa: 'Faixa',
    variavel: 'Variável',
  }
  return labels[t]
}

export function servicoStatusLabel(s: ServicoStatus): string {
  return s === 'ativo' ? 'Ativo' : 'Inativo'
}

export function aprovacaoLabel(a: AprovacaoStatus): string {
  const labels: Record<AprovacaoStatus, string> = {
    nao_requer: 'Não precisa aprovar',
    aguardando: 'Aguardando aprovação do cliente',
    aprovado: 'Aprovado',
    recusado: 'Recusado',
  }
  return labels[a]
}

export function faseFotoLabel(f: FaseFoto): string {
  const labels: Record<FaseFoto, string> = {
    antes: 'Antes',
    durante: 'Durante',
    depois: 'Depois',
  }
  return labels[f]
}

/* ---- Tempo médio ---- */

/**
 * Converte um rótulo de tempo médio em minutos.
 *
 * REGRA: sempre usa o LIMITE SUPERIOR do intervalo (o maior valor encontrado),
 * pois é o que melhor protege a agenda contra estouro de tempo.
 *
 * Exemplos:
 *  - "1h30 a 2h"     → 120
 *  - "40min a 1h"    → 60
 *  - "20min a 40min" → 40
 *  - "3h+"           → 180
 *  - "Variável"      → undefined  (sem tempo determinável)
 *  - ""              → undefined
 *
 * Tokens reconhecidos: "1h30", "2h", "40min".
 */
export function parseTempoMedio(label: string): number | undefined {
  if (!label) return undefined
  const normalized = label.toLowerCase()
  // "Variável" / "variavel" → sem tempo determinável
  if (normalized.includes('vari')) return undefined

  // Captura cada token de duração: horas (com minutos opcionais) OU minutos.
  const re = /(\d+)\s*h\s*(\d+)?|(\d+)\s*min/g
  let max: number | undefined
  let m: RegExpExecArray | null
  while ((m = re.exec(normalized)) !== null) {
    let minutos: number
    if (m[1] !== undefined) {
      // grupo de horas (com minutos opcionais): "1h30" → 90, "2h" → 120
      minutos = parseInt(m[1], 10) * 60 + (m[2] ? parseInt(m[2], 10) : 0)
    } else {
      // grupo de minutos: "40min" → 40
      minutos = parseInt(m[3], 10)
    }
    if (max === undefined || minutos > max) max = minutos
  }
  return max
}

/**
 * Formata o tempo médio para exibição.
 * Prefere o rótulo humano (label) quando disponível; senão deriva dos minutos.
 * Sem ambos → "Variável".
 */
export function formatTempoMedio(min?: number, label?: string): string {
  if (label && label.trim()) return label.trim()
  if (min === undefined || min <= 0) return 'Variável'
  const h = Math.floor(min / 60)
  const m = min % 60
  if (h === 0) return `${m}min`
  if (m === 0) return `${h}h`
  return `${h}h${String(m).padStart(2, '0')}`
}

/* ---- Valor ---- */

/**
 * Formata o valor de um serviço.
 *  - 'faixa' com valorBaseMax → "R$ 50,00 a R$ 80,00"
 *  - demais casos → formatCurrency(valorBase)
 */
export function formatValorServico(s: Servico): string {
  if (s.tipoValor === 'faixa' && s.valorBaseMax !== undefined) {
    return `${formatCurrency(s.valorBase)} a ${formatCurrency(s.valorBaseMax)}`
  }
  return formatCurrency(s.valorBase)
}

/* ---- Relatório ao cliente ---- */

/** Texto padrão do rodapé do relatório enviado ao cliente. */
export const RELATORIO_TEXTO_PADRAO =
  'Seu serviço foi concluído. Confira abaixo o resumo do que foi executado pela equipe ' +
  'Cleanox. Caso identifique qualquer falha, intercorrência ou ponto que precise de revisão, ' +
  'entre em contato em até 3 dias após a execução para análise e possível correção.'

/** Prazo padrão (em dias) para o cliente relatar intercorrências. */
export const RELATORIO_PRAZO_DIAS = 3
