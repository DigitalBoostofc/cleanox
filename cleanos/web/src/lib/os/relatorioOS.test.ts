import { describe, it, expect } from 'vitest'
import { buildRelatorioOS, buildWhatsAppMessage } from './relatorioOS'
import type {
  ServiceSnapshot,
  ServicoAdicionalOS,
  ChecklistExecItem,
  ObservacaoProfissional,
} from '../servicos/types'

// ---- Fixtures ----

const SNAPSHOT: ServiceSnapshot = {
  serviceId: 'svc_test',
  nome: 'Cleanox Essencial',
  categoria: 'veicular',
  grupo: 'plano',
  valorBase: 150,
  tipoValor: 'fixo',
  tempoMedioLabel: '1h30 a 2h',
  tempoMedioMin: 120,
  checklistPadrao: [
    { id: 'chk_1', titulo: 'Fotos de antes', ordem: 1 },
    { id: 'chk_2', titulo: 'Conferência final', ordem: 2 },
  ],
  orientacoesPosServico: 'Tempo de secagem de 2 a 6 horas.',
  capturedAt: '2025-06-30T10:00:00.000Z',
}

function makeAdicional(
  id: string,
  nome: string,
  valor: number,
  quantidade: number,
  aprovacao: ServicoAdicionalOS['aprovacao'],
): ServicoAdicionalOS {
  return { id, nome, valor, tipoValor: 'fixo', quantidade, aprovacao }
}

function makeObs(
  id: string,
  texto: string,
  visivelCliente: boolean,
): ObservacaoProfissional {
  return { id, texto, visivelCliente, criadoEm: '2025-06-30T11:00:00.000Z' }
}

const BASE_INPUT = {
  osId: 'os_abc123',
  numeroOS: '42',
  clienteNome: 'Carlos Silva',
  dataHora: '2025-06-30 10:00:00.000Z',
  snapshot: SNAPSHOT,
  adicionais: [] as ServicoAdicionalOS[],
  checklist: [] as ChecklistExecItem[],
  evidencias: [],
  observacoes: [] as ObservacaoProfissional[],
}

// ---- buildRelatorioOS ----

describe('buildRelatorioOS', () => {
  it('osId e clienteNome passados corretamente', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    expect(rel.osId).toBe('os_abc123')
    expect(rel.clienteNome).toBe('Carlos Silva')
  })

  it('observacoesVisiveis filtra apenas visivelCliente === true', () => {
    const obs = [
      makeObs('obs_1', 'Visível ao cliente', true),
      makeObs('obs_2', 'Só interna', false),
      makeObs('obs_3', 'Também visível', true),
    ]
    const rel = buildRelatorioOS({ ...BASE_INPUT, observacoes: obs })
    expect(rel.observacoesVisiveis).toHaveLength(2)
    expect(rel.observacoesVisiveis.map((o) => o.id)).toEqual(['obs_1', 'obs_3'])
  })

  it('observacoesVisiveis vazio quando nenhuma é visível', () => {
    const obs = [makeObs('obs_1', 'Interna', false)]
    const rel = buildRelatorioOS({ ...BASE_INPUT, observacoes: obs })
    expect(rel.observacoesVisiveis).toHaveLength(0)
  })

  it('valorPrincipal = snapshot.valorBase', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    expect(rel.valorPrincipal).toBe(SNAPSHOT.valorBase)
  })

  it('valorAdicionais = soma só dos cobráveis (aprovado/nao_requer)', () => {
    const adicionais = [
      makeAdicional('a1', 'Extra A', 50, 1, 'aprovado'),
      makeAdicional('a2', 'Extra B', 30, 2, 'nao_requer'),
      makeAdicional('a3', 'Extra C', 100, 1, 'aguardando'),
      makeAdicional('a4', 'Extra D', 200, 1, 'recusado'),
    ]
    const rel = buildRelatorioOS({ ...BASE_INPUT, adicionais })
    // 50 + 60 = 110
    expect(rel.valorAdicionais).toBe(110)
  })

  it('adicionais no relatório contém só os cobráveis', () => {
    const adicionais = [
      makeAdicional('a1', 'Aprovado', 50, 1, 'aprovado'),
      makeAdicional('a2', 'Aguardando', 30, 1, 'aguardando'),
      makeAdicional('a3', 'Recusado', 20, 1, 'recusado'),
      makeAdicional('a4', 'Nao requer', 10, 1, 'nao_requer'),
    ]
    const rel = buildRelatorioOS({ ...BASE_INPUT, adicionais })
    expect(rel.adicionais).toHaveLength(2)
    expect(rel.adicionais.map((a) => a.id)).toEqual(['a1', 'a4'])
  })

  it('valorTotal = calcTotalOS (principal + cobráveis - descontos)', () => {
    const adicionais = [
      makeAdicional('a1', 'Extra', 50, 1, 'aprovado'),
    ]
    // 150 + 50 - 20 = 180
    const rel = buildRelatorioOS({ ...BASE_INPUT, adicionais, descontos: 20 })
    expect(rel.valorTotal).toBe(180)
  })

  it('valorTotal nunca negativo (desconto maior que total)', () => {
    const rel = buildRelatorioOS({ ...BASE_INPUT, descontos: 9999 })
    expect(rel.valorTotal).toBe(0)
  })

  it('textoPadrao está preenchido', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    expect(rel.textoPadrao).toBeTruthy()
    expect(rel.textoPadrao.length).toBeGreaterThan(10)
  })

  it('prazoIntercorrenciaDias = 3', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    expect(rel.prazoIntercorrenciaDias).toBe(3)
  })

  it('orientacoesPos vem de snapshot.orientacoesPosServico', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    expect(rel.orientacoesPos).toBe(SNAPSHOT.orientacoesPosServico)
  })

  it('geradoEm é string ISO não vazia', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    expect(rel.geradoEm).toBeTruthy()
    expect(new Date(rel.geradoEm).getTime()).toBeGreaterThan(0)
  })
})

// ---- buildWhatsAppMessage ----

describe('buildWhatsAppMessage', () => {
  it('mensagem contém nome do serviço', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    const msg = buildWhatsAppMessage(rel)
    expect(msg).toContain('Cleanox Essencial')
  })

  it('mensagem contém o total formatado', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    const msg = buildWhatsAppMessage(rel)
    // valorTotal = 150, deve aparecer "150" na mensagem
    expect(msg).toMatch(/150/)
    expect(msg).toMatch(/R\$/)
  })

  it('mensagem contém prazo de 3 dias', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    const msg = buildWhatsAppMessage(rel)
    expect(msg).toContain('3 dias')
  })

  it('mensagem contém nome do cliente', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    const msg = buildWhatsAppMessage(rel)
    expect(msg).toContain('Carlos Silva')
  })

  it('mensagem contém seção de resumo financeiro', () => {
    const rel = buildRelatorioOS(BASE_INPUT)
    const msg = buildWhatsAppMessage(rel)
    expect(msg).toContain('Resumo financeiro')
  })

  it('observações visíveis aparecem na mensagem', () => {
    const obs = [
      makeObs('o1', 'Bancos com manchas residuais removidas.', true),
      makeObs('o2', 'Nota interna irrelevante.', false),
    ]
    const rel = buildRelatorioOS({ ...BASE_INPUT, observacoes: obs })
    const msg = buildWhatsAppMessage(rel)
    expect(msg).toContain('Bancos com manchas residuais removidas.')
    expect(msg).not.toContain('Nota interna irrelevante.')
  })

  it('observações invisíveis NÃO aparecem na mensagem', () => {
    const obs = [makeObs('o1', 'Texto Secreto', false)]
    const rel = buildRelatorioOS({ ...BASE_INPUT, observacoes: obs })
    const msg = buildWhatsAppMessage(rel)
    expect(msg).not.toContain('Texto Secreto')
  })

  it('adicionais cobráveis aparecem na mensagem', () => {
    const adicionais = [makeAdicional('a1', 'Veículo muito sujo', 50, 1, 'aprovado')]
    const rel = buildRelatorioOS({ ...BASE_INPUT, adicionais })
    const msg = buildWhatsAppMessage(rel)
    expect(msg).toContain('Veículo muito sujo')
  })

  it('adicionais não cobráveis (recusado/aguardando) NÃO aparecem', () => {
    const adicionais = [
      makeAdicional('a1', 'Extra Recusado', 50, 1, 'recusado'),
      makeAdicional('a2', 'Extra Aguardando', 30, 1, 'aguardando'),
    ]
    const rel = buildRelatorioOS({ ...BASE_INPUT, adicionais })
    const msg = buildWhatsAppMessage(rel)
    expect(msg).not.toContain('Extra Recusado')
    expect(msg).not.toContain('Extra Aguardando')
  })
})
