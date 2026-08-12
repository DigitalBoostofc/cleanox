import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const require = createRequire(import.meta.url)
globalThis.__hooks = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../pb/pb_hooks',
)
const lib = require('../../pb/pb_hooks/vitrine_lib.js')

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

describe('vitrine catálogo personalizável', () => {
  it('expõe personalização comercial com fallbacks seguros', () => {
    const rec = record('svc1', {
      nome: 'Sofá 3 lugares',
      descricao: 'Descrição operacional',
      grupo: 'sofa',
      ativo: true,
      valor_base: 180,
      vitrine_destaque: true,
      vitrine_layout: 'antes_depois',
      vitrine_titulo: 'Sofá renovado',
      vitrine_descricao: 'Extração profunda e acabamento.',
      vitrine_badge: 'Mais escolhido',
      vitrine_cta: 'Quero este cuidado',
      vitrine_preco_modo: 'a_partir_de',
      vitrine_ordem: 7,
    })

    const out = lib.servicoPublico(rec)

    assert.equal(out.vitrine_layout, 'antes_depois')
    assert.equal(out.vitrine_titulo, 'Sofá renovado')
    assert.equal(out.vitrine_descricao, 'Extração profunda e acabamento.')
    assert.equal(out.vitrine_badge, 'Mais escolhido')
    assert.equal(out.vitrine_cta, 'Quero este cuidado')
    assert.equal(out.vitrine_preco_modo, 'a_partir_de')
    assert.equal(out.vitrine_ordem, 7)
  })

  it('normaliza opções inválidas ao salvar e preserva apenas campos permitidos', () => {
    const rec = record('svc1', {
      nome: 'Sofá',
      ativo: true,
      vitrine: true,
    })
    const app = {
      findRecordById() {
        return rec
      },
      save() {},
    }

    const out = lib.setServicoVitrineConfig(app, 'svc1', {
      vitrine_layout: 'layout_inexistente',
      vitrine_titulo: '  Sofá premium  ',
      vitrine_descricao: 'x'.repeat(800),
      vitrine_badge: ' Destaque ',
      vitrine_cta: ' Adicionar ',
      vitrine_preco_modo: 'modo_invalido',
      vitrine_ordem: -12,
      nome: 'NÃO DEVE ALTERAR',
      valor_base: 1,
    })

    assert.equal(rec.get('nome'), 'Sofá')
    assert.equal(rec.get('valor_base'), undefined)
    assert.equal(out.vitrine_layout, 'fotografico')
    assert.equal(out.vitrine_preco_modo, 'a_partir_de')
    assert.equal(out.vitrine_ordem, 0)
    assert.equal(rec.get('vitrine_descricao').length, 500)
    assert.equal(out.vitrine_titulo, 'Sofá premium')
  })

  it('ordena por ordem editorial, destaque e nome', () => {
    const records = [
      record('b', { nome: 'Básico', ativo: true, vitrine_ordem: 20 }),
      record('z', { nome: 'Zeta', ativo: true, vitrine_ordem: 0 }),
      record('a', {
        nome: 'Premium',
        ativo: true,
        vitrine_ordem: 20,
        vitrine_destaque: true,
      }),
    ]
    const app = {
      findRecordsByFilter() {
        return records
      },
    }

    const out = lib.listarServicosPublicos(app)

    assert.deepEqual(
      out.map((item) => item.id),
      ['z', 'a', 'b'],
    )
  })

  it('expõe mídia associada ao serviço com papel e foco visual', () => {
    const media = record('img1', {
      chave: 'servico_svc1_antes',
      titulo: 'Antes da extração',
      arquivo: 'antes.webp',
      ordem: 2,
      ativo: true,
      servico: { id: 'svc1' },
      papel: 'antes',
      par_id: 'sala-principal',
      legenda: 'Manchas antigas no assento',
      foco_x: 22,
      foco_y: 70,
    })
    const app = {
      findAllRecords() {
        return [media]
      },
    }

    const [out] = lib.listarMidiaPublica(app, 'https://app.cleanox.com.br', true)

    assert.equal(out.servico, 'svc1')
    assert.equal(out.papel, 'antes')
    assert.equal(out.par_id, 'sala-principal')
    assert.equal(out.legenda, 'Manchas antigas no assento')
    assert.equal(out.foco_x, 22)
    assert.equal(out.foco_y, 70)
    assert.match(out.url, /antes\.webp$/)
  })

  it('usa galeria e foco central como fallback para mídia de serviço', () => {
    const media = record('img2', {
      chave: 'servico_svc2_galeria',
      url_externa: 'https://cdn.example/foto.jpg',
      ativo: true,
      servico: 'svc2',
      papel: 'desconhecido',
    })
    const app = { findAllRecords: () => [media] }

    const [out] = lib.listarMidiaPublica(app, '', true)

    assert.equal(out.papel, 'galeria')
    assert.equal(out.foco_x, 50)
    assert.equal(out.foco_y, 50)
  })

  function agendamentoApp() {
    const services = {
      sofa1: record('sofa1', {
        nome: 'Sofá 3 lugares',
        grupo: 'sofa',
        ativo: true,
        vitrine: true,
        valor_base: 200,
        tempo_medio_min: 90,
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
    return {
      findRecordById(collection, id) {
        if (collection !== 'servicos' || !services[id]) {
          throw new Error('record not found')
        }
        return services[id]
      },
      findAllRecords(collection) {
        return collection === 'vitrine_order_bumps' ? [bump] : []
      },
    }
  }

  it('recalcula nome e preço de serviço base no servidor', () => {
    const itens = lib.normalizarItensAgendamento(agendamentoApp(), [
      { id: 'sofa1', nome: 'Serviço grátis', valor: 1 },
    ])

    assert.deepEqual(itens, [
      {
        id: 'sofa1',
        nome: 'Sofá 3 lugares',
        valor: 200,
        duracao_min: 90,
      },
    ])
  })

  it('aceita somente preço promocional de bump elegível', () => {
    const itens = lib.normalizarItensAgendamento(agendamentoApp(), [
      { id: 'sofa1', valor: 0 },
      { id: 'imper1', order_bump_id: 'bump1', valor: 0 },
    ])

    assert.equal(itens[1].nome, 'Impermeabilização protegida')
    assert.equal(itens[1].valor, 99)
    assert.equal(itens[1].duracao_min, 30)
  })

  it('rejeita bump forjado ou inelegível', () => {
    assert.throws(
      () =>
        lib.normalizarItensAgendamento(agendamentoApp(), [
          { id: 'sofa1' },
          { id: 'imper1', order_bump_id: 'bump-falso', valor: 1 },
        ]),
      /Oferta adicional inválida/,
    )
  })

  it('nunca deixa o token reduzir a duração canônica dos itens', () => {
    assert.equal(lib.duracaoFinalAgendamento(30, 120), 120)
    assert.equal(lib.duracaoFinalAgendamento(180, 90), 180)
    assert.equal(lib.duracaoFinalAgendamento(0, 0), 60)
  })
})
