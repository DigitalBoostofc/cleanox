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
// BRT = UTC-3; usar nas datas enviadas ao day-check para evitar divergência nas primeiras horas UTC
function todayBRT()     { return new Date(Date.now() - 3 * 3_600_000).toISOString().slice(0, 10) }
function yesterdayBRT() { return new Date(Date.now() - 3 * 3_600_000 - 86_400_000).toISOString().slice(0, 10) }

// Segredo de serviço (deve bater com o valor de CLEANOS_SERVICE_SECRET no PocketBase).
// Para rodar os testes L/N: inicie o PocketBase com
//   CLEANOS_SERVICE_SECRET=test-cleanox-secret ./pocketbase serve --http=127.0.0.1:8090
const SVC_SECRET = process.env.CLEANOS_SERVICE_SECRET ?? 'test-cleanox-secret'

async function apiSvc(method, path, secret, body) {
  const headers = { 'Content-Type': 'application/json' }
  if (secret) headers['X-Cleanos-Secret'] = secret
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body != null ? JSON.stringify(body) : undefined,
  })
  return { status: res.status, body: await res.json().catch(() => null) }
}
const SVC_POST = (path, secret, body) => apiSvc('POST', path, secret, body)
const SVC_GET  = (path, secret)       => apiSvc('GET',  path, secret)

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
      // Usa todayBRT() para que o dia coincida com o que o hook calcula em BRT,
      // mesmo quando os testes rodam nas primeiras horas UTC (≠ dia BRT).
      flow.osId = (await createOS(s.adminTok, {
        cliente: s.clienteId,
        servico: s.servicoId,
        profissional: s.profId,
        data_hora: `${todayBRT()} 10:00:00.000Z`,
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
  describe('K · WhatsApp — guards de papel e ausência de dados sensíveis', () => {
    // OS em_andamento criada para os testes K3 / K4
    let waOsId

    before(async () => {
      waOsId = (await createOS(s.adminTok, {
        cliente: s.clienteId,
        servico: s.servicoId,
        profissional: s.profId,
        data_hora: `${todayUTC()} 10:00:00.000Z`,
        status: 'em_andamento',
        valor_servico: 100,
      })).id
    })

    after(async () => {
      await deleteOS(s.adminTok, waOsId)
    })

    it('K1 · profissional não acessa GET /whatsapp/status → 401 ou 403', async () => {
      const { status } = await GET('/api/cleanos/whatsapp/status', s.profTok)
      assert.ok(
        status === 401 || status === 403,
        `Profissional deveria ser bloqueado em /whatsapp/status, got HTTP ${status}`
      )
    })

    it('K2 · profissional não acessa POST /whatsapp/connect → 401 ou 403', async () => {
      const { status } = await POST('/api/cleanos/whatsapp/connect', s.profTok)
      assert.ok(
        status === 401 || status === 403,
        `Profissional deveria ser bloqueado em /whatsapp/connect, got HTTP ${status}`
      )
    })

    it('K3 · outro profissional (lucas) não dispara a-caminho de OS de pedro → 403', async () => {
      const { status } = await POST(`/api/cleanos/os/${waOsId}/a-caminho`, s.prof2Tok)
      assert.strictEqual(
        status, 403,
        `Lucas deveria receber 403 ao tentar disparar a-caminho de OS de Pedro, got ${status}`
      )
    })

    it('K4 · a-caminho da própria OS: resposta NÃO contém telefone; retorna 409 (WA não conectado) ou 200', async () => {
      const { status, body } = await POST(`/api/cleanos/os/${waOsId}/a-caminho`, s.profTok)
      // Em ambiente de teste o WhatsApp não está conectado → espera 409
      // Se por algum motivo estiver conectado, aceita 200 também
      assert.ok(
        status === 409 || status === 200,
        `a-caminho deveria retornar 409 (WA desconectado) ou 200, got ${status}: ${JSON.stringify(body)}`
      )
      // Em NENHUM caso a resposta pode conter telefone
      const bodyStr = JSON.stringify(body || {})
      assert.ok(
        !bodyStr.includes('telefone') && !bodyStr.includes('phone') && !bodyStr.includes('numero'),
        `Resposta da rota a-caminho vazou dado sensível: ${bodyStr}`
      )
    })

    it('K5 · profissional não grava aviso_a_caminho_em via PATCH direto → bloqueado', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${waOsId}`,
        s.profTok,
        { aviso_a_caminho_em: '2026-01-01 10:00:00.000Z' }
      )
      assert.notStrictEqual(
        status, 200,
        'Profissional não deveria conseguir gravar aviso_a_caminho_em via PATCH direto'
      )
    })

    it('K6 · admin acessa GET /whatsapp/status → 200', async () => {
      const { status, body } = await GET('/api/cleanos/whatsapp/status', s.adminTok)
      assert.strictEqual(status, 200, `Admin deveria acessar /whatsapp/status, got ${status}`)
      assert.ok('configured' in (body || {}), 'Resposta deve ter campo `configured`')
      // Token NUNCA deve vazar na resposta
      assert.ok(!body?.token && !body?.instanceToken && !body?.whatsapp_instance_token,
        'Token da instância não deve aparecer na resposta de /whatsapp/status')
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('L · Ratings — endpoints de serviço (secret)', () => {
    // Para rodar estes testes o PocketBase deve ser iniciado com:
    //   CLEANOS_SERVICE_SECRET=test-cleanox-secret ./pocketbase serve
    const r = {}

    before(async () => {
      // Lê o telefone do cliente de teste (admin pode ver)
      const clRes = await GET(`/api/collections/clientes/records/${s.clienteId}`, s.adminTok)
      r.phone = clRes.body?.telefone || ''

      // Cria OS concluida (admin cria diretamente)
      const os = await createOS(s.adminTok, {
        cliente:         s.clienteId,
        servico:         s.servicoId,
        profissional:    s.profId,
        data_hora:       `${todayUTC()} 10:00:00.000Z`,
        status:          'concluida',
        valor_servico:   100,
        valor_pago:      100,
        forma_pagamento: 'pix_maquininha',
      })
      r.osId = os.id

      // Admin seta avaliacao_solicitada_em para simular o que o trigger faria
      // (admin bypassa o locked; o trigger só roda em onRecordUpdate com transição)
      await PATCH(`/api/collections/ordens_servico/records/${r.osId}`, s.adminTok, {
        avaliacao_solicitada_em: `${todayUTC()} 12:00:00.000Z`,
      })
    })

    after(async () => {
      await deleteOS(s.adminTok, r.osId)
    })

    it('L1 · POST /ratings/ingest sem secret → 401', async () => {
      const { status } = await SVC_POST('/api/cleanos/ratings/ingest', '', { os_id: r.osId, nota: 4 })
      assert.strictEqual(status, 401, `Ingest sem secret deveria retornar 401, got ${status}`)
    })

    it('L2 · POST /ratings/ingest com nota 4 → ok=true, needsReason=false', async () => {
      // Cria OS separada para não sujar o estado de r.osId
      const os2 = await createOS(s.adminTok, {
        cliente:         s.clienteId,
        servico:         s.servicoId,
        data_hora:       `${todayUTC()} 10:00:00.000Z`,
        status:          'concluida',
        valor_servico:   100,
        valor_pago:      100,
        forma_pagamento: 'pix_maquininha',
      })
      const { status, body } = await SVC_POST('/api/cleanos/ratings/ingest', SVC_SECRET, {
        os_id: os2.id,
        nota:  4,
      })
      await deleteOS(s.adminTok, os2.id)
      assert.strictEqual(status, 200, `Ingest nota 4 falhou: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.ok, true)
      assert.strictEqual(body?.nota, 4)
      assert.strictEqual(body?.needsReason, false, 'nota 4 não deveria exigir motivo')
    })

    it('L3 · POST /ratings/ingest com nota 2 sem motivo → needsReason=true', async () => {
      const { status, body } = await SVC_POST('/api/cleanos/ratings/ingest', SVC_SECRET, {
        os_id: r.osId,
        nota:  2,
      })
      assert.strictEqual(status, 200, `Ingest nota 2 falhou: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.ok, true)
      assert.strictEqual(body?.nota, 2)
      assert.strictEqual(body?.needsReason, true, 'nota ≤ 3 sem motivo deveria ter needsReason=true')
    })

    it('L4 · POST /ratings/ingest com motivo grava e needsReason vira false', async () => {
      const { status, body } = await SVC_POST('/api/cleanos/ratings/ingest', SVC_SECRET, {
        os_id:  r.osId,
        motivo: 'Profissional atrasou 30 minutos',
      })
      assert.strictEqual(status, 200, `Ingest motivo falhou: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.ok, true)
      assert.strictEqual(body?.needsReason, false, 'Após gravar motivo, needsReason deve ser false')
      // Confirma que o motivo foi persistido
      const osAfter = await GET(`/api/collections/ordens_servico/records/${r.osId}`, s.adminTok)
      assert.ok(
        osAfter.body?.avaliacao_motivo && osAfter.body.avaliacao_motivo.length > 0,
        'Motivo não foi persistido na OS'
      )
    })

    it('L5 · GET /ratings/pending?phone=... retorna a OS correta', async () => {
      // r.osId: nota=2, motivo gravado — NÃO deve ser retornada (motivo preenchido)
      // Precisa de uma OS com nota 1-3 e SEM motivo para a query retornar
      const os3 = await createOS(s.adminTok, {
        cliente:         s.clienteId,
        servico:         s.servicoId,
        data_hora:       `${todayUTC()} 10:00:00.000Z`,
        status:          'concluida',
        valor_servico:   100,
        valor_pago:      100,
        forma_pagamento: 'pix_maquininha',
      })
      // Admin seta avaliacao_solicitada_em e nota 3 sem motivo
      await PATCH(`/api/collections/ordens_servico/records/${os3.id}`, s.adminTok, {
        avaliacao_solicitada_em: `${todayUTC()} 13:00:00.000Z`,
      })
      await SVC_POST('/api/cleanos/ratings/ingest', SVC_SECRET, { os_id: os3.id, nota: 3 })

      const encodedPhone = encodeURIComponent(r.phone)
      const { status, body } = await SVC_GET(
        `/api/cleanos/ratings/pending?phone=${encodedPhone}`,
        SVC_SECRET
      )
      await deleteOS(s.adminTok, os3.id)
      assert.strictEqual(status, 200, `Pending falhou: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.os_id, os3.id, 'Pending deveria retornar os3.id')
      assert.ok(!body?.phone && !body?.telefone, 'Pending não deve retornar o telefone')
    })

    it('L8 · GET /ratings/pending — match tolerante: 55+dígitos e ausência de 9º dígito', async () => {
      // Cria OS com nota 1 (sem motivo) para o cliente de teste
      const os4 = await createOS(s.adminTok, {
        cliente:         s.clienteId,
        servico:         s.servicoId,
        data_hora:       `${todayUTC()} 10:00:00.000Z`,
        status:          'concluida',
        valor_servico:   100,
        valor_pago:      100,
        forma_pagamento: 'pix_maquininha',
      })
      try {
        await PATCH(`/api/collections/ordens_servico/records/${os4.id}`, s.adminTok, {
          avaliacao_solicitada_em: `${todayUTC()} 14:00:00.000Z`,
        })
        await SVC_POST('/api/cleanos/ratings/ingest', SVC_SECRET, { os_id: os4.id, nota: 1 })

        // Variante 1: 55 + só dígitos (formato que o WhatsApp/n8n envia)
        const rawDigits = (r.phone || '').replace(/\D/g, '')
        const waPhone   = rawDigits.startsWith('55') ? rawDigits : '55' + rawDigits
        const r1 = await SVC_GET(
          `/api/cleanos/ratings/pending?phone=${encodeURIComponent(waPhone)}`,
          SVC_SECRET
        )
        assert.strictEqual(r1.status, 200, `Pending 55+dígitos falhou: ${JSON.stringify(r1.body)}`)
        assert.strictEqual(r1.body?.os_id, os4.id, `Formato 55+dígitos não casou (phone=${waPhone})`)

        // Variante 2: sem 9º dígito — só quando o canônico tem 11 dígitos
        const canon = rawDigits.startsWith('55') ? rawDigits.slice(2) : rawDigits
        if (canon.length === 11) {
          // DDD(2) + 9th(1) + num(8) → DDD(2) + num(8)
          const noNine = canon.slice(0, 2) + canon.slice(3)
          const r2 = await SVC_GET(
            `/api/cleanos/ratings/pending?phone=${encodeURIComponent(noNine)}`,
            SVC_SECRET
          )
          assert.strictEqual(r2.status, 200, `Pending sem 9º dígito falhou: ${JSON.stringify(r2.body)}`)
          assert.strictEqual(r2.body?.os_id, os4.id, `Sem 9º dígito não casou (phone=${noNine})`)
        }
      } finally {
        await deleteOS(s.adminTok, os4.id)
      }
    })

    it('L6 · GET /ratings/pending com telefone desconhecido → { os_id: null }', async () => {
      const { status, body } = await SVC_GET(
        '/api/cleanos/ratings/pending?phone=5500000000000',
        SVC_SECRET
      )
      assert.strictEqual(status, 200, `Pending telefone desconhecido falhou: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.os_id, null, 'Telefone desconhecido deveria retornar { os_id: null }')
    })

    it('L7 · POST /ratings/ingest com OS não concluida → 400', async () => {
      const osAgendada = await createOS(s.adminTok, {
        cliente:       s.clienteId,
        servico:       s.servicoId,
        data_hora:     `${futureUTC()} 10:00:00.000Z`,
        status:        'agendada',
        valor_servico: 100,
      })
      const { status } = await SVC_POST('/api/cleanos/ratings/ingest', SVC_SECRET, {
        os_id: osAgendada.id,
        nota:  4,
      })
      await deleteOS(s.adminTok, osAgendada.id)
      assert.strictEqual(status, 400, 'Ingest em OS não concluida deveria retornar 400')
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('M · Travas de avaliação: profissional não grava avaliacao_* via PATCH', () => {
    let mOsId

    before(async () => {
      // OS em em_andamento (profissional pode editar, mas só os campos permitidos)
      mOsId = (await createOS(s.adminTok, {
        cliente:       s.clienteId,
        servico:       s.servicoId,
        profissional:  s.profId,
        data_hora:     `${todayUTC()} 10:00:00.000Z`,
        status:        'em_andamento',
        valor_servico: 100,
      })).id
    })

    after(async () => {
      await deleteOS(s.adminTok, mOsId)
    })

    it('M1 · profissional não grava avaliacao_nota via PATCH → bloqueado', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${mOsId}`,
        s.profTok,
        { avaliacao_nota: 5 }
      )
      assert.notStrictEqual(status, 200, 'avaliacao_nota deveria ser campo bloqueado para profissional')
    })

    it('M2 · profissional não grava avaliacao_motivo via PATCH → bloqueado', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${mOsId}`,
        s.profTok,
        { avaliacao_motivo: 'ótimo' }
      )
      assert.notStrictEqual(status, 200, 'avaliacao_motivo deveria ser campo bloqueado para profissional')
    })

    it('M3 · profissional não grava avaliacao_em via PATCH → bloqueado', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${mOsId}`,
        s.profTok,
        { avaliacao_em: '2026-01-01 10:00:00.000Z' }
      )
      assert.notStrictEqual(status, 200, 'avaliacao_em deveria ser campo bloqueado para profissional')
    })

    it('M4 · profissional não grava avaliacao_solicitada_em via PATCH → bloqueado', async () => {
      const { status } = await PATCH(
        `/api/collections/ordens_servico/records/${mOsId}`,
        s.profTok,
        { avaliacao_solicitada_em: '2026-01-01 10:00:00.000Z' }
      )
      assert.notStrictEqual(status, 200, 'avaliacao_solicitada_em deveria ser campo bloqueado para profissional')
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('N · Config WhatsApp/avaliação — GET/POST só admin/gerente', () => {
    it('N1 · GET /whatsapp/config como admin → 200 com 4 campos', async () => {
      const { status, body } = await GET('/api/cleanos/whatsapp/config', s.adminTok)
      assert.strictEqual(status, 200, `Admin deveria acessar /whatsapp/config, got ${status}`)
      assert.ok('aviso_template'          in (body || {}), 'Falta aviso_template')
      assert.ok('avaliacao_poll_texto'    in (body || {}), 'Falta avaliacao_poll_texto')
      assert.ok('avaliacao_motivo_texto'  in (body || {}), 'Falta avaliacao_motivo_texto')
      assert.ok('avaliacao_agradecimento' in (body || {}), 'Falta avaliacao_agradecimento')
      // Token nunca deve vazar
      assert.ok(
        !body?.whatsapp_instance_token && !body?.instanceToken && !body?.token,
        'Token da instância não deve aparecer na resposta'
      )
    })

    it('N2 · GET /whatsapp/config como gerente → 200', async () => {
      const { status } = await GET('/api/cleanos/whatsapp/config', s.gerenteTok)
      assert.strictEqual(status, 200, `Gerente deveria acessar /whatsapp/config, got ${status}`)
    })

    it('N3 · GET /whatsapp/config como profissional → 401 ou 403', async () => {
      const { status } = await GET('/api/cleanos/whatsapp/config', s.profTok)
      assert.ok(
        status === 401 || status === 403,
        `Profissional deveria ser bloqueado em /whatsapp/config, got ${status}`
      )
    })

    it('N4 · POST /whatsapp/config como admin → 200 com campos atualizados', async () => {
      const novoTexto = 'Teste de avaliação: como foi o serviço de {servico}?'
      const { status, body } = await POST('/api/cleanos/whatsapp/config', s.adminTok, {
        avaliacao_poll_texto: novoTexto,
      })
      assert.strictEqual(status, 200, `Admin deveria poder atualizar config, got ${status}: ${JSON.stringify(body)}`)
      assert.strictEqual(
        body?.avaliacao_poll_texto, novoTexto,
        'Campo avaliacao_poll_texto não foi atualizado'
      )
    })

    it('N5 · POST /whatsapp/config como gerente → 403', async () => {
      const { status } = await POST('/api/cleanos/whatsapp/config', s.gerenteTok, {
        avaliacao_poll_texto: 'tentativa gerente',
      })
      assert.strictEqual(
        status, 403,
        `Gerente não deveria poder alterar config, got ${status}`
      )
    })

    it('N6 · POST /whatsapp/config como profissional → 401 ou 403', async () => {
      const { status } = await POST('/api/cleanos/whatsapp/config', s.profTok, {
        avaliacao_poll_texto: 'tentativa profissional',
      })
      assert.ok(
        status === 401 || status === 403,
        `Profissional não deveria poder alterar config, got ${status}`
      )
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('O · dispatch-info — endpoint de serviço para o n8n', () => {
    it('O1 · GET /whatsapp/dispatch-info sem secret → 401', async () => {
      const { status } = await SVC_GET('/api/cleanos/whatsapp/dispatch-info', '')
      assert.strictEqual(status, 401, `Sem secret deveria retornar 401, got ${status}`)
    })

    it('O2 · GET /whatsapp/dispatch-info com secret correto → 200 com uazapi_base, token e templates', async () => {
      const { status, body } = await SVC_GET('/api/cleanos/whatsapp/dispatch-info', SVC_SECRET)
      assert.strictEqual(status, 200, `dispatch-info falhou: ${JSON.stringify(body)}`)
      // Campos de topo presentes
      assert.ok('uazapi_base'     in (body || {}), 'Falta uazapi_base')
      assert.ok('uazapi_token'    in (body || {}), 'Falta uazapi_token')
      assert.ok('instance_status' in (body || {}), 'Falta instance_status')
      assert.ok('templates'       in (body || {}), 'Falta templates')
      // uazapi_token deve ser uma string (pode ser vazia se instância ainda não criada)
      assert.strictEqual(typeof body.uazapi_token, 'string', 'uazapi_token deve ser string')
      // Templates presentes
      const t = body.templates || {}
      assert.ok('aviso_template'          in t, 'Falta templates.aviso_template')
      assert.ok('avaliacao_poll_texto'    in t, 'Falta templates.avaliacao_poll_texto')
      assert.ok('avaliacao_motivo_texto'  in t, 'Falta templates.avaliacao_motivo_texto')
      assert.ok('avaliacao_agradecimento' in t, 'Falta templates.avaliacao_agradecimento')
    })

    it('O3 · GET /whatsapp/dispatch-info com secret errado → 401', async () => {
      const { status } = await SVC_GET('/api/cleanos/whatsapp/dispatch-info', 'secret-errado')
      assert.strictEqual(status, 401, `Secret errado deveria retornar 401, got ${status}`)
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('P · Repasse automático na conclusão (F-002)', () => {
    let pOsId

    before(async () => {
      pOsId = (await createOS(s.adminTok, {
        cliente:       s.clienteId,
        servico:       s.servicoId,
        profissional:  s.profId,
        data_hora:     `${todayUTC()} 10:00:00.000Z`,
        status:        'atribuida',
        valor_servico: 150,
      })).id
    })

    after(async () => {
      await deleteOS(s.adminTok, pOsId)
    })

    it('P1 · transição para concluida → repasse_status=pendente e repasse_valor=valor_pago', async () => {
      const { status, body } = await PATCH(
        `/api/collections/ordens_servico/records/${pOsId}`,
        s.adminTok,
        { status: 'concluida', valor_pago: 150, forma_pagamento: 'pix_maquininha' }
      )
      assert.strictEqual(status, 200, `Concluir falhou: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.repasse_status, 'pendente', 'repasse_status deve ser pendente após concluir')
      assert.strictEqual(body?.repasse_valor, 150, 'repasse_valor deve igualar valor_pago após concluir')
    })

    it('P2 · save subsequente de OS concluida não zera repasse_status', async () => {
      const { status, body } = await PATCH(
        `/api/collections/ordens_servico/records/${pOsId}`,
        s.adminTok,
        { observacoes: 'save subsequente' }
      )
      assert.strictEqual(status, 200)
      assert.strictEqual(body?.repasse_status, 'pendente', 'repasse_status deve permanecer pendente em save subsequente')
    })

    it('P3 · CREATE direto com status=concluida NÃO auto-seta repasse_status (sem transição)', async () => {
      const direct = await createOS(s.adminTok, {
        cliente:         s.clienteId,
        servico:         s.servicoId,
        data_hora:       `${todayUTC()} 10:00:00.000Z`,
        status:          'concluida',
        valor_servico:   100,
        valor_pago:      100,
        forma_pagamento: 'pix_maquininha',
      })
      try {
        assert.ok(
          !direct.repasse_status || direct.repasse_status === '',
          `CREATE direto concluida não deve auto-setar repasse_status, got: "${direct.repasse_status}"`
        )
      } finally {
        await deleteOS(s.adminTok, direct.id)
      }
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('Q · Guard de repasse no CREATE por gerente/profissional (F-403)', () => {
    it('Q1 · gerente cria OS com repasse_status → rejeitado (403)', async () => {
      const { status } = await POST(
        '/api/collections/ordens_servico/records',
        s.gerenteTok,
        {
          cliente:        s.clienteId,
          servico:        s.servicoId,
          data_hora:      `${todayUTC()} 10:00:00.000Z`,
          status:         'agendada',
          valor_servico:  100,
          repasse_status: 'pago',
        }
      )
      assert.ok(
        status === 403 || status === 400,
        `Gerente criou OS com repasse_status; esperado 403/400, got ${status}`
      )
    })

    it('Q2 · gerente cria OS com repasse_valor → rejeitado (403)', async () => {
      const { status } = await POST(
        '/api/collections/ordens_servico/records',
        s.gerenteTok,
        {
          cliente:       s.clienteId,
          servico:       s.servicoId,
          data_hora:     `${todayUTC()} 10:00:00.000Z`,
          status:        'agendada',
          valor_servico: 100,
          repasse_valor: 9999,
        }
      )
      assert.ok(
        status === 403 || status === 400,
        `Gerente criou OS com repasse_valor; esperado 403/400, got ${status}`
      )
    })

    it('Q3 · admin pode criar OS com repasse_status definido', async () => {
      const { status, body } = await POST(
        '/api/collections/ordens_servico/records',
        s.adminTok,
        {
          cliente:         s.clienteId,
          servico:         s.servicoId,
          data_hora:       `${todayUTC()} 10:00:00.000Z`,
          status:          'concluida',
          valor_servico:   100,
          valor_pago:      100,
          forma_pagamento: 'pix_maquininha',
          repasse_status:  'pendente',
        }
      )
      assert.strictEqual(status, 200, `Admin deve poder criar OS com repasse_status: ${JSON.stringify(body)}`)
      await deleteOS(s.adminTok, body.id)
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('R · emailVisibility — admin vê e-mail de todos os usuários (F-005)', () => {
    it('R1 · admin lista users → todos têm email visível', async () => {
      const { status, body } = await GET('/api/collections/users/records?perPage=200', s.adminTok)
      assert.strictEqual(status, 200)
      const items = body?.items ?? []
      assert.ok(items.length >= 4, `Esperado ≥ 4 usuários, got ${items.length}`)
      const withoutEmail = items.filter(u => !u.email)
      assert.strictEqual(
        withoutEmail.length, 0,
        `${withoutEmail.length} usuários sem email visível: ${withoutEmail.map(u => u.name || u.id).join(', ')}`
      )
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('S · Catálogo idempotente — sem duplicatas (F-001)', () => {
    it('S1 · GET /servicos → todos os nomes são únicos (sem duplicatas)', async () => {
      const { status, body } = await GET('/api/collections/servicos/records?perPage=200', s.adminTok)
      assert.strictEqual(status, 200)
      const items = body?.items ?? []
      const names = items.map(i => i.nome)
      const unique = new Set(names)
      assert.strictEqual(
        unique.size, names.length,
        `Catálogo tem duplicatas: ${names.filter((n, i) => names.indexOf(n) !== i).join(', ')}`
      )
    })

    it('S2 · catálogo tem exatamente 7 serviços', async () => {
      const { body } = await GET('/api/collections/servicos/records?perPage=200', s.adminTok)
      assert.strictEqual((body?.items ?? []).length, 7, `Esperado 7 serviços, got ${body?.totalItems}`)
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('T · Endereço não re-preenchido em save subsequente de OS em_andamento (F-401)', () => {
    let tOsId

    before(async () => {
      tOsId = (await createOS(s.adminTok, {
        cliente:       s.clienteId,
        servico:       s.servicoId,
        profissional:  s.profId,
        data_hora:     `${todayUTC()} 10:00:00.000Z`,
        status:        'em_andamento',
        valor_servico: 100,
      })).id
    })

    after(async () => {
      await deleteOS(s.adminTok, tOsId)
    })

    it('T1 · OS em_andamento recém-criada tem endereco_liberado preenchido', async () => {
      const { body } = await GET(`/api/collections/ordens_servico/records/${tOsId}`, s.adminTok)
      assert.ok(
        body?.endereco_liberado && body.endereco_liberado !== '',
        'endereco_liberado deve estar preenchido na criação em_andamento'
      )
    })

    it('T2 · admin limpa endereco_liberado (simula cron) → fica vazio', async () => {
      const { status, body } = await PATCH(
        `/api/collections/ordens_servico/records/${tOsId}`,
        s.adminTok,
        { endereco_liberado: '' }
      )
      assert.strictEqual(status, 200, `PATCH falhou: ${JSON.stringify(body)}`)
      assert.ok(
        !body?.endereco_liberado || body.endereco_liberado === '',
        `endereco_liberado deve estar vazio após limpeza, got: "${body?.endereco_liberado}"`
      )
    })

    it('T3 · save subsequente (sem mudar status) NÃO re-preenche o endereço', async () => {
      const { status, body } = await PATCH(
        `/api/collections/ordens_servico/records/${tOsId}`,
        s.adminTok,
        { observacoes: 'save subsequente sem mudar status' }
      )
      assert.strictEqual(status, 200)
      assert.ok(
        !body?.endereco_liberado || body.endereco_liberado === '',
        `Hook re-preencheu endereco_liberado indevidamente: "${body?.endereco_liberado}"`
      )
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('U · config_atuacao e disponibilidade — controle de acesso', () => {
    // config_atuacao: singleton criado pela migration; testa update (não create)
    // disponibilidade: testa create + get como admin/gerente; nega profissional

    let dispId    // id do registro de disponibilidade criado pelo admin
    let atuacaoId // id do singleton de config_atuacao

    before(async () => {
      // pega o id do singleton de config_atuacao (criado pela migration 7)
      const r = await GET('/api/collections/config_atuacao/records?perPage=1', s.adminTok)
      atuacaoId = r.body?.items?.[0]?.id ?? null
    })

    after(async () => {
      if (dispId) await DELETE(`/api/collections/disponibilidade/records/${dispId}`, s.adminTok)
    })

    it('U1 · admin lê config_atuacao → 200', async () => {
      const { status } = await GET('/api/collections/config_atuacao/records', s.adminTok)
      assert.strictEqual(status, 200, `Admin deveria ler config_atuacao, got ${status}`)
    })

    it('U2 · gerente lê config_atuacao → 200', async () => {
      const { status } = await GET('/api/collections/config_atuacao/records', s.gerenteTok)
      assert.strictEqual(status, 200, `Gerente deveria ler config_atuacao, got ${status}`)
    })

    it('U3 · profissional NÃO lê config_atuacao → 403 ou lista vazia', async () => {
      const { status, body } = await GET('/api/collections/config_atuacao/records', s.profTok)
      const total = body?.totalItems ?? 0
      assert.ok(
        status === 403 || status === 404 || total === 0,
        `Profissional não deveria ler config_atuacao: HTTP ${status}, totalItems=${total}`
      )
    })

    it('U4 · admin edita config_atuacao (PATCH singleton) → 200', async () => {
      if (!atuacaoId) return assert.fail('Singleton config_atuacao não encontrado — migration 7 aplicada?')
      const payload = {
        estado: 'SP',
        cidades: [{ nome: 'São Paulo', principal: true, bairros: ['Centro', 'Vila Madalena'] }],
      }
      const { status, body } = await PATCH(
        `/api/collections/config_atuacao/records/${atuacaoId}`,
        s.adminTok,
        payload
      )
      assert.strictEqual(status, 200, `Admin deveria editar config_atuacao, got ${status}: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.estado, 'SP', 'Campo estado não persistiu')
    })

    it('U5 · gerente edita config_atuacao → 200', async () => {
      if (!atuacaoId) return assert.fail('Singleton config_atuacao não encontrado')
      const { status } = await PATCH(
        `/api/collections/config_atuacao/records/${atuacaoId}`,
        s.gerenteTok,
        { estado: 'SP' }
      )
      assert.strictEqual(status, 200, `Gerente deveria editar config_atuacao, got ${status}`)
    })

    it('U6 · profissional NÃO edita config_atuacao → 403 ou 404', async () => {
      if (!atuacaoId) return assert.fail('Singleton config_atuacao não encontrado')
      const { status } = await PATCH(
        `/api/collections/config_atuacao/records/${atuacaoId}`,
        s.profTok,
        { estado: 'RJ' }
      )
      assert.ok(
        status === 403 || status === 404,
        `Profissional não deveria editar config_atuacao, got ${status}`
      )
    })

    it('U7 · admin cria disponibilidade para profissional → 200', async () => {
      const payload = {
        profissional: s.profId,
        duracao_min:  60,
        dias: [
          { ativo: false, inicio: '08:00', fim: '18:00' }, // dom
          { ativo: true,  inicio: '08:00', fim: '18:00' }, // seg
          { ativo: true,  inicio: '08:00', fim: '18:00' }, // ter
          { ativo: true,  inicio: '08:00', fim: '18:00' }, // qua
          { ativo: true,  inicio: '08:00', fim: '18:00' }, // qui
          { ativo: true,  inicio: '08:00', fim: '18:00' }, // sex
          { ativo: false, inicio: '08:00', fim: '18:00' }, // sáb
        ],
      }
      const { status, body } = await POST(
        '/api/collections/disponibilidade/records',
        s.adminTok,
        payload
      )
      assert.strictEqual(status, 200, `Admin deveria criar disponibilidade, got ${status}: ${JSON.stringify(body)}`)
      dispId = body?.id
    })

    it('U8 · gerente lê disponibilidade → 200', async () => {
      const { status } = await GET('/api/collections/disponibilidade/records', s.gerenteTok)
      assert.strictEqual(status, 200, `Gerente deveria ler disponibilidade, got ${status}`)
    })

    it('U9 · profissional NÃO lê disponibilidade → 403 ou lista vazia', async () => {
      const { status, body } = await GET('/api/collections/disponibilidade/records', s.profTok)
      const total = body?.totalItems ?? 0
      assert.ok(
        status === 403 || status === 404 || total === 0,
        `Profissional não deveria ler disponibilidade: HTTP ${status}, totalItems=${total}`
      )
    })

    it('U10 · profissional NÃO cria disponibilidade → 403 ou 400', async () => {
      const { status } = await POST(
        '/api/collections/disponibilidade/records',
        s.profTok,
        { profissional: s.profId, duracao_min: 60, dias: [] }
      )
      assert.ok(
        status === 403 || status === 400,
        `Profissional não deveria criar disponibilidade, got ${status}`
      )
    })

    it('U11 · admin atualiza disponibilidade (duracao_min) → 200', async () => {
      if (!dispId) return assert.fail('Registro de disponibilidade não criado em U7')
      const { status, body } = await PATCH(
        `/api/collections/disponibilidade/records/${dispId}`,
        s.adminTok,
        { duracao_min: 90 }
      )
      assert.strictEqual(status, 200, `Admin deveria atualizar disponibilidade, got ${status}: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.duracao_min, 90, 'duracao_min não foi atualizado')
    })

    it('U12 · profissional NÃO edita disponibilidade → 403 ou 404', async () => {
      if (!dispId) return assert.fail('Registro de disponibilidade não criado em U7')
      const { status } = await PATCH(
        `/api/collections/disponibilidade/records/${dispId}`,
        s.profTok,
        { duracao_min: 30 }
      )
      assert.ok(
        status === 403 || status === 404,
        `Profissional não deveria editar disponibilidade, got ${status}`
      )
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('J · F-04 — Day-check em BRT (UTC-3)', () => {
    // Valida que o day-check usa fuso BRT, não UTC cru.
    // Cobre o cenário: data_hora ontem 23h UTC = ontem 20h BRT → deve BLOQUEAR.
    // (O teste E1 cobre data futura; este cobre a borda noturna BRT)

    let osYesterdayNight

    before(async () => {
      // OS com data_hora = ontem BRT 23:00 UTC = ontem BRT 20:00 BRT → dia ANTERIOR em BRT.
      // Usa yesterdayBRT() (não yesterdayUTC()) para garantir que o dia seja corretamente
      // "ontem em BRT" mesmo quando o teste roda nas primeiras horas UTC (00-03h UTC),
      // período em que yesterdayUTC() coincidiria com "hoje em BRT".
      osYesterdayNight = (await createOS(s.adminTok, {
        cliente: s.clienteId,
        servico: s.servicoId,
        profissional: s.profId,
        data_hora: `${yesterdayBRT()} 23:00:00.000Z`,
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

  // ────────────────────────────────────────────────────────────────────────
  describe('V · Rastreamento GPS "estou a caminho" + push (doc 09 §3)', () => {
    // Campos de tracking gravados SÓ server-side (rotas dedicadas/cron). O
    // profissional nunca os grava via PATCH; coords são efêmeras e somem ao
    // concluir; push_tokens é isolado por profissional; /posicao e /cheguei
    // exigem dono + em_andamento.

    // ---- V1–V3: profissional não grava campos de tracking via PATCH ----
    describe('V.a · travas de campo (denylist)', () => {
      let osId
      before(async () => {
        osId = (await createOS(s.adminTok, {
          cliente:       s.clienteId,
          servico:       s.servicoId,
          profissional:  s.profId,
          data_hora:     `${todayUTC()} 10:00:00.000Z`,
          status:        'em_andamento',
          valor_servico: 100,
        })).id
      })
      after(async () => { await deleteOS(s.adminTok, osId) })

      const campos = [
        ['prof_lat', -23.55],
        ['prof_lng', -46.63],
        ['prof_pos_em', '2026-01-01 10:00:00.000Z'],
        ['dest_lat', -23.5],
        ['dest_lng', -46.6],
        ['aviso_5min_em', '2026-01-01 10:00:00.000Z'],
        ['aviso_1min_em', '2026-01-01 10:00:00.000Z'],
        ['cheguei_em', '2026-01-01 10:00:00.000Z'],
      ]
      for (const [campo, valor] of campos) {
        it(`V.a · profissional NÃO grava ${campo} via PATCH → bloqueado`, async () => {
          const { status } = await PATCH(
            `/api/collections/ordens_servico/records/${osId}`,
            s.profTok,
            { [campo]: valor }
          )
          assert.notStrictEqual(status, 200, `${campo} deveria ser campo bloqueado para profissional`)
        })
      }
    })

    // ---- V4–V6: rota /posicao (dono + em_andamento) ----
    describe('V.b · rota /posicao', () => {
      let emAndId, atribId
      before(async () => {
        emAndId = (await createOS(s.adminTok, {
          cliente: s.clienteId, servico: s.servicoId, profissional: s.profId,
          data_hora: `${todayBRT()} 10:00:00.000Z`, status: 'em_andamento', valor_servico: 100,
        })).id
        atribId = (await createOS(s.adminTok, {
          cliente: s.clienteId, servico: s.servicoId, profissional: s.profId,
          data_hora: `${todayBRT()} 10:00:00.000Z`, status: 'atribuida', valor_servico: 100,
        })).id
      })
      after(async () => {
        await deleteOS(s.adminTok, emAndId)
        await deleteOS(s.adminTok, atribId)
      })

      it('V.b1 · outro profissional (lucas) não envia posição de OS de pedro → 403', async () => {
        const { status } = await POST(`/api/cleanos/os/${emAndId}/posicao`, s.prof2Tok, { lat: -23.55, lng: -46.63 })
        assert.strictEqual(status, 403, `Lucas deveria receber 403, got ${status}`)
      })

      it('V.b2 · posição em OS não em_andamento (atribuida) → bloqueado', async () => {
        const { status } = await POST(`/api/cleanos/os/${atribId}/posicao`, s.profTok, { lat: -23.55, lng: -46.63 })
        assert.notStrictEqual(status, 200, 'posição só deveria ser aceita em em_andamento')
      })

      it('V.b3 · coordenadas inválidas → 400', async () => {
        const { status } = await POST(`/api/cleanos/os/${emAndId}/posicao`, s.profTok, { lat: 999, lng: 'x' })
        assert.strictEqual(status, 400, `lat/lng inválidos deveriam retornar 400, got ${status}`)
      })

      it('V.b4 · dono envia posição em em_andamento → 200 {ok} sem vazar telefone; grava prof_lat', async () => {
        const { status, body } = await POST(`/api/cleanos/os/${emAndId}/posicao`, s.profTok, { lat: -23.55, lng: -46.63 })
        assert.strictEqual(status, 200, `posição do dono deveria retornar 200, got ${status}: ${JSON.stringify(body)}`)
        assert.strictEqual(body?.ok, true)
        const bodyStr = JSON.stringify(body || {})
        assert.ok(!bodyStr.includes('telefone') && !bodyStr.includes('phone'), 'Resposta de /posicao vazou dado sensível')
        // Confirma gravação server-side (admin lê a OS)
        const after = await GET(`/api/collections/ordens_servico/records/${emAndId}`, s.adminTok)
        assert.strictEqual(Number(after.body?.prof_lat), -23.55, 'prof_lat não foi gravado server-side')
        assert.ok(after.body?.prof_pos_em, 'prof_pos_em deveria estar preenchido')
      })
    })

    // ---- V7: coords somem ao concluir ----
    describe('V.c · coords efêmeras somem ao concluir', () => {
      let osId
      before(async () => {
        osId = (await createOS(s.adminTok, {
          cliente: s.clienteId, servico: s.servicoId, profissional: s.profId,
          data_hora: `${todayBRT()} 10:00:00.000Z`, status: 'em_andamento', valor_servico: 100,
        })).id
        // grava posição (server-side seta prof_lat/lng/pos_em)
        await POST(`/api/cleanos/os/${osId}/posicao`, s.profTok, { lat: -23.55, lng: -46.63 })
      })
      after(async () => { await deleteOS(s.adminTok, osId) })

      it('V.c1 · após concluir, prof_lat/prof_lng/dest_lat/dest_lng ficam vazios', async () => {
        // sanity: antes de concluir a posição está lá
        const before = await GET(`/api/collections/ordens_servico/records/${osId}`, s.adminTok)
        assert.strictEqual(Number(before.body?.prof_lat), -23.55, 'pré-condição: prof_lat gravado')

        const { status } = await PATCH(
          `/api/collections/ordens_servico/records/${osId}`,
          s.profTok,
          { valor_pago: 100, forma_pagamento: 'pix_maquininha', status: 'concluida' }
        )
        assert.strictEqual(status, 200, 'concluir com pagamento deveria funcionar')

        const after = await GET(`/api/collections/ordens_servico/records/${osId}`, s.adminTok)
        const empty = v => v == null || v === '' || Number(v) === 0
        assert.ok(empty(after.body?.prof_lat), `prof_lat deveria sumir, got ${after.body?.prof_lat}`)
        assert.ok(empty(after.body?.prof_lng), `prof_lng deveria sumir, got ${after.body?.prof_lng}`)
        assert.ok(empty(after.body?.dest_lat), `dest_lat deveria sumir, got ${after.body?.dest_lat}`)
        assert.ok(empty(after.body?.dest_lng), `dest_lng deveria sumir, got ${after.body?.dest_lng}`)
      })
    })

    // ---- V8–V9: rota /cheguei (dono + em_andamento) ----
    describe('V.d · rota /cheguei', () => {
      let osId
      before(async () => {
        osId = (await createOS(s.adminTok, {
          cliente: s.clienteId, servico: s.servicoId, profissional: s.profId,
          data_hora: `${todayBRT()} 10:00:00.000Z`, status: 'em_andamento', valor_servico: 100,
        })).id
      })
      after(async () => { await deleteOS(s.adminTok, osId) })

      it('V.d1 · outro profissional (lucas) não registra chegada de OS de pedro → 403', async () => {
        const { status } = await POST(`/api/cleanos/os/${osId}/cheguei`, s.prof2Tok)
        assert.strictEqual(status, 403, `Lucas deveria receber 403, got ${status}`)
      })

      it('V.d2 · dono registra chegada → 200 sem vazar telefone; grava cheguei_em', async () => {
        const { status, body } = await POST(`/api/cleanos/os/${osId}/cheguei`, s.profTok)
        assert.strictEqual(status, 200, `chegada do dono deveria retornar 200, got ${status}: ${JSON.stringify(body)}`)
        assert.strictEqual(body?.ok, true)
        const bodyStr = JSON.stringify(body || {})
        assert.ok(!bodyStr.includes('telefone') && !bodyStr.includes('phone'), 'Resposta de /cheguei vazou dado sensível')
        const after = await GET(`/api/collections/ordens_servico/records/${osId}`, s.adminTok)
        assert.ok(after.body?.cheguei_em, 'cheguei_em deveria estar preenchido após a rota')
      })
    })

    // ---- V10–V12: push_tokens isolado + register/upsert ----
    describe('V.e · push/register e isolamento de push_tokens', () => {
      after(async () => {
        // Limpa quaisquer tokens criados pelos testes (admin)
        for (const uid of [s.profId, s.prof2Id]) {
          const r = await GET(`/api/collections/push_tokens/records?perPage=200&filter=(usuario='${uid}')`, s.adminTok)
          for (const rec of (r.body?.items ?? [])) {
            await DELETE(`/api/collections/push_tokens/records/${rec.id}`, s.adminTok)
          }
        }
      })

      it('V.e1 · profissional registra token → 200 {ok}', async () => {
        const { status, body } = await POST('/api/cleanos/push/register', s.profTok, {
          token: 'tok-pedro-abc123', plataforma: 'android',
        })
        assert.strictEqual(status, 200, `register deveria retornar 200, got ${status}: ${JSON.stringify(body)}`)
        assert.strictEqual(body?.ok, true)
      })

      it('V.e2 · pedro vê só o próprio token; lucas NÃO vê o de pedro (isolado)', async () => {
        // pedro registra o dele (idempotente com V.e1) e lucas registra o dele
        await POST('/api/cleanos/push/register', s.profTok,  { token: 'tok-pedro-abc123', plataforma: 'android' })
        await POST('/api/cleanos/push/register', s.prof2Tok, { token: 'tok-lucas-zzz999', plataforma: 'android' })

        const pedro = await GET('/api/collections/push_tokens/records?perPage=200', s.profTok)
        const alheios = (pedro.body?.items ?? []).filter(t => t.usuario !== s.profId)
        assert.strictEqual(alheios.length, 0, 'Pedro não deveria enxergar tokens de outro profissional')

        const lucas = await GET('/api/collections/push_tokens/records?perPage=200', s.prof2Tok)
        const dePedro = (lucas.body?.items ?? []).filter(t => t.usuario === s.profId || t.token === 'tok-pedro-abc123')
        assert.strictEqual(dePedro.length, 0, 'Lucas não deveria enxergar o token de Pedro')
      })

      it('V.e3 · register é upsert por (usuario, plataforma) — não duplica', async () => {
        await POST('/api/cleanos/push/register', s.profTok, { token: 'tok-pedro-v1', plataforma: 'android' })
        await POST('/api/cleanos/push/register', s.profTok, { token: 'tok-pedro-v2', plataforma: 'android' })
        const r = await GET(
          `/api/collections/push_tokens/records?filter=(usuario='${s.profId}' %26%26 plataforma='android')`,
          s.adminTok
        )
        assert.strictEqual((r.body?.items ?? []).length, 1, 'Deveria haver exatamente 1 token android para pedro (upsert)')
        assert.strictEqual(r.body.items[0].token, 'tok-pedro-v2', 'O token deveria ter sido atualizado para o mais recente')
      })

      it('V.e4 · register sem auth → 401', async () => {
        const { status } = await POST('/api/cleanos/push/register', null, { token: 'x', plataforma: 'android' })
        assert.strictEqual(status, 401, `register sem auth deveria retornar 401, got ${status}`)
      })
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('W · Dedupe idempotente de evidências (os_evidencias)', () => {
    // Contrato com o app: o multipart de criação de os_evidencias inclui
    // `idempotency_key` (uuid, string). 2 creates com a MESMA (os, idempotency_key)
    // → 1 registro (retry sequencial devolve o existente com o MESMO id); chaves
    // diferentes → 2 registros; SEM chave → comportamento atual inalterado.
    let osId
    const keyA = 'idem-key-aaa-111'
    const keyB = 'idem-key-bbb-222'

    before(async () => {
      osId = (await createOS(s.adminTok, {
        cliente: s.clienteId, servico: s.servicoId, profissional: s.profId,
        data_hora: `${todayBRT()} 10:00:00.000Z`, status: 'em_andamento', valor_servico: 100,
      })).id
    })
    after(async () => {
      const r = await GET(`/api/collections/os_evidencias/records?perPage=200&filter=(os='${osId}')`, s.adminTok)
      for (const rec of (r.body?.items ?? [])) {
        await DELETE(`/api/collections/os_evidencias/records/${rec.id}`, s.adminTok)
      }
      await deleteOS(s.adminTok, osId)
    })

    const createEvid = (tok, fields) => POST('/api/collections/os_evidencias/records', tok, fields)

    it('W1 · 2 creates com a MESMA (os, idempotency_key) → 1 registro (mesmo id)', async () => {
      const r1 = await createEvid(s.profTok, { os: osId, fase: 'antes', legenda: 'a', idempotency_key: keyA })
      assert.strictEqual(r1.status, 200, `1º create falhou: ${JSON.stringify(r1.body)}`)
      const id1 = r1.body?.id
      assert.ok(id1, 'primeiro create deveria retornar id')

      const r2 = await createEvid(s.profTok, { os: osId, fase: 'antes', legenda: 'a', idempotency_key: keyA })
      assert.strictEqual(r2.status, 200, `retry idempotente deveria dar 200: ${JSON.stringify(r2.body)}`)
      assert.strictEqual(r2.body?.id, id1, 'retry com a mesma chave deveria devolver o MESMO registro')

      const q = await GET(
        `/api/collections/os_evidencias/records?perPage=200&filter=(os='${osId}' %26%26 idempotency_key='${keyA}')`,
        s.adminTok
      )
      assert.strictEqual((q.body?.items ?? []).length, 1, 'deveria existir exatamente 1 evidência para (os, keyA)')
    })

    it('W2 · chave DIFERENTE → novo registro (2 no total)', async () => {
      const rB = await createEvid(s.profTok, { os: osId, fase: 'depois', legenda: 'b', idempotency_key: keyB })
      assert.strictEqual(rB.status, 200, `create com chave nova falhou: ${JSON.stringify(rB.body)}`)

      const q = await GET(`/api/collections/os_evidencias/records?perPage=200&filter=(os='${osId}')`, s.adminTok)
      const keys = new Set((q.body?.items ?? []).map(x => x.idempotency_key))
      assert.ok(keys.has(keyA) && keys.has(keyB), 'deveria haver evidências com keyA e keyB')
      assert.strictEqual((q.body?.items ?? []).length, 2, 'chaves diferentes deveriam gerar 2 registros')
    })

    it('W3 · SEM idempotency_key → comportamento inalterado (não deduz)', async () => {
      const n1 = await createEvid(s.profTok, { os: osId, fase: 'durante', legenda: 'sem-chave' })
      const n2 = await createEvid(s.profTok, { os: osId, fase: 'durante', legenda: 'sem-chave' })
      assert.strictEqual(n1.status, 200, `create sem chave #1 falhou: ${JSON.stringify(n1.body)}`)
      assert.strictEqual(n2.status, 200, `create sem chave #2 falhou: ${JSON.stringify(n2.body)}`)
      assert.notStrictEqual(n1.body?.id, n2.body?.id, 'sem chave, cada create deve ser um registro distinto')
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('X · Gate de checklist obrigatório no servidor (P1)', () => {
    // os_logic.js:411-420 — OS em_andamento com item obrigatório PENDENTE +
    // pagamento OK: PATCH status=concluida deve FALHAR; marcar o item done → 200.
    let osId
    before(async () => {
      osId = (await createOS(s.adminTok, {
        cliente: s.clienteId, servico: s.servicoId, profissional: s.profId,
        data_hora: `${todayBRT()} 10:00:00.000Z`, status: 'em_andamento', valor_servico: 100,
        checklist_exec: [
          { id: 'ckx1', titulo: 'Obrigatório', status: 'pendente', obrigatorio: true },
          { id: 'ckx2', titulo: 'Opcional',    status: 'pendente', obrigatorio: false },
        ],
      })).id
    })
    after(async () => { await deleteOS(s.adminTok, osId) })

    it('X1 · concluir com obrigatório PENDENTE (pagamento OK) → bloqueado (!=200)', async () => {
      const { status, body } = await PATCH(
        `/api/collections/ordens_servico/records/${osId}`,
        s.profTok,
        { valor_pago: 100, forma_pagamento: 'pix_maquininha', status: 'concluida' }
      )
      assert.notStrictEqual(status, 200, `Deveria bloquear conclusão com obrigatório pendente: ${JSON.stringify(body)}`)
    })

    it('X2 · marcar o obrigatório como concluido → conclui (200)', async () => {
      const { status, body } = await PATCH(
        `/api/collections/ordens_servico/records/${osId}`,
        s.profTok,
        {
          checklist_exec: [
            { id: 'ckx1', titulo: 'Obrigatório', status: 'concluido', obrigatorio: true },
            { id: 'ckx2', titulo: 'Opcional',    status: 'pendente',  obrigatorio: false },
          ],
          valor_pago: 100, forma_pagamento: 'pix_maquininha', status: 'concluida',
        }
      )
      assert.strictEqual(status, 200, `Deveria concluir com obrigatório done: ${JSON.stringify(body)}`)
      assert.strictEqual(body?.status, 'concluida')
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('Y · /posicao — geocode do destino na 1ª posição (P2)', () => {
    // Sem GOOGLE_MAPS_API_KEY (padrão do harness): dest fica vazio (degradação
    // graciosa). Com a chave: dest é uma coordenada válida. A asserção é robusta
    // aos dois cenários — nunca aceita lixo. Também confirma que a rota não vaza.
    let osId
    before(async () => {
      osId = (await createOS(s.adminTok, {
        cliente: s.clienteId, servico: s.servicoId, profissional: s.profId,
        data_hora: `${todayBRT()} 10:00:00.000Z`, status: 'em_andamento', valor_servico: 100,
      })).id
    })
    after(async () => { await deleteOS(s.adminTok, osId) })

    it('Y1 · 1ª posição → 200 sem vazar; dest vazio (sem chave) OU coordenada válida (com chave)', async () => {
      const { status, body } = await POST(`/api/cleanos/os/${osId}/posicao`, s.profTok, { lat: -23.55, lng: -46.63 })
      assert.strictEqual(status, 200, `posição deveria 200: ${JSON.stringify(body)}`)
      const bodyStr = JSON.stringify(body || {})
      assert.ok(!bodyStr.includes('telefone') && !bodyStr.includes('phone'), 'Resposta de /posicao vazou dado sensível')

      const after = await GET(`/api/collections/ordens_servico/records/${osId}`, s.adminTok)
      const okCoord = (v, lo, hi) => {
        if (v == null || v === '' || Number(v) === 0) return true // sem chave → vazio
        const n = Number(v)
        return Number.isFinite(n) && n >= lo && n <= hi                // com chave → válido
      }
      assert.ok(okCoord(after.body?.dest_lat, -90, 90),  `dest_lat inválido: ${after.body?.dest_lat}`)
      assert.ok(okCoord(after.body?.dest_lng, -180, 180), `dest_lng inválido: ${after.body?.dest_lng}`)
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  // AA · Integridade de saldo server-side (fin_contas.saldo_atual)
  //
  // O saldo passa a ser mutado SÓ pelo servidor, por incremento atômico em SQL:
  //   - hook de modelo em fin_lancamentos (create/update/delete) — fonte única;
  //   - hook OS→Financeiro apenas CRIA o lançamento `via_os` (o saldo é creditado
  //     pelo hook de fin_lancamentos — reconciliação, sem contar em dobro);
  //   - guard de request em fin_contas ignora escrita direta de saldo_atual;
  //   - endpoints /fin/conta/{id}/ajuste e /fin/transferencia (admin/gerente),
  //     transacionais e atômicos.
  // ────────────────────────────────────────────────────────────────────────
  describe('AA · Integridade de saldo server-side (financeiro)', () => {
    const CX = 'fincaixa0000001'   // Caixa físico
    const NU = 'finnubank000001'   // Nubank
    const near = (a, b, eps = 0.005) => Math.abs(Number(a) - Number(b)) < eps

    let receitaCat, despesaCat
    const created = [] // ids de lançamentos a limpar

    before(async () => {
      const rc = await GET(`/api/collections/fin_categorias/records?filter=${encodeURIComponent("tipo='receita'")}&perPage=1`, s.adminTok)
      receitaCat = rc.body.items[0].id
      const dc = await GET(`/api/collections/fin_categorias/records?filter=${encodeURIComponent("tipo='despesa'")}&perPage=1`, s.adminTok)
      despesaCat = dc.body.items[0].id
    })

    after(async () => {
      for (const id of created) {
        await DELETE(`/api/collections/fin_lancamentos/records/${id}`, s.adminTok)
      }
    })

    const saldo = async (id) => Number(
      (await GET(`/api/collections/fin_contas/records/${id}`, s.adminTok)).body.saldo_atual
    )
    const mkLanc = async (over = {}) => {
      const r = await POST('/api/collections/fin_lancamentos/records', s.adminTok, {
        tipo: 'receita', descricao: 'AA teste', categoria_id: receitaCat, valor: 100,
        conta_id: CX, data: '2026-07-01 10:00:00.000Z', status: 'pago',
        recorrencia: 'unica', origem: 'manual', ...over,
      })
      if (r.status === 200 && r.body?.id) created.push(r.body.id)
      return r
    }

    it('AA1 · CREATE de lançamento PAGO credita/debita o saldo pelo servidor', async () => {
      const s0 = await saldo(CX)
      const r = await mkLanc({ valor: 123.45 })
      assert.strictEqual(r.status, 200, `create falhou: ${JSON.stringify(r.body)}`)
      const s1 = await saldo(CX)
      assert.ok(near(s1, s0 + 123.45), `esperado ${s0 + 123.45}, veio ${s1}`)
    })

    it('AA2 · lançamento PENDENTE não mexe no saldo', async () => {
      const s0 = await saldo(CX)
      const r = await mkLanc({ tipo: 'despesa', categoria_id: despesaCat, valor: 50, status: 'pendente' })
      assert.strictEqual(r.status, 200)
      const s1 = await saldo(CX)
      assert.ok(near(s1, s0), `pendente mexeu no saldo: ${s0} → ${s1}`)
    })

    it('AA3 · UPDATE pendente→pago aplica o efeito (despesa)', async () => {
      const r = await mkLanc({ tipo: 'despesa', categoria_id: despesaCat, valor: 30, status: 'pendente' })
      const s0 = await saldo(CX)
      await PATCH(`/api/collections/fin_lancamentos/records/${r.body.id}`, s.adminTok, { status: 'pago' })
      const s1 = await saldo(CX)
      assert.ok(near(s1, s0 - 30), `esperado ${s0 - 30}, veio ${s1}`)
    })

    it('AA4 · UPDATE com troca de conta estorna na antiga e aplica na nova', async () => {
      const r = await mkLanc({ valor: 80, conta_id: CX })
      const cx0 = await saldo(CX), nu0 = await saldo(NU)
      await PATCH(`/api/collections/fin_lancamentos/records/${r.body.id}`, s.adminTok, { conta_id: NU })
      const cx1 = await saldo(CX), nu1 = await saldo(NU)
      assert.ok(near(cx1, cx0 - 80), `CX esperado ${cx0 - 80}, veio ${cx1}`)
      assert.ok(near(nu1, nu0 + 80), `NU esperado ${nu0 + 80}, veio ${nu1}`)
    })

    it('AA5 · DELETE de lançamento pago estorna o efeito', async () => {
      const r = await mkLanc({ valor: 44 })
      const s0 = await saldo(CX)
      const del = await DELETE(`/api/collections/fin_lancamentos/records/${r.body.id}`, s.adminTok)
      assert.strictEqual(del.status, 204)
      const s1 = await saldo(CX)
      assert.ok(near(s1, s0 - 44), `esperado ${s0 - 44}, veio ${s1}`)
    })

    it('AA6 · OS concluída credita o saldo EXATAMENTE uma vez (reconciliação, sem dobro)', async () => {
      const padrao = (await GET(`/api/collections/fin_contas/records?filter=${encodeURIComponent('padrao=true')}`, s.adminTok)).body.items[0]
      const s0 = await saldo(padrao.id)
      const os = await createOS(s.adminTok, {
        cliente: s.clienteId, servico: s.servicoId, data_hora: '2026-07-01 10:00:00.000Z',
        status: 'concluida', valor_servico: 250, valor_pago: 250, forma_pagamento: 'pix_maquininha',
      })
      const s1 = await saldo(padrao.id)
      assert.ok(near(s1, s0 + 250), `crédito != 250 (dobro?): ${s0} → ${s1}`)

      const lancs = await GET(`/api/collections/fin_lancamentos/records?filter=${encodeURIComponent(`os_id='${os.id}' && origem='via_os'`)}`, s.adminTok)
      assert.strictEqual(lancs.body.totalItems, 1, `esperado 1 lançamento via_os, veio ${lancs.body.totalItems}`)

      // re-save da OS concluída (sem transição) NÃO credita de novo
      await PATCH(`/api/collections/ordens_servico/records/${os.id}`, s.adminTok, { observacoes_prof: 'toque' })
      const s2 = await saldo(padrao.id)
      assert.ok(near(s2, s1), `re-save duplicou o crédito: ${s1} → ${s2}`)

      // limpa o lançamento e a OS
      await DELETE(`/api/collections/fin_lancamentos/records/${lancs.body.items[0].id}`, s.adminTok)
      await deleteOS(s.adminTok, os.id)
    })

    it('AA7 · cliente NÃO consegue setar saldo_atual direto (ignorado); demais campos ok', async () => {
      const s0 = await saldo(CX)
      const r = await PATCH(`/api/collections/fin_contas/records/${CX}`, s.adminTok, { saldo_atual: 999999, cor: '#AA7AA7' })
      const s1 = await saldo(CX)
      assert.ok(near(s1, s0), `saldo_atual foi setado pelo cliente: ${s0} → ${s1}`)
      assert.strictEqual(r.body?.cor, '#AA7AA7', 'CRUD de outros campos da conta quebrou')
      // restaura a cor original (não polui o seed visualmente)
      await PATCH(`/api/collections/fin_contas/records/${CX}`, s.adminTok, { cor: '#64748B' })
    })

    it('AA8 · POST /fin/conta/{id}/ajuste {delta} é transacional e atômico', async () => {
      const s0 = await saldo(CX)
      const r = await POST(`/api/cleanos/fin/conta/${CX}/ajuste`, s.adminTok, { delta: 55.5 })
      assert.strictEqual(r.status, 200, `ajuste falhou: ${JSON.stringify(r.body)}`)
      const s1 = await saldo(CX)
      assert.ok(near(s1, s0 + 55.5), `esperado ${s0 + 55.5}, veio ${s1}`)
      assert.ok(near(r.body.saldo_atual, s1), 'resposta do ajuste != saldo persistido')
      // volta ao estado anterior
      await POST(`/api/cleanos/fin/conta/${CX}/ajuste`, s.adminTok, { delta: -55.5 })
    })

    it('AA9 · POST /fin/conta/{id}/ajuste {novoSaldo} converte para delta na transação', async () => {
      const s0 = await saldo(CX)
      const r = await POST(`/api/cleanos/fin/conta/${CX}/ajuste`, s.adminTok, { novoSaldo: s0 + 10 })
      assert.strictEqual(r.status, 200)
      const s1 = await saldo(CX)
      assert.ok(near(s1, s0 + 10), `esperado ${s0 + 10}, veio ${s1}`)
      await POST(`/api/cleanos/fin/conta/${CX}/ajuste`, s.adminTok, { novoSaldo: s0 })
    })

    it('AA10 · POST /fin/transferencia debita origem e credita destino na mesma transação', async () => {
      const cx0 = await saldo(CX), nu0 = await saldo(NU)
      const r = await POST('/api/cleanos/fin/transferencia', s.adminTok, { from: CX, to: NU, valor: 200 })
      assert.strictEqual(r.status, 200, `transferência falhou: ${JSON.stringify(r.body)}`)
      const cx1 = await saldo(CX), nu1 = await saldo(NU)
      assert.ok(near(cx1, cx0 - 200), `origem esperada ${cx0 - 200}, veio ${cx1}`)
      assert.ok(near(nu1, nu0 + 200), `destino esperado ${nu0 + 200}, veio ${nu1}`)
      // estorna a transferência
      await POST('/api/cleanos/fin/transferencia', s.adminTok, { from: NU, to: CX, valor: 200 })
    })

    it('AA11 · transferência que falha (destino inexistente) NÃO debita a origem', async () => {
      const cx0 = await saldo(CX)
      const r = await POST('/api/cleanos/fin/transferencia', s.adminTok, { from: CX, to: 'naoexiste00000', valor: 77 })
      assert.ok(r.status >= 400, `esperado erro, veio ${r.status}`)
      const cx1 = await saldo(CX)
      assert.ok(near(cx1, cx0), `origem foi debitada numa transferência falha: ${cx0} → ${cx1}`)
    })

    it('AA12 · profissional é BLOQUEADO nos endpoints de saldo (403)', async () => {
      const a = await POST(`/api/cleanos/fin/conta/${CX}/ajuste`, s.profTok, { delta: 1 })
      assert.ok(a.status === 403 || a.status === 401, `ajuste: esperado 403/401, veio ${a.status}`)
      const t = await POST('/api/cleanos/fin/transferencia', s.profTok, { from: CX, to: NU, valor: 1 })
      assert.ok(t.status === 403 || t.status === 401, `transferência: esperado 403/401, veio ${t.status}`)
    })

    it('AA13 · concorrência: N ajustes atômicos concorrentes somam certo (sem lost-update)', async () => {
      const base = await saldo(NU)
      const N = 25
      await Promise.all(Array.from({ length: N }, () =>
        POST(`/api/cleanos/fin/conta/${NU}/ajuste`, s.adminTok, { delta: 1 })
      ))
      const after = await saldo(NU)
      assert.ok(near(after, base + N), `lost-update! esperado ${base + N}, veio ${after}`)
      await POST(`/api/cleanos/fin/conta/${NU}/ajuste`, s.adminTok, { delta: -N })
    })
  })

  // ────────────────────────────────────────────────────────────────────────
  describe('Z · Casos que exigem mock de UAZAPI+Google Maps (documentados/pendentes)', () => {
    // O harness de integração bate num PocketBase real SEM instância UAZAPI
    // conectada e SEM GOOGLE_MAPS_API_KEY. Os casos abaixo dependem de simular
    // ambos (WhatsApp `connected` + geocode/ETA determinísticos). Ficam como
    // `skip` com o caso pretendido registrado — o risco é conhecido e rastreado.
    // Para exercê-los: subir uma instância isolada com uazapi.js/maps.js stub.

    it('Z1 · /a-caminho reseta aviso_5min_em/1min_em/cheguei_em da nova viagem',
      { skip: 'requer UAZAPI connected (rota retorna 409 sem instância)' }, () => {})

    it('Z2 · /a-caminho geocodifica o destino quando dest_lat/lng ainda vazios',
      { skip: 'requer GOOGLE_MAPS_API_KEY + UAZAPI connected' }, () => {})

    it('Z3 · cron trackingAvisos: ETA cai direto para ≤1min sem ter mandado a de 5 → manda só a de 1 e carimba ambas',
      { skip: 'requer mock de maps.etaMinutes + uazapi; cron é time-triggered' }, () => {})

    it('Z4 · cron trackingAvisos: pula quando has5 && has1 (ambos já enviados)',
      { skip: 'requer mock de maps.etaMinutes + uazapi; cron é time-triggered' }, () => {})

    it('Z5 · cron trackingAvisos: posição stale (> POS_FRESH_MS) → não envia',
      { skip: 'requer mock de maps.etaMinutes + uazapi; cron é time-triggered' }, () => {})

    it('Z6 · cron trackingAvisos: viagem > MAX_TRIP_MS → não envia',
      { skip: 'requer mock de maps.etaMinutes + uazapi; cron é time-triggered' }, () => {})

    it('Z7 · cron trackingAvisos: coord 0/NaN → pula a OS',
      { skip: 'requer mock de maps.etaMinutes + uazapi; cron é time-triggered' }, () => {})

    it('Z8 · cron trackingAvisos: WhatsApp != connected → pula o loop de ETA (não queima quota Maps)',
      { skip: 'requer mock de uazapi.instanceStatus + contador de chamadas maps.etaMinutes' }, () => {})
  })
})
