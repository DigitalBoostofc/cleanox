/**
 * servicos/store.ts — Store MOCK do catálogo de serviços, com persistência em localStorage.
 *
 * API desenhada para ser trocada por chamadas pb.collection('servicos') depois:
 * o CRUD é assíncrono (Promise) como será no PocketBase; os helpers puros
 * (buildSnapshot / snapshotToChecklistExec / calcTotalOS) permanecem síncronos.
 *
 * Veja os comentários // TODO PB nos pontos de troca.
 */

import { SERVICOS_SEED } from './seed'
import type {
  ChecklistExecItem,
  Servico,
  ServicoAdicionalOS,
  ServicoInput,
  ServiceSnapshot,
} from './types'

/** Chave de persistência no localStorage. */
export const STORAGE_KEY = 'cleanox.servicos.v1'

/* ---- Utilidades internas ---- */

/** Clone profundo simples (dados são JSON-safe). */
function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T
}

/** ISO datetime atual (runtime). */
function nowIso(): string {
  return new Date().toISOString()
}

/** Gera um ID único com prefixo (mock; o PB geraria o ID no servidor). */
function genId(prefix: string): string {
  const rand = Math.random().toString(36).slice(2, 8)
  const time = Date.now().toString(36)
  return `${prefix}_${time}${rand}`
}

/** Persiste a lista no localStorage (no-op em ambientes sem localStorage). */
function persist(servicos: Servico[]): void {
  if (typeof localStorage === 'undefined') return
  localStorage.setItem(STORAGE_KEY, JSON.stringify(servicos))
}

/**
 * Carrega a lista do localStorage; faz seed automático a partir de SERVICOS_SEED
 * na primeira carga (ou se o conteúdo estiver corrompido).
 */
// TODO PB: substituir por pb.collection(COLLECTIONS.SERVICOS).getFullList()
function load(): Servico[] {
  if (typeof localStorage === 'undefined') return clone(SERVICOS_SEED)
  const raw = localStorage.getItem(STORAGE_KEY)
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as Servico[]
      if (Array.isArray(parsed)) return parsed
    } catch {
      /* conteúdo corrompido → re-seed abaixo */
    }
  }
  persist(SERVICOS_SEED)
  return clone(SERVICOS_SEED)
}

/* ---- CRUD (assíncrono, espelhando o PocketBase) ---- */

/** Lista todos os serviços do catálogo. */
// TODO PB: pb.collection(COLLECTIONS.SERVICOS).getFullList({ sort: 'nome' })
export async function listServicos(): Promise<Servico[]> {
  return clone(load())
}

/** Busca um serviço pelo ID (undefined se não existir). */
// TODO PB: pb.collection(COLLECTIONS.SERVICOS).getOne(id)
export async function getServico(id: string): Promise<Servico | undefined> {
  const found = load().find((s) => s.id === id)
  return found ? clone(found) : undefined
}

/** Cria um novo serviço; gera id/created/updated. */
// TODO PB: pb.collection(COLLECTIONS.SERVICOS).create(data)
export async function createServico(data: ServicoInput): Promise<Servico> {
  const list = load()
  const ts = nowIso()
  const novo: Servico = {
    ...clone(data),
    id: genId('svc'),
    created: ts,
    updated: ts,
  }
  list.push(novo)
  persist(list)
  return clone(novo)
}

/** Atualiza um serviço existente; refaz updated. Lança se o ID não existir. */
// TODO PB: pb.collection(COLLECTIONS.SERVICOS).update(id, data)
export async function updateServico(
  id: string,
  data: Partial<ServicoInput>,
): Promise<Servico> {
  const list = load()
  const idx = list.findIndex((s) => s.id === id)
  if (idx === -1) throw new Error(`Serviço não encontrado: ${id}`)
  const atualizado: Servico = {
    ...list[idx],
    ...clone(data),
    id: list[idx].id,
    created: list[idx].created,
    updated: nowIso(),
  }
  list[idx] = atualizado
  persist(list)
  return clone(atualizado)
}

/** Remove um serviço. Retorna true se algo foi removido. */
// TODO PB: pb.collection(COLLECTIONS.SERVICOS).delete(id)
export async function deleteServico(id: string): Promise<boolean> {
  const list = load()
  const next = list.filter((s) => s.id !== id)
  const removed = next.length !== list.length
  if (removed) persist(next)
  return removed
}

/** Duplica um serviço (novo id, nome com sufixo "(cópia)"). Lança se o ID não existir. */
export async function duplicateServico(id: string): Promise<Servico> {
  const original = load().find((s) => s.id === id)
  if (!original) throw new Error(`Serviço não encontrado: ${id}`)
  const { id: _id, created: _c, updated: _u, ...rest } = original
  return createServico({ ...clone(rest), nome: `${original.nome} (cópia)` })
}

/* ---- Helpers de integração Serviço → OS (puros, síncronos) ---- */

/**
 * Cria o snapshot congelado do serviço para gravar dentro da OS.
 * A OS guarda este snapshot — NÃO referencia o serviço original — para que edições
 * futuras no cadastro não alterem OS antigas.
 */
export function buildSnapshot(servico: Servico): ServiceSnapshot {
  return {
    serviceId: servico.id,
    nome: servico.nome,
    categoria: servico.categoria,
    grupo: servico.grupo,
    valorBase: servico.valorBase,
    valorBaseMax: servico.valorBaseMax,
    tipoValor: servico.tipoValor,
    tempoMedioMin: servico.tempoMedioMin,
    tempoMedioLabel: servico.tempoMedioLabel,
    observacaoTecnica: servico.observacao,
    checklistPadrao: clone(servico.checklistPadrao),
    orientacoesPreServico: servico.orientacoesPre,
    orientacoesPosServico: servico.orientacoesPos,
    capturedAt: nowIso(),
  }
}

/**
 * Converte o checklist padrão do snapshot em itens executáveis da OS,
 * cada um iniciando como 'pendente'. Preserva a ordem definida em `ordem`.
 */
export function snapshotToChecklistExec(
  snapshot: ServiceSnapshot,
): ChecklistExecItem[] {
  return [...snapshot.checklistPadrao]
    .sort((a, b) => a.ordem - b.ordem)
    .map((item) => ({
      id: genId('cke'),
      titulo: item.titulo,
      status: 'pendente',
    }))
}

/**
 * Calcula o total da OS:
 *   valor principal + Σ (adicional.valor × quantidade) − descontos
 *
 * Conta apenas adicionais que efetivamente entram na cobrança: 'aprovado' e
 * 'nao_requer'. Adicionais 'aguardando' ou 'recusado' são ignorados.
 * O resultado nunca é negativo.
 */
export function calcTotalOS(
  valorPrincipal: number,
  adicionais: ServicoAdicionalOS[],
  descontos = 0,
): number {
  const totalAdicionais = adicionais
    .filter((a) => a.aprovacao === 'aprovado' || a.aprovacao === 'nao_requer')
    .reduce((sum, a) => sum + a.valor * a.quantidade, 0)
  return Math.max(0, valorPrincipal + totalAdicionais - descontos)
}

/* ---- Utilitário de manutenção (dev/testes) ---- */

/** Limpa a persistência e reaplica o seed. Útil em dev/testes. */
export function resetServicosStore(): void {
  if (typeof localStorage !== 'undefined') localStorage.removeItem(STORAGE_KEY)
  persist(SERVICOS_SEED)
}
