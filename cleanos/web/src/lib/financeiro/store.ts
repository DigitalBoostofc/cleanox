/**
 * financeiro/store.ts — Camada de dados MOCK do módulo Financeiro.
 *
 * Persiste em localStorage (chaves 'cleanox.fin.*.v1') e expõe uma API ASSÍNCRONA
 * que ESPELHA a forma de pb.collection() — list/get/create/update/delete — para
 * que a troca por PocketBase depois seja mecânica (ver // TODO PB). Em ambientes
 * sem localStorage (testes em Node puro), cai para um fallback em memória.
 *
 * Além do CRUD, este módulo concentra as DERIVAÇÕES puras e testáveis (resumo do
 * período, saldo geral, agrupamento por data, contas a pagar/receber, gasto por
 * categoria e progresso de limite). Elas recebem os dados por parâmetro e NÃO
 * leem o relógio — qualquer "data de referência" (hoje) entra como argumento.
 */

import {
  CATEGORIAS_SEED,
  CONTAS_SEED,
  LANCAMENTOS_SEED,
  LIMITES_SEED,
} from './seed'
import { signedValue } from './labels'
import type {
  Categoria,
  CategoriaInput,
  Conta,
  ContaInput,
  ContaPendente,
  FinRecord,
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
 * Chaves de armazenamento (versão v1)
 * ============================================================ */

export const STORAGE_KEYS = {
  lancamentos: 'cleanox.fin.lancamentos.v1',
  contas: 'cleanox.fin.contas.v1',
  categorias: 'cleanox.fin.categorias.v1',
  limites: 'cleanox.fin.limites.v1',
} as const

/* ============================================================
 * Utilidades internas (puras)
 * ============================================================ */

/** Clone profundo simples (dados são JSON-safe). */
function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T
}

/** ISO datetime atual (runtime) — usado em created/updated dos registros do store. */
function nowIso(): string {
  return new Date().toISOString()
}

/** Sequência local para IDs (combinada com timestamp p/ evitar colisão entre reloads). */
let _seq = 0

/** Gera um ID local único com prefixo, ex.: 'lanc_lq3x8_2'. */
function genId(prefix: string): string {
  _seq += 1
  return `${prefix}_${Date.now().toString(36)}_${_seq.toString(36)}`
}

/** Só a parte 'YYYY-MM-DD' de uma string ISO (datetime ou date). */
function dateOnly(iso: string): string {
  return iso.slice(0, 10)
}

/* ============================================================
 * Camada de persistência (localStorage + fallback em memória)
 * ============================================================ */

/** Fallback usado quando localStorage não existe/está bloqueado (ex.: testes Node). */
const memFallback = new Map<string, string>()

function getRaw(key: string): string | null {
  try {
    if (typeof localStorage !== 'undefined') return localStorage.getItem(key)
  } catch {
    /* acesso bloqueado → fallback */
  }
  return memFallback.has(key) ? memFallback.get(key)! : null
}

function setRaw(key: string, value: string): void {
  try {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(key, value)
      return
    }
  } catch {
    /* acesso bloqueado → fallback */
  }
  memFallback.set(key, value)
}

function removeRaw(key: string): void {
  try {
    if (typeof localStorage !== 'undefined') {
      localStorage.removeItem(key)
      return
    }
  } catch {
    /* ignore */
  }
  memFallback.delete(key)
}

/**
 * Lê a coleção do storage. Na 1ª carga (chave ausente ou conteúdo inválido),
 * faz o SEED automático: grava uma cópia do seed e a retorna.
 */
function loadCollection<T>(key: string, seed: readonly T[]): T[] {
  const raw = getRaw(key)
  if (raw !== null) {
    try {
      const parsed: unknown = JSON.parse(raw)
      if (Array.isArray(parsed)) return parsed as T[]
    } catch {
      /* conteúdo corrompido → reseed abaixo */
    }
  }
  const initial = clone(seed) as T[]
  setRaw(key, JSON.stringify(initial))
  return initial
}

/** Persiste a coleção inteira. */
function saveCollection<T>(key: string, rows: T[]): void {
  setRaw(key, JSON.stringify(rows))
}

/* ============================================================
 * CRUD genérico (assíncrono — espelha pb.collection)
 *   TODO PB: trocar cada operação por pb.collection(NOME).<op>().
 * ============================================================ */

/** Cria os campos de auditoria de um registro novo. */
function stampNew<T extends FinRecord>(prefix: string, input: Omit<T, keyof FinRecord>): T {
  const ts = nowIso()
  return { ...(input as object), id: genId(prefix), created: ts, updated: ts } as T
}

async function list<T>(key: string, seed: readonly T[]): Promise<T[]> {
  return loadCollection<T>(key, seed)
}

async function getById<T extends FinRecord>(
  key: string,
  seed: readonly T[],
  id: string,
): Promise<T | undefined> {
  return loadCollection<T>(key, seed).find((r) => r.id === id)
}

async function create<T extends FinRecord>(
  key: string,
  seed: readonly T[],
  prefix: string,
  input: Omit<T, keyof FinRecord>,
): Promise<T> {
  const rows = loadCollection<T>(key, seed)
  const record = stampNew<T>(prefix, input)
  rows.push(record)
  saveCollection(key, rows)
  return clone(record)
}

async function update<T extends FinRecord>(
  key: string,
  seed: readonly T[],
  id: string,
  patch: Partial<Omit<T, keyof FinRecord>>,
): Promise<T> {
  const rows = loadCollection<T>(key, seed)
  const idx = rows.findIndex((r) => r.id === id)
  if (idx === -1) throw new Error(`Registro não encontrado: ${id}`)
  const updated: T = { ...rows[idx], ...(patch as object), updated: nowIso() } as T
  rows[idx] = updated
  saveCollection(key, rows)
  return clone(updated)
}

async function remove<T extends FinRecord>(
  key: string,
  seed: readonly T[],
  id: string,
): Promise<boolean> {
  const rows = loadCollection<T>(key, seed)
  const next = rows.filter((r) => r.id !== id)
  if (next.length === rows.length) return false
  saveCollection(key, next)
  return true
}

/* ============================================================
 * Lançamentos
 * ============================================================ */

export function listLancamentos(): Promise<Lancamento[]> {
  return list(STORAGE_KEYS.lancamentos, LANCAMENTOS_SEED)
}
export function getLancamento(id: string): Promise<Lancamento | undefined> {
  return getById(STORAGE_KEYS.lancamentos, LANCAMENTOS_SEED, id)
}
export function createLancamento(input: LancamentoInput): Promise<Lancamento> {
  return create(STORAGE_KEYS.lancamentos, LANCAMENTOS_SEED, 'lanc', input)
}
export function updateLancamento(
  id: string,
  patch: Partial<LancamentoInput>,
): Promise<Lancamento> {
  return update(STORAGE_KEYS.lancamentos, LANCAMENTOS_SEED, id, patch)
}
export function deleteLancamento(id: string): Promise<boolean> {
  return remove(STORAGE_KEYS.lancamentos, LANCAMENTOS_SEED, id)
}

/** Copia um lançamento como NOVO (sufixo " (cópia)" na descrição, mesmo status). */
export async function duplicateLancamento(id: string): Promise<Lancamento> {
  const base = await getLancamento(id)
  if (!base) throw new Error(`Lançamento não encontrado: ${id}`)
  const { id: _id, created: _c, updated: _u, ...rest } = base
  return createLancamento({ ...rest, descricao: `${rest.descricao} (cópia)` })
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
  return createLancamento({
    ...rest,
    status: 'previsto',
    parcelaAtual: proximaParcela,
    ...overrides,
  })
}

/* ============================================================
 * Contas / Carteiras
 * ============================================================ */

export function listContas(): Promise<Conta[]> {
  return list(STORAGE_KEYS.contas, CONTAS_SEED)
}
export function getConta(id: string): Promise<Conta | undefined> {
  return getById(STORAGE_KEYS.contas, CONTAS_SEED, id)
}
export function createConta(input: ContaInput): Promise<Conta> {
  return create(STORAGE_KEYS.contas, CONTAS_SEED, 'conta', input)
}
export function updateConta(id: string, patch: Partial<ContaInput>): Promise<Conta> {
  return update(STORAGE_KEYS.contas, CONTAS_SEED, id, patch)
}
export function deleteConta(id: string): Promise<boolean> {
  return remove(STORAGE_KEYS.contas, CONTAS_SEED, id)
}

/* ============================================================
 * Categorias
 * ============================================================ */

export function listCategorias(): Promise<Categoria[]> {
  return list(STORAGE_KEYS.categorias, CATEGORIAS_SEED)
}
export function getCategoria(id: string): Promise<Categoria | undefined> {
  return getById(STORAGE_KEYS.categorias, CATEGORIAS_SEED, id)
}
export function createCategoria(input: CategoriaInput): Promise<Categoria> {
  return create(STORAGE_KEYS.categorias, CATEGORIAS_SEED, 'cat', input)
}
export function updateCategoria(
  id: string,
  patch: Partial<CategoriaInput>,
): Promise<Categoria> {
  return update(STORAGE_KEYS.categorias, CATEGORIAS_SEED, id, patch)
}
export function deleteCategoria(id: string): Promise<boolean> {
  return remove(STORAGE_KEYS.categorias, CATEGORIAS_SEED, id)
}

/* ============================================================
 * Limites de gasto
 * ============================================================ */

export function listLimites(): Promise<LimiteGasto[]> {
  return list(STORAGE_KEYS.limites, LIMITES_SEED)
}
export function getLimite(id: string): Promise<LimiteGasto | undefined> {
  return getById(STORAGE_KEYS.limites, LIMITES_SEED, id)
}
export function createLimite(input: LimiteInput): Promise<LimiteGasto> {
  return create(STORAGE_KEYS.limites, LIMITES_SEED, 'lim', input)
}
export function updateLimite(id: string, patch: Partial<LimiteInput>): Promise<LimiteGasto> {
  return update(STORAGE_KEYS.limites, LIMITES_SEED, id, patch)
}
export function deleteLimite(id: string): Promise<boolean> {
  return remove(STORAGE_KEYS.limites, LIMITES_SEED, id)
}

/* ============================================================
 * Reset (dev/testes) — limpa o storage e força reseed na próxima leitura
 * ============================================================ */

/** Apaga todas as chaves do Financeiro. A próxima leitura recria o seed. */
export function resetFinanceiroStore(): void {
  Object.values(STORAGE_KEYS).forEach(removeRaw)
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
