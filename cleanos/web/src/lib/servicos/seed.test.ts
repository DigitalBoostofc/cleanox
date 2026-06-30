import { describe, it, expect } from 'vitest'
import { SERVICOS_SEED } from './seed'
import { parseTempoMedio } from './labels'

describe('SERVICOS_SEED integridade', () => {
  it('total de 32 serviços', () => {
    expect(SERVICOS_SEED).toHaveLength(32)
  })

  it('15 veiculares', () => {
    const veic = SERVICOS_SEED.filter((s) => s.categoria === 'veicular')
    expect(veic).toHaveLength(15)
  })

  it('17 residenciais', () => {
    const resid = SERVICOS_SEED.filter((s) => s.categoria === 'residencial')
    expect(resid).toHaveLength(17)
  })

  it('IDs únicos (sem duplicata)', () => {
    const ids = SERVICOS_SEED.map((s) => s.id)
    const uniq = new Set(ids)
    expect(uniq.size).toBe(ids.length)
  })

  it('todos os IDs são strings não-vazias', () => {
    SERVICOS_SEED.forEach((s) => {
      expect(typeof s.id).toBe('string')
      expect(s.id.length).toBeGreaterThan(0)
    })
  })

  it('tempoMedioMin coerente com tempoMedioLabel (limite superior)', () => {
    SERVICOS_SEED.forEach((s) => {
      const expected = parseTempoMedio(s.tempoMedioLabel)
      expect(s.tempoMedioMin).toBe(expected)
    })
  })

  it('serviços do tipo faixa têm valorBaseMax definido', () => {
    const faixa = SERVICOS_SEED.filter((s) => s.tipoValor === 'faixa')
    faixa.forEach((s) => {
      expect(s.valorBaseMax).toBeDefined()
      expect(s.valorBaseMax).toBeGreaterThan(s.valorBase)
    })
  })

  it('valorBase sempre > 0', () => {
    SERVICOS_SEED.forEach((s) => {
      expect(s.valorBase).toBeGreaterThan(0)
    })
  })

  it('todos têm campos obrigatórios (nome, categoria, grupo, tipoValor, status)', () => {
    SERVICOS_SEED.forEach((s) => {
      expect(s.nome).toBeTruthy()
      expect(s.categoria).toMatch(/^(veicular|residencial)$/)
      expect(s.grupo).toBeTruthy()
      expect(s.tipoValor).toMatch(/^(fixo|faixa|variavel)$/)
      expect(s.status).toMatch(/^(ativo|inativo)$/)
    })
  })

  it('adicionaisRelacionados é array (nunca undefined)', () => {
    SERVICOS_SEED.forEach((s) => {
      expect(Array.isArray(s.adicionaisRelacionados)).toBe(true)
    })
  })

  it('checklistPadrao é array (nunca undefined)', () => {
    SERVICOS_SEED.forEach((s) => {
      expect(Array.isArray(s.checklistPadrao)).toBe(true)
    })
  })

  it('itens do checklist têm id, titulo e ordem', () => {
    SERVICOS_SEED.forEach((s) => {
      s.checklistPadrao.forEach((item) => {
        expect(item.id).toBeTruthy()
        expect(item.titulo).toBeTruthy()
        expect(typeof item.ordem).toBe('number')
        expect(item.ordem).toBeGreaterThan(0)
      })
    })
  })

  it('IDs dos itens de checklist são únicos dentro do mesmo serviço', () => {
    SERVICOS_SEED.forEach((s) => {
      const ids = s.checklistPadrao.map((i) => i.id)
      const uniq = new Set(ids)
      expect(uniq.size).toBe(ids.length)
    })
  })

  it('serviço svc_resid_poltrona é faixa 50→80', () => {
    const poltrona = SERVICOS_SEED.find((s) => s.id === 'svc_resid_poltrona')
    expect(poltrona).toBeDefined()
    expect(poltrona!.tipoValor).toBe('faixa')
    expect(poltrona!.valorBase).toBe(50)
    expect(poltrona!.valorBaseMax).toBe(80)
  })

  it('serviços de tipo "Variável" têm tempoMedioMin undefined', () => {
    const variaveis = SERVICOS_SEED.filter((s) => s.tempoMedioLabel === 'Variável')
    expect(variaveis.length).toBeGreaterThan(0)
    variaveis.forEach((s) => {
      expect(s.tempoMedioMin).toBeUndefined()
    })
  })
})
