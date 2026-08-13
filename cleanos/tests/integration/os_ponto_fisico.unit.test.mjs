/**
 * CleanOS — unit: ponto físico na OS (endereço denorm / liberado).
 */
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { createRequire } from 'node:module'
const require = createRequire(import.meta.url)
const os = require('../../pb/pb_hooks/os_logic.js')

function rec(fields) {
  const data = { ...fields }
  return {
    get(k) {
      return data[k]
    },
    set(k, v) {
      data[k] = v
    },
    original() {
      return rec(fields._orig || fields)
    },
    _data: data,
  }
}

function appWith({ cliente, ponto }) {
  return {
    findRecordById(col, id) {
      if (col === 'clientes' && cliente && cliente.id === id) return cliente
      if (col === 'pontos_fisicos' && ponto && ponto.id === id) return ponto
      throw new Error('not found ' + col + ' ' + id)
    },
  }
}

function pbRec(map) {
  return {
    id: map.id,
    get(k) {
      return map[k]
    },
    getString(k) {
      return String(map[k] || '')
    },
  }
}

describe('os_logic ponto físico', () => {
  it('buildEnderecoPonto monta nome + endereço', () => {
    const p = pbRec({
      id: 'p1',
      nome: 'Galpão Centro',
      endereco_rua: 'Rua A',
      endereco_numero: '10',
      endereco_bairro: 'Centro',
      endereco_cidade: 'Fortaleza',
      endereco_estado: 'CE',
      endereco_cep: '60000000',
    })
    const s = os.buildEnderecoPonto(p)
    assert.match(s, /Galpão Centro/)
    assert.match(s, /Rua A, 10/)
    assert.match(s, /Centro/)
    assert.match(s, /Fortaleza/)
    assert.match(s, /CEP 60000000/)
  })

  it('syncDenormalized usa bairro do ponto quando local_tipo=ponto_fisico', () => {
    const cliente = pbRec({
      id: 'c1',
      nome: 'Ana',
      sobrenome: 'Silva',
      endereco_bairro: 'BairroCliente',
    })
    const ponto = pbRec({
      id: 'p1',
      nome: 'Loja',
      endereco_bairro: 'BairroPonto',
    })
    const r = rec({
      cliente: 'c1',
      local_tipo: 'ponto_fisico',
      ponto_fisico: 'p1',
      bairro: '',
    })
    os.syncDenormalized(appWith({ cliente, ponto }), r)
    assert.equal(r.get('bairro'), 'BairroPonto')
    assert.equal(r.get('nome_curto'), 'Ana Silva')
  })

  it('syncDenormalized limpa ponto quando local_tipo=cliente', () => {
    const cliente = pbRec({
      id: 'c1',
      nome: 'Ana',
      sobrenome: '',
      endereco_bairro: 'ClienteB',
    })
    const r = rec({
      cliente: 'c1',
      local_tipo: 'cliente',
      ponto_fisico: 'p1',
      bairro: '',
    })
    os.syncDenormalized(appWith({ cliente }), r)
    assert.equal(r.get('ponto_fisico'), '')
    assert.equal(r.get('bairro'), 'ClienteB')
  })

  it('manageEndereco libera endereço do ponto em atribuida', () => {
    const ponto = pbRec({
      id: 'p1',
      nome: 'Galpão',
      endereco_rua: 'Av. X',
      endereco_numero: '1',
      endereco_bairro: 'Meireles',
      endereco_cidade: 'Fortaleza',
      endereco_estado: 'CE',
    })
    const r = rec({
      status: 'atribuida',
      local_tipo: 'ponto_fisico',
      ponto_fisico: 'p1',
      cliente: 'c1',
      endereco_liberado: '',
      _orig: { status: 'agendada', local_tipo: 'ponto_fisico', ponto_fisico: 'p1' },
    })
    // original() uses _orig via rec helper — fix helper
    const origFields = {
      status: 'agendada',
      local_tipo: 'ponto_fisico',
      ponto_fisico: 'p1',
    }
    const data = {
      status: 'atribuida',
      local_tipo: 'ponto_fisico',
      ponto_fisico: 'p1',
      cliente: 'c1',
      endereco_liberado: '',
    }
    const record = {
      get(k) {
        return data[k]
      },
      set(k, v) {
        data[k] = v
      },
      original() {
        return {
          get(k) {
            return origFields[k]
          },
        }
      },
    }
    os.manageEndereco(appWith({ ponto }), record)
    assert.match(String(data.endereco_liberado), /Galpão/)
    assert.match(String(data.endereco_liberado), /Av\. X/)
  })

  it('isLocalPontoFisico', () => {
    assert.equal(
      os.isLocalPontoFisico({
        get: (k) => (k === 'local_tipo' ? 'ponto_fisico' : ''),
      }),
      true,
    )
    assert.equal(
      os.isLocalPontoFisico({ get: (k) => (k === 'local_tipo' ? 'cliente' : '') }),
      false,
    )
  })
})
