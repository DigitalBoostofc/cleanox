import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const hookPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../pb/pb_hooks/users_switch_role.pb.js',
)

class TestError extends Error {}
globalThis.UnauthorizedError = TestError
globalThis.BadRequestError = TestError
globalThis.ForbiddenError = TestError
globalThis.$apis = { requireAuth: () => 'auth' }
let handler
globalThis.routerAdd = (_method, _path, fn) => {
  handler = fn
}
require(hookPath)

describe('users switch-role', () => {
  it('troca para papel autorizado e preserva a lista', () => {
    const saved = []
    const fields = { role: 'admin', roles: ['admin', 'profissional'] }
    const auth = {
      id: 'u1',
      get: (key) => fields[key],
      set: (key, value) => { fields[key] = value },
    }
    globalThis.$app = { save: (record) => saved.push(record) }
    const result = handler({
      auth,
      requestInfo: () => ({ body: { role: 'profissional' } }),
      json: (status, body) => ({ status, body }),
    })
    assert.equal(result.body.role, 'profissional')
    assert.equal(fields.role, 'profissional')
    assert.deepEqual(fields.roles, ['admin', 'profissional'])
    assert.equal(saved.length, 1)
  })

  it('bloqueia papel que não está autorizado na conta', () => {
    const fields = { role: 'admin', roles: ['admin'] }
    const auth = { get: (key) => fields[key], set: () => {} }
    assert.throws(
      () => handler({
        auth,
        requestInfo: () => ({ body: { role: 'profissional' } }),
      }),
      ForbiddenError,
    )
  })
})
