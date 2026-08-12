import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..')
const migrationPath = path.join(
  repoRoot,
  'cleanos/pb/pb_migrations/1700000064_vitrine_catalogo_personalizavel.js',
)

describe('vitrine catálogo personalizável — contrato de schema', () => {
  it('adiciona configuração comercial aos serviços', () => {
    const src = readFileSync(migrationPath, 'utf8')
    for (const field of [
      'vitrine_layout',
      'vitrine_titulo',
      'vitrine_descricao',
      'vitrine_badge',
      'vitrine_cta',
      'vitrine_preco_modo',
      'vitrine_ordem',
    ]) {
      assert.match(src, new RegExp(`name: ["']${field}["']`))
    }
    for (const value of [
      'destaque',
      'fotografico',
      'antes_depois',
      'compacto',
      'a_partir_de',
      'sob_avaliacao',
      'ocultar',
    ]) {
      assert.match(src, new RegExp(`["']${value}["']`))
    }
  })

  it('associa mídia ao serviço e registra papel, par e ponto focal', () => {
    const src = readFileSync(migrationPath, 'utf8')
    for (const field of [
      'servico',
      'papel',
      'par_id',
      'legenda',
      'foco_x',
      'foco_y',
    ]) {
      assert.match(src, new RegExp(`name: ["']${field}["']`))
    }
    assert.match(src, /new RelationField/)
    assert.match(src, /values:\s*\[[^\]]*["']capa["']/s)
    assert.match(src, /["']galeria["']/)
    assert.match(src, /["']antes["']/)
    assert.match(src, /["']depois["']/)
  })
})
