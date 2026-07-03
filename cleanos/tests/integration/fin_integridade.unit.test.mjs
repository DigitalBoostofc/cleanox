/**
 * CleanOS — testes UNITÁRIOS dos 2 fixes de integridade de dinheiro no backend.
 *
 * Não precisam de PocketBase rodando: carregam os módulos CommonJS reais
 * (fin_saldo_lib.js / os_financeiro_lib.js) com um `app` mockado e exercitam
 * exatamente os caminhos de código dos fixes — que NÃO são alcançáveis pela API
 * REST (a validação de relation do PB rejeita conta_id inexistente no create, e
 * forçar rollback do e.next() por HTTP não é determinístico).
 *
 * Cobre:
 *   Fix 1 (janela de receita órfã): criarLancamentoFinanceiro passa a receber o
 *     `origStatus` (capturado ANTES do e.next()); a detecção de transição
 *     continua correta rodando DEPOIS do e.next().
 *   Fix 2 (sub-crédito silencioso): quando incSaldo afeta 0 linhas (conta
 *     inexistente) com delta não-nulo, applyCreate/Update/Delete SINALIZAM em
 *     nível ALTO (logger.error + console.error) em vez de ignorar.
 */

import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const finSaldo = require('../../pb/pb_hooks/fin_saldo_lib.js')
const osFin     = require('../../pb/pb_hooks/os_financeiro_lib.js')

// ── mocks ────────────────────────────────────────────────────────────────────

/** Record mockado: get(campo) devolve o valor do mapa; id é o id do lançamento. */
function mockRec(fields, id = 'lancTEST') {
  return { id, get: (k) => fields[k] }
}

/** app mockado: incSaldo faz app.db().newQuery().bind().execute().rowsAffected();
 *  logger().error acumula em `logs`. `rows` é o rowsAffected que o UPDATE simula. */
function mockApp(rows, logs) {
  return {
    db: () => ({
      newQuery: () => ({
        bind: () => ({ execute: () => ({ rowsAffected: () => rows }) }),
      }),
    }),
    logger: () => ({ error: (m) => logs.push(String(m)) }),
    // runInTransaction executa o callback com o mesmo app (transação já mockada).
    runInTransaction: function (cb) { return cb(this) },
  }
}

/** Captura console.error/console.log durante `fn`. */
function captureConsole(fn) {
  const errs = [], logs = []
  const oe = console.error, ol = console.log
  console.error = (...a) => errs.push(a.join(' '))
  console.log   = (...a) => logs.push(a.join(' '))
  try { fn() } finally { console.error = oe; console.log = ol }
  return { errs, logs }
}

// ── Fix 2 · sub-crédito silencioso → sinalização ─────────────────────────────

describe('Fix 2 · incSaldo rowsAffected==0 é sinalizado (não silencioso)', () => {
  it('applyCreate: conta inexistente (0 linhas, delta≠0) → logger.error + console.error com os ids', () => {
    const logs = []
    const app = mockApp(0, logs) // UPDATE não achou a conta → 0 linhas
    const rec = mockRec({ status: 'pago', tipo: 'receita', valor: 100, conta_id: 'contaFANTASMA' }, 'lancORFAO')
    const { errs } = captureConsole(() => finSaldo.applyCreate(app, rec))

    assert.strictEqual(logs.length, 1, 'esperado exatamente 1 log em nível ALTO (logger.error)')
    assert.match(logs[0], /RECONCILIAR/, 'log deve marcar RECONCILIAR')
    assert.match(logs[0], /lancORFAO/, 'log deve conter o id do lançamento')
    assert.match(logs[0], /contaFANTASMA/, 'log deve conter o id da conta')
    assert.ok(errs.some((l) => /lancORFAO/.test(l)), 'console.error também deve sinalizar')
  })

  it('applyCreate: conta existente (1 linha) → NÃO sinaliza', () => {
    const logs = []
    const app = mockApp(1, logs) // UPDATE creditou 1 linha
    const rec = mockRec({ status: 'pago', tipo: 'receita', valor: 100, conta_id: 'contaOK' })
    const { errs } = captureConsole(() => finSaldo.applyCreate(app, rec))
    assert.strictEqual(logs.length, 0, 'crédito normal não deve gerar alerta')
    assert.strictEqual(errs.length, 0, 'crédito normal não deve escrever em console.error')
  })

  it('applyCreate: lançamento PENDENTE (efeito 0) não chama incSaldo nem sinaliza', () => {
    const logs = []
    const app = mockApp(0, logs)
    const rec = mockRec({ status: 'pendente', tipo: 'receita', valor: 100, conta_id: 'qualquer' })
    const { errs } = captureConsole(() => finSaldo.applyCreate(app, rec))
    assert.strictEqual(logs.length, 0, 'pendente não mexe no saldo → nada a sinalizar')
    assert.strictEqual(errs.length, 0)
  })

  it('applyDelete: estorno em conta inexistente (0 linhas) → sinaliza com o id do lançamento', () => {
    const logs = []
    const app = mockApp(0, logs)
    const before = finSaldo.snapshot(mockRec({ status: 'pago', tipo: 'receita', valor: 44, conta_id: 'contaMORTA' }, 'lancDEL'))
    const { errs } = captureConsole(() => finSaldo.applyDelete(app, before))
    assert.strictEqual(logs.length, 1)
    assert.match(logs[0], /lancDEL/)
    assert.match(logs[0], /contaMORTA/)
    assert.ok(errs.some((l) => /RECONCILIAR/.test(l)))
  })

  it('applyUpdate (mesma conta): novo delta em conta inexistente (0 linhas) → sinaliza', () => {
    const logs = []
    const app = mockApp(0, logs)
    const before = finSaldo.snapshot(mockRec({ status: 'pendente', tipo: 'despesa', valor: 30, conta_id: 'contaX' }, 'lancUPD'))
    const after  = mockRec({ status: 'pago', tipo: 'despesa', valor: 30, conta_id: 'contaX' }, 'lancUPD')
    const { errs } = captureConsole(() => finSaldo.applyUpdate(app, before, after))
    assert.strictEqual(logs.length, 1)
    assert.match(logs[0], /lancUPD/)
    assert.ok(errs.some((l) => /RECONCILIAR/.test(l)))
  })

  it('snapshot inclui o id do lançamento (para reconciliação por lançamento)', () => {
    const s = finSaldo.snapshot(mockRec({ status: 'pago', tipo: 'receita', valor: 10, conta_id: 'c1' }, 'lancZ'))
    assert.strictEqual(s.id, 'lancZ')
    assert.strictEqual(s.contaId, 'c1')
    assert.strictEqual(s.efeito, 10)
  })
})

// ── Fix 1 · janela de receita órfã: transição via origStatus (pós e.next()) ──

describe('Fix 1 · criarLancamentoFinanceiro detecta transição por origStatus', () => {
  // app que EXPLODE se for tocado — garante que os early-returns não chamam o DB.
  const appProibido = new Proxy({}, { get() { throw new Error('app não deveria ser tocado') } })

  it('origStatus="concluida" (não é transição, ex.: re-save) → skip sem tocar o app', () => {
    const rec = mockRec({ status: 'concluida', valor_pago: 250 })
    const { logs } = captureConsole(() => {
      const r = osFin.criarLancamentoFinanceiro(appProibido, rec, 'concluida')
      assert.strictEqual(r, undefined)
    })
    // Skip no gate de transição: não chega no gate de valor_pago (nenhum log).
    assert.strictEqual(logs.length, 0, 'não deve nem avaliar valor_pago quando já era concluida')
  })

  it('origStatus="em_andamento" (transição real) → PASSA do gate de transição', () => {
    // valor_pago=0 faz parar no gate seguinte com log conhecido — prova que
    // NÃO foi barrado no gate de transição (comportamento oposto ao caso acima).
    const rec = mockRec({ status: 'concluida', valor_pago: 0 })
    const { logs } = captureConsole(() => {
      osFin.criarLancamentoFinanceiro(appProibido, rec, 'em_andamento')
    })
    assert.ok(
      logs.some((l) => /valor_pago/.test(l)),
      'transição real deve prosseguir até o gate de valor_pago (log esperado)'
    )
  })

  it('CREATE: origStatus=null (OS nascendo concluida) → prossegue (não é skip)', () => {
    const rec = mockRec({ status: 'concluida', valor_pago: 0 })
    const { logs } = captureConsole(() => {
      osFin.criarLancamentoFinanceiro(appProibido, rec, null)
    })
    assert.ok(logs.some((l) => /valor_pago/.test(l)), 'null → sem estado anterior → prossegue')
  })

  it('newStatus != concluida → skip imediato sem tocar o app', () => {
    const rec = mockRec({ status: 'em_andamento', valor_pago: 999 })
    const { logs } = captureConsole(() => {
      osFin.criarLancamentoFinanceiro(appProibido, rec, 'atribuida')
    })
    assert.strictEqual(logs.length, 0)
  })

  it('fallback legado (sem 3º arg): usa record.original() — original concluida → skip', () => {
    const rec = mockRec({ status: 'concluida', valor_pago: 250 })
    rec.original = () => mockRec({ status: 'concluida' })
    const { logs } = captureConsole(() => {
      osFin.criarLancamentoFinanceiro(appProibido, rec) // 2 args → fallback
    })
    assert.strictEqual(logs.length, 0, 'original concluida → skip (fallback preservado)')
  })
})
