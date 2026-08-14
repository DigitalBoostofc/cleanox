/** Categoria financeira automática: Equipe → nome do profissional. */
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const hooksDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../pb/pb_hooks',
)
globalThis.__hooks = hooksDir

class TestError extends Error {}
globalThis.BadRequestError = TestError

class Record {
  constructor(collection) {
    this.collection = collection
    this.id = 'sub_nova'
    this.data = {}
  }
  set(key, value) {
    this.data[key] = value
  }
  get(key) {
    return this.data[key]
  }
}
globalThis.Record = Record

const lib = require('../../pb/pb_hooks/users_categoria_comissao_lib.js')

function rec(id, fields) {
  return {
    id,
    get: (key) => fields[key],
    set: (key, value) => {
      fields[key] = value
    },
    fields,
  }
}

function userRec(fields, id = 'u1') {
  const data = { ...fields }
  return rec(id, data)
}

function mockApp({ categorias = [], users = [], lancamentos = [] } = {}) {
  const saved = []
  const deleted = []
  const cats = [...categorias]
  let nextSub = 1

  const app = {
    cats,
    saved,
    deleted,
    findFirstRecordByFilter(collection, filter) {
      if (collection !== 'fin_categorias') throw new Error('not found')
      const nomeEquipe = filter.includes("nome = 'Equipe'")
      const parentMatch = /parent_id = '([^']+)'/.exec(filter)
      const nomeMatch = /nome = '([^']+)'/.exec(filter)
      const hit = cats.find((c) => {
        if (nomeEquipe) {
          return (
            c.get('nome') === 'Equipe' &&
            c.get('tipo') === 'despesa' &&
            !c.get('parent_id')
          )
        }
        if (parentMatch && nomeMatch) {
          return (
            c.get('tipo') === 'despesa' &&
            c.get('parent_id') === parentMatch[1] &&
            c.get('nome') === nomeMatch[1]
          )
        }
        return false
      })
      if (!hit) throw new Error('not found')
      return hit
    },
    findRecordById(collection, id) {
      if (collection === 'fin_categorias') {
        const hit = cats.find((c) => c.id === id)
        if (hit) return hit
      }
      if (collection === 'users') {
        const hit = users.find((u) => u.id === id)
        if (hit) return hit
      }
      throw new Error('not found')
    },
    findRecordsByFilter(collection, filter) {
      if (collection === 'users') {
        const m = /categoria_comissao = {:id}/.exec(filter) ||
          /categoria_comissao = '([^']+)'/.exec(filter)
        if (m) {
          const id = typeof arguments[5] === 'object' && arguments[5]?.id
            ? arguments[5].id
            : m[1]
          return users.filter((u) => String(u.get('categoria_comissao') || '') === id)
        }
        return users
      }
      if (collection === 'fin_lancamentos') {
        const m = /subcategoria_id = {:id}/.exec(filter) ||
          /subcategoria_id = '([^']+)'/.exec(filter)
        if (m) {
          const id = typeof arguments[5] === 'object' && arguments[5]?.id
            ? arguments[5].id
            : m[1]
          return lancamentos.filter((l) => String(l.get('subcategoria_id') || '') === id)
        }
        return lancamentos
      }
      if (collection === 'fin_categorias') {
        return cats.filter((c) => c.get('tipo') === 'despesa' && !c.get('parent_id'))
      }
      return []
    },
    findCollectionByNameOrId: () => ({ name: 'fin_categorias' }),
    save: (record) => {
      if (!record.id) record.id = 'sub_' + nextSub++
      saved.push(record)
      if (record.collection && record.collection.name === 'fin_categorias') {
        cats.push(
          rec(record.id, {
            nome: record.get('nome'),
            tipo: record.get('tipo'),
            parent_id: record.get('parent_id'),
          }),
        )
      }
    },
    delete: (record) => {
      deleted.push(record.id)
    },
  }
  return app
}

const EQUIPE = rec('catdequipe00001', {
  tipo: 'despesa',
  nome: 'Equipe',
  parent_id: '',
})

describe('temPapelProfissional', () => {
  it('detecta role ativo profissional', () => {
    assert.equal(
      lib.temPapelProfissional(userRec({ role: 'profissional', roles: ['profissional'] })),
      true,
    )
  })

  it('detecta conta admin+profissional', () => {
    assert.equal(
      lib.temPapelProfissional(
        userRec({ role: 'admin', roles: ['admin', 'profissional'] }),
      ),
      true,
    )
  })

  it('admin/gerente sem profissional não configura', () => {
    assert.equal(
      lib.temPapelProfissional(userRec({ role: 'admin', roles: ['admin'] })),
      false,
    )
    assert.equal(
      lib.temPapelProfissional(userRec({ role: 'gerente', roles: ['gerente'] })),
      false,
    )
  })

  it('role vazio e roles vazio herda o default profissional', () => {
    assert.equal(lib.temPapelProfissional(userRec({ role: '', roles: [] })), true)
  })
})

describe('aplicarCategoriaNoCreate', () => {
  it('profissional novo cria Equipe → Nome e grava categoria_comissao', () => {
    const app = mockApp({ categorias: [EQUIPE] })
    const user = userRec({
      role: 'profissional',
      roles: ['profissional'],
      name: '  João Pedro  ',
      nome: '',
      categoria_comissao: 'cat_arbitraria',
    })

    const out = lib.aplicarCategoriaNoCreate(app, user)

    assert.equal(user.get('categoria_comissao'), 'sub_nova')
    assert.equal(out.created, true)
    assert.equal(out.subId, 'sub_nova')
    assert.equal(app.saved[0].get('nome'), 'João Pedro')
    assert.equal(app.saved[0].get('parent_id'), 'catdequipe00001')
    assert.equal(app.saved[0].get('tipo'), 'despesa')
  })

  it('conta admin+profissional também configura', () => {
    const app = mockApp({ categorias: [EQUIPE] })
    const user = userRec({
      role: 'admin',
      roles: ['admin', 'profissional'],
      name: 'Ana Dual',
    })
    lib.aplicarCategoriaNoCreate(app, user)
    assert.equal(user.get('categoria_comissao'), 'sub_nova')
  })

  it('admin/gerente sem profissional não configura e ignora o cliente', () => {
    const app = mockApp({ categorias: [EQUIPE] })
    const user = userRec({
      role: 'admin',
      roles: ['admin'],
      name: 'Ana Admin',
      categoria_comissao: 'cat_arbitraria',
    })
    const out = lib.aplicarCategoriaNoCreate(app, user)
    assert.equal(out.created, false)
    assert.equal(user.get('categoria_comissao'), '')
    assert.equal(app.saved.length, 0)
  })

  it('retry reutiliza a subcategoria existente sob Equipe', () => {
    const joao = rec('cat_joao', {
      tipo: 'despesa',
      nome: 'João Pedro',
      parent_id: 'catdequipe00001',
    })
    const app = mockApp({ categorias: [EQUIPE, joao] })
    const user = userRec({
      role: 'profissional',
      roles: ['profissional'],
      name: 'João Pedro',
    })
    const a = lib.aplicarCategoriaNoCreate(app, user)
    const b = lib.aplicarCategoriaNoCreate(app, user)
    assert.equal(a.subId, 'cat_joao')
    assert.equal(b.subId, 'cat_joao')
    assert.equal(a.created, false)
    assert.equal(b.created, false)
    assert.equal(app.saved.length, 0)
  })

  it('falta de Equipe falha claro e não cai em raiz aleatória', () => {
    const marketing = rec('cat_mkt', {
      tipo: 'despesa',
      nome: 'Marketing',
      parent_id: '',
    })
    const app = mockApp({ categorias: [marketing] })
    const user = userRec({
      role: 'profissional',
      roles: ['profissional'],
      name: 'João Pedro',
    })
    assert.throws(
      () => lib.aplicarCategoriaNoCreate(app, user),
      (err) => /Equipe/.test(String(err.message || err)),
    )
    assert.equal(app.saved.length, 0)
    assert.notEqual(user.get('categoria_comissao'), 'cat_mkt')
  })
})

describe('aplicarCategoriaNoUpdate', () => {
  it('categoria já válida em usuário antigo é preservada (mesmo com rename)', () => {
    const marketing = rec('cat_marketing', {
      tipo: 'despesa',
      nome: 'Marketing',
      parent_id: 'cat_despesas',
    })
    const app = mockApp({ categorias: [EQUIPE, marketing] })
    const orig = userRec({
      role: 'profissional',
      roles: ['profissional'],
      name: 'João Pedro',
      categoria_comissao: 'cat_marketing',
    })
    const next = userRec({
      role: 'profissional',
      roles: ['profissional'],
      name: 'João P. Silva',
      categoria_comissao: 'cat_arbitraria',
    })
    next.original = () => orig

    lib.aplicarCategoriaNoUpdate(app, next)
    assert.equal(next.get('categoria_comissao'), 'cat_marketing')
    assert.equal(app.saved.length, 0)
  })

  it('atualização que adiciona profissional reconcilia quando vazio', () => {
    const app = mockApp({ categorias: [EQUIPE] })
    const orig = userRec({
      role: 'admin',
      roles: ['admin'],
      name: 'Ana Dual',
      categoria_comissao: '',
    })
    const next = userRec({
      role: 'admin',
      roles: ['admin', 'profissional'],
      name: 'Ana Dual',
      categoria_comissao: '',
    })
    next.original = () => orig

    lib.aplicarCategoriaNoUpdate(app, next)
    assert.equal(next.get('categoria_comissao'), 'sub_nova')
    assert.equal(app.saved[0].get('nome'), 'Ana Dual')
  })

  it('remover papel profissional não apaga a subcategoria nem o vínculo histórico', () => {
    const joao = rec('cat_joao', {
      tipo: 'despesa',
      nome: 'João Pedro',
      parent_id: 'catdequipe00001',
    })
    const app = mockApp({ categorias: [EQUIPE, joao] })
    const orig = userRec({
      role: 'profissional',
      roles: ['profissional'],
      name: 'João Pedro',
      categoria_comissao: 'cat_joao',
    })
    const next = userRec({
      role: 'admin',
      roles: ['admin'],
      name: 'João Pedro',
      categoria_comissao: '',
    })
    next.original = () => orig

    lib.aplicarCategoriaNoUpdate(app, next)
    assert.equal(next.get('categoria_comissao'), 'cat_joao')
    assert.equal(app.deleted.length, 0)
  })
})

describe('compensarSubcategoriaOrfa', () => {
  it('apaga só a sub criada nesta tentativa se ninguém a usa', () => {
    const orfa = rec('sub_nova', {
      tipo: 'despesa',
      nome: 'João Pedro',
      parent_id: 'catdequipe00001',
    })
    const app = mockApp({ categorias: [EQUIPE, orfa] })
    lib.compensarSubcategoriaOrfa(app, { created: true, subId: 'sub_nova' })
    assert.deepEqual(app.deleted, ['sub_nova'])
  })

  it('não apaga sub reutilizada', () => {
    const app = mockApp({ categorias: [EQUIPE] })
    lib.compensarSubcategoriaOrfa(app, { created: false, subId: 'cat_joao' })
    assert.deepEqual(app.deleted, [])
  })

  it('sub preexistente reutilizada + falha de create nunca é deletada', () => {
    const joao = rec('cat_joao', {
      tipo: 'despesa',
      nome: 'João Pedro',
      parent_id: 'catdequipe00001',
    })
    const app = mockApp({ categorias: [EQUIPE, joao] })
    const user = userRec({
      role: 'profissional',
      roles: ['profissional'],
      name: 'João Pedro',
      categoria_comissao: '',
    })

    const out = lib.aplicarCategoriaNoCreate(app, user)
    assert.equal(out.created, false)
    assert.equal(out.subId, 'cat_joao')

    // Espelha o catch de e.next() (email duplicado, etc.).
    lib.compensarSubcategoriaOrfa(app, out)
    assert.deepEqual(app.deleted, [])
    assert.ok(app.cats.some((c) => c.id === 'cat_joao'))
  })

  it('não trata created omitido/forçado como órfã desta tentativa', () => {
    const joao = rec('cat_joao', {
      tipo: 'despesa',
      nome: 'João Pedro',
      parent_id: 'catdequipe00001',
    })
    const app = mockApp({ categorias: [EQUIPE, joao] })
    lib.compensarSubcategoriaOrfa(app, { subId: 'cat_joao' })
    lib.compensarSubcategoriaOrfa(app, { created: 'true', subId: 'cat_joao' })
    assert.deepEqual(app.deleted, [])
  })
})

describe('hook users_categoria_comissao.pb.js', () => {
  const registered = {}
  globalThis.onRecordCreate = (fn) => {
    registered.create = fn
  }
  globalThis.onRecordUpdate = (fn) => {
    registered.update = fn
  }
  globalThis.onRecordAfterCreateError = (fn) => {
    registered.afterCreateError = fn
  }
  require('../../pb/pb_hooks/users_categoria_comissao.pb.js')

  it('não registra AfterCreateError (apagaria sub reutilizada)', () => {
    assert.equal(registered.afterCreateError, undefined)
    assert.equal(typeof registered.create, 'function')
    assert.equal(typeof registered.update, 'function')
  })

  it('create falho após reutilizar Equipe→nome não apaga a sub preexistente', () => {
    const joao = rec('cat_joao', {
      tipo: 'despesa',
      nome: 'João Pedro',
      parent_id: 'catdequipe00001',
    })
    const app = mockApp({ categorias: [EQUIPE, joao] })
    const user = userRec({
      role: 'profissional',
      roles: ['profissional'],
      name: 'João Pedro',
    })

    assert.throws(
      () =>
        registered.create({
          app,
          record: user,
          next: () => {
            throw new Error('email duplicado')
          },
        }),
      /email duplicado/,
    )
    assert.deepEqual(app.deleted, [])
    assert.ok(app.cats.some((c) => c.id === 'cat_joao'))
  })
})
