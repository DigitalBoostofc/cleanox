/**
 * financeiro/store.ts — Camada de dados do módulo Financeiro (PocketBase).
 *
 * O CRUD conversa com pb.collection(FIN_COLLECTIONS.*). Os mapeadores
 * pbToConta/pbToCategoria/pbToLancamento/pbToLimite traduzem o registro PB
 * (snake_case) para o tipo de domínio camelCase. As derivações puras (resumo do
 * período, saldo geral, agrupamento por data, contas a pagar/receber, gasto por
 * categoria, progresso de limite) recebem dados por parâmetro e NÃO tocam a rede.
 */

import { ClientResponseError } from 'pocketbase'
import { pb } from '../pb'
import { FIN_COLLECTIONS } from '../collections'
import type { FinContaPB, FinCategoriaPB, FinLancamentoPB, FinLimitePB } from '../collections'
import { signedValue } from './labels'
import type {
  Anexo,
  Categoria,
  CategoriaInput,
  Conta,
  ContaInput,
  ContaPendente,
  GrupoPorData,
  Lancamento,
  LancamentoInput,
  LimiteGasto,
  LimiteInput,
  Periodo,
  ProgressoLimite,
  ResumoPeriodo,
} from './types'

/* ============================================================
 * Utilidades internas (puras)
 * ============================================================ */

/** Só a parte 'YYYY-MM-DD' de uma string ISO (datetime ou date). */
function dateOnly(iso: string): string {
  return iso.slice(0, 10)
}

/**
 * Normaliza um campo JSON do PB em array. O SDK normalmente já entrega o valor
 * parseado (array), mas tratamos string defensivamente.
 */
function asArray<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[]
  if (typeof value === 'string') {
    const trimmed = value.trim()
    if (trimmed) {
      try {
        const parsed: unknown = JSON.parse(trimmed)
        if (Array.isArray(parsed)) return parsed as T[]
      } catch {
        /* conteúdo inesperado → array vazio */
      }
    }
  }
  return []
}

/* ============================================================
 * Mapeadores PB (snake_case) → domínio (camelCase)
 * ============================================================ */

function pbToConta(rec: FinContaPB): Conta {
  return {
    id: rec.id,
    created: rec.created,
    updated: rec.updated,
    nome: rec.nome,
    tipo: rec.tipo,
    saldoInicial: rec.saldo_inicial,
    saldoAtual: rec.saldo_atual,
    ativo: rec.ativo,
    cor: rec.cor,
    icone: rec.icone,
  }
}

function pbToCategoria(rec: FinCategoriaPB): Categoria {
  return {
    id: rec.id,
    created: rec.created,
    updated: rec.updated,
    nome: rec.nome,
    tipo: rec.tipo,
    icone: rec.icone ?? '',
    cor: rec.cor ?? '',
    parentId: rec.parent_id || undefined,
    arquivada: rec.arquivada,
  }
}

function pbToLancamento(rec: FinLancamentoPB): Lancamento {
  return {
    id: rec.id,
    created: rec.created,
    updated: rec.updated,
    tipo: rec.tipo,
    descricao: rec.descricao,
    categoriaId: rec.categoria_id,
    subcategoriaId: rec.subcategoria_id || undefined,
    valor: rec.valor,
    contaId: rec.conta_id,
    data: rec.data,
    vencimento: rec.vencimento || undefined,
    status: rec.status,
    recorrencia: rec.recorrencia,
    parcelaAtual: rec.parcela_atual || undefined,
    parcelasTotal: rec.parcelas_total || undefined,
    origem: rec.origem,
    osId: rec.os_id || undefined,
    osNumero: rec.os_numero || undefined,
    clienteNome: rec.cliente_nome || undefined,
    servicoNome: rec.servico_nome || undefined,
    formaPagamento: rec.forma_pagamento || undefined,
    observacao: rec.observacao || undefined,
    tags: asArray<string>(rec.tags),
    anexos: asArray<Anexo>(rec.anexos),
  }
}

function pbToLimite(rec: FinLimitePB): LimiteGasto {
  return {
    id: rec.id,
    created: rec.created,
    updated: rec.updated,
    categoriaId: rec.categoria_id,
    limite: rec.limite,
  }
}

/* ============================================================
 * Conversores domínio → payload PB (suporte a patches parciais)
 * ============================================================ */

function contaToPB(input: Partial<ContaInput>): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  const has = (k: keyof ContaInput) => Object.prototype.hasOwnProperty.call(input, k)
  if (has('nome'))         out.nome          = input.nome
  if (has('tipo'))         out.tipo          = input.tipo
  if (has('saldoInicial')) out.saldo_inicial = input.saldoInicial
  if (has('saldoAtual'))   out.saldo_atual   = input.saldoAtual
  if (has('ativo'))        out.ativo         = input.ativo
  if (has('cor'))          out.cor           = input.cor ?? null
  if (has('icone'))        out.icone         = input.icone ?? null
  return out
}

function categoriaToPB(input: Partial<CategoriaInput>): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  const has = (k: keyof CategoriaInput) => Object.prototype.hasOwnProperty.call(input, k)
  if (has('nome'))      out.nome      = input.nome
  if (has('tipo'))      out.tipo      = input.tipo
  if (has('icone'))     out.icone     = input.icone ?? null
  if (has('cor'))       out.cor       = input.cor ?? null
  if (has('parentId'))  out.parent_id = input.parentId ?? null
  if (has('arquivada')) out.arquivada = input.arquivada
  return out
}

function lancamentoToPB(input: Partial<LancamentoInput>): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  const has = (k: keyof LancamentoInput) => Object.prototype.hasOwnProperty.call(input, k)
  if (has('tipo'))           out.tipo            = input.tipo
  if (has('descricao'))      out.descricao        = input.descricao
  if (has('categoriaId'))    out.categoria_id     = input.categoriaId
  if (has('subcategoriaId')) out.subcategoria_id  = input.subcategoriaId ?? null
  if (has('valor'))          out.valor            = input.valor
  if (has('contaId'))        out.conta_id         = input.contaId
  if (has('data'))           out.data             = input.data
  if (has('vencimento'))     out.vencimento       = input.vencimento ?? null
  if (has('status'))         out.status           = input.status
  if (has('recorrencia'))    out.recorrencia      = input.recorrencia
  if (has('parcelaAtual'))   out.parcela_atual    = input.parcelaAtual ?? null
  if (has('parcelasTotal'))  out.parcelas_total   = input.parcelasTotal ?? null
  if (has('origem'))         out.origem           = input.origem
  if (has('osId'))           out.os_id            = input.osId ?? null
  if (has('osNumero'))       out.os_numero        = input.osNumero ?? null
  if (has('clienteNome'))    out.cliente_nome     = input.clienteNome ?? null
  if (has('servicoNome'))    out.servico_nome     = input.servicoNome ?? null
  if (has('formaPagamento')) out.forma_pagamento  = input.formaPagamento ?? null
  if (has('observacao'))     out.observacao       = input.observacao ?? null
  if (has('tags'))           out.tags             = input.tags ?? []
  if (has('anexos'))         out.anexos           = input.anexos ?? []
  return out
}

function limiteToPB(input: Partial<LimiteInput>): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  const has = (k: keyof LimiteInput) => Object.prototype.hasOwnProperty.call(input, k)
  if (has('categoriaId')) out.categoria_id = input.categoriaId
  if (has('limite'))      out.limite       = input.limite
  return out
}

/* ============================================================
 * Helpers internos de saldo (modelo incremental)
 * ============================================================ */

/**
 * Efeito de um lançamento no saldo_atual da conta: +valor para receita paga, −valor para
 * despesa paga. Não pagos (pendente/previsto/em_atraso) têm efeito zero.
 * MODELO INCREMENTAL: coexiste com transferências (ContasCarteiras.updateConta) que também
 * ajustam saldo_atual diretamente. Nunca recompute do zero — isso apagaria o efeito das transferências.
 */
function efeitoNoSaldo(tipo: Lancamento['tipo'], valor: number, status: Lancamento['status']): number {
  if (status !== 'pago') return 0
  return tipo === 'receita' ? valor : -valor
}

/**
 * Aplica `delta` ao saldo_atual de uma conta de forma ATÔMICA no SERVIDOR (F-220):
 * chama a rota `POST /api/cleanos/contas/ajustar`, que dentro de uma transação DB
 * lê o saldo FRESCO e soma o delta — sem janela entre ler e escrever, então não
 * clobbera o incremento concorrente do hook OS→Financeiro (lost-update). O painel
 * nunca mais grava saldo_atual absoluto a partir de estado de UI stale. Best-effort:
 * ignora 404 (conta inexistente) para não quebrar reverts de lançamento órfão.
 */
export async function ajustarSaldoConta(contaId: string, delta: number): Promise<void> {
  if (delta === 0) return
  try {
    await pb.send('/api/cleanos/contas/ajustar', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contaId, delta }),
    })
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return // conta ausente → no-op
    throw err
  }
}

/**
 * Transferência entre contas ATÔMICA no SERVIDOR (F-220): chama a rota
 * `POST /api/cleanos/contas/transferir`, que debita −valor na origem e credita
 * +valor no destino na MESMA transação DB (all-or-nothing), lendo os dois saldos
 * frescos dentro dela — sem janela de lost-update e sem rollback manual no cliente.
 */
export async function transferirSaldo(fromId: string, toId: string, valor: number): Promise<void> {
  await pb.send('/api/cleanos/contas/transferir', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ de: fromId, para: toId, valor }),
  })
}

/* ============================================================
 * Lançamentos
 * ============================================================ */

export async function listLancamentos(): Promise<Lancamento[]> {
  const rows = await pb
    .collection(FIN_COLLECTIONS.LANCAMENTOS)
    .getFullList<FinLancamentoPB>({ sort: '-data' })
  return rows.map(pbToLancamento)
}

export async function getLancamento(id: string): Promise<Lancamento | undefined> {
  try {
    const rec = await pb.collection(FIN_COLLECTIONS.LANCAMENTOS).getOne<FinLancamentoPB>(id)
    return pbToLancamento(rec)
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return undefined
    throw err
  }
}

export async function createLancamento(input: LancamentoInput): Promise<Lancamento> {
  const rec = await pb
    .collection(FIN_COLLECTIONS.LANCAMENTOS)
    .create<FinLancamentoPB>(lancamentoToPB(input))
  const lanc = pbToLancamento(rec)
  await ajustarSaldoConta(lanc.contaId, efeitoNoSaldo(lanc.tipo, lanc.valor, lanc.status))
  return lanc
}

export async function updateLancamento(
  id: string,
  patch: Partial<LancamentoInput>,
): Promise<Lancamento> {
  const old = await getLancamento(id)
  const rec = await pb
    .collection(FIN_COLLECTIONS.LANCAMENTOS)
    .update<FinLancamentoPB>(id, lancamentoToPB(patch))
  const updated = pbToLancamento(rec)
  if (old) {
    const oldEfeito = efeitoNoSaldo(old.tipo, old.valor, old.status)
    const newEfeito = efeitoNoSaldo(updated.tipo, updated.valor, updated.status)
    if (old.contaId === updated.contaId) {
      await ajustarSaldoConta(old.contaId, newEfeito - oldEfeito)
    } else {
      await ajustarSaldoConta(old.contaId, -oldEfeito)
      await ajustarSaldoConta(updated.contaId, newEfeito)
    }
  }
  return updated
}

export async function deleteLancamento(id: string): Promise<boolean> {
  try {
    const lanc = await getLancamento(id)
    await pb.collection(FIN_COLLECTIONS.LANCAMENTOS).delete(id)
    if (lanc) {
      await ajustarSaldoConta(lanc.contaId, -efeitoNoSaldo(lanc.tipo, lanc.valor, lanc.status))
    }
    return true
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return false
    throw err
  }
}

/**
 * Sanitiza a cópia de um lançamento origem 'via_os': a nova cópia nasce como MANUAL
 * e SEM o vínculo com a OS. Sem isso, "Copiar"/"Repetir" fabricaria um 2º recebimento
 * fantasma da mesma OS (chip "Via OS" + os_id), inflando receita/saldo em dobro
 * (double-count no cálculo de "receita Via OS"). Para origem 'manual' é no-op.
 */
function desvincularOsSeViaOs(input: LancamentoInput): LancamentoInput {
  if (input.origem !== 'via_os') return input
  return {
    ...input,
    origem: 'manual',
    osId: undefined,
    osNumero: undefined,
    clienteNome: undefined,
    servicoNome: undefined,
  }
}

/** Copia um lançamento como NOVO (sufixo " (cópia)" na descrição, mesmo status). */
export async function duplicateLancamento(id: string): Promise<Lancamento> {
  const base = await getLancamento(id)
  if (!base) throw new Error(`Lançamento não encontrado: ${id}`)
  const { id: _id, created: _c, updated: _u, ...rest } = base
  return createLancamento(
    desvincularOsSeViaOs({ ...rest, descricao: `${rest.descricao} (cópia)` }),
  )
}

/**
 * "Repetir": cria a PRÓXIMA ocorrência de um lançamento.
 * Reinicia o status como 'previsto' e, se for parcelado, avança parcelaAtual.
 * `overrides` permite ajustar campos da nova ocorrência (ex.: nova `data`/`vencimento`).
 */
export async function repeatLancamento(
  id: string,
  overrides: Partial<LancamentoInput> = {},
): Promise<Lancamento> {
  const base = await getLancamento(id)
  if (!base) throw new Error(`Lançamento não encontrado: ${id}`)
  const { id: _id, created: _c, updated: _u, ...rest } = base
  const proximaParcela =
    rest.recorrencia === 'parcelada' && typeof rest.parcelaAtual === 'number'
      ? rest.parcelaAtual + 1
      : rest.parcelaAtual
  return createLancamento(
    desvincularOsSeViaOs({
      ...rest,
      status: 'previsto',
      parcelaAtual: proximaParcela,
      ...overrides,
    }),
  )
}

/* ============================================================
 * Contas / Carteiras
 * ============================================================ */

export async function listContas(): Promise<Conta[]> {
  const rows = await pb
    .collection(FIN_COLLECTIONS.CONTAS)
    .getFullList<FinContaPB>({ sort: 'nome' })
  return rows.map(pbToConta)
}

export async function getConta(id: string): Promise<Conta | undefined> {
  try {
    const rec = await pb.collection(FIN_COLLECTIONS.CONTAS).getOne<FinContaPB>(id)
    return pbToConta(rec)
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return undefined
    throw err
  }
}

export async function createConta(input: ContaInput): Promise<Conta> {
  const rec = await pb
    .collection(FIN_COLLECTIONS.CONTAS)
    .create<FinContaPB>(contaToPB(input))
  return pbToConta(rec)
}

export async function updateConta(id: string, patch: Partial<ContaInput>): Promise<Conta> {
  const rec = await pb
    .collection(FIN_COLLECTIONS.CONTAS)
    .update<FinContaPB>(id, contaToPB(patch))
  return pbToConta(rec)
}

export async function deleteConta(id: string): Promise<boolean> {
  try {
    await pb.collection(FIN_COLLECTIONS.CONTAS).delete(id)
    return true
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return false
    throw err
  }
}

/* ============================================================
 * Categorias
 * ============================================================ */

export async function listCategorias(): Promise<Categoria[]> {
  const rows = await pb
    .collection(FIN_COLLECTIONS.CATEGORIAS)
    .getFullList<FinCategoriaPB>({ sort: 'nome' })
  return rows.map(pbToCategoria)
}

export async function getCategoria(id: string): Promise<Categoria | undefined> {
  try {
    const rec = await pb.collection(FIN_COLLECTIONS.CATEGORIAS).getOne<FinCategoriaPB>(id)
    return pbToCategoria(rec)
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return undefined
    throw err
  }
}

export async function createCategoria(input: CategoriaInput): Promise<Categoria> {
  const rec = await pb
    .collection(FIN_COLLECTIONS.CATEGORIAS)
    .create<FinCategoriaPB>(categoriaToPB(input))
  return pbToCategoria(rec)
}

export async function updateCategoria(
  id: string,
  patch: Partial<CategoriaInput>,
): Promise<Categoria> {
  const rec = await pb
    .collection(FIN_COLLECTIONS.CATEGORIAS)
    .update<FinCategoriaPB>(id, categoriaToPB(patch))
  return pbToCategoria(rec)
}

export async function deleteCategoria(id: string): Promise<boolean> {
  try {
    await pb.collection(FIN_COLLECTIONS.CATEGORIAS).delete(id)
    return true
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return false
    throw err
  }
}

/* ============================================================
 * Limites de gasto
 * ============================================================ */

export async function listLimites(): Promise<LimiteGasto[]> {
  const rows = await pb
    .collection(FIN_COLLECTIONS.LIMITES)
    .getFullList<FinLimitePB>({ sort: 'categoria_id' })
  return rows.map(pbToLimite)
}

export async function getLimite(id: string): Promise<LimiteGasto | undefined> {
  try {
    const rec = await pb.collection(FIN_COLLECTIONS.LIMITES).getOne<FinLimitePB>(id)
    return pbToLimite(rec)
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return undefined
    throw err
  }
}

export async function createLimite(input: LimiteInput): Promise<LimiteGasto> {
  const rec = await pb
    .collection(FIN_COLLECTIONS.LIMITES)
    .create<FinLimitePB>(limiteToPB(input))
  return pbToLimite(rec)
}

export async function updateLimite(id: string, patch: Partial<LimiteInput>): Promise<LimiteGasto> {
  const rec = await pb
    .collection(FIN_COLLECTIONS.LIMITES)
    .update<FinLimitePB>(id, limiteToPB(patch))
  return pbToLimite(rec)
}

export async function deleteLimite(id: string): Promise<boolean> {
  try {
    await pb.collection(FIN_COLLECTIONS.LIMITES).delete(id)
    return true
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return false
    throw err
  }
}

/* ============================================================
 * Reset (dev-only) — no-op em modo PB
 * ============================================================ */

/** @dev-only No-op — dados vivem no PocketBase. Use a Admin UI para reset. */
export function resetFinanceiroStore(): void {
  /* no-op */
}

/* ============================================================
 * Derivações PURAS (exportadas, testáveis) — recebem dados por parâmetro
 * ============================================================ */

/** Período (mês) como janela half-open [start, end) em datas 'YYYY-MM-DD'. */
export function mesPeriodo(year: number, month: number): Periodo {
  const p = (n: number) => String(n).padStart(2, '0')
  const start = `${year}-${p(month + 1)}-01`
  const end = month === 11 ? `${year + 1}-01-01` : `${year}-${p(month + 2)}-01`
  return { start, end }
}

/** Está dentro do período [start, end) comparando só a data (ignora a hora)? */
function dentroDoPeriodo(l: Lancamento, periodo: Periodo): boolean {
  const d = dateOnly(l.data)
  return d >= dateOnly(periodo.start) && d < dateOnly(periodo.end)
}

/** Filtra os lançamentos cujo `data` cai no período [start, end). */
export function lancamentosDoPeriodo(lancs: Lancamento[], periodo: Periodo): Lancamento[] {
  return lancs.filter((l) => dentroDoPeriodo(l, periodo))
}

/**
 * Totais REALIZADOS (status 'pago') do período:
 *   entradas = Σ receitas pagas · saidas = Σ despesas pagas · saldoMes = entradas − saidas.
 */
export function resumoPeriodo(lancs: Lancamento[], periodo: Periodo): ResumoPeriodo {
  let entradas = 0
  let saidas = 0
  for (const l of lancs) {
    if (l.status !== 'pago' || !dentroDoPeriodo(l, periodo)) continue
    if (l.tipo === 'receita') entradas += l.valor
    else saidas += l.valor
  }
  return { entradas, saidas, saldoMes: entradas - saidas }
}

/** Saldo geral = Σ saldoAtual de todas as contas (inclui inativas; filtre antes se quiser). */
export function saldoGeral(contas: Conta[]): number {
  return contas.reduce((sum, c) => sum + c.saldoAtual, 0)
}

/**
 * Agrupa lançamentos por DIA ('YYYY-MM-DD'), ordenado do mais recente p/ o mais antigo.
 * `totalDia` é a soma COM sinal (receitas − despesas) dos itens do dia.
 */
export function agruparPorData(lancs: Lancamento[]): GrupoPorData[] {
  const map = new Map<string, Lancamento[]>()
  for (const l of lancs) {
    const dia = dateOnly(l.data)
    const arr = map.get(dia)
    if (arr) arr.push(l)
    else map.set(dia, [l])
  }
  return Array.from(map.entries())
    .map(([data, itens]) => ({
      data,
      itens,
      totalDia: itens.reduce((sum, l) => sum + signedValue(l), 0),
    }))
    .sort((a, b) => (a.data < b.data ? 1 : a.data > b.data ? -1 : 0))
}

/** Está em aberto (não pago)? — pendente, previsto ou em_atraso. */
function emAberto(l: Lancamento): boolean {
  return l.status === 'pendente' || l.status === 'previsto' || l.status === 'em_atraso'
}

/**
 * Anota um lançamento em aberto com as flags vencendoHoje/emAtraso, dada a data
 * de referência `ref` (ISO). `emAtraso` é verdadeiro se o status já for 'em_atraso'
 * OU se houver vencimento anterior a `ref`.
 */
function toContaPendente(l: Lancamento, ref: string): ContaPendente {
  const hoje = dateOnly(ref)
  const venc = l.vencimento ? dateOnly(l.vencimento) : undefined
  return {
    lancamento: l,
    vencendoHoje: venc === hoje,
    emAtraso: l.status === 'em_atraso' || (venc !== undefined && venc < hoje),
  }
}

/** Ordena por vencimento ascendente (sem vencimento por último, depois por `data`). */
function ordenarPorVencimento(a: ContaPendente, b: ContaPendente): number {
  const va = a.lancamento.vencimento ?? a.lancamento.data
  const vb = b.lancamento.vencimento ?? b.lancamento.data
  return va < vb ? -1 : va > vb ? 1 : 0
}

/** Despesas em aberto (contas a PAGAR), anotadas vs. a data de referência `ref`. */
export function contasAPagar(lancs: Lancamento[], ref: string): ContaPendente[] {
  return lancs
    .filter((l) => l.tipo === 'despesa' && emAberto(l))
    .map((l) => toContaPendente(l, ref))
    .sort(ordenarPorVencimento)
}

/** Receitas em aberto (contas a RECEBER), anotadas vs. a data de referência `ref`. */
export function contasAReceber(lancs: Lancamento[], ref: string): ContaPendente[] {
  return lancs
    .filter((l) => l.tipo === 'receita' && emAberto(l))
    .map((l) => toContaPendente(l, ref))
    .sort(ordenarPorVencimento)
}

/**
 * Total de DESPESAS PAGAS por categoria (chave = categoriaId, a categoria-mãe do
 * lançamento). Base de "maiores gastos do mês". Pré-filtre por período se quiser.
 */
export function gastoPorCategoria(lancs: Lancamento[]): Map<string, number> {
  const map = new Map<string, number>()
  for (const l of lancs) {
    if (l.tipo !== 'despesa' || l.status !== 'pago') continue
    map.set(l.categoriaId, (map.get(l.categoriaId) ?? 0) + l.valor)
  }
  return map
}

/**
 * Progresso de um limite: soma as despesas PAGAS cuja categoriaId OU subcategoriaId
 * casa com a categoria do limite (suporta limite na mãe ou na subcategoria).
 * `pct` é clampado em [0, 1]; 0 quando o limite ≤ 0.
 */
export function progressoLimite(limite: LimiteGasto, lancs: Lancamento[]): ProgressoLimite {
  let gasto = 0
  for (const l of lancs) {
    if (l.tipo !== 'despesa' || l.status !== 'pago') continue
    if (l.categoriaId === limite.categoriaId || l.subcategoriaId === limite.categoriaId) {
      gasto += l.valor
    }
  }
  const pct = limite.limite > 0 ? Math.min(1, Math.max(0, gasto / limite.limite)) : 0
  return { gasto, limite: limite.limite, pct }
}
