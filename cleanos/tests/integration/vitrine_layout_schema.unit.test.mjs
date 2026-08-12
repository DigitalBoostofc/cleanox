/** Schema do editor global de layout da Vitrine. */
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const migrationPath = path.resolve(
  here,
  '../../pb/pb_migrations/1700000066_vitrine_layout_global.js',
)

describe('migration 0066 — layout global da Vitrine', () => {
  it('adiciona rascunho e publicado como JSON sem alterar outras coleções', () => {
    const source = readFileSync(migrationPath, 'utf8')
    assert.match(source, /layout_rascunho/)
    assert.match(source, /layout_publicado/)
    assert.match(source, /new JSONField/)
    assert.doesNotMatch(source, /ordens_servico/)
  })

  it('rollback remove somente os dois campos de layout', () => {
    const source = readFileSync(migrationPath, 'utf8')
    assert.match(source, /fields\.removeById/)
    assert.match(source, /\["layout_rascunho",\s*"layout_publicado"\]/)
  })
})
