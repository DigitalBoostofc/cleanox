import { describe, it, expect, beforeEach } from 'vitest'
import {
  listServicos,
  getServico,
  createServico,
  updateServico,
  deleteServico,
  duplicateServico,
  buildSnapshot,
  snapshotToChecklistExec,
  calcTotalOS,
  resetServicosStore,
  STORAGE_KEY,
} from './store'
import { SERVICOS_SEED } from './seed'
import type { Servico, ServicoAdicionalOS } from './types'

// --- localStorage stub (vitest usa environment: 'node', sem jsdom) ---
const _store: Record<string, string> = {}
const localStorageStub = {
  getItem: (key: string) => _store[key] ?? null,
  setItem: (key: string, val: string) => { _store[key] = val },
  removeItem: (key: string) => { delete _store[key] },
  clear: () => { for (const k in _store) delete _store[k] },
}
Object.defineProperty(globalThis, 'localStorage', {
  value: localStorageStub,
  writable: true,
})

// Helper: snapshot mínimo válido para buildSnapshot
function makeServico(overrides: Partial<Servico> = {}): Servico {
  return {
    id: 'svc_test_1',
    categoria: 'veicular',
    grupo: 'plano',
    nome: 'Serviço Teste',
    valorBase: 100,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h',
    tempoMedioMin: 60,
    status: 'ativo',
    checklistPadrao: [
      { id: 'chk_1', titulo: 'Passo A', ordem: 1 },
      { id: 'chk_2', titulo: 'Passo B', ordem: 2 },
    ],
    adicionaisRelacionados: [],
    created: '2025-01-01 00:00:00.000Z',
    updated: '2025-01-01 00:00:00.000Z',
    ...overrides,
  }
}

beforeEach(() => {
  localStorageStub.clear()
  resetServicosStore()
})

// ---- listServicos ----

describe('listServicos', () => {
  it('seed inicial retorna 32 itens', async () => {
    const list = await listServicos()
    expect(list).toHaveLength(32)
  })

  it('retorna cópia — mutar o array não altera o store', async () => {
    const list = await listServicos()
    list.push({ ...list[0], id: 'svc_intruso' })
    const list2 = await listServicos()
    expect(list2).toHaveLength(32)
  })

  it('retorna cópia — mutar um objeto não altera o store', async () => {
    const list = await listServicos()
    const original = list[0].nome
    list[0].nome = 'MUTADO'
    const list2 = await listServicos()
    expect(list2[0].nome).toBe(original)
  })
})

// ---- getServico ----

describe('getServico', () => {
  it('encontra serviço existente pelo id', async () => {
    const first = SERVICOS_SEED[0]
    const found = await getServico(first.id)
    expect(found).toBeDefined()
    expect(found!.id).toBe(first.id)
    expect(found!.nome).toBe(first.nome)
  })

  it('retorna undefined para id inexistente', async () => {
    const found = await getServico('nao_existe_xyz')
    expect(found).toBeUndefined()
  })

  it('retorna cópia — mutar não altera o store', async () => {
    const first = SERVICOS_SEED[0]
    const found = await getServico(first.id)
    found!.nome = 'MUTADO'
    const found2 = await getServico(first.id)
    expect(found2!.nome).toBe(first.nome)
  })
})

// ---- createServico ----

describe('createServico', () => {
  it('cria e gera id/created/updated', async () => {
    const input = {
      categoria: 'veicular' as const,
      grupo: 'avulsos' as const,
      nome: 'Novo serviço',
      valorBase: 80,
      tipoValor: 'fixo' as const,
      tempoMedioLabel: '30min',
      status: 'ativo' as const,
      checklistPadrao: [],
      adicionaisRelacionados: [],
    }
    const created = await createServico(input)
    expect(created.id).toBeTruthy()
    expect(created.id).toMatch(/^svc_/)
    expect(created.created).toBeTruthy()
    expect(created.updated).toBeTruthy()
    expect(created.nome).toBe('Novo serviço')
  })

  it('aumenta a contagem do catálogo em +1', async () => {
    const before = await listServicos()
    await createServico({
      categoria: 'residencial',
      grupo: 'sofa',
      nome: 'Sofá extra',
      valorBase: 200,
      tipoValor: 'fixo',
      tempoMedioLabel: '1h',
      status: 'ativo',
      checklistPadrao: [],
      adicionaisRelacionados: [],
    })
    const after = await listServicos()
    expect(after).toHaveLength(before.length + 1)
  })
})

// ---- updateServico ----

describe('updateServico', () => {
  it('atualiza campo e refaz updated', async () => {
    const first = SERVICOS_SEED[0]
    const original = await getServico(first.id)
    const updated = await updateServico(first.id, { nome: 'Nome Atualizado' })
    expect(updated.nome).toBe('Nome Atualizado')
    expect(updated.updated).not.toBe(original!.updated)
  })

  it('preserva id e created', async () => {
    const first = SERVICOS_SEED[0]
    const original = await getServico(first.id)
    const updated = await updateServico(first.id, { valorBase: 999 })
    expect(updated.id).toBe(first.id)
    expect(updated.created).toBe(original!.created)
  })

  it('lança erro se id inexistente', async () => {
    await expect(updateServico('nao_existe', { nome: 'X' })).rejects.toThrow('nao_existe')
  })
})

// ---- deleteServico ----

describe('deleteServico', () => {
  it('remove serviço existente e retorna true', async () => {
    const first = SERVICOS_SEED[0]
    const removed = await deleteServico(first.id)
    expect(removed).toBe(true)
    const found = await getServico(first.id)
    expect(found).toBeUndefined()
  })

  it('retorna false para id inexistente', async () => {
    const removed = await deleteServico('nao_existe')
    expect(removed).toBe(false)
  })

  it('diminui a contagem em -1', async () => {
    const before = await listServicos()
    await deleteServico(SERVICOS_SEED[0].id)
    const after = await listServicos()
    expect(after).toHaveLength(before.length - 1)
  })
})

// ---- duplicateServico ----

describe('duplicateServico', () => {
  it('gera novo id diferente do original', async () => {
    const original = SERVICOS_SEED[0]
    const dup = await duplicateServico(original.id)
    expect(dup.id).not.toBe(original.id)
  })

  it('nome do duplicado termina com " (cópia)"', async () => {
    const original = SERVICOS_SEED[0]
    const dup = await duplicateServico(original.id)
    expect(dup.nome).toBe(`${original.nome} (cópia)`)
  })

  it('dados de conteúdo são copiados do original', async () => {
    const original = SERVICOS_SEED[0]
    const dup = await duplicateServico(original.id)
    expect(dup.valorBase).toBe(original.valorBase)
    expect(dup.categoria).toBe(original.categoria)
  })

  it('lança erro se id inexistente', async () => {
    await expect(duplicateServico('nao_existe')).rejects.toThrow('nao_existe')
  })
})

// ---- buildSnapshot (imutabilidade) ----

describe('buildSnapshot', () => {
  it('mapeia campos do Servico para o snapshot', () => {
    const svc = makeServico()
    const snap = buildSnapshot(svc)
    expect(snap.serviceId).toBe(svc.id)
    expect(snap.nome).toBe(svc.nome)
    expect(snap.valorBase).toBe(svc.valorBase)
    expect(snap.categoria).toBe(svc.categoria)
    expect(snap.grupo).toBe(svc.grupo)
    expect(snap.tipoValor).toBe(svc.tipoValor)
    expect(snap.tempoMedioLabel).toBe(svc.tempoMedioLabel)
  })

  it('capturedAt é preenchido', () => {
    const snap = buildSnapshot(makeServico())
    expect(snap.capturedAt).toBeTruthy()
    expect(new Date(snap.capturedAt).getTime()).toBeGreaterThan(0)
  })

  it('IMUTABILIDADE: mutar o Servico após buildSnapshot NÃO altera o snapshot', () => {
    const svc = makeServico()
    const snap = buildSnapshot(svc)
    svc.nome = 'MUTADO_DEPOIS'
    expect(snap.nome).toBe('Serviço Teste')
  })

  it('IMUTABILIDADE: checklistPadrao é cópia profunda — mutar o original não altera o snapshot', () => {
    const svc = makeServico()
    const snap = buildSnapshot(svc)
    svc.checklistPadrao[0].titulo = 'MUTADO'
    expect(snap.checklistPadrao[0].titulo).toBe('Passo A')
  })

  it('IMUTABILIDADE: mutar o checklistPadrao do snapshot não altera o Servico original', () => {
    const svc = makeServico()
    const snap = buildSnapshot(svc)
    snap.checklistPadrao[0].titulo = 'MUTADO_SNAP'
    expect(svc.checklistPadrao[0].titulo).toBe('Passo A')
  })

  it('observacaoTecnica vem de servico.observacao', () => {
    const svc = makeServico({ observacao: 'Obs técnica' })
    const snap = buildSnapshot(svc)
    expect(snap.observacaoTecnica).toBe('Obs técnica')
  })

  it('orientações pré/pós mapeadas corretamente', () => {
    const svc = makeServico({ orientacoesPre: 'Antes', orientacoesPos: 'Depois' })
    const snap = buildSnapshot(svc)
    expect(snap.orientacoesPreServico).toBe('Antes')
    expect(snap.orientacoesPosServico).toBe('Depois')
  })
})

// ---- snapshotToChecklistExec ----

describe('snapshotToChecklistExec', () => {
  it('cada item começa como "pendente"', () => {
    const svc = makeServico()
    const snap = buildSnapshot(svc)
    const items = snapshotToChecklistExec(snap)
    expect(items.every((i) => i.status === 'pendente')).toBe(true)
  })

  it('ordem preservada (sort por campo ordem)', () => {
    const svc = makeServico({
      checklistPadrao: [
        { id: 'c3', titulo: 'Terceiro', ordem: 3 },
        { id: 'c1', titulo: 'Primeiro', ordem: 1 },
        { id: 'c2', titulo: 'Segundo', ordem: 2 },
      ],
    })
    const snap = buildSnapshot(svc)
    const items = snapshotToChecklistExec(snap)
    expect(items[0].titulo).toBe('Primeiro')
    expect(items[1].titulo).toBe('Segundo')
    expect(items[2].titulo).toBe('Terceiro')
  })

  it('títulos preservados do checklist padrão', () => {
    const svc = makeServico()
    const snap = buildSnapshot(svc)
    const items = snapshotToChecklistExec(snap)
    expect(items[0].titulo).toBe('Passo A')
    expect(items[1].titulo).toBe('Passo B')
  })

  it('checklist vazio → lista vazia', () => {
    const svc = makeServico({ checklistPadrao: [] })
    const snap = buildSnapshot(svc)
    expect(snapshotToChecklistExec(snap)).toEqual([])
  })

  it('cada item recebe um id gerado', () => {
    const svc = makeServico()
    const snap = buildSnapshot(svc)
    const items = snapshotToChecklistExec(snap)
    expect(items[0].id).toBeTruthy()
    expect(items[1].id).toBeTruthy()
    expect(items[0].id).not.toBe(items[1].id)
  })
})

// ---- calcTotalOS ----

describe('calcTotalOS', () => {
  const makeAdicional = (
    valor: number,
    quantidade: number,
    aprovacao: ServicoAdicionalOS['aprovacao'],
  ): ServicoAdicionalOS => ({
    id: 'add_1',
    nome: 'Extra',
    valor,
    tipoValor: 'fixo',
    quantidade,
    aprovacao,
  })

  it('sem adicionais — retorna valorPrincipal', () => {
    expect(calcTotalOS(200, [])).toBe(200)
  })

  it('adicional aprovado conta', () => {
    expect(calcTotalOS(100, [makeAdicional(50, 1, 'aprovado')])).toBe(150)
  })

  it('adicional nao_requer conta', () => {
    expect(calcTotalOS(100, [makeAdicional(30, 2, 'nao_requer')])).toBe(160)
  })

  it('adicional aguardando NÃO conta', () => {
    expect(calcTotalOS(100, [makeAdicional(50, 1, 'aguardando')])).toBe(100)
  })

  it('adicional recusado NÃO conta', () => {
    expect(calcTotalOS(100, [makeAdicional(50, 1, 'recusado')])).toBe(100)
  })

  it('mistura: só aprovado/nao_requer contam', () => {
    const adicionais = [
      makeAdicional(50, 1, 'aprovado'),
      makeAdicional(30, 1, 'nao_requer'),
      makeAdicional(100, 1, 'aguardando'),
      makeAdicional(200, 1, 'recusado'),
    ]
    expect(calcTotalOS(100, adicionais)).toBe(180)
  })

  it('desconto subtraído do total', () => {
    expect(calcTotalOS(200, [], 20)).toBe(180)
  })

  it('desconto maior que total → nunca negativo (min 0)', () => {
    expect(calcTotalOS(50, [], 100)).toBe(0)
  })

  it('desconto padrão 0 quando não informado', () => {
    expect(calcTotalOS(150, [])).toBe(150)
  })

  it('quantidade × valor multiplicados corretamente', () => {
    expect(calcTotalOS(0, [makeAdicional(25, 3, 'aprovado')])).toBe(75)
  })

  it('lista vazia retorna 0 quando principal é 0', () => {
    expect(calcTotalOS(0, [])).toBe(0)
  })
})
