/**
 * CleanOS — autoagendamento da vitrine (capacidade, OS sem prof, PII, idempotência).
 */
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import fs from 'node:fs'

const require = createRequire(import.meta.url)
const HOOKS = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../pb/pb_hooks',
)
globalThis.__hooks = HOOKS

const slots = require('../../pb/pb_hooks/vitrine_slots_lib.js')
const lib = require('../../pb/pb_hooks/vitrine_lib.js')

const diasSemanaCheia = () =>
  Array.from({ length: 7 }, () => ({
    ativo: true,
    inicio: '08:00',
    fim: '12:00',
  }))

function record(id, initial = {}) {
  const data = { ...initial }
  return {
    id,
    get(key) {
      return data[key]
    },
    set(key, value) {
      data[key] = value
    },
    data,
  }
}

describe('vitrine_slots capacidade (OS sem profissional)', () => {
  it('OS não atribuída consome capacidade no intervalo', () => {
    const livres = slots.calcularSlotsLivres({
      ymd: '2026-08-05',
      servicoDurMin: 60,
      stepMin: 60,
      nowMs: Date.UTC(2026, 6, 1, 12, 0, 0),
      capacidadeSimultanea: 1,
      disponibilidades: [{ profissional: 'p1', dias: diasSemanaCheia() }],
      osOcupadas: [
        {
          profissional: '',
          data_hora: '2026-08-05 12:00:00.000Z', // 09:00 BRT
          duracao_min: 60,
        },
      ],
    })
    const horas = livres.map((s) => s.hora)
    assert.ok(!horas.includes('09:00'), 'slot 09:00 deve ser bloqueado')
    assert.ok(horas.includes('08:00'))
    assert.ok(horas.includes('10:00'))
  })

  it('dois agendamentos no mesmo horário com capacidade 1 bloqueiam o segundo', () => {
    const base = {
      ymd: '2026-08-05',
      servicoDurMin: 60,
      stepMin: 60,
      nowMs: Date.UTC(2026, 6, 1, 12, 0, 0),
      capacidadeSimultanea: 1,
      disponibilidades: [
        { profissional: 'p1', dias: diasSemanaCheia() },
        { profissional: 'p2', dias: diasSemanaCheia() },
      ],
    }
    const aposUm = slots.calcularSlotsLivres({
      ...base,
      osOcupadas: [
        {
          profissional: '',
          data_hora: '2026-08-05 11:00:00.000Z', // 08:00 BRT
          duracao_min: 60,
        },
      ],
    })
    assert.ok(!aposUm.map((s) => s.hora).includes('08:00'))

    const aposZero = slots.calcularSlotsLivres({ ...base, osOcupadas: [] })
    assert.ok(aposZero.map((s) => s.hora).includes('08:00'))
  })

  it('capacidade 2 permite dois sobrepostos e bloqueia o terceiro', () => {
    const livres = slots.calcularSlotsLivres({
      ymd: '2026-08-05',
      servicoDurMin: 60,
      stepMin: 60,
      nowMs: Date.UTC(2026, 6, 1, 12, 0, 0),
      capacidadeSimultanea: 2,
      disponibilidades: [
        { profissional: 'p1', dias: diasSemanaCheia() },
        { profissional: 'p2', dias: diasSemanaCheia() },
      ],
      osOcupadas: [
        {
          profissional: '',
          data_hora: '2026-08-05 11:00:00.000Z',
          duracao_min: 60,
        },
        {
          profissional: 'p1',
          data_hora: '2026-08-05 11:00:00.000Z',
          duracao_min: 60,
        },
      ],
    })
    assert.ok(!livres.map((s) => s.hora).includes('08:00'))
  })

  it('conta sobreposição parcial pela duração', () => {
    // OS 08:00–09:30 bloqueia candidato 09:00–10:00
    const livres = slots.calcularSlotsLivres({
      ymd: '2026-08-05',
      servicoDurMin: 60,
      stepMin: 60,
      nowMs: Date.UTC(2026, 6, 1, 12, 0, 0),
      capacidadeSimultanea: 1,
      disponibilidades: [{ profissional: 'p1', dias: diasSemanaCheia() }],
      osOcupadas: [
        {
          profissional: '',
          data_hora: '2026-08-05 11:00:00.000Z', // 08:00 BRT
          duracao_min: 90,
        },
      ],
    })
    const horas = livres.map((s) => s.hora)
    assert.ok(!horas.includes('08:00'))
    assert.ok(!horas.includes('09:00'))
    assert.ok(horas.includes('10:00'))
  })

  it('usa janela CMS quando não há disponibilidade por profissional', () => {
    const livres = slots.calcularSlotsLivres({
      ymd: '2026-08-05',
      servicoDurMin: 60,
      stepMin: 60,
      nowMs: Date.UTC(2026, 6, 1, 12, 0, 0),
      capacidadeSimultanea: 1,
      janelaInicio: '09:00',
      janelaFim: '11:00',
      disponibilidades: [],
      osOcupadas: [],
    })
    assert.deepEqual(
      livres.map((s) => s.hora),
      ['09:00', '10:00'],
    )
  })
})

describe('vitrine copy autoagendamento', () => {
  it('defaultConfig não usa linguagem de orçamento', () => {
    const cfg = lib.defaultConfig()
    const blob = JSON.stringify(cfg).toLowerCase()
    assert.ok(!blob.includes('orçamento'))
    assert.ok(!blob.includes('orcamento'))
    assert.match(cfg.hero_titulo, /Agende/i)
    assert.match(cfg.hero_cta, /Agendar/i)
    assert.match(cfg.como_funciona, /data e horário/i)
    assert.match(cfg.como_funciona, /equipe/i)
  })

  it('mensagens de item inválido não falam orçamento', () => {
    const app = {
      findRecordById() {
        throw new Error('missing')
      },
      findAllRecords() {
        return []
      },
    }
    assert.throws(
      () => lib.normalizarItensAgendamento(app, [{ id: 'x' }]),
      (err) => !/orçamento/i.test(String(err.message)),
    )
  })
})

describe('vitrine agendar autoagendamento', () => {
  function buildApp(opts = {}) {
    const services = {
      sofa1: record('sofa1', {
        nome: 'Sofá 3 lugares',
        grupo: 'sofa',
        ativo: true,
        vitrine: true,
        valor_base: 200,
        tempo_medio_min: 60,
        checklist_padrao: [],
      }),
      imper1: record('imper1', {
        nome: 'Impermeabilização',
        grupo: 'adicional',
        ativo: true,
        vitrine: true,
        valor_base: 150,
        tempo_medio_min: 30,
      }),
    }
    const bump = record('bump1', {
      titulo: 'Impermeabilização protegida',
      servico_oferta: 'imper1',
      preco_cheio: 150,
      preco_promo: 99,
      gatilho_tipo: 'qualquer_grupo',
      gatilho_valores: ['sofa'],
      excluir_se: [],
      ativo: true,
    })
    const savedOs = []
    const savedClientes = []
    const existingByKey = opts.existingByKey || {}
    const existingByPhone = opts.existingByPhone || {}
    let idSeq = 1

    const app = {
      findRecordById(collection, id) {
        if (collection === 'servicos' && services[id]) return services[id]
        throw new Error('not found')
      },
      findAllRecords(collection) {
        if (collection === 'vitrine_order_bumps') return [bump]
        return []
      },
      findRecordsByFilter(collection, filter) {
        if (collection === 'vitrine_config') return []
        if (collection === 'disponibilidade') {
          return [
            record('d1', {
              profissional: 'p1',
              dias: diasSemanaCheia(),
              duracao_min: 60,
            }),
          ]
        }
        if (collection === 'ordens_servico') {
          if (String(filter).includes('vitrine_idempotency_key')) {
            const m = /vitrine_idempotency_key\s*=\s*"([^"]+)"/.exec(filter)
            const key = m ? m[1] : ''
            return existingByKey[key] ? [existingByKey[key]] : []
          }
          // listarOsOcupadasNoDia
          return opts.osOcupadas || []
        }
        if (collection === 'config_atuacao') {
          return [
            record('at1', {
              estado: 'SP',
              cidades: JSON.stringify(['Campinas', 'Valinhos']),
            }),
          ]
        }
        return []
      },
      findFirstRecordByFilter(collection, filter) {
        if (collection === 'clientes') {
          const m = /telefone\s*=\s*"([^"]+)"/.exec(filter)
          const tel = m ? m[1] : ''
          if (existingByPhone[tel]) return existingByPhone[tel]
          throw new Error('not found')
        }
        if (collection === 'ordens_servico') {
          const m = /vitrine_idempotency_key\s*=\s*"([^"]+)"/.exec(filter)
          const key = m ? m[1] : ''
          if (existingByKey[key]) return existingByKey[key]
          throw new Error('not found')
        }
        throw new Error('not found')
      },
      findCollectionByNameOrId(name) {
        return { id: name, name }
      },
      save(rec) {
        if (!rec.id) {
          rec.id = 'gen' + idSeq++
        }
        if (rec.data && rec.data._collection === 'clientes') {
          savedClientes.push(rec)
        } else if (Object.prototype.hasOwnProperty.call(rec.data || {}, 'status') ||
          rec.get('status') != null) {
          savedOs.push(rec)
          if (rec.get('vitrine_idempotency_key')) {
            existingByKey[rec.get('vitrine_idempotency_key')] = rec
          }
        } else {
          savedClientes.push(rec)
        }
      },
      _savedOs: savedOs,
      _savedClientes: savedClientes,
      _existingByKey: existingByKey,
    }

    // Patch Record constructor used inside lib — goja uses global Record
    globalThis.Record = function Record(col) {
      const r = record('', { _collection: col && col.name ? col.name : col })
      return r
    }

    return app
  }

  function slotToken(app, hora = '08:00') {
    // Force sign with known payload via lib
    return lib.signSlot({
      s: 'sofa1',
      d: '2026-08-05',
      h: hora,
      p: ['p1'],
      e: Date.now() + 60 * 60 * 1000,
      dur: 60,
    })
  }

  const baseBody = (token, extra = {}) => ({
    slot_token: token,
    nome: 'Maria Silva',
    whatsapp: '19999998888',
    telefone: '19999998888',
    cep: '13010000',
    rua: 'Rua das Flores',
    numero: '100',
    complemento: 'Apto 12',
    bairro: 'Centro',
    cidade: 'Campinas',
    estado: 'SP',
    observacoes: 'Portão azul',
    idempotency_key: 'key-abc-12345',
    itens: [{ id: 'sofa1', nome: 'hack', valor: 1 }],
    ...extra,
  })

  it('cria OS agendada sem profissional e sem profissional2', () => {
    const app = buildApp()
    // Stub slotsDoDia path: need OS ocupadas empty and disponibilidade
    const token = slotToken(app)
    const out = lib.agendar(app, baseBody(token))

    assert.equal(out.ok, true)
    assert.ok(out.os_ref)
    assert.equal(app._savedOs.length, 1)
    const os = app._savedOs[0]
    assert.equal(os.get('status'), 'agendada')
    assert.equal(String(os.get('profissional') || ''), '')
    assert.equal(String(os.get('profissional2') || ''), '')
    assert.equal(os.get('canal_origem'), 'vitrine')
    assert.equal(os.get('valor_servico'), 200)
    assert.equal(os.get('bairro'), 'Centro')
    assert.match(String(os.get('observacoes') || ''), /Serviços solicitados via vitrine/)
    assert.ok(!/orçamento/i.test(String(os.get('observacoes') || '')))
  })

  it('não vaza telefone nem endereço completo nas observações da OS', () => {
    const app = buildApp()
    const token = slotToken(app)
    lib.agendar(app, baseBody(token))
    const obs = String(app._savedOs[0].get('observacoes') || '')
    assert.ok(!obs.includes('19999998888'))
    assert.ok(!obs.includes('Rua das Flores'))
    assert.ok(!obs.includes('13010000'))
    assert.ok(!obs.includes('Apto 12'))
  })

  it('grava cliente com endereço estruturado', () => {
    const app = buildApp()
    const token = slotToken(app)
    lib.agendar(app, baseBody(token))
    assert.ok(app._savedClientes.length >= 1)
    const c = app._savedClientes[0]
    assert.equal(c.get('endereco_cep'), '13010000')
    assert.equal(c.get('endereco_rua'), 'Rua das Flores')
    assert.equal(c.get('endereco_numero'), '100')
    assert.equal(c.get('endereco_bairro'), 'Centro')
    assert.equal(c.get('endereco_cidade'), 'Campinas')
    assert.equal(c.get('endereco_estado'), 'SP')
    assert.equal(c.get('origem'), 'vitrine')
  })

  it('ignora preço adulterado e aceita adicional válido', () => {
    const app = buildApp()
    const token = lib.signSlot({
      s: 'sofa1',
      d: '2026-08-05',
      h: '08:00',
      p: ['p1'],
      e: Date.now() + 60 * 60 * 1000,
      dur: 30, // token curto — deve usar soma canônica
    })
    const out = lib.agendar(
      app,
      baseBody(token, {
        itens: [
          { id: 'sofa1', nome: 'Grátis', valor: 1 },
          {
            id: 'imper1',
            order_bump_id: 'bump1',
            nome: 'hack',
            valor: 1,
          },
        ],
      }),
    )
    assert.equal(out.valor, 299)
    const os = app._savedOs[0]
    assert.equal(os.get('valor_servico'), 299)
    assert.ok(Number(os.get('duracao_min')) >= 90)
    const adicionais = os.get('adicionais')
    assert.ok(Array.isArray(adicionais))
    assert.equal(adicionais.length, 1)
    assert.equal(adicionais[0].nome, 'Impermeabilização protegida')
  })

  it('rejeita adicional forjado', () => {
    const app = buildApp()
    const token = slotToken(app)
    assert.throws(
      () =>
        lib.agendar(
          app,
          baseBody(token, {
            itens: [
              { id: 'sofa1' },
              { id: 'imper1', order_bump_id: 'bump-falso' },
            ],
          }),
        ),
      /Oferta adicional inválida/,
    )
  })

  it('não usa endereco livre como bairro', () => {
    const app = buildApp()
    const token = slotToken(app)
    assert.throws(
      () =>
        lib.agendar(
          app,
          baseBody(token, {
            bairro: '',
            endereco: 'Rua X, 10 - Centro',
            rua: '',
            numero: '',
          }),
        ),
      /obrigat|inválid|Rua|Número|Bairro/i,
    )
  })

  it('resposta idempotente para a mesma chave', () => {
    const app = buildApp()
    const token = slotToken(app)
    const body = baseBody(token, { idempotency_key: 'same-key-ok' })
    const a = lib.agendar(app, body)
    const b = lib.agendar(app, body)
    assert.equal(a.os_id, b.os_id)
    assert.equal(app._savedOs.length, 1)
  })

  it('rejeita idempotency_key com caracteres de injeção de filter', () => {
    const app = buildApp()
    const token = slotToken(app)
    // chave inválida é ignorada (não grava, não busca por filter perigoso)
    const out = lib.agendar(
      app,
      baseBody(token, {
        idempotency_key: 'x" || id != "" || telefone = "',
      }),
    )
    assert.equal(out.ok, true)
    assert.equal(String(app._savedOs[0].get('vitrine_idempotency_key') || ''), '')
  })

  it('não sobrescreve PII de cliente existente no cofre', () => {
    const existente = record('cli1', {
      nome: 'Nome Original',
      telefone: '19999998888',
      endereco_rua: 'Rua Antiga',
      endereco_numero: '1',
      endereco_bairro: 'Bairro Velho',
      endereco_cidade: 'Campinas',
      endereco_cep: '13000000',
      origem: 'whatsapp',
    })
    const app = buildApp({
      existingByPhone: { '19999998888': existente },
    })
    const token = slotToken(app)
    lib.agendar(
      app,
      baseBody(token, {
        nome: 'Atacante',
        rua: 'Rua Nova',
        bairro: 'Bairro Novo',
      }),
    )
    assert.equal(existente.get('nome'), 'Nome Original')
    assert.equal(existente.get('endereco_rua'), 'Rua Antiga')
    assert.equal(existente.get('endereco_bairro'), 'Bairro Velho')
    assert.equal(existente.get('origem'), 'whatsapp')
  })

  it('exige campos estruturados mínimos', () => {
    const app = buildApp()
    const token = slotToken(app)
    assert.throws(
      () =>
        lib.agendar(
          app,
          baseBody(token, { rua: '', numero: '1', bairro: 'Centro' }),
        ),
      /Rua/i,
    )
  })
})

describe('migration vitrine autoagendamento', () => {
  const migPath = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '../../pb/pb_migrations/1700000065_vitrine_autoagendamento.js',
  )

  it('arquivo de migration existe e é aditivo/reversível', () => {
    assert.ok(fs.existsSync(migPath))
    const src = fs.readFileSync(migPath, 'utf8')
    assert.match(src, /migrate\s*\(/)
    assert.match(src, /vitrine_idempotency_key/)
    assert.match(src, /capacidade_simultanea/)
    assert.match(src, /Orçamento em 1 minuto/)
    assert.match(src, /Agende seu serviço/)
    // down presente (segundo callback)
    assert.match(src, /DOWN|down|removeById|fields\.remove/i)
  })

  it('só reescreve copy quando valor é exatamente o default legado', () => {
    const src = fs.readFileSync(migPath, 'utf8')
    // deve comparar com string exata antes de set (via const OLD_* ou literal)
    assert.match(src, /OLD_TITULO\s*=\s*"Orçamento em 1 minuto"/)
    assert.match(src, /OLD_CTA\s*=\s*"Montar orçamento"/)
    assert.match(src, /=== OLD_TITULO/)
    assert.match(src, /=== OLD_CTA/)
    assert.ok(src.includes('preserva') || src.includes('custom'))
  })
})
