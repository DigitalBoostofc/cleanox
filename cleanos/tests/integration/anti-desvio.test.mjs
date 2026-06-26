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
