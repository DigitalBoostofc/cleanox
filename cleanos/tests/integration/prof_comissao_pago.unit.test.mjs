/**
 * CleanOS — comissão ↔ despesa em Movimentações.
 *
 * - 👍 individual → "Comissão - Prof - OS - Cliente" (1:1, data = pago_em)
 * - Lote (sem 1:1) → "Comissão - Prof - N OS" agregado (data = pago_em)
 * - Pendente ciclo → "Comissão · Prof · período (N OS)" no fim do ciclo
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

function mockApp({ lancamentos = [], comissoes = [], users } = {}) {
  const saved = []
  const deleted = []
  const cats = [rec({ tipo: 'despesa', nome: 'Equipe', parent_id: '' }, 'cat_equipe')]
  const cnts = [rec({ nome: 'Caixa', ativo: true, padrao: true }, 'conta_padrao')]
  const us = users ?? {
    prof1: rec(
      { name: 'João Pedro', pagamento_frequencia: 'semanal', pagamento_dia: 6 },
      'prof1',
    ),
  }
  let coms = [...comissoes]
  let nextId = 1

  const app = {
    findFirstRecordByFilter(collection, filter) {
      if (collection === 'fin_categorias') {
        const hit = cats.find((c) => c.get('nome') === 'Equipe')
        if (hit) return hit
        throw new Error('not found')
      }
      if (collection === 'fin_lancamentos') {
        const m1 = /comissao_id = '([^']*)'/.exec(filter)
        if (m1) {
          const hit = lancamentos.find((l) => l.get('comissao_id') === m1[1])
          if (hit) return hit
          throw new Error('not found')
        }
        throw new Error('not found')
      }
      throw new Error('not found')
    },
    findRecordsByFilter(collection, filter) {
      if (collection === 'fin_categorias') return cats
      if (collection === 'fin_contas') return cnts
      if (collection === 'fin_lancamentos') {
        let list = lancamentos.filter((l) => l.get('origem') === 'via_comissao')
        const mp =
          /profissional_id = "([^"]*)"/.exec(filter) ||
          /profissional_id = '([^']*)'/.exec(filter)
        if (mp) list = list.filter((l) => l.get('profissional_id') === mp[1])
        if (filter.includes('comissao_id != ""') || filter.includes("comissao_id != ''")) {
          list = list.filter((l) => !!l.get('comissao_id'))
        } else if (
          filter.includes('comissao_id = ""') ||
          filter.includes('comissao_id = null')
        ) {
          list = list.filter((l) => !l.get('comissao_id'))
        }
        return list
      }
      if (collection === 'prof_comissoes') return coms
      return []
    },
    findRecordById(collection, id) {
      if (collection === 'users') return us[id] || rec({ name: 'X' }, id)
      throw new Error('not found')
    },
    findCollectionByNameOrId(name) {
      return { name }
    },
    db() {
      return {
        newQuery(sql) {
          return {
            bind(params) {
              this._p = params
              this._sql = sql
              return this
            },
            execute() {
              const p = this._p || {}
              const sql = String(this._sql || '')
              if (sql.includes('UPDATE prof_comissoes')) {
                const c = coms.find((x) => x.id === p.id)
                if (c) {
                  if (p.st != null) c.set('status', p.st)
                  if (p.pe != null) c.set('pago_em', p.pe)
                }
              }
              if (sql.includes('UPDATE fin_lancamentos')) {
                const l = lancamentos.find((x) => x.id === p.id)
                if (l) {
                  if (p.descricao != null) l.set('descricao', p.descricao)
                  if (p.observacao != null) l.set('observacao', p.observacao)
                  if (p.data != null) l.set('data', p.data)
                  if (p.valor != null) l.set('valor', p.valor)
                  if (p.status != null) l.set('status', p.status)
                }
              }
            },
          }
        },
      }
    },
    save(r) {
      if (r.collection?.name === 'fin_contas') throw new Error('R1')
      if (r.collection?.name === 'fin_lancamentos') {
        if (!r.id || r.id === 'lanc_novo') r.id = 'lanc_' + nextId++
        if (r._data) {
          const d = r._data
          r.get = (k) => d[k]
          r.set = (k, v) => {
            d[k] = v
          }
        }
        if (!lancamentos.find((l) => l.id === r.id)) lancamentos.push(r)
      }
      saved.push(r)
    },
    delete(r) {
      deleted.push(r)
      for (let j = lancamentos.length - 1; j >= 0; j--) {
        if (lancamentos[j].id === r.id || lancamentos[j] === r) {
          lancamentos.splice(j, 1)
        }
      }
    },
  }
  return { app, saved, deleted, lancamentos, coms }
}

function comPaga(over = {}, id = 'c1') {
  return rec(
    {
      status: 'paga',
      valor_comissao: 60,
      profissional: 'prof1',
      profissional_nome: 'João Pedro',
      descricao: 'Serv · Renata Sabóia - Fiat Argo',
      data: '2026-07-22',
      pago_em: '2026-07-27',
      ...over,
    },
    id,
  )
}
function comPend(over = {}, id = 'p1') {
  return rec(
    {
      status: 'pendente',
      valor_comissao: 60,
      profissional: 'prof1',
      profissional_nome: 'João Pedro',
      descricao: 'Serv · Cliente X - Carro',
      data: '2026-07-22',
      pago_em: '',
      ...over,
    },
    id,
  )
}

function ones(lancs) {
  return lancs.filter((l) => l.get('comissao_id') && l.get('status') === 'pago')
}
function lotes(lancs) {
  return lancs.filter(
    (l) =>
      !l.get('comissao_id') &&
      String(l.get('observacao') || '').startsWith('repasse_ciclo_pago:'),
  )
}
function pends(lancs) {
  return lancs.filter(
    (l) =>
      !l.get('comissao_id') &&
      String(l.get('observacao') || '').startsWith('repasse_ciclo:') &&
      !String(l.get('observacao') || '').startsWith('repasse_ciclo_pago:'),
  )
}

describe('individual 👍', () => {
  it('cria 1:1 Comissao - Prof - OS - Cliente na data do 👍', () => {
    const c = comPaga()
    const { app, lancamentos } = mockApp({ comissoes: [c] })
    pago.sincronizarLancamento(app, c, 'pendente')
    const o = ones(lancamentos)
    assert.equal(o.length, 1)
    assert.equal(o[0].get('descricao'), 'Comissão - João Pedro - OS - Renata Sabóia')
    assert.equal(String(o[0].get('data')).slice(0, 10), '2026-07-27')
    assert.equal(lotes(lancamentos).length, 0)
  })

  it('duas 👍 individuais → 2 linhas 1:1 (não agrega)', () => {
    const c1 = comPaga(
      { descricao: 'S · Cli A - V', pago_em: '2026-07-27' },
      'a',
    )
    const c2 = comPaga(
      { descricao: 'S · Cli B - V', pago_em: '2026-07-27' },
      'b',
    )
    const { app, lancamentos } = mockApp({ comissoes: [c1, c2] })
    pago.sincronizarLancamento(app, c1, 'pendente')
    pago.sincronizarLancamento(app, c2, 'pendente')
    assert.equal(ones(lancamentos).length, 2)
    assert.equal(lotes(lancamentos).length, 0)
  })
})

describe('lote (sem 1:1 prévia)', () => {
  it('3 pagas sem 1:1 → 1 linha Comissao - Prof - 3 OS', () => {
    const coms = [
      comPaga({ descricao: 'S · A - X', pago_em: '2026-07-27' }, 'a'),
      comPaga({ descricao: 'S · B - X', pago_em: '2026-07-27' }, 'b'),
      comPaga({ descricao: 'S · C - X', pago_em: '2026-07-27' }, 'c'),
    ]
    // NÃO chama sincronizarLancamento (que cria 1:1) — só resync lote
    const { app, lancamentos } = mockApp({ comissoes: coms })
    pago.sincronizarCiclosDoProf(app, 'prof1')
    assert.equal(ones(lancamentos).length, 0)
    const L = lotes(lancamentos)
    assert.equal(L.length, 1)
    assert.equal(L[0].get('valor'), 180)
    assert.equal(L[0].get('descricao'), 'Comissão - João Pedro - 3 OS')
    assert.equal(String(L[0].get('data')).slice(0, 10), '2026-07-27')
    assert.match(
      String(L[0].get('observacao')),
      /^repasse_ciclo_pago:\d{4}-\d{2}-\d{2}:\d{4}-\d{2}-\d{2}:2026-07-27$/,
    )
  })

  it('1 individual + 2 lote no mesmo ciclo', () => {
    const ind = comPaga(
      { descricao: 'S · Solo - X', pago_em: '2026-07-26' },
      'solo',
    )
    const a = comPaga(
      { descricao: 'S · A - X', pago_em: '2026-07-27' },
      'a',
    )
    const b = comPaga(
      { descricao: 'S · B - X', pago_em: '2026-07-27' },
      'b',
    )
    const { app, lancamentos } = mockApp({ comissoes: [ind, a, b] })
    // individual cria 1:1
    pago.sincronizarLancamento(app, ind, 'pendente')
    // lote: só resync (a,b sem 1:1)
    pago.sincronizarCiclosDoProf(app, 'prof1')
    assert.equal(ones(lancamentos).length, 1)
    assert.match(String(ones(lancamentos)[0].get('descricao')), /Solo/)
    const L = lotes(lancamentos)
    assert.equal(L.length, 1)
    assert.equal(L[0].get('valor'), 120)
    assert.equal(L[0].get('descricao'), 'Comissão - João Pedro - 2 OS')
  })
})

describe('pendente + marcar 1 de N', () => {
  it('9 pend → 1 paga individual: pendente 8 + 1:1', () => {
    const coms = []
    for (let i = 0; i < 9; i++) {
      coms.push(
        comPend(
          { descricao: `S · Cli ${i} - V`, data: '2026-07-22' },
          'p' + i,
        ),
      )
    }
    const { app, lancamentos } = mockApp({ comissoes: coms })
    pago.sincronizarCiclosDoProf(app, 'prof1')
    assert.equal(pends(lancamentos)[0].get('valor'), 540)

    coms[0].set('status', 'paga')
    coms[0].set('pago_em', '2026-07-27')
    pago.sincronizarLancamento(app, coms[0], 'pendente')

    assert.equal(pends(lancamentos)[0].get('valor'), 480)
    assert.equal(ones(lancamentos).length, 1)
    assert.equal(lotes(lancamentos).length, 0)
  })
})

describe('mão na linha / Fechar ciclo (lote via lançamento)', () => {
  it('👍 na linha repasse_ciclo pendente → 1 linha agregada, zero 1:1', () => {
    const coms = [
      comPend({ descricao: 'S · A - X', data: '2026-07-22' }, 'a'),
      comPend({ descricao: 'S · B - X', data: '2026-07-23' }, 'b'),
      comPend({ descricao: 'S · C - X', data: '2026-07-24' }, 'c'),
    ]
    const ciclo = rec(
      {
        tipo: 'despesa',
        origem: 'via_comissao',
        profissional_id: 'prof1',
        data: '2026-07-25',
        valor: 180,
        status: 'pago', // já commitado pelo e.next()
        comissao_id: '',
        descricao: 'Comissão · João Pedro · 19/07 a 25/07/2026 (3 OS)',
        observacao: 'repasse_ciclo:2026-07-19:2026-07-25',
      },
      'ciclo1',
    )
    const { app, lancamentos } = mockApp({
      comissoes: coms,
      lancamentos: [ciclo],
    })
    // Espelha o hook de Transações / Fechar ciclo (e.next já deixou status=pago)
    pago.sincronizarComissaoDoLancamento(app, ciclo, 'pendente')

    assert.equal(ones(lancamentos).length, 0, 'não cria 1:1 por cliente')
    // A MESMA despesa (id ciclo1) — metadados via SQL, sem 2º app.save
    const same = lancamentos.find((l) => l.id === 'ciclo1')
    assert.ok(same, 'mantém o mesmo lançamento')
    assert.equal(same.get('status'), 'pago')
    assert.equal(same.get('valor'), 180)
    assert.equal(same.get('descricao'), 'Comissão - João Pedro - 3 OS')
    assert.match(
      String(same.get('observacao') || ''),
      /^repasse_ciclo_pago:/,
    )
    // comissões todas pagas (SQL)
    assert.equal(coms.filter((c) => c.get('status') === 'paga').length, 3)
  })
})

describe('R1', () => {
  it('não grava fin_contas', () => {
    const c = comPaga()
    const { app } = mockApp({ comissoes: [c] })
    assert.doesNotThrow(() => pago.sincronizarLancamento(app, c, 'pendente'))
  })
})
