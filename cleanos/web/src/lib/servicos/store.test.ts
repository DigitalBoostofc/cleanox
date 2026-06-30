import { describe, it, expect, beforeEach, vi } from 'vitest'
import type { ServicoPB } from '../collections'
import type { Servico, ServicoAdicionalOS } from './types'
import { SERVICOS_SEED } from './seed'

/* ============================================================
 * Mock do cliente PocketBase (../pb)
 *
 * A store agora bate em pb.collection('servicos'). Trocamos a camada de rede por
 * um DB em memória que fala o MESMO protocolo do SDK (getFullList/getOne/create/
 * update/delete + ClientResponseError 404). O DB é semeado a cada teste com os 32
 * itens do catálogo, convertidos para o shape PB (snake_case) — espelhando o seed
 * da Migration 9. As funções PURAS (buildSnapshot/snapshotToChecklistExec/
 * calcTotalOS) não tocam o pb e seguem testadas sem mock.
 * ============================================================ */

// DB compartilhado entre o factory do mock e o reset dos testes (via vi.hoisted).
const db = vi.hoisted(() => ({ records: [] as Record<string, unknown>[], seq: 0 }))

vi.mock('../pb', async () => {
  const { ClientResponseError } =
    await vi.importActual<typeof import('pocketbase')>('pocketbase')
  const notFound = () =>
    new ClientResponseError({ status: 404, response: { code: 404, message: 'Not found.' } })
  const dup = <T,>(v: T): T => JSON.parse(JSON.stringify(v))
  const stamp = (): string => {
    db.seq += 1
    return new Date(Date.UTC(2025, 5, 30, 0, 0, 0, db.seq)).toISOString()
  }
  return {
    pb: {
      collection: () => ({
        getFullList: async (opts?: { sort?: string }) => {
          const list = db.records.map((r) => dup(r))
          if (opts?.sort === 'nome') {
            list.sort((a, b) => String(a.nome).localeCompare(String(b.nome)))
          }
          return list
        },
        getOne: async (id: string) => {
          const rec = db.records.find((r) => r.id === id)
          if (!rec) throw notFound()
          return dup(rec)
        },
        create: async (data: Record<string, unknown>) => {
          const ts = stamp()
          const rec = {
            id: `rec_${db.seq}_${Math.random().toString(36).slice(2, 8)}`,
            created: ts,
            updated: ts,
            ...data,
          }
          db.records.push(rec)
          return dup(rec)
        },
        update: async (id: string, data: Record<string, unknown>) => {
          const idx = db.records.findIndex((r) => r.id === id)
          if (idx === -1) throw notFound()
          const rec = { ...db.records[idx], ...data, updated: stamp() }
          db.records[idx] = rec
          return dup(rec)
        },
        delete: async (id: string) => {
          const idx = db.records.findIndex((r) => r.id === id)
          if (idx === -1) throw notFound()
          db.records.splice(idx, 1)
          return true
        },
      }),
    },
  }
})

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
  pbToServico,
  servicoToPB,
  slugify,
} from './store'

/** Converte um Servico do seed no registro PB (snake_case) que o mock devolve. */
function seedToPB(s: Servico): ServicoPB {
  return {
    id: s.id,
    slug: s.id, // os IDs estáveis do seed viram slug no PB
    categoria: s.categoria,
    grupo: s.grupo,
    nome: s.nome,
    descricao: '',
    valor_base: s.valorBase,
    valor_base_max: s.valorBaseMax ?? 0,
    tipo_valor: s.tipoValor,
    tempo_medio_min: s.tempoMedioMin ?? 0,
    tempo_medio_label: s.tempoMedioLabel,
    status: s.status,
    observacao: s.observacao ?? '',
    checklist_padrao: s.checklistPadrao,
    orientacoes_pre: s.orientacoesPre ?? '',
    orientacoes_pos: s.orientacoesPos ?? '',
    adicionais_relacionados: s.adicionaisRelacionados,
    preco_base: s.valorBase,
    ativo: s.status === 'ativo',
    created: s.created,
    updated: s.updated,
  }
}

// Helper: serviço mínimo válido para os helpers puros (buildSnapshot etc.)
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
  db.records = SERVICOS_SEED.map((s) => seedToPB(s) as unknown as Record<string, unknown>)
  db.seq = 0
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

  it('grava slug único e sincroniza legados (preco_base/ativo)', async () => {
    const input = {
      categoria: 'veicular' as const,
      grupo: 'avulsos' as const,
      nome: 'Lavagem Especial',
      valorBase: 90,
      tipoValor: 'fixo' as const,
      tempoMedioLabel: '1h',
      status: 'inativo' as const,
      checklistPadrao: [],
      adicionaisRelacionados: [],
    }
    const created = await createServico(input)
    const rec = db.records.find((r) => r.id === created.id) as unknown as ServicoPB | undefined
    expect(rec).toBeDefined()
    expect(rec!.slug).toBe('lavagem_especial')
    expect(rec!.preco_base).toBe(90) // legado = valor_base
    expect(rec!.ativo).toBe(false) // legado = (status === 'ativo')
  })

  it('slug ganha sufixo numérico quando o nome colide', async () => {
    const base = {
      categoria: 'veicular' as const,
      grupo: 'avulsos' as const,
      nome: 'Mesmo Nome',
      valorBase: 50,
      tipoValor: 'fixo' as const,
      tempoMedioLabel: '30min',
      status: 'ativo' as const,
      checklistPadrao: [],
      adicionaisRelacionados: [],
    }
    const a = await createServico(base)
    const b = await createServico(base)
    const slugA = (db.records.find((r) => r.id === a.id) as unknown as ServicoPB).slug
    const slugB = (db.records.find((r) => r.id === b.id) as unknown as ServicoPB).slug
    expect(slugA).toBe('mesmo_nome')
    expect(slugB).toBe('mesmo_nome_2')
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

  it('atualização parcial de status sincroniza ativo legado', async () => {
    const first = SERVICOS_SEED[0]
    await updateServico(first.id, { status: 'inativo' })
    const rec = db.records.find((r) => r.id === first.id) as unknown as ServicoPB
    expect(rec.status).toBe('inativo')
    expect(rec.ativo).toBe(false)
  })

  it('rejeita quando id inexistente', async () => {
    await expect(updateServico('nao_existe', { nome: 'X' })).rejects.toThrow()
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

// ---- pbToServico (mapeador puro) ----

describe('pbToServico', () => {
  const base = (over: Partial<ServicoPB> = {}): ServicoPB => ({
    id: 'rec1',
    slug: 'svc_x',
    categoria: 'veicular',
    grupo: 'plano',
    nome: 'X',
    valor_base: 150,
    valor_base_max: 0,
    tipo_valor: 'fixo',
    tempo_medio_min: 120,
    tempo_medio_label: '1h30 a 2h',
    status: 'ativo',
    observacao: '',
    checklist_padrao: [],
    orientacoes_pre: '',
    orientacoes_pos: '',
    adicionais_relacionados: [],
    preco_base: 150,
    ativo: true,
    created: '2025-01-01 00:00:00Z',
    updated: '2025-01-02 00:00:00Z',
    ...over,
  })

  it('mapeia snake_case → camelCase', () => {
    const s = pbToServico(base())
    expect(s.valorBase).toBe(150)
    expect(s.tipoValor).toBe('fixo')
    expect(s.tempoMedioMin).toBe(120)
    expect(s.tempoMedioLabel).toBe('1h30 a 2h')
    expect(s.status).toBe('ativo')
  })

  it('valor_base_max 0 → undefined; >0 preservado', () => {
    expect(pbToServico(base({ valor_base_max: 0 })).valorBaseMax).toBeUndefined()
    expect(pbToServico(base({ valor_base_max: 80 })).valorBaseMax).toBe(80)
  })

  it('tempo_medio_min 0 → undefined (Variável)', () => {
    expect(pbToServico(base({ tempo_medio_min: 0 })).tempoMedioMin).toBeUndefined()
  })

  it('selects vazios caem em defaults seguros', () => {
    const s = pbToServico(base({ categoria: '', grupo: '', tipo_valor: '' }))
    expect(s.categoria).toBe('veicular')
    expect(s.grupo).toBe('outros')
    expect(s.tipoValor).toBe('fixo')
  })

  it('status vazio deriva do ativo legado', () => {
    expect(pbToServico(base({ status: '', ativo: false })).status).toBe('inativo')
    expect(pbToServico(base({ status: '', ativo: true })).status).toBe('ativo')
  })

  it('observação/orientações vazias viram undefined', () => {
    const s = pbToServico(base({ observacao: '', orientacoes_pre: '', orientacoes_pos: '' }))
    expect(s.observacao).toBeUndefined()
    expect(s.orientacoesPre).toBeUndefined()
    expect(s.orientacoesPos).toBeUndefined()
  })

  it('checklist_padrao como STRING JSON é parseado defensivamente', () => {
    const json = JSON.stringify([{ id: 'c1', titulo: 'A', ordem: 1 }])
    const s = pbToServico(base({ checklist_padrao: json as unknown as ServicoPB['checklist_padrao'] }))
    expect(s.checklistPadrao).toHaveLength(1)
    expect(s.checklistPadrao[0].titulo).toBe('A')
  })

  it('adicionais_relacionados ausente/inválido → array vazio', () => {
    const s = pbToServico(base({ adicionais_relacionados: undefined }))
    expect(Array.isArray(s.adicionaisRelacionados)).toBe(true)
    expect(s.adicionaisRelacionados).toHaveLength(0)
  })
})

// ---- servicoToPB (mapeador puro) ----

describe('servicoToPB', () => {
  it('mapeia camelCase → snake_case e sincroniza legados', () => {
    const out = servicoToPB({ valorBase: 200, status: 'ativo' })
    expect(out.valor_base).toBe(200)
    expect(out.preco_base).toBe(200) // sincronizado
    expect(out.status).toBe('ativo')
    expect(out.ativo).toBe(true) // sincronizado
  })

  it('status inativo → ativo=false', () => {
    expect(servicoToPB({ status: 'inativo' }).ativo).toBe(false)
  })

  it('inclui SÓ as chaves presentes (update parcial)', () => {
    const out = servicoToPB({ nome: 'Novo' })
    expect(out).toEqual({ nome: 'Novo' })
    expect('valor_base' in out).toBe(false)
    expect('ativo' in out).toBe(false)
  })

  it('valorBaseMax/tempoMedioMin undefined viram 0', () => {
    const out = servicoToPB({ valorBaseMax: undefined, tempoMedioMin: undefined })
    expect(out.valor_base_max).toBe(0)
    expect(out.tempo_medio_min).toBe(0)
  })

  it('round-trip pbToServico(servicoToPB) preserva os campos do domínio', () => {
    const input = {
      categoria: 'residencial' as const,
      grupo: 'sofa' as const,
      nome: 'Sofá 3 lugares',
      valorBase: 180,
      valorBaseMax: undefined,
      tipoValor: 'fixo' as const,
      tempoMedioMin: 120,
      tempoMedioLabel: '1h30 a 2h',
      status: 'ativo' as const,
      observacao: 'obs',
      checklistPadrao: [{ id: 'c1', titulo: 'A', ordem: 1 }],
      orientacoesPre: 'pre',
      orientacoesPos: 'pos',
      adicionaisRelacionados: ['svc_x'],
    }
    const pbPayload = servicoToPB(input)
    const rec = { id: 'r', slug: 's', created: 'c', updated: 'u', ...pbPayload } as unknown as ServicoPB
    const back = pbToServico(rec)
    expect(back.nome).toBe(input.nome)
    expect(back.valorBase).toBe(input.valorBase)
    expect(back.tipoValor).toBe(input.tipoValor)
    expect(back.tempoMedioLabel).toBe(input.tempoMedioLabel)
    expect(back.observacao).toBe('obs')
    expect(back.checklistPadrao).toEqual(input.checklistPadrao)
    expect(back.adicionaisRelacionados).toEqual(input.adicionaisRelacionados)
  })
})

// ---- slugify (puro) ----

describe('slugify', () => {
  it('minúsculas, sem acento, separador "_"', () => {
    expect(slugify('Cleanox Essencial')).toBe('cleanox_essencial')
    expect(slugify('Higienização de teto')).toBe('higienizacao_de_teto')
  })

  it('colapsa símbolos e apara separadores nas pontas', () => {
    expect(slugify('Sofá 5/6 lugares')).toBe('sofa_5_6_lugares')
    expect(slugify('  Painel / partes!  ')).toBe('painel_partes')
  })

  it('nome só com símbolos → fallback "servico"', () => {
    expect(slugify('!!!')).toBe('servico')
    expect(slugify('')).toBe('servico')
  })

  it('sufixo "(cópia)" gera slug previsível', () => {
    expect(slugify('Cleanox Essencial (cópia)')).toBe('cleanox_essencial_copia')
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
