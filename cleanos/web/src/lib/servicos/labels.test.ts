import { describe, it, expect } from 'vitest'
import {
  parseTempoMedio,
  formatTempoMedio,
  formatValorServico,
} from './labels'
import type { Servico } from './types'

// ---- parseTempoMedio ----

describe('parseTempoMedio', () => {
  it('"1h30 a 2h" → 120 (limite superior)', () => {
    expect(parseTempoMedio('1h30 a 2h')).toBe(120)
  })

  it('"40min a 1h" → 60 (limite superior é 1h)', () => {
    expect(parseTempoMedio('40min a 1h')).toBe(60)
  })

  it('"20min a 40min" → 40', () => {
    expect(parseTempoMedio('20min a 40min')).toBe(40)
  })

  it('"3h+" → 180', () => {
    expect(parseTempoMedio('3h+')).toBe(180)
  })

  it('"3h a 4h" → 240 (4h)', () => {
    expect(parseTempoMedio('3h a 4h')).toBe(240)
  })

  it('"2h a 3h" → 180 (3h)', () => {
    expect(parseTempoMedio('2h a 3h')).toBe(180)
  })

  it('"1h" → 60', () => {
    expect(parseTempoMedio('1h')).toBe(60)
  })

  it('"2h" → 120', () => {
    expect(parseTempoMedio('2h')).toBe(120)
  })

  it('"30min a 1h" → 60', () => {
    expect(parseTempoMedio('30min a 1h')).toBe(60)
  })

  it('"1h30 a 2h30" → 150', () => {
    expect(parseTempoMedio('1h30 a 2h30')).toBe(150)
  })

  it('"2h a 2h30" → 150', () => {
    expect(parseTempoMedio('2h a 2h30')).toBe(150)
  })

  it('"Variável" → undefined', () => {
    expect(parseTempoMedio('Variável')).toBeUndefined()
  })

  it('"variavel" (sem acento, minúsculo) → undefined', () => {
    expect(parseTempoMedio('variavel')).toBeUndefined()
  })

  it('"" (string vazia) → undefined', () => {
    expect(parseTempoMedio('')).toBeUndefined()
  })

  it('"10min a 20min" → 20', () => {
    expect(parseTempoMedio('10min a 20min')).toBe(20)
  })

  it('"15min a 25min" → 25', () => {
    expect(parseTempoMedio('15min a 25min')).toBe(25)
  })
})

// ---- formatTempoMedio ----

describe('formatTempoMedio', () => {
  it('prefere o label humano quando fornecido', () => {
    expect(formatTempoMedio(60, '1h a 1h30')).toBe('1h a 1h30')
  })

  it('label vazio → deriva dos minutos', () => {
    expect(formatTempoMedio(60, '')).toBe('1h')
  })

  it('label undefined → deriva dos minutos', () => {
    expect(formatTempoMedio(90)).toBe('1h30')
  })

  it('min=0 e sem label → "Variável"', () => {
    expect(formatTempoMedio(0)).toBe('Variável')
  })

  it('min undefined e sem label → "Variável"', () => {
    expect(formatTempoMedio(undefined)).toBe('Variável')
  })

  it('45 min → "45min"', () => {
    expect(formatTempoMedio(45)).toBe('45min')
  })

  it('120 min → "2h"', () => {
    expect(formatTempoMedio(120)).toBe('2h')
  })

  it('75 min → "1h15"', () => {
    expect(formatTempoMedio(75)).toBe('1h15')
  })

  it('label só espaços → deriva dos minutos', () => {
    expect(formatTempoMedio(60, '   ')).toBe('1h')
  })
})

// ---- formatValorServico ----

describe('formatValorServico', () => {
  const base: Omit<Servico, 'id' | 'created' | 'updated'> = {
    categoria: 'residencial',
    grupo: 'outros',
    nome: 'Teste',
    valorBase: 50,
    tipoValor: 'fixo',
    tempoMedioLabel: '30min',
    status: 'ativo',
    checklistPadrao: [],
    adicionaisRelacionados: [],
  }

  it('faixa com valorBaseMax → "R$ X,XX a R$ Y,YY"', () => {
    const svc: Servico = {
      ...base,
      id: 'test_faixa',
      tipoValor: 'faixa',
      valorBase: 50,
      valorBaseMax: 80,
      created: '',
      updated: '',
    }
    const result = formatValorServico(svc)
    // Deve conter "a" separando dois valores em R$
    expect(result).toMatch(/R\$/)
    expect(result).toContain(' a ')
    expect(result).toMatch(/50/)
    expect(result).toMatch(/80/)
  })

  it('fixo → formatCurrency simples', () => {
    const svc: Servico = {
      ...base,
      id: 'test_fixo',
      tipoValor: 'fixo',
      valorBase: 150,
      created: '',
      updated: '',
    }
    const result = formatValorServico(svc)
    expect(result).toMatch(/R\$/)
    expect(result).toMatch(/150/)
    expect(result).not.toContain(' a ')
  })

  it('faixa sem valorBaseMax → usa formatCurrency simples (fallback)', () => {
    const svc: Servico = {
      ...base,
      id: 'test_faixa_sem_max',
      tipoValor: 'faixa',
      valorBase: 70,
      created: '',
      updated: '',
    }
    const result = formatValorServico(svc)
    expect(result).toMatch(/R\$/)
    expect(result).toMatch(/70/)
    expect(result).not.toContain(' a ')
  })

  it('variavel → formatCurrency do valorBase', () => {
    const svc: Servico = {
      ...base,
      id: 'test_var',
      tipoValor: 'variavel',
      valorBase: 30,
      created: '',
      updated: '',
    }
    const result = formatValorServico(svc)
    expect(result).toMatch(/R\$/)
    expect(result).toMatch(/30/)
  })
})
