/**
 * CleanOS — testes UNITÁRIOS do tratamento de `_superusers` nos guards de
 * request (os_logic.js).
 *
 * Bug real (visto em prod em 15 e 16/07/2026): o superuser da Admin UI tem
 * `role` vazio e caía no ramo "papel desconhecido" de guardOrdemUpdateRequest
 * → "Sem permissão para alterar ordens de serviço" (403). Superuser é o papel
 * de DEVOPS: deve passar pelos guards de papel como um admin — mas a cerca de
 * horário congelado (OS concluida/cancelada) continua valendo até para ele
 * (protege o histórico financeiro, não é autorização por papel).
 */

import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)

class BadRequestError extends Error {
  constructor(message) { super(message); this.name = 'BadRequestError' }
}
class ForbiddenError extends Error {
  constructor(message) { super(message); this.name = 'ForbiddenError' }
}
globalThis.BadRequestError = BadRequestError
globalThis.ForbiddenError = ForbiddenError

const os = require('../../pb/pb_hooks/os_logic.js')

function mockOS(fields, orig = null, id = 'os1') {
  return {
    id,
    get: (k) => fields[k],
    getString: (k) => String(fields[k] == null ? '' : fields[k]),
    set: (k, v) => { fields[k] = v },
    original: () => orig,
  }
}

/** Auth de _superuser como o JSVM expõe: sem campo `role`. */
function mockSuperuser({ viaMethod = true } = {}) {
  return {
    id: 'su1',
    get: () => undefined,
    ...(viaMethod
      ? { isSuperuser: () => true }
      : { collection: () => ({ name: '_superusers' }) }),
  }
}

const BASE = {
  cliente: 'c1',
  servico: 's1',
  profissional: 'prof1',
  data_hora: '2026-07-20 12:00:00.000Z',
  duracao_min: 60,
  status: 'agendada',
}

describe('isSuperuser — detecção', () => {
  it('via método isSuperuser()', () => {
    assert.equal(os.isSuperuser(mockSuperuser({ viaMethod: true })), true)
  })
  it('via collection().name === "_superusers"', () => {
    assert.equal(os.isSuperuser(mockSuperuser({ viaMethod: false })), true)
  })
  it('user comum (role admin) NÃO é superuser', () => {
    const auth = { id: 'a1', get: (k) => (k === 'role' ? 'admin' : undefined) }
    assert.equal(os.isSuperuser(auth), false)
  })
  it('sem auth → false', () => {
    assert.equal(os.isSuperuser(null), false)
  })
})

describe('guardOrdemUpdateRequest — superuser passa como admin', () => {
  it('superuser edita campo qualquer de OS aberta (antes: 403)', () => {
    const orig = mockOS({ ...BASE })
    const rec = mockOS({ ...BASE, valor_servico: 250 }, orig)
    assert.doesNotThrow(() =>
      os.guardOrdemUpdateRequest({ auth: mockSuperuser(), record: rec })
    )
  })

  it('superuser marca repasse (privilégio de admin)', () => {
    const orig = mockOS({ ...BASE, status: 'concluida' })
    const rec = mockOS(
      { ...BASE, status: 'concluida', repasse_status: 'pago' },
      orig
    )
    assert.doesNotThrow(() =>
      os.guardOrdemUpdateRequest({ auth: mockSuperuser(), record: rec })
    )
  })

  it('cerca de horário congelado vale ATÉ para superuser', () => {
    const orig = mockOS({ ...BASE, status: 'concluida' })
    const rec = mockOS(
      { ...BASE, status: 'concluida', data_hora: '2026-08-01 10:00:00.000Z' },
      orig
    )
    assert.throws(
      () => os.guardOrdemUpdateRequest({ auth: mockSuperuser(), record: rec }),
      (err) => err instanceof BadRequestError
    )
  })

  it('papel desconhecido (não-superuser) segue bloqueado', () => {
    const auth = { id: 'x1', get: () => undefined }
    const orig = mockOS({ ...BASE })
    const rec = mockOS({ ...BASE, valor_servico: 300 }, orig)
    assert.throws(
      () => os.guardOrdemUpdateRequest({ auth, record: rec }),
      (err) => err instanceof ForbiddenError
    )
  })
})
