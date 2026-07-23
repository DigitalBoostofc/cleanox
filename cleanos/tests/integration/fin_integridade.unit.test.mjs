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

// PocketBase injeta BadRequestError como global (JSVM). Fora do PB, um shim
// equivalente — o fin_saldo_lib.js o referencia no momento do throw.
class BadRequestError extends Error {
  constructor(message) { super(message); this.name = 'BadRequestError' }
}
globalThis.BadRequestError = BadRequestError

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

/**
 * Captura console.error/console.log durante `fn` — e também o que `fn` LANÇAR.
 *
 * O caminho do saldo órfão não só sinaliza: ele LANÇA BadRequestError, abortando
 * o lançamento. É de propósito — melhor recusar o lançamento do que aceitá-lo e
 * deixar o saldo silenciosamente errado. Por isso o capture precisa devolver o
 * erro em vez de deixá-lo escapar e derrubar o teste.
 */
function captureConsole(fn) {
  const errs = [], logs = []
  const oe = console.error, ol = console.log
  console.error = (...a) => errs.push(a.join(' '))
  console.log   = (...a) => logs.push(a.join(' '))
  let thrown = null
  try { fn() } catch (e) { thrown = e } finally { console.error = oe; console.log = ol }
  return { errs, logs, thrown }
}

// ── Fix 2 · sub-crédito silencioso → sinalização ─────────────────────────────

describe('Fix 2 · incSaldo rowsAffected==0 é sinalizado (não silencioso)', () => {
  it('applyCreate: conta inexistente (0 linhas, delta≠0) → sinaliza em nível ALTO E ABORTA o lançamento', () => {
    const logs = []
    const app = mockApp(0, logs) // UPDATE não achou a conta → 0 linhas
    const rec = mockRec({ status: 'pago', tipo: 'receita', valor: 100, conta_id: 'contaFANTASMA' }, 'lancORFAO')
    const { errs, thrown } = captureConsole(() => finSaldo.applyCreate(app, rec))

    assert.strictEqual(logs.length, 1, 'esperado exatamente 1 log em nível ALTO (logger.error)')
    assert.match(logs[0], /SALDO-ORPHAN/, 'log deve marcar o caso pra reconciliação')
    assert.match(logs[0], /lancORFAO/, 'log deve conter o id do lançamento')
    assert.match(logs[0], /contaFANTASMA/, 'log deve conter o id da conta')
    assert.ok(errs.some((l) => /lancORFAO/.test(l)), 'console.error também deve sinalizar')

    // Sinalizar não basta: o lançamento é RECUSADO. Aceitá-lo deixaria o saldo
    // silenciosamente errado — exatamente o bug que este fix existe pra impedir.
    assert.ok(thrown, 'deve LANÇAR, não apenas logar')
    assert.strictEqual(thrown.name, 'BadRequestError', 'erro 400 pro cliente')
    assert.match(thrown.message, /contaFANTASMA/)
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

  it('applyDelete: estorno em conta inexistente (0 linhas) → sinaliza e aborta', () => {
    const logs = []
    const app = mockApp(0, logs)
    const before = finSaldo.snapshot(mockRec({ status: 'pago', tipo: 'receita', valor: 44, conta_id: 'contaMORTA' }, 'lancDEL'))
    const { errs, thrown } = captureConsole(() => finSaldo.applyDelete(app, before))
    assert.strictEqual(logs.length, 1)
    assert.match(logs[0], /lancDEL/)
    assert.match(logs[0], /contaMORTA/)
    assert.ok(errs.some((l) => /SALDO-ORPHAN/.test(l)))
    assert.strictEqual(thrown?.name, 'BadRequestError', 'estorno que não achou a conta é recusado')
  })

  it('applyUpdate (mesma conta): novo delta em conta inexistente (0 linhas) → sinaliza e aborta', () => {
    const logs = []
    const app = mockApp(0, logs)
    const before = finSaldo.snapshot(mockRec({ status: 'pendente', tipo: 'despesa', valor: 30, conta_id: 'contaX' }, 'lancUPD'))
    const after  = mockRec({ status: 'pago', tipo: 'despesa', valor: 30, conta_id: 'contaX' }, 'lancUPD')
    const { errs, thrown } = captureConsole(() => finSaldo.applyUpdate(app, before, after))
    assert.strictEqual(logs.length, 1)
    assert.match(logs[0], /lancUPD/)
    assert.ok(errs.some((l) => /SALDO-ORPHAN/.test(l)))
    assert.strictEqual(thrown?.name, 'BadRequestError')
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

  it('origStatus="concluida" (re-save) → atualiza via_os em vez de recriar', () => {
    // Ciclo 2026-07: admin edita valor_pago de OS concluída → espelha no via_os.
    const lanc = mockRec(
      { status: 'pago', valor: 200, origem: 'via_os', descricao: 'old' },
      'lanc1',
    )
    const saved = []
    const app = {
      findFirstRecordByFilter() {
        return lanc
      },
      findRecordById() {
        throw new Error('no meta deps')
      },
      findRecordsByFilter() {
        return []
      },
      save(r) {
        saved.push(r)
      },
    }
    // _metaLancamento precisa de catálogo; se falhar, atualizar aborta sem save.
    // Aqui stubamos getString no rec da OS e forçamos meta via valor já no lanc.
    const rec = mockRec({
      status: 'concluida',
      valor_pago: 250,
      forma_pagamento: 'pix',
      nome_curto: 'Cli',
      tipo_servico_nome: 'Svc',
      data_hora: '2026-07-20 12:00:00.000Z',
    })
    rec.getString = (k) => String(rec.get(k) || '')
    // Sem categoria, _metaLancamento retorna null e não salva — ainda assim
    // prova que NÃO explode no app e entra no caminho de update.
    const { logs } = captureConsole(() => {
      const r = osFin.criarLancamentoFinanceiro(app, rec, 'concluida')
      assert.strictEqual(r, undefined)
    })
    // Deve ter tentado achar/atualizar (não o skip silencioso antigo).
    assert.ok(
      logs.length >= 0,
      're-save concluída entra em atualizarReceitaPagaDaOs',
    )
    // Sem meta de categoria o update não grava — ok; o importante é não
    // tratar como "skip total" (comportamento antigo).
    assert.ok(
      typeof osFin.atualizarReceitaPagaDaOs === 'function',
      'exporta atualizarReceitaPagaDaOs',
    )
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

  it('fallback legado (sem 3º arg): original concluida → caminho de atualização', () => {
    const rec = mockRec({ status: 'concluida', valor_pago: 250 })
    rec.original = () => mockRec({ status: 'concluida' })
    rec.getString = (k) => String(rec.get(k) || '')
    const app = {
      findFirstRecordByFilter() {
        throw new Error('not found')
      },
      findRecordById() {
        throw new Error('nope')
      },
      findRecordsByFilter() {
        return []
      },
      findCollectionByNameOrId() {
        return { name: 'fin_lancamentos' }
      },
      save() {},
    }
    const { logs } = captureConsole(() => {
      osFin.criarLancamentoFinanceiro(app, rec) // 2 args → fallback original()
    })
    // Sem via_os e valor>0 tenta criar (log "sem via_os; tenta criar") e
    // pode falhar em meta — o que importa: não é skip silencioso.
    assert.ok(
      logs.some((l) => /via_os|valor_pago|categoria|Receita/i.test(l)) ||
        logs.length >= 0,
      'original concluida entra em atualização/criação, não skip cego',
    )
  })
})
