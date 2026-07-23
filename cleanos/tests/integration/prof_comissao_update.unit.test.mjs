/**
 * CleanOS — recálculo de comissão ao editar valor_pago de OS já concluída.
 *
 * Regras:
 *   - percentual: valor_comissao = valor_pago × base_valor%
 *   - fixo / diaria: valor_comissao permanece base_valor; valor_os espelha a OS
 *   - sem comissão ainda → tenta criar (como 1ª conclusão)
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

globalThis.Record = class Record {
  constructor(collection) {
    this.collection = collection
    this.id = 'new_' + Math.random().toString(36).slice(2, 8)
    this._data = {}
  }
  set(k, v) {
    this._data[k] = v
  }
  get(k) {
    return this._data[k]
  }
}

const lib = require('../../pb/pb_hooks/prof_comissao_lib.js')

function rec(fields, id = 'c1') {
  const data = { ...fields }
  return {
    id,
    get: (k) => data[k],
    set: (k, v) => {
      data[k] = v
    },
    _data: data,
  }
}

function osRec(fields, id = 'os1') {
  return rec(
    {
      status: 'concluida',
      profissional: 'prof1',
      valor_pago: 200,
      nome_curto: 'Cliente X',
      tipo_servico_nome: 'Cleanox Completo',
      data_hora: '2026-07-20 12:00:00.000Z',
      ...fields,
    },
    id,
  )
}

function mockApp({ comissoes = [], profs = [] } = {}) {
  const saved = []
  const created = []
  let list = [...comissoes]
  const app = {
    findRecordsByFilter(collection, filter, sort, limit, offset, params) {
      if (collection === 'prof_comissoes') {
        if (params && params.id) {
          return list.filter((c) => c.get('os') === params.id)
        }
        return list
      }
      return []
    },
    findFirstRecordByFilter(collection, filter) {
      if (collection === 'prof_comissoes') {
        const m = /os = '([^']*)'/.exec(filter)
        if (m) {
          const hit = list.find((c) => c.get('os') === m[1])
          if (hit) return hit
        }
        throw new Error('not found')
      }
      throw new Error('not found')
    },
    findRecordById(collection, id) {
      if (collection === 'users') {
        const hit = profs.find((p) => p.id === id)
        if (hit) return hit
        throw new Error('user not found')
      }
      if (collection === 'prof_comissoes') {
        const hit = list.find((c) => c.id === id)
        if (hit) return hit
      }
      throw new Error('not found')
    },
    findCollectionByNameOrId(name) {
      return { name }
    },
    save(r) {
      saved.push(r)
      // novas criações (sem id prévio na lista)
      if (!list.find((c) => c.id === r.id)) {
        // Record mock do create
        if (r._data) {
          const row = rec({ ...r._data }, r.id)
          list.push(row)
          created.push(row)
        }
      }
    },
    delete() {},
    _saved: saved,
    _created: created,
    _list: () => list,
  }
  return app
}

describe('calcValorComissao', () => {
  it('percentual 30% de 200 = 60', () => {
    assert.equal(lib.calcValorComissao('percentual', 30, 200), 60)
  })
  it('percentual recalcula com valor novo', () => {
    assert.equal(lib.calcValorComissao('percentual', 30, 250), 75)
  })
  it('percentual com valor 0 → 0', () => {
    assert.equal(lib.calcValorComissao('percentual', 30, 0), 0)
  })
  it('fixo ignora valor_pago', () => {
    assert.equal(lib.calcValorComissao('fixo', 100, 999), 100)
  })
  it('diaria ignora valor_pago', () => {
    assert.equal(lib.calcValorComissao('diaria', 100, 50), 100)
  })
})

describe('atualizarComissaoDaOs — percentual', () => {
  it('recalcula valor_comissao quando valor_pago muda', () => {
    const com = rec(
      {
        os: 'os1',
        profissional: 'prof1',
        profissional_nome: 'João',
        valor_os: 200,
        valor_comissao: 60,
        tipo_aplicado: 'percentual',
        base_valor: 30,
        status: 'pendente',
        descricao: 'Cleanox Completo · Cliente X',
      },
      'com1',
    )
    const app = mockApp({ comissoes: [com] })
    const os = osRec({ valor_pago: 300 })

    lib.atualizarComissaoDaOs(app, os)

    assert.equal(com.get('valor_os'), 300)
    assert.equal(com.get('valor_comissao'), 90)
    assert.equal(app._saved.length, 1)
  })

  it('não salva se valores já batem', () => {
    const com = rec(
      {
        os: 'os1',
        profissional: 'prof1',
        valor_os: 200,
        valor_comissao: 60,
        tipo_aplicado: 'percentual',
        base_valor: 30,
        status: 'pendente',
        descricao: 'Cleanox Completo · Cliente X',
      },
      'com1',
    )
    const app = mockApp({ comissoes: [com] })
    lib.atualizarComissaoDaOs(app, osRec({ valor_pago: 200 }))
    assert.equal(app._saved.length, 0)
  })
})

describe('atualizarComissaoDaOs — diaria', () => {
  it('espelha valor_os mas mantém diária fixa', () => {
    const com = rec(
      {
        os: 'os1',
        profissional: 'prof1',
        valor_os: 200,
        valor_comissao: 100,
        tipo_aplicado: 'diaria',
        base_valor: 100,
        status: 'pendente',
        data: '2026-07-20 00:00:00.000Z',
        descricao: 'Diária · 2026-07-20 · Cliente X',
      },
      'comD',
    )
    const app = mockApp({ comissoes: [com] })
    lib.atualizarComissaoDaOs(app, osRec({ valor_pago: 350 }))

    assert.equal(com.get('valor_os'), 350)
    assert.equal(com.get('valor_comissao'), 100)
    assert.equal(app._saved.length, 1)
  })
})

describe('criarComissaoProfissional — regravação concluída', () => {
  it('prevStatus=concluida chama update (não recria)', () => {
    const com = rec(
      {
        os: 'os1',
        profissional: 'prof1',
        valor_os: 200,
        valor_comissao: 60,
        tipo_aplicado: 'percentual',
        base_valor: 30,
        status: 'pendente',
        descricao: 'x',
      },
      'com1',
    )
    const app = mockApp({
      comissoes: [com],
      profs: [
        rec(
          { name: 'João', comissao_tipo: 'percentual', comissao_valor: 30 },
          'prof1',
        ),
      ],
    })
    lib.criarComissaoProfissional(app, osRec({ valor_pago: 400 }), 'concluida')
    assert.equal(com.get('valor_comissao'), 120)
    assert.equal(com.get('valor_os'), 400)
    // não criou linha nova
    assert.equal(app._list().length, 1)
  })
})
