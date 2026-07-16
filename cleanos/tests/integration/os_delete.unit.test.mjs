/**
 * CleanOS — testes UNITÁRIOS da exclusão de OS (os_delete_lib.js).
 *
 * O buraco que estes testes travam: `ordens_servico.deleteRule = ADMIN_GERENTE`
 * sempre existiu, mas deletar uma OS "crua" ou FALHA no banco (OS concluída tem
 * `prof_comissoes.os` required sem cascade) ou deixa LIXO financeiro (a receita
 * `via_os` referencia a OS por texto `os_id` — sem FK, o lançamento pago fica
 * órfão e o saldo do caixa permanece inflado para sempre).
 *
 * Não precisam de PocketBase rodando: carregam o módulo CommonJS real com um
 * `app` mockado e exercitam os caminhos do handler onRecordDelete("ordens_servico"):
 *
 *   (a) OS concluída com receita paga + comissão ⇒ receita apagada (estorno do
 *       saldo é do fin_saldo, via hook de delete do lançamento), comissão e sua
 *       despesa apagadas, TUDO antes de next(); next() exatamente 1x.
 *   (b) OS sem dependências ⇒ nada apagado, next() 1x.
 *   (c) falha ao apagar a receita ⇒ throw ANTES de next() (OS fica intacta).
 *
 * ── R1 (invariante que estes testes PROTEGEM) ────────────────────────────────
 * O lib NUNCA escreve em `fin_contas.saldo_atual` — quem estorna é o
 * fin_saldo.pb.js, disparado pelo delete do lançamento. O mock FALHA o teste se
 * qualquer save() acontecer durante a exclusão.
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

// O PocketBase (JSVM) injeta `__hooks` como global; o lib usa
// require(`${__hooks}/prof_comissao_lib.js`) para reusar a limpeza de comissão.
globalThis.__hooks = HOOKS_DIR

const osDelete = require('../../pb/pb_hooks/os_delete_lib.js')

// ── mocks ────────────────────────────────────────────────────────────────────

/** Registro mockado: get(campo) do mapa; id fixo. */
function rec(fields, id) {
  return { id, get: (k) => fields[k] }
}

/**
 * app mockado. `receitas` = lançamentos via_os da OS; `comissoes` = registros de
 * prof_comissoes da OS; `despesas` = lançamentos de comissão (achados por
 * `comissao_id = '...'`). Registra deletes na ORDEM em que aconteceram e LANÇA
 * se algo for salvo (o lib não pode escrever nada — só apagar).
 */
function mockApp({ receitas = [], comissoes = [], despesas = [] } = {}) {
  const deleted = []
  const order = []
  const app = {
    findRecordsByFilter(collection, filter, sort, limit, offset, params) {
      if (collection === 'fin_lancamentos') {
        app._receitaQuery = { filter, params }
        return receitas
      }
      if (collection === 'prof_comissoes') return comissoes
      return []
    },
    findFirstRecordByFilter(collection, filter) {
      if (collection === 'fin_lancamentos') {
        const m = /comissao_id = '([^']*)'/.exec(filter)
        const alvo = m ? m[1] : null
        const hit = despesas.find((d) => d.get('comissao_id') === alvo)
        if (hit) return hit
      }
      throw new Error('not found')
    },
    delete(r) {
      deleted.push(r)
      order.push('del:' + r.id)
    },
    save() {
      throw new Error('o lib de exclusão de OS não pode SALVAR nada (R1)')
    },
  }
  return { app, deleted, order }
}

function spyNext(order) {
  const fn = () => { fn.calls++; order.push('next') }
  fn.calls = 0
  return fn
}

const osRec = (id = 'osTEST') => rec({ status: 'concluida' }, id)

// ── (a) OS concluída: receita + comissão somem ANTES de next() ───────────────

describe('(a) OS concluída com receita paga e comissão', () => {
  it('apaga receita via_os (mesmo paga), despesa e comissão ANTES de next(); next() 1x', () => {
    const receita = rec({ status: 'pago', origem: 'via_os' }, 'lanc_receita')
    const comissao = rec({ status: 'paga' }, 'com1')
    const despesa = rec({ comissao_id: 'com1' }, 'lanc_despesa')
    const { app, deleted, order } = mockApp({
      receitas: [receita],
      comissoes: [comissao],
      despesas: [despesa],
    })
    const next = spyNext(order)

    osDelete.handleDelete(app, osRec(), next)

    assert.strictEqual(next.calls, 1, 'next() (exclusão da OS) deve rodar 1x')
    assert.ok(deleted.includes(receita), 'receita via_os PAGA deve ser apagada')
    assert.ok(deleted.includes(despesa), 'despesa da comissão deve ser apagada')
    assert.ok(deleted.includes(comissao), 'comissão deve ser apagada (required sem cascade)')
    // Ordem crítica: toda a limpeza precede o commit (R3) — e a despesa cai
    // antes da comissão (padrão do removerComissoesDaOs).
    assert.deepStrictEqual(order, [
      'del:lanc_receita',
      'del:lanc_despesa',
      'del:com1',
      'next',
    ])
  })

  it('a query da receita filtra por os_id + origem via_os (sem pegar lançamento manual)', () => {
    const { app } = mockApp({})
    osDelete.handleDelete(app, osRec('os42'), () => {})
    assert.ok(app._receitaQuery, 'deve consultar fin_lancamentos')
    assert.match(app._receitaQuery.filter, /os_id = \{:id\}/)
    assert.match(app._receitaQuery.filter, /origem = 'via_os'/)
    assert.strictEqual(app._receitaQuery.params.id, 'os42')
  })

  it('comissão pendente (sem despesa) também é removida', () => {
    const comissao = rec({ status: 'pendente' }, 'com2')
    const { app, deleted, order } = mockApp({ comissoes: [comissao] })
    const next = spyNext(order)
    osDelete.handleDelete(app, osRec(), next)
    assert.deepStrictEqual(deleted, [comissao])
    assert.strictEqual(next.calls, 1)
  })
})

// ── (b) OS sem dependências: fluxo limpo ─────────────────────────────────────

describe('(b) OS sem receita nem comissão', () => {
  it('não apaga nada e chama next() exatamente 1x', () => {
    const { app, deleted, order } = mockApp({})
    const next = spyNext(order)
    osDelete.handleDelete(app, osRec(), next)
    assert.strictEqual(deleted.length, 0)
    assert.strictEqual(next.calls, 1)
    assert.deepStrictEqual(order, ['next'])
  })
})

// ── (c) falha na receita: aborta ANTES de next() ─────────────────────────────

describe('(c) falha ao apagar a receita aborta a exclusão', () => {
  it('erro no delete do lançamento propaga e next() NUNCA roda (OS intacta)', () => {
    const receita = rec({ status: 'pago', origem: 'via_os' }, 'lanc_receita')
    const { app, order } = mockApp({ receitas: [receita] })
    app.delete = () => {
      throw new Error('disk I/O error')
    }
    const next = spyNext(order)
    assert.throws(() => osDelete.handleDelete(app, osRec(), next), /disk I\/O error/)
    assert.strictEqual(next.calls, 0, 'falha na limpeza financeira NÃO pode comitar a exclusão')
  })
})
