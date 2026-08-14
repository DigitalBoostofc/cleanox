import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const lib = require('../../pb/pb_hooks/catalogo_ordem_lib.js')

describe('ordem atômica do catálogo', () => {
  it('normaliza payload e gera posições espaçadas', () => {
    assert.deepEqual(
      lib.parsePayload({ kind: 'servicos', ids: [' a ', 'b'] }),
      { kind: 'servicos', ids: ['a', 'b'] },
    )
    assert.equal(lib.orderAt(0), 10)
    assert.equal(lib.orderAt(2), 30)
  })

  it('rejeita tipo, lista vazia e ids duplicados', () => {
    assert.throws(() => lib.parsePayload({ kind: 'outro', ids: ['a'] }))
    assert.throws(() => lib.parsePayload({ kind: 'taxonomia', ids: [] }))
    assert.throws(() => lib.parsePayload({ kind: 'taxonomia', ids: ['a', 'a'] }))
  })

  it('exige exatamente todos os registros irmãos do escopo', () => {
    const records = [{ id: 'a' }, { id: 'b' }]
    assert.equal(lib.hasExactIds(['b', 'a'], records), true)
    assert.equal(lib.hasExactIds(['a'], records), false)
    assert.equal(lib.hasExactIds(['a', 'c'], records), false)
  })
})
