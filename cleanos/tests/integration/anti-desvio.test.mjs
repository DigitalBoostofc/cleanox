/**
 * CleanOS — Suíte de integração das garantias anti-desvio.
 *
 * Requisito: PocketBase rodando em $PB_URL (padrão: http://127.0.0.1:8090)
 *            com migrations 1 e 2 aplicadas (seed).
 *
 * Executar: npm test          (de dentro de cleanos/tests/)
 *       ou: node --test integration/anti-desvio.test.mjs
 *
 * Cada describe cria os registros que precisa via admin e os remove no after,
 * portanto a suíte é DETERMINÍSTICA e independe do estado do seed.
 */

import { describe, it, before, after } from 'node:test'
import assert from 'node:assert/strict'

const BASE = process.env.PB_URL ?? 'http://127.0.0.1:8090'

// ── helpers HTTP ─────────────────────────────────────────────────────────────

async function login(identity, password) {
  const res = await fetch(`${BASE}/api/collections/users/auth-with-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identity, password }),
  })
  const data = await res.json()
  assert.ok(data.token, `Login falhou para ${identity}: ${JSON.stringify(data)}`)
  return { token: data.token, record: data.record }
}

async function api(method, path, token, body) {
  const headers = { 'Content-Type': 'application/json' }
  if (token) headers.Authorization = token
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body != null ? JSON.stringify(body) : undefined,
  })
  return { status: res.status, body: await res.json().catch(() => null) }
}

const GET    = (path, tok)        => api('GET',    path, tok)
const POST   = (path, tok, body)  => api('POST',   path, tok, body)
const PATCH  = (path, tok, body)  => api('PATCH',  path, tok, body)
const DELETE = (path, tok)        => api('DELETE', path, tok)

function todayUTC()     { return new Date().toISOString().slice(0, 10) }
function futureUTC()    { return new Date(Date.now() + 2 * 86_400_000).toISOString().slice(0, 10) }
function yesterdayUTC() { return new Date(Date.now() - 86_400_000).toISOString().slice(0, 10) }

async function createOS(tok, fields) {
  const r = await POST('/api/collections/ordens_servico/records', tok, fields)
  assert.strictEqual(r.status, 200, `createOS falhou: ${JSON.stringify(r.body)}`)
  return r.body
}

async function deleteOS(tok, id) {
  if (id) await DELETE(`/api/collections/ordens_servico/records/${id}`, tok)
}

// ── suíte ─────────────────────────────────────────────────────────────────────

describe('CleanOS — Garantias Anti-Desvio', { timeout: 60_000 }, () => {
  const s = {} // estado compartilhado: tokens, ids de referência

  before(async () => {
    const health = await fetch(`${BASE}/api/health`).catch(() => null)
    assert.ok(
      health?.ok,
      `PocketBase não está acessível em ${BASE}.\nSuba com: cd cleanos/pb && ./pocketbase serve --http=127.0.0.1:8090`
    )

    const a = await login('admin@cleanox.local', 'cleanox123')
    s.adminTok = a.token

    const p = await login('pedro@cleanox.local', 'cleanox123')
    s.profTok = p.token
    s.profId  = p.record.id

    const l = await login('lucas@cleanox.local', 'cleanox123')
    s.prof2Tok = l.token
    s.prof2Id  = l.record.id

    const g = await login('gerente@cleanox.local', 'cleanox123')
    s.gerenteTok = g.token

    const cl = await GET('/api/collections/clientes/records?perPage=1', s.adminTok)
    s.clienteId = cl.body.items[0].id

    const sv = await GET('/api/collections/servicos/records?perPage=1', s.adminTok)
    s.servicoId = sv.body.items[0].id
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('A · Auth — todos os usuários de seed autenticam', () => {
    it('A1 · profissional (pedro) autentica', () => {
      assert.ok(s.profTok, 'Token de profissional ausente')
    })

    it('A2 · admin autentica', () => {
      assert.ok(s.adminTok, 'Token de admin ausente')
    })

    it('A3 · gerente autentica', () => {
      assert.ok(s.gerenteTok, 'Token de gerente ausente')
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('B · Cofre de clientes — profissional totalmente negado', () => {
    it('B1 · LIST /clientes como profissional → vazio ou 4xx', async () => {
      const { status, body } = await GET('/api/collections/clientes/records', s.profTok)
      const total = body?.totalItems ?? 0
      assert.ok(
        status === 403 || status === 404 || total === 0,
        `Profissional listou clientes: HTTP ${status}, totalItems=${total}`
      )
    })

    it('B2 · VIEW /clientes/:id como profissional → 403 ou 404', async () => {
      const { status } = await GET(
        `/api/collections/clientes/records/${s.clienteId}`,
        s.profTok
      )
      assert.ok(
        status === 403 || status === 404,
        `Profissional visualizou cliente por ID: HTTP ${status}`
      )
    })

    it('B3 · expand=cliente em OS → expand.cliente vazio para profissional', async () => {
      const { body } = await GET(
        '/api/collections/ordens_servico/records?expand=cliente',
        s.profTok
      )
      const leaked = (body?.items ?? []).filter(os => os.expand?.cliente != null)
      assert.strictEqual(
        leaked.length, 0,
        `expand.cliente vazou em ${leaked.length} OS(s)`
      )
    })

    it('B4 · ?fields+expand não expõe telefone do cliente', async () => {
      const { body } = await GET(
        '/api/collections/ordens_servico/records?expand=cliente&fields=id,status,expand.cliente',
        s.profTok
      )
      const withPhone = (body?.items ?? []).filter(os => os.expand?.cliente?.telefone)
      assert.strictEqual(withPhone.length, 0, 'Telefone do cliente vazou via fields+expand')
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('C · Campos sensíveis ausentes nas OS', () => {
    let emAndamentoId

    before(async () => {
      // Cria OS em_andamento para garantir que o teste C3 seja determinístico
      const os = await createOS(s.adminTok, {
        cliente: s.clienteId,
        servico: s.servicoId,
        profissional: s.profId,
        data_hora: `${todayUTC()} 10:00:00.000Z`,
        status: 'em_andamento',
        valor_servico: 100,
      })
      emAndamentoId = os.id
    })

    after(async () => {
      await deleteOS(s.adminTok, emAndamentoId)
    })

    it('C1 · OS não possuem telefone / email / sobrenome', async () => {
      const { body } = await GET(
        '/api/collections/ordens_servico/records?perPage=200',
        s.profTok
      )
      const leaky = (body?.items ?? []).filter(
        os => os.telefone || os.email || os.sobrenome
      )
      assert.strictEqual(leaky.length, 0, 'Campos sensíveis encontrados nas OS')
    })

    it('C2 · agendada/atribuida/concluida/cancelada: endereco_liberado vazio', async () => {
      const { body } = await GET(
        '/api/collections/ordens_servico/records?perPage=200',
        s.profTok
      )
      const bad = (body?.items ?? []).filter(
        os => os.status !== 'em_andamento' &&
              os.endereco_liberado && os.endereco_liberado !== ''
      )
      assert.strictEqual(
        bad.length, 0,
        `Endereço exposto em OS com status: ${bad.map(o => o.status).join(', ')}`
      )
    })

    it('C3 · OS em_andamento: endereco_liberado preenchido', async () => {
      const { body } = await GET(
        `/api/collections/ordens_servico/records/${emAndamentoId}`,
        s.profTok
      )
      assert.ok(
        body?.endereco_liberado && body.endereco_liberado !== '',
        'OS em_andamento deveria ter endereco_liberado preenchido'
      )
    })

    it('C4 · nome_curto usa formato "Nome X." (não expõe sobrenome inteiro)', async () => {
      const { body } = await GET(
        '/api/collections/ordens_servico/records?perPage=200',
        s.profTok
      )
      const withNome = (body?.items ?? []).filter(os => os.nome_curto)
      assert.ok(withNome.length > 0, 'Nenhuma OS com nome_curto visível ao profissional')
      // O último token deve ser uma inicial com ponto: "S." (2 chars max)
      const leaky = withNome.filter(os => {
        const parts = os.nome_curto.trim().split(' ')
        return parts.length > 1 && parts[parts.length - 1].length > 2
      })
      assert.strictEqual(
        leaky.length, 0,
        `nome_curto expõe sobrenome: ${leaky.map(o => o.nome_curto).join(', ')}`
      )
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('D · Profissional só vê as próprias OS', () => {
    it('D1 · toda OS visível a pedro tem profissional = pedroId', async () => {
      const { body } = await GET(
        '/api/collections/ordens_servico/records?perPage=200',
        s.profTok
      )
      const notOwn = (body?.items ?? []).filter(
        os => os.profissional && os.profissional !== s.profId
      )
      assert.strictEqual(
        notOwn.length, 0,
        `Pedro vê ${notOwn.length} OS de outro profissional`
      )
    })

    it('D2 · lucas não vê OS de pedro', async () => {
      const { body } = await GET(
        '/api/collections/ordens_servico/records?perPage=200',
        s.prof2Tok
      )
      const pedros = (body?.items ?? []).filter(os => os.profissional === s.profId)
      assert.strictEqual(pedros.length, 0, `Lucas vê ${pedros.length} OS de Pedro`)
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('E · Ciclo de vida do endereço (fluxo dinâmico)', () => {
    // Os testes E2→E4 compartilham a mesma OS pois evoluem seu estado em sequência.
    // Se E2 falhar, E3/E4 falharão com mensagens diferentes — isso é intencional.
    const flow = {}

    before(async () => {
      // OS com data futura → dia-check (E1)
      flow.dayCheckId = (await createOS(s.adminTok, {
        cliente: s.clienteId,
        servico: s.servicoId,
        profissional: s.profId,
        data_hora: `${futureUTC()} 10:00:00.000Z`,
        status: 'atribuida',
        valor_servico: 100,
      })).id

      // OS de hoje → fluxo completo atribuida→em_andamento→concluida (E2–E4)
      flow.osId = (await createOS(s.adminTok, {
        cliente: s.clienteId,
        servico: s.servicoId,
        profissional: s.profId,
        data_hora: `${todayUTC()} 10:00:00.000Z`,
        status: 'atribuida',
        valor_servico: 100,
      })).id
    })

    after(async () => {
      await deleteOS(s.adminTok, flow.dayCheckId)
      await deleteOS(s.adminTok, flow.osId)
    })

    it('E1 · day-check: iniciar OS com data futura → bloqueado', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${flow.dayCheckId}`,
        s.profTok,
        { status: 'em_andamento' }
      )
      assert.notStrictEqual(status, 200, 'Deveria ter bloqueado Iniciar fora do dia')
    })

    it('E2 · Iniciar hoje (atribuida→em_andamento) → endereço liberado', async () => {
      const { status, body } = await PATCH(
        `/api/collections/ordens_servico/records/${flow.osId}`,
        s.profTok,
        { status: 'em_andamento' }
      )
      assert.strictEqual(status, 200, `Iniciar falhou: ${JSON.stringify(body)}`)
      assert.ok(
        body?.endereco_liberado && body.endereco_liberado !== '',
        'Endereço deve ser liberado ao Iniciar'
      )
      assert.ok(!body?.telefone, 'Telefone nunca deve aparecer na OS')
    })

    it('E3 · Concluir sem pagamento → bloqueado', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${flow.osId}`,
        s.profTok,
        { status: 'concluida' }
      )
      assert.notStrictEqual(status, 200, 'Deveria ter bloqueado concluir sem pagamento')
    })

    it('E4 · Concluir com pagamento → status concluida e endereço limpo', async () => {
      const { status, body } = await PATCH(
        `/api/collections/ordens_servico/records/${flow.osId}`,
        s.profTok,
        { valor_pago: 100, forma_pagamento: 'pix_maquininha', status: 'concluida' }
      )
      assert.strictEqual(status, 200, `Concluir com pagamento falhou: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.status, 'concluida')
      assert.ok(
        !body?.endereco_liberado || body.endereco_liberado === '',
        'Endereço deve ser limpo ao concluir'
      )
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('F · Travas de campo: profissional recebe erro em campos proibidos', () => {
    let lockOsId

    before(async () => {
      // OS em em_andamento: profissional pode fazer PATCH mas só em campos permitidos
      lockOsId = (await createOS(s.adminTok, {
        cliente: s.clienteId,
        servico: s.servicoId,
        profissional: s.profId,
        data_hora: `${todayUTC()} 10:00:00.000Z`,
        status: 'em_andamento',
        valor_servico: 100,
      })).id
    })

    after(async () => {
      await deleteOS(s.adminTok, lockOsId)
    })

    it('F1 · profissional não altera valor_servico', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${lockOsId}`,
        s.profTok,
        { valor_servico: 9999 }
      )
      assert.notStrictEqual(status, 200, 'valor_servico deveria ser campo bloqueado')
    })

    it('F2 · profissional não troca cliente', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${lockOsId}`,
        s.profTok,
        { cliente: 'fake_id_000000000' }
      )
      assert.notStrictEqual(status, 200)
    })

    it('F3 · profissional não troca profissional', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${lockOsId}`,
        s.profTok,
        { profissional: s.prof2Id }
      )
      assert.notStrictEqual(status, 200)
    })

    it('F4 · profissional não altera data_hora', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${lockOsId}`,
        s.profTok,
        { data_hora: '2099-01-01 10:00:00.000Z' }
      )
      assert.notStrictEqual(status, 200)
    })

    it('F5 · profissional não marca repasse_status', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${lockOsId}`,
        s.profTok,
        { repasse_status: 'pago' }
      )
      assert.notStrictEqual(status, 200)
    })

    it('F6 · transição inválida em_andamento→agendada → bloqueada', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${lockOsId}`,
        s.profTok,
        { status: 'agendada' }
      )
      assert.notStrictEqual(status, 200)
    })

    it('F7 · transição inválida em_andamento→atribuida → bloqueada', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${lockOsId}`,
        s.profTok,
        { status: 'atribuida' }
      )
      assert.notStrictEqual(status, 200)
    })

    it('F8 · transição inválida em_andamento→cancelada → bloqueada para profissional', async () => {
      // Profissional só pode avançar para concluida; cancelar é operação de admin/gerente
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${lockOsId}`,
        s.profTok,
        { status: 'cancelada' }
      )
      assert.notStrictEqual(status, 200)
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('G · Profissional não pode criar OS (createRule)', () => {
    it('G1 · POST /ordens_servico como profissional → negado', async () => {
      const { status } = await POST(
        '/api/collections/ordens_servico/records',
        s.profTok,
        {
          cliente: s.clienteId,
          servico: s.servicoId,
          data_hora: `${todayUTC()} 10:00:00.000Z`,
          status: 'agendada',
          valor_servico: 100,
        }
      )
      assert.notStrictEqual(status, 200, 'Profissional não deveria poder criar OS')
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('H · Admin e Gerente: acesso pleno (sanidade)', () => {
    it('H1 · admin lê clientes e tem telefone', async () => {
      const { status, body } = await GET(
        '/api/collections/clientes/records?perPage=1',
        s.adminTok
      )
      assert.strictEqual(status, 200)
      assert.ok(body?.items?.length > 0, 'Admin deve ver ao menos um cliente')
      assert.ok(body.items[0].telefone, 'Admin deve ver telefone do cliente')
    })

    it('H2 · gerente lê clientes', async () => {
      const { status, body } = await GET(
        '/api/collections/clientes/records?perPage=1',
        s.gerenteTok
      )
      assert.strictEqual(status, 200)
      assert.ok(body?.items?.length > 0, 'Gerente deve ver ao menos um cliente')
    })

    it('H3 · admin cria e deleta OS sem restrição', async () => {
      const { status: cs, body: cb } = await POST(
        '/api/collections/ordens_servico/records',
        s.adminTok,
        {
          cliente: s.clienteId,
          servico: s.servicoId,
          data_hora: `${todayUTC()} 10:00:00.000Z`,
          status: 'agendada',
          valor_servico: 100,
        }
      )
      assert.strictEqual(cs, 200, `Admin não criou OS: ${JSON.stringify(cb)}`)
      const { status: ds } = await DELETE(
        `/api/collections/ordens_servico/records/${cb.id}`,
        s.adminTok
      )
      assert.ok(ds === 200 || ds === 204, 'Admin não deletou OS')
    })

    it('H4 · gerente não altera repasse_status (exclusivo do admin)', async () => {
      const os = await createOS(s.adminTok, {
        cliente: s.clienteId,
        servico: s.servicoId,
        data_hora: `${todayUTC()} 10:00:00.000Z`,
        status: 'concluida',
        valor_servico: 100,
        valor_pago: 100,
        forma_pagamento: 'pix_maquininha',
      })
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${os.id}`,
        s.gerenteTok,
        { repasse_status: 'pago' }
      )
      await deleteOS(s.adminTok, os.id)
      assert.notStrictEqual(status, 200, 'Gerente não deveria alterar repasse_status')
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('I · F1 — Guard anti-oráculo relacional (vetores a–d)', () => {
    // Estes testes devem FALHAR antes do fix (filtro retorna 200/dados) e PASSAR
    // depois (filtro retorna 400 rejeitado pelo guard).

    it('I1 (vetor a) · filter=cliente.telefone → 400 para profissional', async () => {
      const { status } = await GET(
        `/api/collections/ordens_servico/records?filter=(cliente.telefone='11999990002')`,
        s.profTok
      )
      assert.strictEqual(
        status, 400,
        `Filtro cliente.telefone deveria retornar 400, got ${status}`
      )
    })

    it('I2 (vetor a) · filter=cliente.sobrenome → 400 para profissional', async () => {
      const { status } = await GET(
        `/api/collections/ordens_servico/records?filter=(cliente.sobrenome='Souza')`,
        s.profTok
      )
      assert.strictEqual(status, 400, `Filtro cliente.sobrenome deveria retornar 400, got ${status}`)
    })

    it('I3 (vetor a) · filter=cliente.email → 400 para profissional', async () => {
      const { status } = await GET(
        `/api/collections/ordens_servico/records?filter=(cliente.email~'carlos')`,
        s.profTok
      )
      assert.strictEqual(status, 400, `Filtro cliente.email deveria retornar 400, got ${status}`)
    })

    it('I4 (vetor b) · filter=@collection.clientes.* → 4xx para profissional', async () => {
      const { status } = await GET(
        `/api/collections/ordens_servico/records?filter=@collection.clientes.telefone='11999990002'`,
        s.profTok
      )
      assert.ok(
        status === 400 || status === 403,
        `@collection filter deveria retornar 400/403, got ${status}`
      )
    })

    it('I5 (vetor c) · sort=cliente.telefone → 400 para profissional', async () => {
      const res = await fetch(
        `${BASE}/api/collections/ordens_servico/records?sort=cliente.telefone`,
        { headers: { Authorization: s.profTok } }
      )
      assert.strictEqual(res.status, 400, `sort=cliente.telefone deveria retornar 400, got ${res.status}`)
    })

    it('I6 · fluxo legítimo: filter por status e sort por data_hora ainda funciona', async () => {
      const res = await fetch(
        `${BASE}/api/collections/ordens_servico/records?filter=(status='em_andamento')&sort=-data_hora`,
        { headers: { Authorization: s.profTok } }
      )
      assert.strictEqual(res.status, 200, `Filtro legítimo deveria retornar 200, got ${res.status}`)
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('J · F-04 — Day-check em BRT (UTC-3)', () => {
    // Valida que o day-check usa fuso BRT, não UTC cru.
    // Cobre o cenário: data_hora ontem 23h UTC = ontem 20h BRT → deve BLOQUEAR.
    // (O teste E1 cobre data futura; este cobre a borda noturna BRT)

    let osYesterdayNight

    before(async () => {
      // OS com data_hora = ontem 23:00 UTC = ontem 20:00 BRT → é dia ANTERIOR em BRT
      osYesterdayNight = (await createOS(s.adminTok, {
        cliente: s.clienteId,
        servico: s.servicoId,
        profissional: s.profId,
        data_hora: `${yesterdayUTC()} 23:00:00.000Z`,
        status: 'atribuida',
        valor_servico: 100,
      })).id
    })

    after(async () => {
      await deleteOS(s.adminTok, osYesterdayNight)
    })

    it('J1 · OS de ontem 23h UTC (ontem 20h BRT) → Iniciar bloqueado (dia anterior em BRT)', async () => {
      const { status, body } = await PATCH(
        `/api/collections/ordens_servico/records/${osYesterdayNight}`,
        s.profTok,
        { status: 'em_andamento' }
      )
      assert.notStrictEqual(
        status, 200,
        `Deveria ter bloqueado: ontem 23h UTC é dia anterior em BRT. Got: ${JSON.stringify(body)}`
      )
    })
  })
})
