/**
 * CleanOS — testes UNITÁRIOS do day-check de Iniciar OS (os_logic.js).
 *
 * Regra (mudança de produto, 2026-07-16): o profissional pode Iniciar a OS no
 * dia do serviço OU DEPOIS (OS que ficou de ontem sem registro no app), mas
 * NUNCA antes do dia — antecipar continua bloqueado porque Iniciar libera o
 * `endereco_liberado` (anti-desvio).
 *
 * Cobre também o que sustenta a regra sem quebrar o anti-desvio:
 *   (b) `iniciada_em` é carimbado server-side na TRANSIÇÃO para em_andamento
 *       (stampIniciadaEm) e está na denylist do profissional;
 *   (c) o corte do cron cleanStaleEndereco passa a olhar QUANDO o serviço
 *       começou (`iniciada_em`), com fallback em `data_hora` para OS legadas —
 *       uma OS de ontem INICIADA HOJE não pode ter o endereço varrido às :05.
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

// ── datas em BRT (mesmo cálculo do hook: UTC-3) ──────────────────────────────
// data_hora é gravada em UTC; o hook converte para BRT e compara o DIA.
// Aqui geramos "meio-dia BRT" (15:00Z) do dia desejado para ficar longe das
// bordas de virada de dia em qualquer fuso.
function diaBRT(offsetDias) {
  const d = new Date(Date.now() - 3 * 3600 * 1000 + offsetDias * 86_400_000)
  return d.toISOString().slice(0, 10)
}
const dataHoraUTC = (offsetDias) => `${diaBRT(offsetDias)} 15:00:00.000Z`

// ── mocks (mesmo padrão de os_agenda.unit.test.mjs) ─────────────────────────
function mockOS(fields, orig = null, id = 'os1') {
  return {
    id,
    get: (k) => fields[k],
    getString: (k) => String(fields[k] == null ? '' : fields[k]),
    set: (k, v) => { fields[k] = v },
    original: () => orig,
    _fields: fields,
  }
}

function mockEvent(role, record, authId = 'prof1') {
  return {
    auth: { id: authId, get: (k) => (k === 'role' ? role : undefined) },
    record,
  }
}

const BASE = {
  cliente: 'c1',
  servico: 's1',
  profissional: 'prof1',
  duracao_min: 60,
  status: 'atribuida',
}

function iniciarEvent(offsetDias) {
  const orig = mockOS({ ...BASE, data_hora: dataHoraUTC(offsetDias) })
  const rec = mockOS(
    { ...BASE, data_hora: dataHoraUTC(offsetDias), status: 'em_andamento' },
    orig
  )
  return mockEvent('profissional', rec)
}

// ── (a) day-check: hoje e passado passam; futuro bloqueia ────────────────────

describe('(a) day-check de Iniciar — dia do serviço ou depois', () => {
  it('profissional inicia OS de HOJE → permitido', () => {
    assert.doesNotThrow(() => os.guardOrdemUpdateRequest(iniciarEvent(0)))
  })

  it('profissional inicia OS de ONTEM (ficou sem registro) → permitido', () => {
    assert.doesNotThrow(() => os.guardOrdemUpdateRequest(iniciarEvent(-1)))
  })

  it('profissional inicia OS de uma semana atrás → permitido', () => {
    assert.doesNotThrow(() => os.guardOrdemUpdateRequest(iniciarEvent(-7)))
  })

  it('profissional inicia OS de AMANHÃ → BadRequestError (400)', () => {
    assert.throws(
      () => os.guardOrdemUpdateRequest(iniciarEvent(1)),
      (err) => {
        assert.ok(err instanceof BadRequestError, 'deve ser BadRequestError (400)')
        assert.match(err.message, /a partir do dia do serviço/)
        return true
      }
    )
  })

  it('profissional inicia OS futura (30 dias) → BadRequestError (400)', () => {
    assert.throws(
      () => os.guardOrdemUpdateRequest(iniciarEvent(30)),
      (err) => err instanceof BadRequestError
    )
  })
})

// ── (b) iniciada_em: carimbo server-side + denylist ─────────────────────────

describe('(b) iniciada_em — carimbo na transição e denylist', () => {
  it('stampIniciadaEm carimba na TRANSIÇÃO atribuida → em_andamento', () => {
    const orig = mockOS({ ...BASE, data_hora: dataHoraUTC(-1) })
    const rec = mockOS(
      { ...BASE, data_hora: dataHoraUTC(-1), status: 'em_andamento' },
      orig
    )
    os.stampIniciadaEm(rec)
    assert.ok(rec._fields.iniciada_em, 'iniciada_em deve ser preenchido')
    assert.match(String(rec._fields.iniciada_em), /^\d{4}-\d{2}-\d{2} /)
  })

  it('save repetido em em_andamento NÃO re-carimba', () => {
    const orig = mockOS({ ...BASE, status: 'em_andamento', iniciada_em: 'X' })
    const rec = mockOS(
      { ...BASE, status: 'em_andamento', iniciada_em: 'X' },
      orig
    )
    os.stampIniciadaEm(rec)
    assert.equal(rec._fields.iniciada_em, 'X', 'não pode sobrescrever o carimbo')
  })

  it('status fora de em_andamento não carimba', () => {
    const rec = mockOS({ ...BASE, status: 'concluida' }, mockOS({ ...BASE, status: 'em_andamento' }))
    os.stampIniciadaEm(rec)
    assert.equal(rec._fields.iniciada_em, undefined)
  })

  it('profissional NÃO grava iniciada_em via PATCH (denylist → 403)', () => {
    const orig = mockOS({ ...BASE, data_hora: dataHoraUTC(0) })
    const rec = mockOS(
      { ...BASE, data_hora: dataHoraUTC(0), iniciada_em: '2026-07-16 12:00:00.000Z' },
      orig
    )
    assert.throws(
      () => os.guardOrdemUpdateRequest(mockEvent('profissional', rec)),
      (err) => {
        assert.ok(err instanceof ForbiddenError)
        assert.match(err.message, /iniciada_em/)
        return true
      }
    )
  })
})

// ── (c) corte do cron: quando o serviço COMEÇOU, não a data agendada ─────────

describe('(c) isStaleEmAndamento — cron não varre OS iniciada hoje', () => {
  const hoje = diaBRT(0)

  it('OS de ontem INICIADA HOJE → não é stale (endereço fica)', () => {
    const rec = mockOS({
      data_hora: dataHoraUTC(-1),
      iniciada_em: `${hoje} 14:00:00.000Z`,
    })
    assert.equal(os.isStaleEmAndamento(rec, hoje), false)
  })

  it('OS iniciada ONTEM e esquecida em_andamento → stale (endereço sai)', () => {
    const rec = mockOS({
      data_hora: dataHoraUTC(-1),
      iniciada_em: `${diaBRT(-1)} 14:00:00.000Z`,
    })
    assert.equal(os.isStaleEmAndamento(rec, hoje), true)
  })

  it('OS legada SEM iniciada_em cai no fallback data_hora (ontem → stale)', () => {
    const rec = mockOS({ data_hora: dataHoraUTC(-1) })
    assert.equal(os.isStaleEmAndamento(rec, hoje), true)
  })

  it('OS legada SEM iniciada_em com data_hora hoje → não é stale', () => {
    const rec = mockOS({ data_hora: dataHoraUTC(0) })
    assert.equal(os.isStaleEmAndamento(rec, hoje), false)
  })

  it('OS sem nenhuma data → não é stale (defensivo)', () => {
    const rec = mockOS({})
    assert.equal(os.isStaleEmAndamento(rec, hoje), false)
  })
})
