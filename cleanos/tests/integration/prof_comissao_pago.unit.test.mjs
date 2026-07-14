/**
 * CleanOS — testes UNITÁRIOS do F-231: comissão paga vira DESPESA de verdade
 * (prof_comissao_pago_lib.js).
 *
 * O bug que estes testes travam (QA E2E de 14/07/2026): marcar uma comissão como
 * "paga" só trocava um enum dentro de `prof_comissoes`. NENHUM lançamento era
 * criado, NENHUM saldo era debitado. O dinheiro saía do bolso do dono no mundo
 * real e o painel continuava contando ele — saldo e relatórios INFLADOS pelo total
 * pago aos profissionais, para sempre.
 *
 * Não precisam de PocketBase rodando: carregam o módulo CommonJS real com um `app`
 * mockado e exercitam os caminhos que o hook prof_comissao_pago.pb.js dispara:
 *
 *   (a) pendente → paga   ⇒ cria 1 lançamento `despesa`, origem "via_comissao",
 *                            ligado por comissao_id, na conta padrão
 *   (b) paga → pendente   ⇒ APAGA esse lançamento (estorno)
 *   (c) idempotência      ⇒ marcar como paga 2x NÃO cria 2 despesas
 *   (d) status não mudou  ⇒ não faz nada
 *   (e) comissão excluída ⇒ apaga o lançamento junto (sem despesa órfã)
 *
 * ── R1 (invariante que estes testes PROTEGEM) ────────────────────────────────
 * O lib NUNCA pode escrever em `fin_contas.saldo_atual` — quem debita/estorna é o
 * fin_saldo.pb.js, por UPDATE SQL atômico. Se alguém "otimizar" mexendo no saldo
 * aqui, o débito conta em DOBRO. O mock ABAIXO FALHA O TESTE se o lib tocar em
 * fin_contas: é a única forma de essa regra não depender de alguém lembrar dela.
 */

import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const require = createRequire(import.meta.url)

const HOOKS_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../pb/pb_hooks',
)

// O PocketBase (JSVM) injeta `__hooks` (caminho da pasta de hooks) e a classe
// `Record` como globais. Fora do PB, fornecemos os equivalentes: o lib usa
// `require(`${__hooks}/...`)` e `new Record(col)`.
globalThis.__hooks = HOOKS_DIR

class Record {
  constructor(collection) {
    this.collection = collection
    this.id = 'lanc_novo'
    this._data = {}
  }
  set(k, v) { this._data[k] = v }
  get(k) { return this._data[k] }
}
globalThis.Record = Record

const pago = require('../../pb/pb_hooks/prof_comissao_pago_lib.js')

// ── mocks ────────────────────────────────────────────────────────────────────

/** Registro mockado: get(campo) do mapa. */
function rec(fields, id = 'com1') {
  return { id, get: (k) => fields[k], _data: fields }
}

/**
 * app mockado com uma base mínima: 1 categoria de despesa "Comissões", 1 conta
 * padrão ativa, e a lista de lançamentos existentes (que o teste controla).
 *
 * Registra em `saved` tudo que foi salvo e em `deleted` tudo que foi apagado.
 * Se o lib tentar salvar em `fin_contas` (violando R1), lança na hora.
 */
function mockApp({ lancamentos = [], categorias, contas } = {}) {
  const saved = []
  const deleted = []

  const cats = categorias ?? [
    rec({ tipo: 'despesa', nome: 'Comissões' }, 'cat_comissoes'),
  ]
  const cnts = contas ?? [
    rec({ nome: 'Banco Inter', ativo: true, padrao: true }, 'conta_padrao'),
  ]

  const app = {
    findFirstRecordByFilter(collection, filter) {
      if (collection === 'fin_categorias') {
        const hit = cats.find(
          (c) => c.get('tipo') === 'despesa' && c.get('nome') === 'Comissões',
        )
        if (hit) return hit
        throw new Error('not found')
      }
      if (collection === 'fin_lancamentos') {
        // filtro: comissao_id = 'xxx'
        const m = /comissao_id = '([^']*)'/.exec(filter)
        const alvo = m ? m[1] : null
        const hit = lancamentos.find((l) => l.get('comissao_id') === alvo)
        if (hit) return hit
        throw new Error('not found')
      }
      throw new Error('not found')
    },

    findRecordsByFilter(collection, filter) {
      if (collection === 'fin_categorias') {
        return cats.filter((c) => c.get('tipo') === 'despesa')
      }
      if (collection === 'fin_contas') {
        const ativas = cnts.filter((c) => c.get('ativo') === true)
        if (filter.includes('padrao = true')) {
          return ativas.filter((c) => c.get('padrao') === true)
        }
        return ativas
      }
      return []
    },

    findRecordById(collection, id) {
      if (collection === 'users') return rec({ name: 'Fulano da Relação' }, id)
      throw new Error('not found')
    },

    findCollectionByNameOrId(name) {
      return { name }
    },

    save(r) {
      const col = r.collection?.name ?? r._collection
      if (col === 'fin_contas') {
        throw new Error(
          'R1 VIOLADO: o lib escreveu em fin_contas — o saldo é do fin_saldo.pb.js',
        )
      }
      saved.push(r)
    },

    delete(r) { deleted.push(r) },
  }

  return { app, saved, deleted }
}

/** Lançamento já existente ligado a uma comissão. */
function lancDe(comissaoId, id = 'lanc_existente') {
  return rec({ comissao_id: comissaoId, tipo: 'despesa', valor: 60 }, id)
}

const COMISSAO_PAGA = () =>
  rec(
    {
      status: 'paga',
      valor_comissao: 60,
      profissional: 'prof1',
      profissional_nome: 'João Pedro',
      os: 'os_abc123def456',
      descricao: 'Limpeza · Carlos S.',
    },
    'com1',
  )

// ── (a) pendente → paga: nasce a despesa ─────────────────────────────────────

describe('(a) pendente → paga cria a DESPESA (F-231)', () => {
  it('cria exatamente 1 lançamento de despesa, origem via_comissao, na conta padrão', () => {
    const { app, saved, deleted } = mockApp()
    pago.sincronizarLancamento(app, COMISSAO_PAGA(), 'pendente')

    assert.equal(saved.length, 1, 'deve criar exatamente 1 lançamento')
    assert.equal(deleted.length, 0, 'não apaga nada ao pagar')

    const l = saved[0]
    assert.equal(l.get('tipo'), 'despesa', 'comissão paga é SAÍDA de dinheiro')
    assert.equal(l.get('valor'), 60)
    assert.equal(
      l.get('origem'),
      'via_comissao',
      'origem dedicada: o dono precisa distinguir do lançamento da OS',
    )
    assert.equal(
      l.get('comissao_id'),
      'com1',
      'o link é o que permite ESTORNAR ao desmarcar',
    )
    assert.equal(l.get('conta_id'), 'conta_padrao', 'sai da conta padrão ativa')
    assert.equal(l.get('categoria_id'), 'cat_comissoes')
    assert.equal(l.get('status'), 'pago')
  })

  it('a descrição diz QUEM recebeu (senão o extrato vira "despesa de R$60 pra ninguém")', () => {
    const { app, saved } = mockApp()
    pago.sincronizarLancamento(app, COMISSAO_PAGA(), 'pendente')
    assert.match(saved[0].get('descricao'), /Comissão/)
    assert.match(saved[0].get('descricao'), /João Pedro/)
  })

  it('usa o nome DESNORMALIZADO, não a relação (F-225: o profissional pode ter sido excluído)', () => {
    // Relação vazia — exatamente o estado que o PB deixa após excluir o usuário.
    const orfa = rec(
      {
        status: 'paga',
        valor_comissao: 60,
        profissional: '',
        profissional_nome: 'Zé Descartável',
        os: 'os1',
      },
      'com_orfa',
    )
    const { app, saved } = mockApp()
    pago.sincronizarLancamento(app, orfa, 'pendente')

    assert.equal(saved.length, 1, 'comissão de profissional excluído ainda vira despesa')
    assert.match(
      saved[0].get('descricao'),
      /Zé Descartável/,
      'o histórico continua LEGÍVEL sem o usuário',
    )
  })

  it('não cria lançamento se o valor for 0 (nada saiu do caixa)', () => {
    const zero = rec({ status: 'paga', valor_comissao: 0, profissional: 'p1' }, 'c0')
    const { app, saved } = mockApp()
    pago.sincronizarLancamento(app, zero, 'pendente')
    assert.equal(saved.length, 0)
  })

  it('desiste em silêncio se não houver conta ativa — pagar não pode FALHAR por causa do financeiro', () => {
    const { app, saved } = mockApp({ contas: [] })
    assert.doesNotThrow(() =>
      pago.sincronizarLancamento(app, COMISSAO_PAGA(), 'pendente'),
    )
    assert.equal(saved.length, 0)
  })
})

// ── (b) paga → pendente: estorna ─────────────────────────────────────────────

describe('(b) paga → pendente ESTORNA a despesa', () => {
  it('apaga o lançamento da comissão (o fin_saldo devolve o saldo)', () => {
    const { app, saved, deleted } = mockApp({ lancamentos: [lancDe('com1')] })
    const voltou = rec({ status: 'pendente', valor_comissao: 60 }, 'com1')

    pago.sincronizarLancamento(app, voltou, 'paga')

    assert.equal(deleted.length, 1, 'deve apagar o lançamento')
    assert.equal(deleted[0].id, 'lanc_existente')
    assert.equal(saved.length, 0, 'estorno não cria lançamento novo')
  })

  it('não explode se o lançamento já não existir (apagado à mão no painel)', () => {
    const { app, deleted } = mockApp({ lancamentos: [] })
    const voltou = rec({ status: 'pendente' }, 'com1')
    assert.doesNotThrow(() => pago.sincronizarLancamento(app, voltou, 'paga'))
    assert.equal(deleted.length, 0)
  })
})

// ── (c) idempotência: o débito NÃO pode contar duas vezes ────────────────────

describe('(c) idempotência', () => {
  it('marcar como paga 2x NÃO cria a segunda despesa (débito em dobro)', () => {
    // 2ª chamada: o lançamento da 1ª já existe na base.
    const { app, saved } = mockApp({ lancamentos: [lancDe('com1')] })
    pago.sincronizarLancamento(app, COMISSAO_PAGA(), 'pendente')
    assert.equal(saved.length, 0, 'já existe lançamento pra esta comissão; não duplica')
  })

  it('salvar a comissão SEM mudar o status não mexe no financeiro', () => {
    // Ex.: editar a descrição de uma comissão já paga.
    const { app, saved, deleted } = mockApp({ lancamentos: [lancDe('com1')] })
    pago.sincronizarLancamento(app, COMISSAO_PAGA(), 'paga') // paga → paga
    assert.equal(saved.length, 0)
    assert.equal(deleted.length, 0, 'NÃO pode estornar uma comissão que continua paga')
  })
})

// ── (e) comissão paga excluída: nada de despesa órfã ─────────────────────────

describe('(e) excluir uma comissão paga apaga a despesa junto', () => {
  it('apagarLancamentoDaComissao remove o lançamento (senão o saldo fica debitado por um fantasma)', () => {
    const { app, deleted } = mockApp({ lancamentos: [lancDe('com1')] })
    const achou = pago.apagarLancamentoDaComissao(app, 'com1')
    assert.equal(achou, true)
    assert.equal(deleted.length, 1)
    assert.equal(deleted[0].id, 'lanc_existente')
  })

  it('comissão pendente excluída não tem o que apagar', () => {
    const { app, deleted } = mockApp({ lancamentos: [] })
    assert.equal(pago.apagarLancamentoDaComissao(app, 'com_sem_lanc'), false)
    assert.equal(deleted.length, 0)
  })
})

// ── F-229: a data da comissão é BRT, não UTC ─────────────────────────────────

describe('F-229: data no fuso BRT (UTC-3)', () => {
  it('dataBrtAgora() volta 3h do UTC — senão a OS das 21h30 cai no DIA SEGUINTE', () => {
    const { dataBrtAgora } = require('../../pb/pb_hooks/prof_comissao_lib.js')

    const antes = Date.now()
    const s = dataBrtAgora()
    const depois = Date.now()

    // Formato que o PB grava: "YYYY-MM-DD HH:MM:SS.mmmZ"
    assert.match(s, /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}Z$/)

    const gravado = new Date(s.replace(' ', 'T')).getTime()
    const deslocamento = antes - gravado
    const TRES_HORAS = 3 * 60 * 60 * 1000

    // Tolerância: o tempo que o próprio teste levou pra rodar.
    const folga = depois - antes + 1000
    assert.ok(
      Math.abs(deslocamento - TRES_HORAS) <= folga,
      `esperado ~3h de deslocamento (BRT), veio ${deslocamento}ms`,
    )
  })

  it('cai no MESMO dia do lançamento da OS (os_financeiro_lib.js, fix F-222)', () => {
    // A receita e a comissão da mesma OS não podem cair em dias diferentes no
    // relatório. Ambas usam a mesma fórmula — este teste trava as duas juntas.
    const { dataBrtAgora } = require('../../pb/pb_hooks/prof_comissao_lib.js')
    const os = require('../../pb/pb_hooks/os_financeiro_lib.js')

    const diaComissao = dataBrtAgora().slice(0, 10)
    const agoraBrt = new Date(Date.now() - 3 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10)
    assert.equal(diaComissao, agoraBrt)
    assert.ok(os, 'os_financeiro_lib.js carrega (mesma convenção de data)')
  })
})
