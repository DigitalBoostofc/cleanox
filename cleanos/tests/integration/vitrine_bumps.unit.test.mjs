/**
 * CleanOS — matching de order bumps (unitário, sem PB).
 */
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const require = createRequire(import.meta.url)
const HOOKS = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../pb/pb_hooks',
)
globalThis.__hooks = HOOKS

const lib = require('../../pb/pb_hooks/vitrine_bumps_lib.js')

describe('vitrine_bumps_lib', () => {
  const bumps = [
    {
      id: 'b1',
      ativo: true,
      titulo: 'Impermeabilização',
      gatilho_tipo: 'qualquer_grupo',
      gatilho_valores: ['sofa'],
      excluir_se: [],
      servico_oferta: 'imp1',
      prioridade: 10,
      preco_promo: 49,
    },
    {
      id: 'b2',
      ativo: true,
      titulo: 'Cadeiras combo',
      gatilho_tipo: 'qualquer_grupo',
      gatilho_valores: ['sofa', 'colchao'],
      excluir_se: [],
      servico_oferta: 'cad1',
      prioridade: 5,
      preco_promo: 79,
    },
    {
      id: 'b3',
      ativo: false,
      titulo: 'Pausado',
      gatilho_tipo: 'qualquer_grupo',
      gatilho_valores: ['sofa'],
      servico_oferta: 'x',
      prioridade: 99,
    },
    {
      id: 'b4',
      ativo: true,
      titulo: 'Por serviço id',
      gatilho_tipo: 'qualquer_servico',
      gatilho_valores: ['svc-sofa-3'],
      servico_oferta: 'imp1',
      prioridade: 1,
    },
  ]

  it('mostra bump de grupo sofa', () => {
    const m = lib.matchOrderBumps(
      [{ id: 'svc-sofa-3', grupo: 'sofa' }],
      bumps,
    )
    assert.ok(m.some((x) => x.id === 'b1'))
    assert.ok(!m.some((x) => x.id === 'b3')) // inativo
  })

  it('não mostra se oferta já está no carrinho', () => {
    const m = lib.matchOrderBumps(
      [
        { id: 'svc-sofa-3', grupo: 'sofa' },
        { id: 'imp1', grupo: 'adicional' },
      ],
      bumps,
    )
    assert.ok(!m.some((x) => x.id === 'b1'))
  })

  it('match qualquer_servico por id', () => {
    const m = lib.matchOrderBumps(
      [{ id: 'svc-sofa-3', grupo: 'x' }],
      bumps,
    )
    assert.ok(m.some((x) => x.id === 'b4'))
  })

  it('ordena por prioridade desc', () => {
    const m = lib.matchOrderBumps(
      [
        { id: 'a', grupo: 'sofa' },
        { id: 'b', grupo: 'colchao' },
      ],
      bumps,
    )
    assert.equal(m[0].id, 'b1')
  })

  it('toStrArray aceita JSON string e lista', () => {
    assert.deepEqual(lib.toStrArray(['a', 'b']), ['a', 'b'])
    assert.deepEqual(lib.toStrArray('["x","y"]'), ['x', 'y'])
  })

  it('toStrArray recupera JSON gravado como bytes (JSVM/SQL)', () => {
    const s = '["sofa"]'
    const bytes = Array.from(s, (c) => c.charCodeAt(0))
    assert.deepEqual(lib.toStrArray(bytes), ['sofa'])
    const asStrCodes = bytes.map(String)
    assert.deepEqual(lib.toStrArray(asStrCodes), ['sofa'])
  })
})

