/**
 * servicos/store.ts — Camada de dados do catálogo de Serviços (PocketBase).
 *
 * O CRUD conversa com pb.collection(COLLECTIONS.SERVICOS) (coleção `servicos`,
 * schema RICO snake_case — ver ServicoPB em ../collections). Os mapeadores
 * pbToServico / servicoToPB traduzem entre o registro PB e o tipo de domínio
 * camelCase `Servico` (./types).
 *
 * As assinaturas públicas são IDÊNTICAS às da versão localStorage anterior, para
 * não quebrar consumidores (ServicosListPage, ServicoEditorPage, OSExecucaoPage,
 * relatorioOS). Os helpers puros (buildSnapshot / snapshotToChecklistExec /
 * calcTotalOS) continuam síncronos e operam só sobre o domínio.
 *
 * Back-compat: ao GRAVAR, os campos legados são sincronizados —
 *   preco_base = valorBase · ativo = (status === 'ativo').
 * Todo serviço criado recebe um `slug` único (slugify do nome + sufixo).
 */

import { ClientResponseError } from 'pocketbase'
import { pb } from '../pb'
import { COLLECTIONS } from '../collections'
import type { ServicoPB } from '../collections'
import type {
  Categoria,
  ChecklistExecItem,
  ChecklistTemplateItem,
  Grupo,
  Servico,
  ServicoAdicionalOS,
  ServicoInput,
  ServicoStatus,
  ServiceSnapshot,
  TipoValor,
} from './types'

/* ============================================================
 * Utilidades internas (puras)
 * ============================================================ */

/** Clone profundo simples (dados são JSON-safe). */
function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T
}

/** ISO datetime atual (runtime) — usado pelos helpers de snapshot. */
function nowIso(): string {
  return new Date().toISOString()
}

/** Gera um ID local único com prefixo (itens do checklist de execução da OS). */
function genId(prefix: string): string {
  const rand = Math.random().toString(36).slice(2, 8)
  const time = Date.now().toString(36)
  return `${prefix}_${time}${rand}`
}

/**
 * Normaliza um campo JSON do PB em array. O SDK normalmente já entrega o valor
 * parseado (array), mas tratamos string defensivamente (sem JSON.parse cego).
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
 * Mapeadores domínio ↔ PocketBase
 * ============================================================ */

/**
 * Converte um registro PB (snake_case) no tipo de domínio `Servico` (camelCase).
 * Selects vazios ('') de linhas não enriquecidas caem em defaults seguros, e
 * `status` deriva do `ativo` legado quando ausente.
 */
export function pbToServico(rec: ServicoPB): Servico {
  return {
    id: rec.id,
    categoria: (rec.categoria || 'veicular') as Categoria,
    grupo: (rec.grupo || 'outros') as Grupo,
    nome: rec.nome,
    valorBase: rec.valor_base ?? 0,
    // 0 / ausente = sem máximo
    valorBaseMax: rec.valor_base_max ? rec.valor_base_max : undefined,
    tipoValor: (rec.tipo_valor || 'fixo') as TipoValor,
    // 0 / ausente = Variável (sem tempo determinável)
    tempoMedioMin: rec.tempo_medio_min ? rec.tempo_medio_min : undefined,
    tempoMedioLabel: rec.tempo_medio_label ?? '',
    status: (rec.status || (rec.ativo ? 'ativo' : 'inativo')) as ServicoStatus,
    observacao: rec.observacao || undefined,
    checklistPadrao: asArray<ChecklistTemplateItem>(rec.checklist_padrao).map((i) => ({ ...i })),
    orientacoesPre: rec.orientacoes_pre || undefined,
    orientacoesPos: rec.orientacoes_pos || undefined,
    adicionaisRelacionados: [...asArray<string>(rec.adicionais_relacionados)],
    created: rec.created,
    updated: rec.updated,
  }
}

/**
 * Converte um `ServicoInput` (ou parcial) no payload PB snake_case.
 * Só inclui as chaves PRESENTES no input (suporta updates parciais, ex.: só
 * `{ status }`). Sincroniza os campos legados (preco_base, ativo). NÃO inclui
 * `slug` — ele é gerado/garantido em createServico.
 */
export function servicoToPB(input: Partial<ServicoInput>): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  const has = (k: keyof ServicoInput): boolean =>
    Object.prototype.hasOwnProperty.call(input, k)

  if (has('categoria')) out.categoria = input.categoria
  if (has('grupo')) out.grupo = input.grupo
  if (has('nome')) out.nome = input.nome
  if (has('valorBase')) {
    out.valor_base = input.valorBase
    out.preco_base = input.valorBase // 🔁 legado sincronizado
  }
  if (has('valorBaseMax')) out.valor_base_max = input.valorBaseMax ?? 0
  if (has('tipoValor')) out.tipo_valor = input.tipoValor
  if (has('tempoMedioMin')) out.tempo_medio_min = input.tempoMedioMin ?? 0
  if (has('tempoMedioLabel')) out.tempo_medio_label = input.tempoMedioLabel ?? ''
  if (has('status')) {
    out.status = input.status
    out.ativo = input.status === 'ativo' // 🔁 legado sincronizado
  }
  if (has('observacao')) out.observacao = input.observacao ?? ''
  if (has('checklistPadrao')) out.checklist_padrao = input.checklistPadrao ?? []
  if (has('orientacoesPre')) out.orientacoes_pre = input.orientacoesPre ?? ''
  if (has('orientacoesPos')) out.orientacoes_pos = input.orientacoesPos ?? ''
  if (has('adicionaisRelacionados')) {
    out.adicionais_relacionados = input.adicionaisRelacionados ?? []
  }
  return out
}

/* ============================================================
 * Slug (referência estável, única via índice parcial no PB)
 * ============================================================ */

/** Slugify estável: minúsculas sem acento, não-alfanumérico → "_". */
export function slugify(nome: string): string {
  const base = nome
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // remove acentos (diacríticos combinados)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_') // não-alfanumérico → _
    .replace(/^_+|_+$/g, '') // trim de _
  return base || 'servico'
}

/** Primeiro slug livre a partir de `base` (`base`, `base_2`, `base_3`, …). */
function nextFreeSlug(base: string, taken: Set<string>): string {
  if (!taken.has(base)) return base
  let i = 2
  while (taken.has(`${base}_${i}`)) i++
  return `${base}_${i}`
}

/** Slugs já em uso no catálogo (índice parcial ignora os vazios). */
async function takenSlugs(): Promise<Set<string>> {
  // TODO otimizar p/ catálogo grande: hoje varre todos os slugs (getFullList) a
  // cada create. Para muitos serviços, trocar por uma checagem pontual do slug.
  const rows = await pb
    .collection(COLLECTIONS.SERVICOS)
    .getFullList<Pick<ServicoPB, 'slug'>>({ fields: 'slug' })
  return new Set(rows.map((r) => r.slug).filter(Boolean))
}

/** A falha de criação foi violação de unicidade do slug (índice parcial)? */
function isSlugConflict(err: unknown): boolean {
  if (!(err instanceof ClientResponseError) || err.status !== 400) return false
  const body = err.response as { data?: Record<string, unknown> } | undefined
  return !!body?.data && Object.prototype.hasOwnProperty.call(body.data, 'slug')
}

/* ============================================================
 * CRUD (assíncrono — PocketBase)
 * ============================================================ */

/** Lista todos os serviços do catálogo (ordenado por nome). */
export async function listServicos(): Promise<Servico[]> {
  const records = await pb
    .collection(COLLECTIONS.SERVICOS)
    .getFullList<ServicoPB>({ sort: 'nome' })
  return records.map(pbToServico)
}

/** Busca um serviço pelo ID (undefined se não existir). */
export async function getServico(id: string): Promise<Servico | undefined> {
  try {
    const rec = await pb.collection(COLLECTIONS.SERVICOS).getOne<ServicoPB>(id)
    return pbToServico(rec)
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return undefined
    throw err
  }
}

/**
 * Cria um serviço novo. Gera um slug ÚNICO (a UI sempre manda slug; o índice
 * parcial é a garantia final) e sincroniza os campos legados.
 */
export async function createServico(data: ServicoInput): Promise<Servico> {
  const base = slugify(data.nome)
  const taken = await takenSlugs()
  let slug = nextFreeSlug(base, taken)
  // Retry defensivo contra a corrida entre takenSlugs() e create(): o índice
  // parcial de `slug` rejeita duplicatas com 400 → reescolhemos e tentamos de novo.
  for (let attempt = 0; ; attempt++) {
    try {
      const rec = await pb
        .collection(COLLECTIONS.SERVICOS)
        .create<ServicoPB>({ ...servicoToPB(data), slug })
      return pbToServico(rec)
    } catch (err) {
      if (attempt < 3 && isSlugConflict(err)) {
        taken.add(slug)
        slug = nextFreeSlug(base, taken)
        continue
      }
      throw err
    }
  }
}

/**
 * Atualiza um serviço existente (parcial). Propaga ClientResponseError 404 se o
 * ID não existir (o consumidor trata via error-banner).
 */
export async function updateServico(
  id: string,
  data: Partial<ServicoInput>,
): Promise<Servico> {
  const rec = await pb
    .collection(COLLECTIONS.SERVICOS)
    .update<ServicoPB>(id, servicoToPB(data))
  return pbToServico(rec)
}

/** Remove um serviço. Retorna true se removido, false se não existia. */
export async function deleteServico(id: string): Promise<boolean> {
  try {
    await pb.collection(COLLECTIONS.SERVICOS).delete(id)
    return true
  } catch (err) {
    if (err instanceof ClientResponseError && err.status === 404) return false
    throw err
  }
}

/** Duplica um serviço (slug novo, nome com sufixo "(cópia)"). Lança se o ID não existir. */
export async function duplicateServico(id: string): Promise<Servico> {
  const original = await getServico(id)
  if (!original) throw new Error(`Serviço não encontrado: ${id}`)
  const { id: _id, created: _created, updated: _updated, ...rest } = original
  return createServico({ ...rest, nome: `${original.nome} (cópia)` })
}

/* ============================================================
 * Helpers de integração Serviço → OS (puros, síncronos)
 * ============================================================ */

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

/* ============================================================
 * Compat / deprecated (não há mais localStorage)
 * ============================================================ */

/** @deprecated A persistência agora é o PocketBase; mantido só p/ compat de imports. */
export const STORAGE_KEY = 'cleanox.servicos.v1'

/** @deprecated No-op — não há mais store local para resetar (dados vivem no PB). */
export function resetServicosStore(): void {
  /* no-op */
}
