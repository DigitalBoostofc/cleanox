/**
 * CleanOS — testes UNITÁRIOS de assertPaymentIfConcluida (os_logic.js).
 *
 * Regra: concluir exige valor_pago > 0 + forma_pagamento.
 * Exceção: OS `refazer` (reabertura/garantia) pode fechar com valor 0 e sem forma.
 * stampConcluidaEm zera `refazer` antes do assert no hook de modelo — o assert
 * deve olhar original() também.
 */

import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)

class BadRequestError extends Error {
  constructor(message) {
    super(message)
    this.name = 'BadRequestError'
  }
}
globalThis.BadRequestError = BadRequestError

const os = require('../../pb/pb_hooks/os_logic.js')

function mockOS(fields, orig = null) {
  return {
    id: 'os1',
    get: (k) => fields[k],
    getString: (k) => String(fields[k] == null ? '' : fields[k]),
    set: (k, v) => {
      fields[k] = v
    },
    original: () => orig,
    _fields: fields,
  }
}

describe('assertPaymentIfConcluida', () => {
  it('status ≠ concluida → não valida', () => {
    assert.doesNotThrow(() =>
      os.assertPaymentIfConcluida(
        mockOS({ status: 'em_andamento', valor_pago: 0, forma_pagamento: '' })
      )
    )
  })

  it('concluida sem pagamento → BadRequest', () => {
    assert.throws(
      () =>
        os.assertPaymentIfConcluida(
          mockOS({
            status: 'concluida',
            valor_pago: 0,
            forma_pagamento: '',
            refazer: false,
          })
        ),
      (e) => e instanceof BadRequestError && /pagamento/i.test(e.message)
    )
  })

  it('concluida com valor > 0 e forma → ok', () => {
    assert.doesNotThrow(() =>
      os.assertPaymentIfConcluida(
        mockOS({
          status: 'concluida',
          valor_pago: 150,
          forma_pagamento: 'pix',
          refazer: false,
        })
      )
    )
  })

  it('refazer + valor 0 + sem forma → ok', () => {
    assert.doesNotThrow(() =>
      os.assertPaymentIfConcluida(
        mockOS({
          status: 'concluida',
          valor_pago: 0,
          forma_pagamento: '',
          refazer: true,
        })
      )
    )
  })

  it('refazer já limpo no record mas original.refazer=true + valor 0 → ok', () => {
    // Simula ordem do hook de modelo: stampConcluidaEm limpou refazer.
    const orig = mockOS({
      status: 'em_andamento',
      valor_pago: 0,
      forma_pagamento: '',
      refazer: true,
    })
    const rec = mockOS(
      {
        status: 'concluida',
        valor_pago: 0,
        forma_pagamento: '',
        refazer: false,
      },
      orig
    )
    assert.doesNotThrow(() => os.assertPaymentIfConcluida(rec))
  })

  it('refazer com valor > 0 sem forma → ainda bloqueia', () => {
    assert.throws(
      () =>
        os.assertPaymentIfConcluida(
          mockOS({
            status: 'concluida',
            valor_pago: 50,
            forma_pagamento: '',
            refazer: true,
          })
        ),
      (e) => e instanceof BadRequestError
    )
  })
})
