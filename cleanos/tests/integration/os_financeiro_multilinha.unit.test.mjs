/**
 * CleanOS — multi-linha via_os (serviço principal + extras).
 * Unitário: carrega os_financeiro_lib.js com app mockado.
 */
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const osFin = require('../../pb/pb_hooks/os_financeiro_lib.js')

function osRec(fields) {
  const f = { ...fields }
  return {
    id: f.id || 'osABC123',
    get: (k) => f[k],
    getString: (k) => String(f[k] ?? ''),
  }
}

describe('_linhasReceitaOs — split principal + extras', () => {
  it('1 serviço: só principal com valor_servico', () => {
    const lines = osFin._linhasReceitaOs(
      osRec({
        valor_servico: 200,
        tipo_servico_nome: 'Cleanox Completo',
        service_snapshot: JSON.stringify({ categoria: 'veicular' }),
        adicionais: [],
      }),
      false,
    )
    assert.equal(lines.length, 1)
    assert.equal(lines[0].key, 'principal')
    assert.equal(lines[0].valor, 200)
    assert.equal(lines[0].servicoNome, 'Cleanox Completo')
    assert.equal(lines[0].catNome, 'Serviço Automotivo')
  })

  it('principal + extra residencial: 2 linhas com valores e categorias corretas', () => {
    const lines = osFin._linhasReceitaOs(
      osRec({
        valor_servico: 200,
        tipo_servico_nome: 'Cleanox Completo',
        service_snapshot: JSON.stringify({ categoria: 'veicular' }),
        adicionais: [
          {
            id: 'add_sofa',
            nome: 'Sofá 3 lugares',
            valor: 150,
            quantidade: 1,
            categoria: 'residencial',
            aprovacao: 'nao_requer',
          },
        ],
      }),
      false,
    )
    assert.equal(lines.length, 2)
    assert.deepEqual(
      lines.map((l) => ({ k: l.key, v: l.valor, s: l.servicoNome, c: l.catNome })),
      [
        {
          k: 'principal',
          v: 200,
          s: 'Cleanox Completo',
          c: 'Serviço Automotivo',
        },
        {
          k: 'add_add_sofa',
          v: 150,
          s: 'Sofá 3 lugares',
          c: 'Serviço Residencial',
        },
      ],
    )
  })

  it('pago: escala linhas para bater com valor_pago (ex.: desconto no total)', () => {
    const lines = osFin._linhasReceitaOs(
      osRec({
        valor_servico: 200,
        tipo_servico_nome: 'Auto',
        valor_pago: 300,
        service_snapshot: JSON.stringify({ categoria: 'veicular' }),
        adicionais: [
          {
            id: 'x1',
            nome: 'Extra',
            valor: 150,
            quantidade: 1,
            categoria: 'residencial',
            aprovacao: 'aprovado',
          },
        ],
      }),
      true,
    )
    const sum = lines.reduce((a, l) => a + l.valor, 0)
    assert.ok(Math.abs(sum - 300) < 0.01, `soma=${sum}`)
    assert.equal(lines.length, 2)
  })

  it('adicional recusado não entra', () => {
    const lines = osFin._linhasReceitaOs(
      osRec({
        valor_servico: 200,
        tipo_servico_nome: 'Auto',
        adicionais: [
          {
            id: 'r1',
            nome: 'Recusado',
            valor: 99,
            quantidade: 1,
            categoria: 'residencial',
            aprovacao: 'recusado',
          },
        ],
      }),
      false,
    )
    assert.equal(lines.length, 1)
    assert.equal(lines[0].valor, 200)
  })
})

describe('criarLancamentoFinanceiro multi-linha', () => {
  it('cria 2 lançamentos pagos com categorias distintas', () => {
    const cats = {
      'Serviço Automotivo': { id: 'cat_auto' },
      'Serviço Residencial': { id: 'cat_res' },
    }
    const contas = [{ id: 'conta1' }]
    const saved = []
    const app = {
      findFirstRecordByFilter(col, filter, params) {
        if (col === 'fin_categorias' && params && params.n) {
          const c = cats[params.n]
          if (c) return c
          throw new Error('not found')
        }
        throw new Error('not found')
      },
      findRecordsByFilter(col, filter) {
        if (col === 'fin_contas') return contas
        if (col === 'fin_lancamentos') return []
        if (col === 'fin_categorias') return [{ id: 'cat_auto' }]
        return []
      },
      findCollectionByNameOrId() {
        return { name: 'fin_lancamentos' }
      },
      save(r) {
        saved.push({
          valor: r.get('valor'),
          servico_nome: r.get('servico_nome'),
          categoria_id: r.get('categoria_id'),
          observacao: r.get('observacao'),
          status: r.get('status'),
          origem: r.get('origem'),
        })
      },
    }

    // Record mock com set/get para new Record
    globalThis.Record = function () {
      const data = {}
      this.set = (k, v) => {
        data[k] = v
      }
      this.get = (k) => data[k]
      this.id = 'new'
    }

    const rec = osRec({
      status: 'concluida',
      valor_servico: 200,
      valor_pago: 350,
      tipo_servico_nome: 'Cleanox Completo',
      nome_curto: 'João',
      forma_pagamento: 'pix_maquininha',
      data_hora: '2026-07-20 15:00:00.000Z',
      service_snapshot: JSON.stringify({ categoria: 'veicular' }),
      adicionais: JSON.stringify([
        {
          id: 'sofa1',
          nome: 'Sofá',
          valor: 150,
          quantidade: 1,
          categoria: 'residencial',
          aprovacao: 'nao_requer',
        },
      ]),
    })

    osFin.criarLancamentoFinanceiro(app, rec, 'em_andamento')

    assert.equal(saved.length, 2, `esperado 2, veio ${saved.length}`)
    assert.equal(saved[0].status, 'pago')
    assert.equal(saved[0].origem, 'via_os')
    assert.equal(saved[0].valor, 200)
    assert.equal(saved[0].servico_nome, 'Cleanox Completo')
    assert.equal(saved[0].categoria_id, 'cat_auto')
    assert.match(saved[0].observacao, /via_os_line:principal/)

    assert.equal(saved[1].valor, 150)
    assert.equal(saved[1].servico_nome, 'Sofá')
    assert.equal(saved[1].categoria_id, 'cat_res')
    assert.match(saved[1].observacao, /via_os_line:add_sofa1/)

    const sum = saved[0].valor + saved[1].valor
    assert.equal(sum, 350)
  })
})
