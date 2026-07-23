/**
 * CleanOS — motor de slots da vitrine (unitário, sem PB).
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

const lib = require('../../pb/pb_hooks/vitrine_slots_lib.js')

const diasSemanaCheia = () =>
  Array.from({ length: 7 }, () => ({
    ativo: true,
    inicio: '08:00',
    fim: '12:00',
  }))

describe('vitrine_slots_lib', () => {
  it('hmToMin / minToHm round-trip', () => {
    assert.equal(lib.hmToMin('08:30'), 510)
    assert.equal(lib.minToHm(510), '08:30')
  })

  it('weekdayFromYmd: 2026-07-22 é quarta (3)', () => {
    // 2026-07-22 = Wednesday
    assert.equal(lib.weekdayFromYmd('2026-07-22'), 3)
  })

  it('gera slots sem ocupação', () => {
    const slots = lib.calcularSlotsLivres({
      ymd: '2026-08-05', // quarta
      servicoDurMin: 60,
      stepMin: 60,
      nowMs: Date.UTC(2026, 6, 1, 12, 0, 0), // bem antes
      disponibilidades: [
        { profissional: 'p1', dias: diasSemanaCheia() },
      ],
      osOcupadas: [],
    })
    const horas = slots.map((s) => s.hora)
    assert.deepEqual(horas, ['08:00', '09:00', '10:00', '11:00'])
    assert.deepEqual(slots[0].profissionais, ['p1'])
  })

  it('remove slot ocupado por OS', () => {
    // 09:00 BRT = 12:00 UTC no mesmo dia civil de verão? BRT = UTC-3
    // 2026-08-05 09:00 BRT → 12:00 UTC
    const slots = lib.calcularSlotsLivres({
      ymd: '2026-08-05',
      servicoDurMin: 60,
      stepMin: 60,
      nowMs: Date.UTC(2026, 6, 1, 12, 0, 0),
      disponibilidades: [
        { profissional: 'p1', dias: diasSemanaCheia() },
      ],
      osOcupadas: [
        {
          profissional: 'p1',
          data_hora: '2026-08-05 12:00:00.000Z', // 09:00 BRT
          duracao_min: 60,
        },
      ],
    })
    const horas = slots.map((s) => s.hora)
    assert.ok(!horas.includes('09:00'))
    assert.ok(horas.includes('08:00'))
    assert.ok(horas.includes('10:00'))
  })

  it('unifica horário quando 2 pros livres', () => {
    const slots = lib.calcularSlotsLivres({
      ymd: '2026-08-05',
      servicoDurMin: 60,
      stepMin: 60,
      nowMs: Date.UTC(2026, 6, 1, 12, 0, 0),
      disponibilidades: [
        { profissional: 'p1', dias: diasSemanaCheia() },
        { profissional: 'p2', dias: diasSemanaCheia() },
      ],
      osOcupadas: [],
    })
    const s8 = slots.find((s) => s.hora === '08:00')
    assert.ok(s8)
    assert.equal(s8.profissionais.length, 2)
  })

  it('escolhe pro com menos OS no dia', () => {
    assert.equal(
      lib.escolherProfissional(['a', 'b'], { a: 3, b: 1 }),
      'b',
    )
  })

  it('brtSlotToUtcPb round-trip com osStartMinOnYmdBrt', () => {
    const utc = lib.brtSlotToUtcPb('2026-08-05', '09:00')
    assert.match(utc, /2026-08-05 12:00:00/)
    const min = lib.osStartMinOnYmdBrt(utc, '2026-08-05')
    assert.equal(min, 9 * 60)
  })
})
