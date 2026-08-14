/**
 * PocketBase 0.39.4 real — só API, fixture temporária.
 * Não entra em test:unit. Timeout explícito; finally mata o PB.
 *
 *   node --test --test-timeout=45000 integration/users_categoria_comissao.live.test.mjs
 *
 * Fixture: copia pb_migrations excluindo os seeds históricos
 * 1700000002_seed.js e 1700000015_seed_financeiro.js. Equipe é criada
 * depois via API. Baseline que bloqueia migrate sem esses seeds (cópia
 * temp only, repo intacto):
 *   - 1700000057: IDs de prod (parafusadeira)
 *   - 1700000058: exige Equipe do seed 0015
 * Sem no-op dessas duas, o migrate para antes de 0059 (campo
 * users.categoria_comissao). 0047 só loga e segue.
 */
import { describe, it, before, after } from 'node:test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdtemp, cp, rm, writeFile, access, chmod } from 'node:fs/promises'
import { constants } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const repo = path.resolve(here, '../..')
const PORT = Number(process.env.PB_LIVE_PORT || 18917)
const BASE = `http://127.0.0.1:${PORT}`
const SU_EMAIL = 'su-live@cleanos.test'
const SU_PASS = 'super-live-pass-1234'
const HARD_MS = 40000

async function findPb() {
  for (const p of [
    process.env.PB_BIN,
    path.join(repo, 'pb/pocketbase'),
    '/home/leonardo-groff/projetos/cleanox/cleanos/pb/pocketbase',
  ].filter(Boolean)) {
    try {
      await access(p, constants.X_OK)
      return p
    } catch (_) {}
  }
  return null
}

function run(cmd, args, cwd, timeoutMs = 20000) {
  const child = spawn(cmd, args, {
    cwd,
    detached: true,
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  let out = ''
  child.stdout.on('data', (d) => { out += d.toString() })
  child.stderr.on('data', (d) => { out += d.toString() })
  return new Promise((resolve) => {
    const t = setTimeout(() => {
      killTree(child)
      resolve({ code: -1, out: out + '\n[timeout]' })
    }, timeoutMs)
    child.on('exit', (code) => {
      clearTimeout(t)
      resolve({ code, out })
    })
  })
}

function killTree(child) {
  if (!child || !child.pid) return
  try { process.kill(-child.pid, 'SIGKILL') } catch (_) {}
  try { child.kill('SIGKILL') } catch (_) {}
}

async function api(method, urlPath, token, body) {
  const ac = new AbortController()
  const t = setTimeout(() => ac.abort(), 8000)
  try {
    const headers = { 'Content-Type': 'application/json' }
    if (token) headers.Authorization = token
    const res = await fetch(`${BASE}${urlPath}`, {
      method,
      headers,
      body: body != null ? JSON.stringify(body) : undefined,
      signal: ac.signal,
    })
    let json = null
    try { json = await res.json() } catch { json = null }
    return { status: res.status, body: json }
  } finally {
    clearTimeout(t)
  }
}

async function waitHealth(ms = 15000) {
  const start = Date.now()
  while (Date.now() - start < ms) {
    try {
      const res = await fetch(`${BASE}/api/health`, { signal: AbortSignal.timeout(1500) })
      if (res.ok) return
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 200))
  }
  throw new Error('PB temporário sem /api/health')
}

const pbBin = await findPb()

describe('PB 0.39.4 live API (fixture)', { skip: !pbBin, timeout: HARD_MS }, () => {
  let tmp
  let server
  let tok
  let equipeId
  let watchdog

  async function cleanup() {
    clearTimeout(watchdog)
    killTree(server)
    server = null
    try {
      spawn('fuser', ['-k', `${PORT}/tcp`], { stdio: 'ignore' }).unref()
    } catch (_) {}
    if (tmp) {
      await rm(tmp, { recursive: true, force: true })
      tmp = null
    }
  }

  before(async () => {
    watchdog = setTimeout(() => {
      killTree(server)
    }, HARD_MS)
    tmp = await mkdtemp(path.join(os.tmpdir(), 'cleanos-api-'))
    await cp(path.join(repo, 'pb/pb_hooks'), path.join(tmp, 'pb_hooks'), { recursive: true })
    await cp(path.join(repo, 'pb/pb_migrations'), path.join(tmp, 'pb_migrations'), { recursive: true })
    await rm(path.join(tmp, 'pb_migrations/1700000002_seed.js'), { force: true })
    await rm(path.join(tmp, 'pb_migrations/1700000015_seed_financeiro.js'), { force: true })
    // Baseline: sem 0015 o migrate para em 0057/0058. No-op só na cópia temp.
    await writeFile(
      path.join(tmp, 'pb_migrations/1700000057_corrigir_parafusadeira_agosto.js'),
      'migrate((app) => {}, (app) => {});',
    )
    await writeFile(
      path.join(tmp, 'pb_migrations/1700000058_comissao_subcategoria_profissional.js'),
      'migrate((app) => {}, (app) => {});',
    )
    const bin = path.join(tmp, 'pocketbase')
    await cp(pbBin, bin)
    await chmod(bin, 0o755)
    const su = await run(bin, ['superuser', 'upsert', SU_EMAIL, SU_PASS], tmp, 20000)
    if (su.code !== 0) {
      await cleanup()
      throw new Error('superuser upsert falhou: ' + su.out.slice(-800))
    }
    // stdio ignore: se o pipe encher com log de migrate, o serve trava.
    server = spawn(bin, ['serve', `--http=127.0.0.1:${PORT}`], {
      cwd: tmp,
      detached: true,
      stdio: 'ignore',
    })
    try {
      await waitHealth(15000)
      const auth = await api('POST', '/api/collections/_superusers/auth-with-password', null, {
        identity: SU_EMAIL,
        password: SU_PASS,
      })
      assert.equal(auth.status, 200, JSON.stringify(auth.body))
      tok = auth.body.token
      const equipe = await api('POST', '/api/collections/fin_categorias/records', tok, {
        nome: 'Equipe',
        tipo: 'despesa',
        parent_id: '',
        icone: 'users',
        cor: '#F59E0B',
        arquivada: false,
      })
      assert.equal(equipe.status, 200, JSON.stringify(equipe.body))
      equipeId = equipe.body.id
    } catch (err) {
      await cleanup()
      throw err
    }
  })

  after(async () => {
    await cleanup()
  })

  it('create de profissional configura Equipe → nome', async () => {
    const mkt = await api('POST', '/api/collections/fin_categorias/records', tok, {
      nome: 'Marketing Live',
      tipo: 'despesa',
      parent_id: '',
      arquivada: false,
    })
    const prof = await api('POST', '/api/collections/users/records', tok, {
      email: 'joao.live@cleanos.test',
      password: 'senha1234',
      passwordConfirm: 'senha1234',
      name: 'João Live',
      nome: 'João Live',
      role: 'profissional',
      roles: ['profissional'],
      categoria_comissao: mkt.body.id,
      emailVisibility: true,
    })
    assert.equal(prof.status, 200, JSON.stringify(prof.body))
    assert.ok(prof.body.categoria_comissao)
    assert.notEqual(prof.body.categoria_comissao, mkt.body.id)
    const sub = await api(
      'GET',
      `/api/collections/fin_categorias/records/${prof.body.categoria_comissao}`,
      tok,
    )
    assert.equal(sub.body.nome, 'João Live')
    assert.equal(sub.body.parent_id, equipeId)
  })

  it('update adiciona profissional e reconcilia', async () => {
    const ger = await api('POST', '/api/collections/users/records', tok, {
      email: 'ger.only@cleanos.test',
      password: 'senha1234',
      passwordConfirm: 'senha1234',
      name: 'Gerente Only',
      role: 'gerente',
      roles: ['gerente'],
      emailVisibility: true,
    })
    assert.equal(ger.body.categoria_comissao, '')
    const promote = await api('PATCH', `/api/collections/users/records/${ger.body.id}`, tok, {
      roles: ['gerente', 'profissional'],
    })
    assert.equal(promote.status, 200, JSON.stringify(promote.body))
    assert.ok(promote.body.categoria_comissao)
  })

  it('sub preexistente reutilizada sobrevive a create falho', async () => {
    const pre = await api('POST', '/api/collections/fin_categorias/records', tok, {
      nome: 'Joao Preexistente',
      tipo: 'despesa',
      parent_id: equipeId,
      arquivada: false,
    })
    const reuseFail = await api('POST', '/api/collections/users/records', tok, {
      email: 'joao.live@cleanos.test',
      password: 'senha1234',
      passwordConfirm: 'senha1234',
      name: 'Joao Preexistente',
      nome: 'Joao Preexistente',
      role: 'profissional',
      roles: ['profissional'],
      emailVisibility: true,
    })
    assert.notEqual(reuseFail.status, 200)
    const still = await api(
      'GET',
      `/api/collections/fin_categorias/records/${pre.body.id}`,
      tok,
    )
    assert.equal(still.status, 200)
    assert.equal(still.body.nome, 'Joao Preexistente')
  })

  it('sem Equipe o create falha claro', async () => {
    await api('PATCH', `/api/collections/fin_categorias/records/${equipeId}`, tok, {
      nome: 'EquipeOld',
      tipo: 'receita',
    })
    const failCreate = await api('POST', '/api/collections/users/records', tok, {
      email: 'sem.equipe@cleanos.test',
      password: 'senha1234',
      passwordConfirm: 'senha1234',
      name: 'Sem Equipe',
      role: 'profissional',
      roles: ['profissional'],
      emailVisibility: true,
    })
    assert.notEqual(failCreate.status, 200)
    assert.match(JSON.stringify(failCreate.body), /Equipe/)
  })
})
