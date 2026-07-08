/**
 * CleanOS — testes UNITÁRIOS da exclusão segura de profissional (prof_delete_lib.js).
 *
 * Não precisam de PocketBase rodando: carregam o módulo CommonJS real com um `app`
 * mockado e exercitam exatamente os caminhos do handler onRecordDelete("users"):
 *
 *   (a) delete BLOQUEADO — profissional COM OS "em aberto": handleDelete lança
 *       BadRequestError com a mensagem PT-BR ANTES de next() (que comita a exclusão),
 *       e NÃO apaga nada.
 *   (b) delete OK + cascata — profissional SEM OS em aberto: handleDelete apaga as
 *       `disponibilidade` do profissional ANTES de next() (senão o próprio delete
 *       falharia: required=true & cascadeDelete=false) e então chama next() 1x.
 *
 * Também cobre: papel != profissional não é interceptado; o filtro de OS usa os
 * valores REAIS do enum de ordens_servico.status (concluida/cancelada = encerradas);
 * e a mensagem exata (singular/plural) que o Flutter vai ver.
 */

import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)

// PocketBase injeta BadRequestError como global (JSVM). Fora do PB, fornecemos um
// shim equivalente — o lib só o referencia no momento do throw.
class BadRequestError extends Error {
  constructor(message) { super(message); this.name = 'BadRequestError' }
}
globalThis.BadRequestError = BadRequestError

const prof = require('../../pb/pb_hooks/prof_delete_lib.js')

// ── mocks ────────────────────────────────────────────────────────────────────

/** Record mockado de `users`: get(campo) do mapa; id fixo. */
function mockUser(fields, id = 'profTEST') {
  return { id, get: (k) => fields[k] }
}

/**
 * app mockado. `byCollection` mapeia nome da coleção → array de registros que
 * findRecordsByFilter retornará. Registra cada chamada em `calls` (coleção, filtro,
 * params) e cada delete em `deleted` (na ORDEM em que aconteceram).
 */
function mockApp(byCollection) {
  const calls = []
  const deleted = []
  const order = []
  const app = {
    findRecordsByFilter(collection, filter, sort, limit, offset, params) {
      calls.push({ collection, filter, params })
      return byCollection[collection] || []
    },
    delete(rec) { deleted.push(rec); order.push('disp:' + rec.id) },
  }
  return { app, calls, deleted, order }
}

/** Cria um next() spy que conta chamadas e registra a ordem no array `order`. */
function spyNext(order) {
  const fn = () => { fn.calls++; order.push('next') }
  fn.calls = 0
  return fn
}

// ── (a) BLOQUEIO: profissional com OS em aberto ──────────────────────────────

describe('(a) delete BLOQUEADO quando o profissional tem OS em aberto', () => {
  it('lança BadRequestError com a mensagem PT-BR e NÃO chama next() nem apaga nada', () => {
    const osAberta = mockUser({ status: 'em_andamento' }, 'os1')
    const { app, deleted, order } = mockApp({ ordens_servico: [osAberta] })
    const user = mockUser({ role: 'profissional' })
    const next = spyNext(order)

    assert.throws(
      () => prof.handleDelete(app, user, next),
      (err) => {
        assert.ok(err instanceof BadRequestError, 'deve ser BadRequestError (400)')
        assert.match(err.message, /Não é possível excluir este profissional/)
        assert.match(err.message, /ordem de serviço em aberto|ordens de serviço em aberto/)
        return true
      }
    )
    assert.strictEqual(next.calls, 0, 'bloqueio DEVE ocorrer ANTES de next() (que comita)')
    assert.strictEqual(deleted.length, 0, 'nada pode ser apagado quando bloqueado')
  })

  it('a mensagem é montada com a QUANTIDADE de OS em aberto (plural)', () => {
    const abertas = [mockUser({}, 'a'), mockUser({}, 'b'), mockUser({}, 'c')]
    const { app } = mockApp({ ordens_servico: abertas })
    const user = mockUser({ role: 'profissional' })
    assert.throws(
      () => prof.handleDelete(app, user, () => {}),
      (err) => { assert.match(err.message, /possui 3 ordens de serviço em aberto/); return true }
    )
  })
})

// ── (b) SUCESSO + cascata: profissional sem OS em aberto ─────────────────────

describe('(b) delete OK e cascateia disponibilidade quando NÃO há OS em aberto', () => {
  it('apaga a disponibilidade ANTES de next(), e chama next() exatamente 1x', () => {
    const disp = mockUser({ profissional: 'profTEST' }, 'disp1')
    const { app, deleted, order } = mockApp({ ordens_servico: [], disponibilidade: [disp] })
    const user = mockUser({ role: 'profissional' })
    const next = spyNext(order)

    prof.handleDelete(app, user, next)

    assert.strictEqual(next.calls, 1, 'next() (exclusão do usuário) deve ser chamado 1x')
    assert.deepStrictEqual(deleted, [disp], 'a disponibilidade do profissional é removida')
    // Ordem crítica: a disponibilidade some ANTES do commit (senão next() falharia).
    assert.deepStrictEqual(order, ['disp:disp1', 'next'],
      'delete da disponibilidade deve preceder next()')
  })

  it('sem disponibilidade: não apaga nada e ainda chama next() 1x', () => {
    const { app, deleted } = mockApp({ ordens_servico: [], disponibilidade: [] })
    const user = mockUser({ role: 'profissional' })
    const next = spyNext([])
    prof.handleDelete(app, user, next)
    assert.strictEqual(deleted.length, 0)
    assert.strictEqual(next.calls, 1)
  })

  it('OS apenas concluida/cancelada NÃO bloqueiam (filtro usa o enum real)', () => {
    // O filtro exclui concluida/cancelada no nível do banco → a query de OS em
    // aberto volta vazia. Verificamos que o filtro enviado nomeia esses estados.
    const { app, calls } = mockApp({ ordens_servico: [], disponibilidade: [] })
    const user = mockUser({ role: 'profissional' })
    prof.handleDelete(app, user, () => {})
    const osQuery = calls.find((c) => c.collection === 'ordens_servico')
    assert.ok(osQuery, 'deve consultar ordens_servico')
    assert.match(osQuery.filter, /status != 'concluida'/, "filtro deve excluir 'concluida'")
    assert.match(osQuery.filter, /status != 'cancelada'/, "filtro deve excluir 'cancelada'")
    assert.match(osQuery.filter, /profissional = \{:pid\}/, 'filtro deve ser por profissional')
    assert.strictEqual(osQuery.params.pid, 'profTEST', 'param pid = id do profissional')
  })
})

// ── papel != profissional: comportamento padrão ─────────────────────────────

describe('papel != profissional não é interceptado', () => {
  it('admin: chama next() direto, sem consultar OS nem apagar nada', () => {
    const { app, calls, deleted } = mockApp({})
    const user = mockUser({ role: 'admin' }, 'adm1')
    const next = spyNext([])
    prof.handleDelete(app, user, next)
    assert.strictEqual(next.calls, 1, 'exclusão de admin segue o fluxo padrão do PB')
    assert.strictEqual(calls.length, 0, 'não deve consultar ordens_servico/disponibilidade')
    assert.strictEqual(deleted.length, 0)
  })

  it('gerente: idem (sem bloqueio nem limpeza)', () => {
    const { app, calls } = mockApp({})
    const next = spyNext([])
    prof.handleDelete(app, mockUser({ role: 'gerente' }, 'ger1'), next)
    assert.strictEqual(next.calls, 1)
    assert.strictEqual(calls.length, 0)
  })
})

// ── mensagemBloqueio: strings exatas (singular vs plural) ────────────────────

describe('mensagemBloqueio — texto PT-BR exato surfado ao Flutter', () => {
  it('n=1 → singular', () => {
    assert.strictEqual(
      prof.mensagemBloqueio(1),
      'Não é possível excluir este profissional: ele possui uma ordem de serviço em aberto (não concluída/cancelada). Conclua ou cancele essa ordem de serviço antes de excluir o profissional.'
    )
  })
  it('n=2 → plural com contagem', () => {
    assert.strictEqual(
      prof.mensagemBloqueio(2),
      'Não é possível excluir este profissional: ele possui 2 ordens de serviço em aberto (não concluída/cancelada). Conclua ou cancele essas ordens de serviço antes de excluir o profissional.'
    )
  })
})

// ── isProfissional: guarda de papel ─────────────────────────────────────────

describe('isProfissional', () => {
  it('true só para role === "profissional"', () => {
    assert.strictEqual(prof.isProfissional(mockUser({ role: 'profissional' })), true)
    assert.strictEqual(prof.isProfissional(mockUser({ role: 'admin' })), false)
    assert.strictEqual(prof.isProfissional(mockUser({ role: '' })), false)
    assert.strictEqual(prof.isProfissional(null), false)
  })
})
