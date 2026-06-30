// @vitest-environment node
import { describe, it, expect, beforeEach } from 'vitest'
import {
  STORAGE_KEYS,
  resetFinanceiroStore,
  // Lançamentos
  listLancamentos,
  getLancamento,
  createLancamento,
  updateLancamento,
  deleteLancamento,
  duplicateLancamento,
  repeatLancamento,
  // Contas
  listContas,
  getConta,
  createConta,
  updateConta,
  deleteConta,
  // Categorias
  listCategorias,
  getCategoria,
  createCategoria,
  updateCategoria,
  deleteCategoria,
  // Limites
  listLimites,
  getLimite,
  createLimite,
  updateLimite,
  deleteLimite,
  // Derivações puras
  mesPeriodo,
  lancamentosDoPeriodo,
  resumoPeriodo,
  saldoGeral,
  agruparPorData,
  contasAPagar,
  contasAReceber,
  gastoPorCategoria,
  progressoLimite,
} from './store'
import { CONTAS_SEED, CATEGORIAS_SEED, LANCAMENTOS_SEED, LIMITES_SEED } from './seed'
import type {
  CategoriaInput,
  ContaInput,
  LancamentoInput,
  LimiteGasto,
  LimiteInput,
} from './types'

/* ============================================================
 * Stub de localStorage (env node — não há Web Storage).
 *
 * O store (financeiro/store.ts) usa `localStorage` quando disponível e cai num
 * fallback em memória quando não. Aqui instalamos um stub Map-backed FRESCO a
 * cada teste, exercendo de fato o caminho de persistência real (getRaw/setRaw),
 * e garantindo isolamento entre os casos. Espelha a abordagem de isolar a camada
 * de dados de src/lib/servicos/store.test.ts (lá via mock do pb).
 * ============================================================ */

class LocalStorageStub {
  private map = new Map<string, string>()
  get length(): number {
    return this.map.size
  }
  clear(): void {
    this.map.clear()
  }
  getItem(key: string): string | null {
    return this.map.has(key) ? this.map.get(key)! : null
  }
  key(index: number): string | null {
    return Array.from(this.map.keys())[index] ?? null
  }
  removeItem(key: string): void {
    this.map.delete(key)
  }
  setItem(key: string, value: string): void {
    this.map.set(key, String(value))
  }
}

beforeEach(() => {
  globalThis.localStorage = new LocalStorageStub() as unknown as Storage
  resetFinanceiroStore()
})

/* ---- Builders de input mínimos válidos ---- */

function lancInput(over: Partial<LancamentoInput> = {}): LancamentoInput {
  return {
    tipo: 'despesa',
    descricao: 'Novo lançamento',
    categoriaId: 'cat_outros',
    valor: 50,
    contaId: 'conta_carteira',
    data: '2026-06-15T10:00:00.000Z',
    status: 'pago',
    recorrencia: 'unica',
    origem: 'manual',
    ...over,
  }
}

function contaInput(over: Partial<ContaInput> = {}): ContaInput {
  return {
    nome: 'Nova conta',
    tipo: 'banco',
    saldoInicial: 1000,
    saldoAtual: 1000,
    ativo: true,
    ...over,
  }
}

function categoriaInput(over: Partial<CategoriaInput> = {}): CategoriaInput {
  return {
    nome: 'Nova categoria',
    tipo: 'despesa',
    icone: 'circle-dashed',
    cor: '#9CA3AF',
    arquivada: false,
    ...over,
  }
}

function limiteInput(over: Partial<LimiteInput> = {}): LimiteInput {
  return {
    categoriaId: 'cat_outros',
    limite: 500,
    ...over,
  }
}

const REF = '2026-06-30' // data de referência fixa para contas a pagar/receber
const JUNHO = mesPeriodo(2026, 5) // month 0-based: 5 = junho

/* ============================================================
 * Seed inicial
 * ============================================================ */

describe('seed inicial', () => {
  it('5 contas', async () => {
    expect(await listContas()).toHaveLength(5)
  })
  it('34 categorias', async () => {
    expect(await listCategorias()).toHaveLength(34)
  })
  it('20 lançamentos', async () => {
    expect(await listLancamentos()).toHaveLength(20)
  })
  it('6 limites', async () => {
    expect(await listLimites()).toHaveLength(6)
  })
  it('persiste o seed no localStorage na primeira leitura', async () => {
    expect(globalThis.localStorage.getItem(STORAGE_KEYS.lancamentos)).toBeNull()
    await listLancamentos()
    expect(globalThis.localStorage.getItem(STORAGE_KEYS.lancamentos)).not.toBeNull()
  })
})

/* ============================================================
 * CRUD — Lançamentos
 * ============================================================ */

describe('CRUD lancamentos', () => {
  it('create gera id/created/updated e soma +1', async () => {
    const before = await listLancamentos()
    const novo = await createLancamento(lancInput({ descricao: 'Café' }))
    expect(novo.id).toBeTruthy()
    expect(novo.created).toBeTruthy()
    expect(novo.updated).toBeTruthy()
    expect(novo.descricao).toBe('Café')
    expect(await listLancamentos()).toHaveLength(before.length + 1)
  })

  it('get encontra por id e undefined p/ inexistente', async () => {
    const found = await getLancamento('lanc_seed_01')
    expect(found?.descricao).toBe('OS #000245 - Cleanox Premium')
    expect(await getLancamento('nao_existe')).toBeUndefined()
  })

  it('list devolve cópia — mutar o array não afeta o store', async () => {
    const l1 = await listLancamentos()
    l1.push({ ...l1[0], id: 'intruso' })
    expect(await listLancamentos()).toHaveLength(20)
  })

  it('list devolve cópia — mutar um objeto não afeta o store', async () => {
    const l1 = await listLancamentos()
    l1[0].descricao = 'MUTADO'
    const l2 = await listLancamentos()
    expect(l2[0].descricao).not.toBe('MUTADO')
  })

  it('update altera campo + refaz updated e preserva id/created', async () => {
    const original = await getLancamento('lanc_seed_01')
    const upd = await updateLancamento('lanc_seed_01', { valor: 999 })
    expect(upd.valor).toBe(999)
    expect(upd.id).toBe('lanc_seed_01')
    expect(upd.created).toBe(original!.created)
    expect(upd.updated).not.toBe(original!.updated)
  })

  it('update rejeita id inexistente', async () => {
    await expect(updateLancamento('nao_existe', { valor: 1 })).rejects.toThrow()
  })

  it('delete remove e retorna true; false p/ inexistente', async () => {
    expect(await deleteLancamento('lanc_seed_01')).toBe(true)
    expect(await getLancamento('lanc_seed_01')).toBeUndefined()
    expect(await listLancamentos()).toHaveLength(19)
    expect(await deleteLancamento('nao_existe')).toBe(false)
  })
})

/* ---- duplicate / repeat ---- */

describe('duplicateLancamento', () => {
  it('gera novo id e sufixo " (cópia)" copiando o conteúdo', async () => {
    const dup = await duplicateLancamento('lanc_seed_09')
    expect(dup.id).not.toBe('lanc_seed_09')
    expect(dup.descricao).toBe('Fornecedor CleanTech (cópia)')
    expect(dup.valor).toBe(980)
    expect(dup.categoriaId).toBe('cat_produtos')
    expect(await listLancamentos()).toHaveLength(21)
  })

  it('lança erro p/ id inexistente', async () => {
    await expect(duplicateLancamento('nao_existe')).rejects.toThrow('nao_existe')
  })
})

describe('repeatLancamento', () => {
  it('reinicia status como "previsto"', async () => {
    const prox = await repeatLancamento('lanc_seed_09') // era pago
    expect(prox.status).toBe('previsto')
  })

  it('parcelada avança parcelaAtual (+1)', async () => {
    // lanc_seed_17: parcelada, parcelaAtual 1, parcelasTotal 10
    const prox = await repeatLancamento('lanc_seed_17')
    expect(prox.recorrencia).toBe('parcelada')
    expect(prox.parcelaAtual).toBe(2)
    expect(prox.parcelasTotal).toBe(10)
  })

  it('não-parcelada mantém parcelaAtual indefinido', async () => {
    const prox = await repeatLancamento('lanc_seed_09')
    expect(prox.parcelaAtual).toBeUndefined()
  })

  it('overrides são aplicados (ex.: nova data/vencimento)', async () => {
    const prox = await repeatLancamento('lanc_seed_17', {
      data: '2026-07-01T10:00:00.000Z',
      vencimento: '2026-07-01',
    })
    expect(prox.data).toBe('2026-07-01T10:00:00.000Z')
    expect(prox.vencimento).toBe('2026-07-01')
    expect(prox.status).toBe('previsto')
  })

  it('lança erro p/ id inexistente', async () => {
    await expect(repeatLancamento('nao_existe')).rejects.toThrow('nao_existe')
  })
})

/* ============================================================
 * CRUD — Contas
 * ============================================================ */

describe('CRUD contas', () => {
  it('create soma +1 e gera id', async () => {
    const novo = await createConta(contaInput({ nome: 'C6 Bank' }))
    expect(novo.id).toBeTruthy()
    expect(novo.nome).toBe('C6 Bank')
    expect(await listContas()).toHaveLength(6)
  })
  it('get / update / delete', async () => {
    expect((await getConta('conta_inter'))?.nome).toBe('Banco Inter')
    const upd = await updateConta('conta_inter', { saldoAtual: 7000 })
    expect(upd.saldoAtual).toBe(7000)
    expect(await deleteConta('conta_inter')).toBe(true)
    expect(await listContas()).toHaveLength(4)
    expect(await deleteConta('conta_inter')).toBe(false)
  })
})

/* ============================================================
 * CRUD — Categorias
 * ============================================================ */

describe('CRUD categorias', () => {
  it('create soma +1 e gera id', async () => {
    const nova = await createCategoria(categoriaInput({ nome: 'Seguros' }))
    expect(nova.id).toBeTruthy()
    expect(nova.nome).toBe('Seguros')
    expect(await listCategorias()).toHaveLength(35)
  })
  it('get / update / delete', async () => {
    expect((await getCategoria('cat_marketing'))?.nome).toBe('Marketing')
    const upd = await updateCategoria('cat_marketing', { arquivada: true })
    expect(upd.arquivada).toBe(true)
    expect(await deleteCategoria('cat_marketing')).toBe(true)
    expect(await listCategorias()).toHaveLength(33)
    expect(await deleteCategoria('cat_marketing')).toBe(false)
  })
})

/* ============================================================
 * CRUD — Limites
 * ============================================================ */

describe('CRUD limites', () => {
  it('create soma +1 e gera id', async () => {
    const novo = await createLimite(limiteInput({ categoriaId: 'cat_alimentacao', limite: 300 }))
    expect(novo.id).toBeTruthy()
    expect(novo.limite).toBe(300)
    expect(await listLimites()).toHaveLength(7)
  })
  it('get / update / delete', async () => {
    expect((await getLimite('lim_produtos'))?.limite).toBe(1500)
    const upd = await updateLimite('lim_produtos', { limite: 2000 })
    expect(upd.limite).toBe(2000)
    expect(await deleteLimite('lim_produtos')).toBe(true)
    expect(await listLimites()).toHaveLength(5)
    expect(await deleteLimite('lim_produtos')).toBe(false)
  })
})

/* ============================================================
 * Derivações puras — período
 * ============================================================ */

describe('mesPeriodo', () => {
  it('junho/2026 → [2026-06-01, 2026-07-01)', () => {
    expect(mesPeriodo(2026, 5)).toEqual({ start: '2026-06-01', end: '2026-07-01' })
  })
  it('dezembro vira ano seguinte → [2026-12-01, 2027-01-01)', () => {
    expect(mesPeriodo(2026, 11)).toEqual({ start: '2026-12-01', end: '2027-01-01' })
  })
})

describe('lancamentosDoPeriodo', () => {
  it('filtra só junho (exclui a parcela de julho lanc_seed_18)', () => {
    const junho = lancamentosDoPeriodo(LANCAMENTOS_SEED, JUNHO)
    expect(junho).toHaveLength(19)
    expect(junho.some((l) => l.id === 'lanc_seed_18')).toBe(false)
  })
})

/* ============================================================
 * Derivações puras — VALORES DE CONFERÊNCIA
 * ============================================================ */

describe('resumoPeriodo (conferência jun/2026)', () => {
  const resumo = resumoPeriodo(LANCAMENTOS_SEED, JUNHO)

  it('entradas = R$ 2.230,00 (só receitas pagas)', () => {
    expect(resumo.entradas).toBeCloseTo(2230, 2)
  })
  it('saídas = R$ 7.223,74 (só despesas pagas)', () => {
    expect(resumo.saidas).toBeCloseTo(7223.74, 2)
  })
  it('saldoMes = −R$ 4.993,74', () => {
    expect(resumo.saldoMes).toBeCloseTo(-4993.74, 2)
  })
  it('ignora pendente/previsto/em_atraso (não soma reembolso pendente nem aluguel)', () => {
    // reembolso (120, pendente) e colchão (160, previsto) NÃO entram nas entradas
    expect(resumo.entradas).not.toBeCloseTo(2230 + 120 + 160, 2)
  })
})

describe('saldoGeral (conferência)', () => {
  it('Σ saldoAtual das contas = R$ 9.126,26 (inclui cartão negativo)', () => {
    expect(saldoGeral(CONTAS_SEED)).toBeCloseTo(9126.26, 2)
  })
  it('lista vazia → 0', () => {
    expect(saldoGeral([])).toBe(0)
  })
})

describe('agruparPorData', () => {
  const grupos = agruparPorData(lancamentosDoPeriodo(LANCAMENTOS_SEED, JUNHO))

  it('ordena por dia DESC (mais recente primeiro)', () => {
    expect(grupos[0].data).toBe('2026-06-28')
    expect(grupos[grupos.length - 1].data).toBe('2026-06-01')
    for (let i = 1; i < grupos.length; i++) {
      expect(grupos[i - 1].data >= grupos[i].data).toBe(true)
    }
  })

  it('14 dias distintos em junho', () => {
    expect(grupos).toHaveLength(14)
  })

  it('totalDia é a soma COM sinal (06-20: +120 −800 −800 = −1480)', () => {
    const dia20 = grupos.find((g) => g.data === '2026-06-20')!
    expect(dia20.itens).toHaveLength(3)
    expect(dia20.totalDia).toBeCloseTo(-1480, 2)
  })
})

describe('contasAPagar (ref 2026-06-30)', () => {
  const pagar = contasAPagar(LANCAMENTOS_SEED, REF)

  it('lista as 3 despesas em aberto, ordenadas por vencimento ASC', () => {
    expect(pagar).toHaveLength(3)
    expect(pagar.map((c) => c.lancamento.id)).toEqual([
      'lanc_seed_19', // venc 06-18
      'lanc_seed_20', // venc 06-25
      'lanc_seed_18', // venc 07-05
    ])
  })

  it('flag emAtraso: vencido antes da ref OU status em_atraso', () => {
    const v19 = pagar.find((c) => c.lancamento.id === 'lanc_seed_19')!
    const v18 = pagar.find((c) => c.lancamento.id === 'lanc_seed_18')!
    expect(v19.emAtraso).toBe(true) // status em_atraso (venc 06-18 < 06-30)
    expect(v18.emAtraso).toBe(false) // venc 07-05 ainda no futuro
  })

  it('flag vencendoHoje quando venc === ref', () => {
    const pagar25 = contasAPagar(LANCAMENTOS_SEED, '2026-06-25')
    const v20 = pagar25.find((c) => c.lancamento.id === 'lanc_seed_20')!
    expect(v20.vencendoHoje).toBe(true)
    expect(v20.emAtraso).toBe(false) // previsto, venc não anterior à ref
  })
})

describe('contasAReceber (ref 2026-06-30)', () => {
  const receber = contasAReceber(LANCAMENTOS_SEED, REF)

  it('lista as 2 receitas em aberto, ordenadas por vencimento ASC', () => {
    expect(receber.map((c) => c.lancamento.id)).toEqual([
      'lanc_seed_06', // venc 06-20
      'lanc_seed_04', // venc 06-28
    ])
  })

  it('ambas em atraso vs 06-30 (vencimentos anteriores)', () => {
    expect(receber.every((c) => c.emAtraso)).toBe(true)
  })

  it('flag vencendoHoje quando venc === ref', () => {
    const receber28 = contasAReceber(LANCAMENTOS_SEED, '2026-06-28')
    const v04 = receber28.find((c) => c.lancamento.id === 'lanc_seed_04')!
    expect(v04.vencendoHoje).toBe(true)
    expect(v04.emAtraso).toBe(false)
  })
})

describe('gastoPorCategoria (conferência — maiores gastos do mês)', () => {
  const gastos = gastoPorCategoria(lancamentosDoPeriodo(LANCAMENTOS_SEED, JUNHO))

  it('agrupa despesas PAGAS pela categoria-mãe com os valores de conferência', () => {
    expect(gastos.get('cat_equipe')).toBeCloseTo(3250, 2)
    expect(gastos.get('cat_socios')).toBeCloseTo(1600, 2)
    expect(gastos.get('cat_produtos')).toBeCloseTo(980, 2)
    expect(gastos.get('cat_marketing')).toBeCloseTo(800, 2)
    expect(gastos.get('cat_equipamentos')).toBeCloseTo(280, 2)
    expect(gastos.get('cat_transporte')).toBeCloseTo(193.84, 2)
    expect(gastos.get('cat_assinaturas')).toBeCloseTo(99.9, 2)
    expect(gastos.get('cat_taxas_bancarias')).toBeCloseTo(20, 2)
  })

  it('exatamente 8 categorias com gasto pago', () => {
    expect(gastos.size).toBe(8)
  })

  it('não inclui receitas nem despesas não pagas', () => {
    expect(gastos.has('cat_servico_automotivo')).toBe(false) // receita
    expect(gastos.has('cat_aluguel')).toBe(false) // despesa pendente (julho)
  })
})

describe('progressoLimite', () => {
  const limProdutos = LIMITES_SEED.find((l) => l.id === 'lim_produtos')!
  const limCombustivel = LIMITES_SEED.find((l) => l.id === 'lim_combustivel')!
  const limEquipamentos = LIMITES_SEED.find((l) => l.id === 'lim_equipamentos')!

  it('casa categoria-MÃE (lim_produtos: gasto 980 / 1500)', () => {
    const p = progressoLimite(limProdutos, LANCAMENTOS_SEED)
    expect(p.gasto).toBeCloseTo(980, 2)
    expect(p.limite).toBe(1500)
    expect(p.pct).toBeCloseTo(980 / 1500, 4)
  })

  it('casa SUBcategoria (lim_combustivel: gasto 155,34 / 400)', () => {
    const p = progressoLimite(limCombustivel, LANCAMENTOS_SEED)
    expect(p.gasto).toBeCloseTo(155.34, 2)
    expect(p.pct).toBeCloseTo(155.34 / 400, 4)
  })

  it('ignora despesas não pagas (lim_equipamentos: só a parcela paga 280 / 1000)', () => {
    const p = progressoLimite(limEquipamentos, LANCAMENTOS_SEED)
    expect(p.gasto).toBeCloseTo(280, 2) // exclui em_atraso (320) e previsto (280)
    expect(p.pct).toBeCloseTo(0.28, 4)
  })

  it('pct é clampado em 1 quando o gasto estoura o limite', () => {
    const apertado: LimiteGasto = {
      id: 'lim_test',
      categoriaId: 'cat_equipe', // gasto 3250
      limite: 100,
      created: '2026-06-01T00:00:00.000Z',
      updated: '2026-06-01T00:00:00.000Z',
    }
    const p = progressoLimite(apertado, LANCAMENTOS_SEED)
    expect(p.gasto).toBeCloseTo(3250, 2)
    expect(p.pct).toBe(1)
  })

  it('limite ≤ 0 → pct 0 (sem divisão por zero)', () => {
    const zero: LimiteGasto = {
      id: 'lim_zero',
      categoriaId: 'cat_equipe',
      limite: 0,
      created: '2026-06-01T00:00:00.000Z',
      updated: '2026-06-01T00:00:00.000Z',
    }
    const p = progressoLimite(zero, LANCAMENTOS_SEED)
    expect(p.pct).toBe(0)
    expect(p.gasto).toBeCloseTo(3250, 2)
  })
})
