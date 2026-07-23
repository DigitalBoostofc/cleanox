/**
 * CleanOS — comissão paga vira DESPESA de repasse (1 por profissional/dia).
 *
 * Regras (2026-07-21):
 *   - OS concluída → só prof_comissoes (sem despesa por OS)
 *   - Marcar paga → 1 despesa via_comissao com Σ do dia (repasse)
 *   - 2 comissões pagas no mesmo dia → 1 despesa com valor somado
 *   - R1: nunca mexe em fin_contas.saldo_atual
 */

import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const require = createRequire(import.meta.url)

const HOOKS_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../pb/pb_hooks',
)

globalThis.__hooks = HOOKS_DIR

class Record {
  constructor(collection) {
    this.collection = collection
    this.id = 'lanc_novo'
    this._data = {}
  }
  set(k, v) {
    this._data[k] = v
  }
  get(k) {
    return this._data[k]
  }
}
globalThis.Record = Record

const pago = require('../../pb/pb_hooks/prof_comissao_pago_lib.js')

function rec(fields, id = 'com1') {
  return {
    id,
    get: (k) => fields[k],
    set: (k, v) => {
      fields[k] = v
    },
    _data: fields,
  }
}

function mockApp({
  lancamentos = [],
  comissoes = [],
  categorias,
  contas,
} = {}) {
  const saved = []
  const deleted = []
  const cats = categorias ?? [
    rec({ tipo: 'despesa', nome: 'Comissões' }, 'cat_comissoes'),
  ]
  const cnts = contas ?? [
    rec({ nome: 'Banco Inter', ativo: true, padrao: true }, 'conta_padrao'),
  ]
  // mutável: comissões conhecidas pelo mock
  let coms = [...comissoes]

  const app = {
    findFirstRecordByFilter(collection, filter) {
      if (collection === 'fin_categorias') {
        const hit = cats.find(
          (c) => c.get('tipo') === 'despesa' && c.get('nome') === 'Comissões',
        )
        if (hit) return hit
        throw new Error('not found')
      }
      if (collection === 'fin_lancamentos') {
        // 1:1 legado
        const m1 = /comissao_id = '([^']*)'/.exec(filter)
        if (m1) {
          const hit = lancamentos.find((l) => l.get('comissao_id') === m1[1])
          if (hit) return hit
          throw new Error('not found')
        }
        // repasse: profissional_id + data
        const mp = /profissional_id = '([^']*)'/.exec(filter)
        const md = /data = '([^']*)'/.exec(filter)
        if (mp && md) {
          const hit = lancamentos.find(
            (l) =>
              l.get('origem') === 'via_comissao' &&
              l.get('profissional_id') === mp[1] &&
              String(l.get('data') || '').slice(0, 10) === md[1] &&
              !l.get('comissao_id'),
          )
          if (hit) return hit
          throw new Error('not found')
        }
        throw new Error('not found')
      }
      throw new Error('not found')
    },

    findRecordsByFilter(collection, filter) {
      if (collection === 'fin_categorias') {
        return cats.filter((c) => c.get('tipo') === 'despesa')
      }
      if (collection === 'fin_contas') {
        const ativas = cnts.filter((c) => c.get('ativo') === true)
        if (filter.includes('padrao = true')) {
          return ativas.filter((c) => c.get('padrao') === true)
        }
        return ativas
      }
      if (collection === 'fin_lancamentos') {
        // repasse: janela de data ou data literal
        let list = lancamentos.filter(
          (l) =>
            l.get('origem') === 'via_comissao' &&
            !l.get('comissao_id'),
        )
        const mp = /profissional_id = "([^"]*)"/.exec(filter) ||
          /profissional_id = '([^']*)'/.exec(filter)
        if (mp) {
          list = list.filter((l) => l.get('profissional_id') === mp[1])
        }
        const mdEq = /data = "([^"]*)"/.exec(filter) ||
          /data = '([^']*)'/.exec(filter)
        if (mdEq) {
          const d = mdEq[1].slice(0, 10)
          list = list.filter(
            (l) => String(l.get('data') || '').slice(0, 10) === d,
          )
        }
        const mdGe = /data >= "([^"]*)"/.exec(filter)
        const mdLt = /data < "([^"]*)"/.exec(filter)
        if (mdGe) {
          const d = mdGe[1].slice(0, 10)
          list = list.filter(
            (l) => String(l.get('data') || '').slice(0, 10) >= d,
          )
        }
        if (mdLt) {
          const d = mdLt[1].slice(0, 10)
          list = list.filter(
            (l) => String(l.get('data') || '').slice(0, 10) < d,
          )
        }
        return list
      }
      if (collection === 'prof_comissoes') {
        // filter com {:pid} ou string
        let list = coms
        if (filter.includes("status = 'paga'")) {
          list = list.filter((c) => c.get('status') === 'paga')
        }
        // mockApp passa {:pid} — use all coms and filter in recalcular fallback
        return list
      }
      return []
    },

    findRecordById(collection, id) {
      if (collection === 'users') return rec({ name: 'Fulano da Relação' }, id)
      throw new Error('not found')
    },

    findCollectionByNameOrId(name) {
      return { name }
    },

    save(r) {
      const col = r.collection?.name ?? r._collection
      if (col === 'fin_contas') {
        throw new Error(
          'R1 VIOLADO: o lib escreveu em fin_contas — o saldo é do fin_saldo.pb.js',
        )
      }
      // se for comissão mock (sem collection de lancamento)
      if (!r.collection || r.collection.name !== 'fin_lancamentos') {
        // pode ser comissão regravada com pago_em
        if (r.id && r._data && 'pago_em' in r._data) {
          const idx = coms.findIndex((c) => c.id === r.id)
          if (idx >= 0) coms[idx] = r
          else coms.push(r)
        }
      } else {
        // novo lançamento: entra na lista para idempotência
        if (!lancamentos.find((l) => l.id === r.id)) {
          lancamentos.push(r)
        }
      }
      saved.push(r)
    },

    delete(r) {
      deleted.push(r)
      const i = lancamentos.indexOf(r)
      if (i >= 0) lancamentos.splice(i, 1)
    },
  }

  return { app, saved, deleted, coms, lancamentos }
}

function comissaoPaga(overrides = {}, id = 'com1') {
  return rec(
    {
      status: 'paga',
      valor_comissao: 60,
      profissional: 'prof1',
      profissional_nome: 'João Pedro',
      os: 'os_abc123def456',
      descricao: 'Limpeza · Carlos S.',
      pago_em: '',
      ...overrides,
    },
    id,
  )
}

describe('(0) OS concluída NÃO gera despesa', () => {
  it('onComissaoCriada com status pendente não cria lançamento', () => {
    const c = rec(
      {
        status: 'pendente',
        valor_comissao: 60,
        profissional: 'prof1',
        profissional_nome: 'João',
      },
      'c1',
    )
    const { app, saved } = mockApp({ comissoes: [c] })
    pago.onComissaoCriada(app, c)
    const despesas = saved.filter(
      (s) => s.collection && s.collection.name === 'fin_lancamentos',
    )
    assert.equal(despesas.length, 0)
  })
})

describe('(a) marcar paga gera 1 despesa de repasse', () => {
  it('cria 1 despesa via_comissao com valor da comissão e profissional_id', () => {
    const c = comissaoPaga()
    const { app, saved } = mockApp({ comissoes: [c] })
    pago.sincronizarLancamento(app, c, 'pendente')

    const despesas = saved.filter(
      (s) => s.get && s.get('tipo') === 'despesa',
    )
    assert.ok(despesas.length >= 1, 'deve criar despesa de repasse')
    const l = despesas[despesas.length - 1]
    assert.equal(l.get('tipo'), 'despesa')
    assert.equal(l.get('origem'), 'via_comissao')
    assert.equal(l.get('status'), 'pago')
    assert.equal(l.get('valor'), 60)
    assert.equal(l.get('profissional_id'), 'prof1')
    assert.equal(l.get('comissao_id') || '', '')
    assert.match(String(l.get('descricao')), /Repasse comissões/)
    assert.match(String(l.get('descricao')), /João Pedro/)
  })

  it('duas comissões pagas no mesmo dia → 1 despesa com soma', () => {
    const c1 = comissaoPaga({ valor_comissao: 40, pago_em: '2026-07-21' }, 'c1')
    const c2 = comissaoPaga({ valor_comissao: 25, pago_em: '2026-07-21' }, 'c2')
    // fix dataBrtHoje for stable test via already set pago_em
    const { app, saved, lancamentos } = mockApp({ comissoes: [c1, c2] })

    pago.sincronizarLancamento(app, c1, 'pendente')
    // after first, may have created repasse with 40+25 if both already paga in list
    pago.sincronizarLancamento(app, c2, 'pendente')

    const despesas = lancamentos.filter(
      (l) => l.get('origem') === 'via_comissao' && !l.get('comissao_id'),
    )
    assert.equal(despesas.length, 1, 'só 1 despesa de repasse no dia')
    assert.equal(despesas[0].get('valor'), 65)
  })

  it('data no formato PB (…00:00:00.000Z) ainda encontra e faz upsert', () => {
    const c1 = comissaoPaga({ valor_comissao: 100, pago_em: '2026-07-21' }, 'c1')
    const c2 = comissaoPaga({ valor_comissao: 50, pago_em: '2026-07-21' }, 'c2')
    // repasse já existente com data no formato real do PocketBase
    const existente = rec(
      {
        tipo: 'despesa',
        origem: 'via_comissao',
        profissional_id: 'prof1',
        data: '2026-07-21 00:00:00.000Z',
        valor: 100,
        status: 'pago',
        comissao_id: '',
        descricao: 'Repasse comissões · João Pedro · 2026-07-21 (1 OS)',
      },
      'rep_old',
    )
    const { app, lancamentos, deleted } = mockApp({
      comissoes: [c1, c2],
      lancamentos: [existente],
    })

    pago.sincronizarLancamento(app, c2, 'pendente')

    const vivos = lancamentos.filter(
      (l) => l.get('origem') === 'via_comissao' && !l.get('comissao_id'),
    )
    assert.equal(vivos.length, 1, 'continua 1 repasse (upsert, não cria outro)')
    assert.equal(vivos[0].get('valor'), 150)
    assert.equal(deleted.length, 0, 'não apaga o único existente')
  })

  it('consolida repasses duplicados no mesmo dia', () => {
    const c1 = comissaoPaga({ valor_comissao: 100, pago_em: '2026-07-21' }, 'c1')
    const dups = [
      rec(
        {
          tipo: 'despesa',
          origem: 'via_comissao',
          profissional_id: 'prof1',
          data: '2026-07-21 00:00:00.000Z',
          valor: 100,
          status: 'pago',
          comissao_id: '',
        },
        'r1',
      ),
      rec(
        {
          tipo: 'despesa',
          origem: 'via_comissao',
          profissional_id: 'prof1',
          data: '2026-07-21 00:00:00.000Z',
          valor: 200,
          status: 'pago',
          comissao_id: '',
        },
        'r2',
      ),
      rec(
        {
          tipo: 'despesa',
          origem: 'via_comissao',
          profissional_id: 'prof1',
          data: '2026-07-21 00:00:00.000Z',
          valor: 300,
          status: 'pago',
          comissao_id: '',
        },
        'r3',
      ),
    ]
    const { app, lancamentos, deleted } = mockApp({
      comissoes: [c1],
      lancamentos: dups,
    })

    pago.recalcularDespesaRepasse(app, 'prof1', '2026-07-21')

    const vivos = lancamentos.filter(
      (l) => l.get('origem') === 'via_comissao' && !l.get('comissao_id'),
    )
    assert.equal(vivos.length, 1, 'fica 1 repasse')
    assert.equal(vivos[0].get('valor'), 100, 'valor = soma das comissões pagas')
    assert.equal(deleted.length, 2, 'apaga as 2 cópias extras')
  })

  it('valor 0 não cria despesa', () => {
    const c = comissaoPaga({ valor_comissao: 0 })
    const { app, saved } = mockApp({ comissoes: [c] })
    pago.sincronizarLancamento(app, c, 'pendente')
    const despesas = saved.filter((s) => s.get && s.get('tipo') === 'despesa')
    assert.equal(despesas.length, 0)
  })
})

describe('(b) reabrir (paga → pendente) recalcula / remove repasse', () => {
  it('sem comissões pagas no dia remove a despesa de repasse', () => {
    const c = comissaoPaga({ pago_em: '2026-07-21', status: 'pendente' })
    const repasse = rec(
      {
        tipo: 'despesa',
        origem: 'via_comissao',
        profissional_id: 'prof1',
        data: '2026-07-21',
        valor: 60,
        status: 'pago',
        comissao_id: '',
      },
      'rep1',
    )
    const { app, deleted } = mockApp({
      comissoes: [c],
      lancamentos: [repasse],
    })
    pago.sincronizarLancamento(app, c, 'paga')
    assert.ok(
      deleted.some((d) => d.id === 'rep1'),
      'repasse deve ser removido sem comissões pagas',
    )
  })
})

describe('(c) R1 e idempotência', () => {
  it('nunca grava fin_contas', () => {
    const c = comissaoPaga()
    const { app } = mockApp({ comissoes: [c] })
    assert.doesNotThrow(() => pago.sincronizarLancamento(app, c, 'pendente'))
  })

  it('recalcular 2x no mesmo estado não duplica despesa', () => {
    const c = comissaoPaga({ pago_em: '2026-07-21' })
    const { app, lancamentos } = mockApp({ comissoes: [c] })
    pago.sincronizarLancamento(app, c, 'pendente')
    pago.sincronizarLancamento(app, c, 'paga') // status already paga
    const despesas = lancamentos.filter(
      (l) => l.get('origem') === 'via_comissao' && !l.get('comissao_id'),
    )
    assert.equal(despesas.length, 1)
  })
})

describe('(e) apagar comissão 1:1 legado', () => {
  it('apagarLancamentoDaComissao remove lançamento ligado por comissao_id', () => {
    const legado = rec(
      {
        comissao_id: 'com1',
        tipo: 'despesa',
        valor: 60,
        origem: 'via_comissao',
      },
      'lanc_leg',
    )
    const { app, deleted } = mockApp({ lancamentos: [legado] })
    const ok = pago.apagarLancamentoDaComissao(app, 'com1')
    assert.equal(ok, true)
    assert.equal(deleted.length, 1)
  })
})
