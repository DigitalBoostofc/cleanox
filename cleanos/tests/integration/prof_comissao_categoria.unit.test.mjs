/** Comissão/bonificação: categoria Equipe → profissional. */
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

const { acharCategoriaComissao } = require('../../pb/pb_hooks/prof_comissao_pago_lib.js')

function category(id, fields) {
  return {
    id,
    get: (key) => fields[key],
  }
}

describe('categoria de comissão por profissional', () => {
  it('resolve subcategoria existente sob Equipe', () => {
    const equipe = category('cat_equipe', {
      tipo: 'despesa',
      nome: 'Equipe',
      parent_id: '',
    })
    const joao = category('cat_joao', {
      tipo: 'despesa',
      nome: 'João Pedro',
      parent_id: 'cat_equipe',
    })
    const app = {
      findFirstRecordByFilter(collection, filter) {
        if (collection !== 'fin_categorias') throw new Error('unexpected')
        if (filter.includes("nome = 'Equipe'")) return equipe
        if (filter.includes("nome = 'João Pedro'")) return joao
        throw new Error('not found')
      },
    }

    assert.deepEqual(acharCategoriaComissao(app, 'João Pedro'), {
      categoriaId: 'cat_equipe',
      subcategoriaId: 'cat_joao',
    })
  })

  it('cria subcategoria com o nome quando ainda não existe', () => {
    const equipe = category('cat_equipe', {
      tipo: 'despesa',
      nome: 'Equipe',
      parent_id: '',
    })
    let saved
    const app = {
      findFirstRecordByFilter(collection, filter) {
        if (filter.includes("nome = 'Equipe'")) return equipe
        throw new Error('not found')
      },
      findCollectionByNameOrId: () => ({ name: 'fin_categorias' }),
      save: (record) => {
        saved = record
      },
    }

    assert.deepEqual(acharCategoriaComissao(app, 'Maria Silva'), {
      categoriaId: 'cat_equipe',
      subcategoriaId: 'sub_nova',
    })
    assert.equal(saved.get('nome'), 'Maria Silva')
    assert.equal(saved.get('tipo'), 'despesa')
    assert.equal(saved.get('parent_id'), 'cat_equipe')
  })

  it('prioriza a categoria configurada no usuário', () => {
    const app = {
      findRecordById(collection, id) {
        if (collection === 'users' && id === 'prof1') {
          return category(id, { categoria_comissao: 'cat_marketing' })
        }
        if (collection === 'fin_categorias' && id === 'cat_marketing') {
          return category(id, {
            tipo: 'despesa',
            nome: 'Marketing',
            parent_id: 'cat_despesas',
          })
        }
        throw new Error('not found')
      },
    }

    assert.deepEqual(acharCategoriaComissao(app, 'João Pedro', 'prof1'), {
      categoriaId: 'cat_despesas',
      subcategoriaId: 'cat_marketing',
    })
  })
})
