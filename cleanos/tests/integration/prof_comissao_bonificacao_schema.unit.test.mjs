import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../..',
)
const migrationPath = path.join(
  repoRoot,
  'cleanos/pb/pb_migrations/1700000056_prof_comissoes_bonificacao.js',
)

describe('bonificação manual — contrato de schema', () => {
  it('índice único de comissão automática não bloqueia bonificação vinculada à mesma OS/profissional', () => {
    const src = readFileSync(migrationPath, 'utf8')

    assert.match(src, /DROP INDEX IF EXISTS idx_prof_comissoes_os_prof/)
    assert.match(src, /CREATE UNIQUE INDEX IF NOT EXISTS idx_prof_comissoes_os_prof/)
    assert.match(src, /ON prof_comissoes \(os, profissional\)/)
    assert.match(src, /tipo_aplicado\s*!=\s*'bonificacao'/)
  })
})
