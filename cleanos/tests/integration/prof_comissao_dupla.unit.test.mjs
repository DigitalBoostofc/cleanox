/**
 * CleanOS — comissão em dupla (metade para cada profissional).
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
      execucao_modo: 'solo',
      ...fields,
    },
    id,
  )
}

function mockApp({ comissoes = [], profs = [] } = {}) {
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
    findFirstRecordByFilter(collection, filter, params) {
      if (collection === 'prof_comissoes') {
        const osId = params && params.os
        const pid = params && params.pid
        if (osId && pid) {
          const hit = list.find(
            (c) =>
              c.get('os') === osId &&
              c.get('profissional') === pid &&
              String(c.get('tipo_aplicado') || '') !== 'diaria',
          )
          if (hit) return hit
        }
        // fallback string filter
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
      throw new Error('not found')
    },
    findCollectionByNameOrId() {
      return { name: 'prof_comissoes' }
    },
    save(rec) {
      if (!list.find((c) => c.id === rec.id)) {
        list.push(rec)
        created.push(rec)
      }
    },
    delete(rec) {
      list = list.filter((c) => c.id !== rec.id)
    },
    _created: created,
    _list: () => list,
  }
  return app
}

describe('calcValorComissao — fração dupla', () => {
  it('percentual solo 30% de 200 = 60', () => {
    assert.equal(lib.calcValorComissao('percentual', 30, 200, 1), 60)
  })
  it('percentual dupla 30% de 200 = 30 (metade)', () => {
    assert.equal(lib.calcValorComissao('percentual', 30, 200, 0.5), 30)
  })
  it('fixo solo 50 → 50; dupla → 25', () => {
    assert.equal(lib.calcValorComissao('fixo', 50, 200, 1), 50)
    assert.equal(lib.calcValorComissao('fixo', 50, 200, 0.5), 25)
  })
  it('diária com fracao 1 permanece cheia', () => {
    assert.equal(lib.calcValorComissao('diaria', 80, 200, 1), 80)
  })
})

describe('criarComissaoProfissional — OS em dupla', () => {
  it('gera 2 comissões com metade cada (30% → 15% efetivo)', () => {
    const app = mockApp({
      profs: [
        rec(
          { comissao_tipo: 'percentual', comissao_valor: 30, name: 'Ana' },
          'prof1',
        ),
        rec(
          { comissao_tipo: 'percentual', comissao_valor: 30, name: 'Bia' },
          'prof2',
        ),
      ],
    })
    const os = osRec({
      execucao_modo: 'dupla',
      profissional: 'prof1',
      profissional2: 'prof2',
      valor_pago: 200,
    })
    lib.criarComissaoProfissional(app, os, 'em_andamento')
    assert.equal(app._created.length, 2)
    const vals = app._created.map((c) => c.get('valor_comissao')).sort()
    assert.deepEqual(vals, [30, 30])
    for (const c of app._created) {
      assert.match(String(c.get('descricao') || ''), /Dupla/)
    }
  })

  it('solo continua 1 comissão integral', () => {
    const app = mockApp({
      profs: [
        rec(
          { comissao_tipo: 'percentual', comissao_valor: 30, name: 'Ana' },
          'prof1',
        ),
      ],
    })
    lib.criarComissaoProfissional(
      app,
      osRec({ valor_pago: 200, profissional: 'prof1' }),
      'em_andamento',
    )
    assert.equal(app._created.length, 1)
    assert.equal(app._created[0].get('valor_comissao'), 60)
  })
})
