/** Contrato do editor global de layout da Vitrine. */
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const here = path.dirname(fileURLToPath(import.meta.url))
const hooks = path.resolve(here, '../../pb/pb_hooks')
globalThis.__hooks = hooks
const lib = require(path.join(hooks, 'vitrine_lib.js'))

class HttpTestError extends Error {}
globalThis.UnauthorizedError = HttpTestError
globalThis.ForbiddenError = HttpTestError
globalThis.$apis = { requireAuth: () => 'auth' }
const routes = new Map()
globalThis.routerAdd = (method, route, handler) => {
  routes.set(`${method} ${route}`, handler)
}
require(path.join(hooks, 'vitrine_routes.pb.js'))

const ids = [
  'hero',
  'categories',
  'featured',
  'catalog',
  'how_it_works',
  'cities',
  'payment',
  'final_cta',
]

describe('layout global da Vitrine', () => {
  it('normaliza ids, duplicatas, variantes e completa seções ausentes', () => {
    const value = lib.normalizarLayoutVitrine({
      v: 99,
      sections: [
        { id: 'featured', visible: false, variant: 'carousel' },
        { id: 'featured', visible: true, variant: 'impact' },
        { id: 'injetado', visible: true, variant: 'html' },
        { id: 'hero', visible: false, variant: 'invalida' },
      ],
    })

    assert.deepEqual(value.sections.map((item) => item.id), [
      'featured',
      'hero',
      'categories',
      'catalog',
      'how_it_works',
      'cities',
      'payment',
      'final_cta',
    ])
    assert.equal(value.sections[0].visible, false)
    assert.equal(value.sections[1].visible, true)
    assert.equal(value.sections[1].variant, 'standard')
    assert.deepEqual(new Set(value.sections.map((item) => item.id)), new Set(ids))
  })

  it('publicação copia snapshot normalizado sem compartilhar referência', () => {
    const draft = lib.normalizarLayoutVitrine({
      sections: [{ id: 'hero', variant: 'impact' }],
    })
    const published = lib.snapshotLayoutVitrine(draft)
    draft.sections[0].variant = 'compact'

    assert.equal(published.sections[0].variant, 'impact')
    assert.equal(published.v, 1)
  })

  it('schema 0066 adiciona os dois JSONFields e rollback remove ambos', () => {
    const migrationPath = path.resolve(
      here,
      '../../pb/pb_migrations/1700000066_vitrine_layout_global.js',
    )
    assert.ok(fs.existsSync(migrationPath))
    const src = fs.readFileSync(migrationPath, 'utf8')
    assert.match(src, /new JSONField\s*\(\s*\{\s*name:\s*["']layout_rascunho["']/s)
    assert.match(src, /new JSONField\s*\(\s*\{\s*name:\s*["']layout_publicado["']/s)
    assert.match(src, /removeById/)
    assert.match(src, /layout_rascunho/)
    assert.match(src, /layout_publicado/)
  })

  it('config público expõe só publicado e admin recebe rascunho e publicado', () => {
    const record = fakeRecord({
      hero_titulo: 'Hero',
      layout_rascunho: { sections: [{ id: 'featured', visible: false }] },
      layout_publicado: { sections: [{ id: 'hero', variant: 'impact' }] },
    })
    const app = fakeApp(record)

    const publico = lib.getConfig(app)
    const admin = lib.adminGetConfig(app)

    assert.equal('layout_rascunho' in publico, false)
    assert.equal('layout' in publico, false)
    assert.equal(publico.layout_publicado.sections[0].id, 'hero')
    assert.equal(publico.layout_publicado.sections[0].variant, 'impact')
    assert.equal(admin.layout_rascunho.sections[0].id, 'featured')
    assert.equal(admin.layout_publicado.sections[0].id, 'hero')
  })

  it('decodifica JSONField retornado pelo PB/JSVM como bytes', () => {
    const json = JSON.stringify({
      sections: [{ id: 'featured', visible: true, variant: 'carousel' }],
    })
    const bytes = Array.from(Buffer.from(json, 'utf8'))
    const record = fakeRecord({ layout_publicado: bytes })

    const publico = lib.getConfig(fakeApp(record))

    assert.equal(publico.layout_publicado.sections[0].id, 'featured')
    assert.equal(publico.layout_publicado.sections[0].variant, 'carousel')
  })

  it('salvar rascunho usa allowlist e nunca altera o publicado', () => {
    const published = lib.normalizarLayoutVitrine({
      sections: [{ id: 'hero', variant: 'standard' }],
    })
    const record = fakeRecord({ layout_publicado: published })
    const app = fakeApp(record)

    const result = lib.salvarLayoutRascunho(app, {
      layout: { sections: [{ id: 'featured', visible: false, variant: 'carousel' }] },
      layout_publicado: { sections: [{ id: 'hero', variant: 'impact' }] },
      hero_titulo: 'não deve mudar',
    })

    assert.equal(record.get('hero_titulo'), undefined)
    assert.equal(record.get('layout_publicado').sections[0].variant, 'standard')
    assert.equal(result.layout_rascunho.sections[0].id, 'featured')
  })

  it('publicar copia snapshot do rascunho e preserva o rascunho', () => {
    const record = fakeRecord({
      layout_rascunho: { sections: [{ id: 'featured', visible: false, variant: 'carousel' }] },
      layout_publicado: { sections: [{ id: 'hero', variant: 'standard' }] },
    })
    const app = fakeApp(record)

    const result = lib.publicarLayoutVitrine(app)
    record.get('layout_rascunho').sections[0].variant = 'compact'

    assert.equal(result.layout_publicado.sections[0].id, 'featured')
    assert.equal(result.layout_publicado.sections[0].variant, 'carousel')
    assert.equal(record.get('layout_publicado').sections[0].variant, 'carousel')
  })

  it('rotas admin separam salvar rascunho de publicar e exigem admin ou gerente', () => {
    const draftRoute = routes.get('PUT /api/cleanos/vitrine/admin/layout/rascunho')
    const publishRoute = routes.get('POST /api/cleanos/vitrine/admin/layout/publicar')
    assert.equal(typeof draftRoute, 'function')
    assert.equal(typeof publishRoute, 'function')

    const record = fakeRecord({
      layout_publicado: { sections: [{ id: 'hero', variant: 'standard' }] },
    })
    const app = fakeApp(record)
    const gerente = routeEvent(app, 'gerente', {
      layout: { sections: [{ id: 'featured', variant: 'impact' }] },
    })
    const saved = draftRoute(gerente)
    assert.equal(saved.status, 200)
    assert.equal(record.get('layout_publicado').sections[0].variant, 'standard')

    const published = publishRoute(routeEvent(app, 'admin'))
    assert.equal(published.status, 200)
    assert.equal(record.get('layout_publicado').sections[0].id, 'featured')

    const blocked = draftRoute(routeEvent(app, 'profissional', { layout: {} }))
    assert.equal(blocked.status, 403)
  })
})

function fakeRecord(initial = {}) {
  const fields = structuredClone(initial)
  return {
    id: 'cfg1',
    get: (key) => fields[key],
    set: (key, value) => { fields[key] = structuredClone(value) },
  }
}

function fakeApp(record) {
  return {
    findRecordsByFilter: () => record ? [record] : [],
    save: () => {},
  }
}

function routeEvent(app, role, body = {}) {
  return {
    app,
    auth: { get: (key) => key === 'role' ? role : '' },
    requestInfo: () => ({ body }),
    json: (status, value) => ({ status, body: value }),
  }
}
