import { describe, it, expect } from 'vitest'
import { formatCurrency } from '../collections'
import type {
  ContaTipo,
  Lancamento,
  LancamentoStatus,
  OrigemLancamento,
  RecorrenciaTipo,
} from './types'
import {
  contaTipoLabel,
  formatSigned,
  origemLabel,
  recorrenciaLabel,
  signedValue,
  statusLabel,
  statusTone,
  tipoLancamentoLabel,
} from './labels'

/** Lançamento mínimo válido; sobrescreva tipo/valor por teste. */
function makeLanc(over: Partial<Lancamento> = {}): Lancamento {
  return {
    id: 'lanc_x',
    tipo: 'receita',
    descricao: 'Teste',
    categoriaId: 'cat_x',
    valor: 100,
    contaId: 'conta_x',
    data: '2026-06-10T12:00:00.000Z',
    status: 'pago',
    recorrencia: 'unica',
    origem: 'manual',
    created: '2026-06-10T12:00:00.000Z',
    updated: '2026-06-10T12:00:00.000Z',
    ...over,
  }
}

// ---- signedValue ----

describe('signedValue', () => {
  it('receita → valor POSITIVO', () => {
    expect(signedValue(makeLanc({ tipo: 'receita', valor: 300 }))).toBe(300)
  })

  it('despesa → valor NEGATIVO', () => {
    expect(signedValue(makeLanc({ tipo: 'despesa', valor: 980 }))).toBe(-980)
  })

  it('preserva centavos com o sinal', () => {
    expect(signedValue(makeLanc({ tipo: 'despesa', valor: 155.34 }))).toBeCloseTo(-155.34, 2)
    expect(signedValue(makeLanc({ tipo: 'receita', valor: 99.9 }))).toBeCloseTo(99.9, 2)
  })

  it('valor zero não ganha sinal negativo perceptível', () => {
    expect(signedValue(makeLanc({ tipo: 'despesa', valor: 0 }))).toBe(-0)
    expect(signedValue(makeLanc({ tipo: 'receita', valor: 0 }))).toBe(0)
  })
})

// ---- formatSigned ----

describe('formatSigned', () => {
  it('receita começa com "+" e usa formatCurrency', () => {
    const l = makeLanc({ tipo: 'receita', valor: 300 })
    expect(formatSigned(l)).toBe(`+${formatCurrency(300)}`)
  })

  it('despesa começa com "−" (U+2212) e usa formatCurrency', () => {
    const l = makeLanc({ tipo: 'despesa', valor: 980 })
    expect(formatSigned(l)).toBe(`−${formatCurrency(980)}`)
  })

  it('o sinal é a primeira posição da string', () => {
    expect(formatSigned(makeLanc({ tipo: 'receita', valor: 10 })).startsWith('+')).toBe(true)
    expect(formatSigned(makeLanc({ tipo: 'despesa', valor: 10 })).startsWith('−')).toBe(true)
  })

  it('mantém os dígitos do valor formatado', () => {
    expect(formatSigned(makeLanc({ tipo: 'despesa', valor: 155.34 }))).toMatch(/155/)
    expect(formatSigned(makeLanc({ tipo: 'despesa', valor: 155.34 }))).toContain(',')
  })
})

// ---- statusTone ----

describe('statusTone', () => {
  it('pago → success', () => {
    expect(statusTone('pago')).toBe('success')
  })

  it('pendente → warning', () => {
    expect(statusTone('pendente')).toBe('warning')
  })

  it('previsto → info', () => {
    expect(statusTone('previsto')).toBe('info')
  })

  it('em_atraso → error', () => {
    expect(statusTone('em_atraso')).toBe('error')
  })

  it('cobre todos os status do union (mapeamento total)', () => {
    const todos: LancamentoStatus[] = ['pago', 'pendente', 'previsto', 'em_atraso']
    for (const s of todos) {
      expect(['success', 'warning', 'info', 'error']).toContain(statusTone(s))
    }
  })
})

// ---- recorrenciaLabel ----

describe('recorrenciaLabel', () => {
  it('mapeia cada recorrência ao rótulo PT-BR', () => {
    const esperado: Record<RecorrenciaTipo, string> = {
      unica: 'Única',
      fixa: 'Fixa',
      recorrente: 'Recorrente',
      parcelada: 'Parcelada',
    }
    for (const [chave, label] of Object.entries(esperado) as [RecorrenciaTipo, string][]) {
      expect(recorrenciaLabel(chave)).toBe(label)
    }
  })
})

// ---- statusLabel ----

describe('statusLabel', () => {
  it('mapeia cada status ao rótulo PT-BR (em_atraso → "Em atraso")', () => {
    const esperado: Record<LancamentoStatus, string> = {
      pago: 'Pago',
      pendente: 'Pendente',
      previsto: 'Previsto',
      em_atraso: 'Em atraso',
    }
    for (const [chave, label] of Object.entries(esperado) as [LancamentoStatus, string][]) {
      expect(statusLabel(chave)).toBe(label)
    }
  })
})

// ---- origemLabel ----

describe('origemLabel', () => {
  it('mapeia manual/via_os aos rótulos PT-BR', () => {
    const esperado: Record<OrigemLancamento, string> = {
      manual: 'Manual',
      via_os: 'Via OS',
    }
    for (const [chave, label] of Object.entries(esperado) as [OrigemLancamento, string][]) {
      expect(origemLabel(chave)).toBe(label)
    }
  })
})

// ---- contaTipoLabel ----

describe('contaTipoLabel', () => {
  it('mapeia cada tipo de conta ao rótulo PT-BR', () => {
    const esperado: Record<ContaTipo, string> = {
      carteira: 'Carteira',
      banco: 'Banco',
      cartao: 'Cartão',
      caixa: 'Caixa',
    }
    for (const [chave, label] of Object.entries(esperado) as [ContaTipo, string][]) {
      expect(contaTipoLabel(chave)).toBe(label)
    }
  })
})

// ---- tipoLancamentoLabel (cobertura do contrato) ----

describe('tipoLancamentoLabel', () => {
  it('receita → "Receita" · despesa → "Despesa"', () => {
    expect(tipoLancamentoLabel('receita')).toBe('Receita')
    expect(tipoLancamentoLabel('despesa')).toBe('Despesa')
  })
})
