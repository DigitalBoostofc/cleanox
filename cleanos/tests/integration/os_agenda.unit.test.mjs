/**
 * CleanOS — testes UNITÁRIOS da cerca de agenda da OS (os_logic.js).
 *
 * Não precisam de PocketBase rodando: carregam o módulo CommonJS real com records
 * mockados e exercitam exatamente os caminhos do handler
 * onRecordUpdateRequest("ordens_servico") → guardOrdemUpdateRequest:
 *
 *   (a) CERCA DE STATUS — OS `concluida`/`cancelada` tem horário CONGELADO:
 *       mudar `data_hora` OU `duracao_min` lança BadRequestError ANTES do e.next()
 *       (padrão R3: throw depois do commit não faz rollback). Vale até para ADMIN.
 *   (b) DENYLIST DO PROFISSIONAL — `duracao_min` é campo do painel: o profissional
 *       não estica o próprio serviço via PATCH (403). O contrato casa com o
 *       `OSExecPatch` do Flutter, que NÃO tem duracao_min.
 *   (c) O caminho legítimo continua aberto: admin remarca uma OS `agendada`.
 */

import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)

// PocketBase injeta as classes de erro como globais (JSVM). Fora do PB, shims.
class BadRequestError extends Error {
  constructor(message) { super(message); this.name = 'BadRequestError' }
}
class ForbiddenError extends Error {
  constructor(message) { super(message); this.name = 'ForbiddenError' }
}
globalThis.BadRequestError = BadRequestError
globalThis.ForbiddenError = ForbiddenError

const os = require('../../pb/pb_hooks/os_logic.js')

// ── mocks ────────────────────────────────────────────────────────────────────

/**
 * Record mockado de `ordens_servico`. `getString` (usado por changed()) devolve o
 * campo como string — é assim que o JSVM compara campos de forma estável.
 * `original()` devolve o record do estado ANTERIOR (null no create).
 */
function mockOS(fields, orig = null, id = 'os1') {
  return {
    id,
    get: (k) => fields[k],
    getString: (k) => String(fields[k] == null ? '' : fields[k]),
    original: () => orig,
  }
}

/** Evento de request mockado: e.auth (usuário logado) + e.record (estado novo). */
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
  data_hora: '2026-07-20 12:00:00.000Z',
  duracao_min: 60,
  status: 'agendada',
}

// ── (a) cerca de status: OS fechada tem horário congelado ────────────────────

describe('(a) cerca de status — OS concluida/cancelada não remarca', () => {
  for (const status of ['concluida', 'cancelada']) {
    it(`admin NÃO altera data_hora de uma OS ${status}`, () => {
      const orig = mockOS({ ...BASE, status })
      const rec = mockOS({ ...BASE, status, data_hora: '2026-08-01 15:00:00.000Z' }, orig)

      assert.throws(
        () => os.guardOrdemUpdateRequest(mockEvent('admin', rec, 'adm1')),
        (err) => {
          assert.ok(err instanceof BadRequestError, 'deve ser BadRequestError (400)')
          assert.match(err.message, /data\/hora ou duração/)
          assert.match(err.message, new RegExp(status))
          return true
        }
      )
    })

    it(`admin NÃO altera duracao_min de uma OS ${status}`, () => {
      const orig = mockOS({ ...BASE, status })
      const rec = mockOS({ ...BASE, status, duracao_min: 120 }, orig)

      assert.throws(
        () => os.guardOrdemUpdateRequest(mockEvent('admin', rec, 'adm1')),
        (err) => err instanceof BadRequestError
      )
    })
  }

  it('gerente também é barrado (a cerca não é por papel)', () => {
    const orig = mockOS({ ...BASE, status: 'concluida' })
    const rec = mockOS({ ...BASE, status: 'concluida', duracao_min: 90 }, orig)
    assert.throws(
      () => os.guardOrdemUpdateRequest(mockEvent('gerente', rec, 'ger1')),
      (err) => err instanceof BadRequestError
    )
  })

  it('editar OUTRO campo de uma OS concluida continua permitido (só o horário congela)', () => {
    const orig = mockOS({ ...BASE, status: 'concluida' })
    const rec = mockOS({ ...BASE, status: 'concluida', observacoes: 'nota do admin' }, orig)
    assert.doesNotThrow(() => os.guardOrdemUpdateRequest(mockEvent('admin', rec, 'adm1')))
  })

  it('no CREATE (sem original()) a cerca não dispara', () => {
    const rec = mockOS({ ...BASE, status: 'concluida' }, null)
    assert.doesNotThrow(() => os.assertHorarioNaoCongelado(rec))
  })
})

// ── (b) denylist do profissional: duracao_min é do painel ────────────────────

describe('(b) denylist — profissional não altera duracao_min', () => {
  it('PATCH do profissional em duracao_min → ForbiddenError (403)', () => {
    const orig = mockOS({ ...BASE, status: 'atribuida' })
    const rec = mockOS({ ...BASE, status: 'atribuida', duracao_min: 180 }, orig)

    assert.throws(
      () => os.guardOrdemUpdateRequest(mockEvent('profissional', rec)),
      (err) => {
        assert.ok(err instanceof ForbiddenError, 'deve ser ForbiddenError (403)')
        assert.match(err.message, /duracao_min/)
        return true
      }
    )
  })

  it('o trabalho legítimo do profissional (OSExecPatch) continua passando', () => {
    const orig = mockOS({ ...BASE, status: 'atribuida' })
    const rec = mockOS(
      { ...BASE, status: 'atribuida', observacoes_prof: '[]', adicionais: '[]' },
      orig
    )
    assert.doesNotThrow(() => os.guardOrdemUpdateRequest(mockEvent('profissional', rec)))
  })
})

// ── (c) caminho legítimo do painel ───────────────────────────────────────────

describe('(c) painel remarca OS aberta', () => {
  it('admin altera data_hora + duracao_min de uma OS agendada', () => {
    const orig = mockOS({ ...BASE, status: 'agendada' })
    const rec = mockOS(
      { ...BASE, status: 'agendada', data_hora: '2026-07-21 09:00:00.000Z', duracao_min: 90 },
      orig
    )
    assert.doesNotThrow(() => os.guardOrdemUpdateRequest(mockEvent('admin', rec, 'adm1')))
  })

  it('admin remarca OS em_andamento (ainda não fechou o histórico)', () => {
    const orig = mockOS({ ...BASE, status: 'em_andamento' })
    const rec = mockOS({ ...BASE, status: 'em_andamento', duracao_min: 120 }, orig)
    assert.doesNotThrow(() => os.guardOrdemUpdateRequest(mockEvent('admin', rec, 'adm1')))
  })
})
