// @vitest-environment node
import { describe, it, expect, beforeEach, vi } from 'vitest'

/* ============================================================
 * Mock do cliente PocketBase (../pb)
 *
 * A store agora conversa com pb.collection(FIN_COLLECTIONS.*). Trocamos a
 * camada de rede por um DB em memória multi-coleção que fala o MESMO protocolo
 * do SDK (getFullList/getOne/create/update/delete + ClientResponseError 404).
 * O DB é semeado a cada teste com os dados do seed.ts convertidos para o shape
 * PB (snake_case). As DERIVAÇÕES PURAS não tocam o pb e são testadas sem mock,
 * diretamente sobre LANCAMENTOS_SEED (valores de conferência jun/2026).
 * ============================================================ */

// DB compartilhado entre o factory do mock e o reset dos testes (via vi.hoisted).
const db = vi.hoisted(() => ({
  stores: {} as Record<string, Record<string, unknown>[]>,
  seq: 0,
}))

vi.mock('../pb', async () => {
  const { ClientResponseError } =
    await vi.importActual<typeof import('pocketbase')>('pocketbase')
  const notFound = () =>
    new ClientResponseError({ status: 404, response: { code: 404, message: 'Not found.' } })
  const dup = <T,>(v: T): T => JSON.parse(JSON.stringify(v))
  const stamp = (): string => {
    db.seq += 1
    return new Date(Date.UTC(2026, 5, 30, 0, 0, 0, db.seq)).toISOString()
  }
  return {
    pb: {
      collection: (name: string) => ({
        getFullList: async () => (db.stores[name] ?? []).map(dup),
        getOne: async (id: string) => {
          const rec = (db.stores[name] ?? []).find((r) => r.id === id)
          if (!rec) throw notFound()
          return dup(rec)
        },
        create: async (data: Record<string, unknown>) => {
          if (!db.stores[name]) db.stores[name] = []
          const ts = stamp()
          const rec = { id: `rec_${db.seq}`, created: ts, updated: ts, ...data }
          db.stores[name].push(rec)
          return dup(rec)
        },
        update: async (id: string, data: Record<string, unknown>) => {
          const list = db.stores[name] ?? []
          const idx = list.findIndex((r) => r.id === id)
          if (idx === -1) throw notFound()
          const rec = { ...list[idx], ...data, updated: stamp() }
          list[idx] = rec
          return dup(rec)
        },
        delete: async (id: string) => {
          const list = db.stores[name] ?? []
          const idx = list.findIndex((r) => r.id === id)
          if (idx === -1) throw notFound()
          list.splice(idx, 1)
          return true
        },
      }),
    },
  }
})

import {
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

/* ---- Conversores seed (camelCase) → registros PB (snake_case) para o mock ---- */

function contaSeedToPB(c: (typeof CONTAS_SEED)[number]): Record<string, unknown> {
  return {
    id: c.id, created: c.created, updated: c.updated,
    nome: c.nome, tipo: c.tipo,
    saldo_inicial: c.saldoInicial,
    saldo_atual: c.saldoAtual,
    ativo: c.ativo,
    cor: c.cor ?? null,
    icone: c.icone ?? null,
  }
}

function categoriaSeedToPB(c: (typeof CATEGORIAS_SEED)[number]): Record<string, unknown> {
  return {
    id: c.id, created: c.created, updated: c.updated,
    nome: c.nome, tipo: c.tipo,
    icone: c.icone ?? null,
    cor: c.cor ?? null,
    parent_id: c.parentId ?? null,
    arquivada: c.arquivada,
  }
}

function lancamentoSeedToPB(l: (typeof LANCAMENTOS_SEED)[number]): Record<string, unknown> {
  return {
    id: l.id, created: l.created, updated: l.updated,
    tipo: l.tipo, descricao: l.descricao,
    categoria_id: l.categoriaId,
    subcategoria_id: l.subcategoriaId ?? null,
    valor: l.valor,
    conta_id: l.contaId,
    data: l.data,
    vencimento: l.vencimento ?? null,
    status: l.status,
    recorrencia: l.recorrencia,
    parcela_atual: l.parcelaAtual ?? null,
    parcelas_total: l.parcelasTotal ?? null,
    origem: l.origem,
    os_id: l.osId ?? null,
    os_numero: l.osNumero ?? null,
    cliente_nome: l.clienteNome ?? null,
    servico_nome: l.servicoNome ?? null,
    forma_pagamento: l.formaPagamento ?? null,
    observacao: l.observacao ?? null,
    tags: l.tags ?? null,
    anexos: l.anexos ?? null,
  }
}

function limiteSeedToPB(l: (typeof LIMITES_SEED)[number]): Record<string, unknown> {
  return {
    id: l.id, created: l.created, updated: l.updated,
    categoria_id: l.categoriaId,
    limite: l.limite,
  }
}

beforeEach(() => {
  db.stores = {
    fin_contas: CONTAS_SEED.map(contaSeedToPB),
    fin_categorias: CATEGORIAS_SEED.map(categoriaSeedToPB),
    fin_lancamentos: LANCAMENTOS_SEED.map(lancamentoSeedToPB),
    fin_limites: LIMITES_SEED.map(limiteSeedToPB),
  }
  db.seq = 0
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
    expect(l2.every((l) => l.descricao !== 'MUTADO')).toBe(true)
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

/* ============================================================
 * A-001 — saldo_atual incremental nos CRUDs de lançamento
 * ============================================================ */

describe('saldo_atual — createLancamento', () => {
  it('despesa pago reduz saldo_atual da conta', async () => {
    const before = (await getConta('conta_carteira'))!.saldoAtual // 306.16
    await createLancamento(lancInput({ tipo: 'despesa', valor: 100, contaId: 'conta_carteira', status: 'pago' }))
    const after = (await getConta('conta_carteira'))!.saldoAtual
    expect(after).toBeCloseTo(before - 100, 2)
  })

  it('receita pago aumenta saldo_atual da conta', async () => {
    const before = (await getConta('conta_carteira'))!.saldoAtual // 306.16
    await createLancamento(lancInput({ tipo: 'receita', valor: 200, contaId: 'conta_carteira', status: 'pago' }))
    const after = (await getConta('conta_carteira'))!.saldoAtual
    expect(after).toBeCloseTo(before + 200, 2)
  })

  it('status pendente NÃO altera saldo_atual', async () => {
    const before = (await getConta('conta_carteira'))!.saldoAtual
    await createLancamento(lancInput({ tipo: 'despesa', valor: 100, contaId: 'conta_carteira', status: 'pendente' }))
    const after = (await getConta('conta_carteira'))!.saldoAtual
    expect(after).toBeCloseTo(before, 2)
  })
})

describe('saldo_atual — deleteLancamento', () => {
  it('deletar lançamento pago reverte o efeito no saldo', async () => {
    // lanc_seed_10: despesa, pago, 155.34, conta_carteira
    const before = (await getConta('conta_carteira'))!.saldoAtual // 306.16
    await deleteLancamento('lanc_seed_10')
    const after = (await getConta('conta_carteira'))!.saldoAtual
    expect(after).toBeCloseTo(before + 155.34, 2) // reverte o efeito -155.34
  })
})

describe('saldo_atual — updateLancamento', () => {
  it('mudança de status pendente→pago aplica o efeito', async () => {
    // lanc_seed_18: despesa, pendente, 1200, conta_inter (efeito era 0)
    const before = (await getConta('conta_inter'))!.saldoAtual // 6450
    await updateLancamento('lanc_seed_18', { status: 'pago' })
    const after = (await getConta('conta_inter'))!.saldoAtual
    expect(after).toBeCloseTo(before - 1200, 2)
  })

  it('mudança de contaId move o efeito entre as duas contas', async () => {
    // lanc_seed_10: despesa, pago, 155.34, conta_carteira → transferir para conta_inter
    const carteiraAntes = (await getConta('conta_carteira'))!.saldoAtual // 306.16
    const interAntes = (await getConta('conta_inter'))!.saldoAtual // 6450
    await updateLancamento('lanc_seed_10', { contaId: 'conta_inter' })
    const carteiraDepois = (await getConta('conta_carteira'))!.saldoAtual
    const interDepois = (await getConta('conta_inter'))!.saldoAtual
    expect(carteiraDepois).toBeCloseTo(carteiraAntes + 155.34, 2) // reverte na carteira
    expect(interDepois).toBeCloseTo(interAntes - 155.34, 2) // aplica no inter
  })

  it('mudança de valor ajusta o delta incremental', async () => {
    // lanc_seed_10: despesa, pago, 155.34, conta_carteira → valor 200
    const before = (await getConta('conta_carteira'))!.saldoAtual // 306.16
    await updateLancamento('lanc_seed_10', { valor: 200 })
    const after = (await getConta('conta_carteira'))!.saldoAtual
    // delta = -200 - (-155.34) = -44.66
    expect(after).toBeCloseTo(before - 44.66, 2)
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

/* ============================================================
 * M-002 — pbToLancamento: 0 de NumberField tratado como ausente
 * ============================================================ */

describe('pbToLancamento — parcela_atual/parcelas_total zero → undefined (M-002)', () => {
  it('não-parcelado com parcela_atual=0/parcelas_total=0 → parcelaAtual/parcelasTotal undefined', async () => {
    db.stores['fin_lancamentos'] = [
      {
        id: 'lanc_m002_nao_parc',
        created: '2026-06-01T00:00:00.000Z',
        updated: '2026-06-01T00:00:00.000Z',
        tipo: 'despesa',
        descricao: 'Não-parcelado PB',
        categoria_id: 'cat_outros',
        subcategoria_id: null,
        valor: 50,
        conta_id: 'conta_carteira',
        data: '2026-06-15T10:00:00.000Z',
        vencimento: null,
        status: 'pago',
        recorrencia: 'unica',
        parcela_atual: 0,
        parcelas_total: 0,
        origem: 'manual',
        os_id: null, os_numero: null, cliente_nome: null, servico_nome: null,
        forma_pagamento: null, observacao: null, tags: [], anexos: [],
      },
    ]
    const [l] = await listLancamentos()
    expect(l.parcelaAtual).toBeUndefined()
    expect(l.parcelasTotal).toBeUndefined()
  })

  it('parcelado com parcela_atual=1/parcelas_total=10 → preserva 1 e 10', async () => {
    db.stores['fin_lancamentos'] = [
      {
        id: 'lanc_m002_parc',
        created: '2026-06-01T00:00:00.000Z',
        updated: '2026-06-01T00:00:00.000Z',
        tipo: 'despesa',
        descricao: 'Parcelado PB',
        categoria_id: 'cat_equipamentos',
        subcategoria_id: null,
        valor: 280,
        conta_id: 'conta_inter',
        data: '2026-06-15T10:00:00.000Z',
        vencimento: null,
        status: 'pago',
        recorrencia: 'parcelada',
        parcela_atual: 1,
        parcelas_total: 10,
        origem: 'manual',
        os_id: null, os_numero: null, cliente_nome: null, servico_nome: null,
        forma_pagamento: null, observacao: null, tags: [], anexos: [],
      },
    ]
    const [l] = await listLancamentos()
    expect(l.parcelaAtual).toBe(1)
    expect(l.parcelasTotal).toBe(10)
  })
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
