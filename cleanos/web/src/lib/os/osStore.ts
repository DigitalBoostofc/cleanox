/**
 * os/osStore.ts — Camada de persistência REAL da execução da OS no PocketBase.
 *
 * Substitui a antiga gambiarra de localStorage (`cleanox.os-exec.*`) e o upload
 * mock via `URL.createObjectURL`. Aqui ficam todas as chamadas PB da superfície de
 * execução:
 *   - loadOSExec / saveOSExecPatch  → campos JSON ricos da `ordens_servico`
 *     (service_snapshot, checklist_exec, adicionais, observacoes_prof).
 *   - listEvidencias / createEvidencia / updateEvidencia / deleteEvidencia
 *     → coleção `os_evidencias` (upload de fotos antes/durante/depois).
 *
 * IMUTABILIDADE: `service_snapshot` é gravado UMA vez (na seleção do serviço) e
 * travado pelo hook do servidor contra o profissional. Os saves de rotina
 * (checklist/adicionais/observações) NÃO reenviam o snapshot — assim nunca
 * colidem com a trava, mantendo a operação idempotente.
 */

import { ClientResponseError } from 'pocketbase'
import { pb } from '../pb'
import {
  COLLECTIONS,
  userDisplayName,
  type OrdemServico,
  type OSEvidenciaPB,
} from '../collections'
import type {
  ServiceSnapshot,
  ChecklistExecItem,
  ServicoAdicionalOS,
  ObservacaoProfissional,
  EvidenciaFoto,
  FaseFoto,
} from '../servicos/types'

/* ──────────────────────────────────────────────────────────────────────
 * Erros — tradução amigável (rede / permissão / não encontrado)
 * ────────────────────────────────────────────────────────────────────── */

export interface OSError {
  message: string
  /** true para HTTP 403 — sem permissão (ex.: profissional sem acesso à OS). */
  isPermission: boolean
  /** true para HTTP 0 — sem conexão com o servidor. */
  isOffline: boolean
  /** true para HTTP 404 — OS/registro inexistente. */
  isNotFound: boolean
}

export function describeOSError(err: unknown): OSError {
  if (err instanceof ClientResponseError) {
    if (err.status === 0) {
      return { message: 'Sem conexão com o servidor. Verifique sua internet.', isPermission: false, isOffline: true, isNotFound: false }
    }
    if (err.status === 403) {
      return { message: 'Você não tem permissão para esta ação.', isPermission: true, isOffline: false, isNotFound: false }
    }
    if (err.status === 404) {
      return { message: 'Ordem de serviço não encontrada.', isPermission: false, isOffline: false, isNotFound: true }
    }
    const data = err.data as { message?: string } | undefined
    if (typeof data?.message === 'string' && data.message) {
      return { message: data.message, isPermission: false, isOffline: false, isNotFound: false }
    }
    return { message: `Erro ${err.status}: tente novamente.`, isPermission: false, isOffline: false, isNotFound: false }
  }
  if (err instanceof Error) return { message: err.message, isPermission: false, isOffline: false, isNotFound: false }
  return { message: 'Erro inesperado.', isPermission: false, isOffline: false, isNotFound: false }
}

/* ──────────────────────────────────────────────────────────────────────
 * ordens_servico — campos JSON ricos da execução
 * ────────────────────────────────────────────────────────────────────── */

/** Patch parcial dos campos JSON da execução. Campos ausentes não são tocados. */
export interface OSExecPatch {
  /** snapshot IMUTÁVEL — só enviar na seleção do serviço (a trava do hook é idempotente). */
  service_snapshot?: ServiceSnapshot | null
  checklist_exec?: ChecklistExecItem[]
  adicionais?: ServicoAdicionalOS[]
  observacoes_prof?: ObservacaoProfissional[]
  /** desconto (R$) aplicado no resumo financeiro — abatido no total e no relatório */
  descontos?: number
}

/**
 * Carrega a OS estendida (com expands de profissional e serviço). Os campos JSON
 * (service_snapshot/checklist_exec/adicionais/observacoes_prof) já vêm parseados
 * pelo SDK.
 */
export async function loadOSExec(osId: string): Promise<OrdemServico> {
  return pb
    .collection(COLLECTIONS.ORDENS_SERVICO)
    .getOne<OrdemServico>(osId, { expand: 'profissional,servico' })
}

/** Update parcial dos campos JSON da execução. */
export async function saveOSExecPatch(
  osId: string,
  patch: OSExecPatch,
): Promise<OrdemServico> {
  return pb
    .collection(COLLECTIONS.ORDENS_SERVICO)
    .update<OrdemServico>(osId, patch)
}

/* ──────────────────────────────────────────────────────────────────────
 * os_evidencias — upload e CRUD de fotos
 * ────────────────────────────────────────────────────────────────────── */

const FASES_VALIDAS: readonly FaseFoto[] = ['antes', 'durante', 'depois']

function normalizeFase(fase: FaseFoto | '' | undefined): FaseFoto {
  return fase && FASES_VALIDAS.includes(fase) ? fase : 'antes'
}

/**
 * Mapeia o registro PB de evidência para o tipo de domínio EvidenciaFoto.
 *
 * As fotos de `os_evidencias` são PROTEGIDAS (FileField protected:true) — a URL
 * só serve a imagem acompanhada de um file token. O caller gera UM token por load
 * (ver {@link listEvidencias}) e o injeta aqui. O token expira em ~2min; para esta
 * superfície (admin/dono) é aceitável — um refresh da lista renova o token.
 */
export function evidenciaToFoto(rec: OSEvidenciaPB, token?: string): EvidenciaFoto {
  return {
    id: rec.id,
    // URL real do arquivo no PB (vazia se, por algum motivo, não houver arquivo).
    // Arquivo protegido → precisa do token na query (?token=...).
    url: rec.foto ? pb.files.getUrl(rec, rec.foto, token ? { token } : {}) : '',
    fase: normalizeFase(rec.fase),
    legenda: rec.legenda || undefined,
    criadoEm: rec.created,
    enviadoPor: rec.expand?.enviado_por
      ? userDisplayName(rec.expand.enviado_por)
      : undefined,
    checklistItemId: rec.checklist_item_id || undefined,
    observacaoId: rec.observacao_id || undefined,
    adicionalId: rec.adicional_id || undefined,
  }
}

/** Lista todas as evidências de uma OS (ordenadas por criação), já como EvidenciaFoto. */
export async function listEvidencias(osId: string): Promise<EvidenciaFoto[]> {
  const recs = await pb
    .collection(COLLECTIONS.OS_EVIDENCIAS)
    .getFullList<OSEvidenciaPB>({
      filter: pb.filter('os = {:osId}', { osId }),
      sort: 'created',
      expand: 'enviado_por',
    })
  // Fotos são protegidas: gera UM file token por load (não por foto) e injeta em
  // todas as URLs. Só pede token se houver ao menos uma foto. Token expira ~2min.
  const token = recs.some((r) => r.foto) ? await pb.files.getToken() : undefined
  return recs.map((rec) => evidenciaToFoto(rec, token))
}

export interface CreateEvidenciaInput {
  file: File
  fase: FaseFoto
  legenda?: string
  checklistItemId?: string
  observacaoId?: string
  adicionalId?: string
  /** ID do usuário atual (relation enviado_por). */
  enviadoPorId?: string
}

/** Cria uma evidência com upload do arquivo (FormData). Retorna já como EvidenciaFoto. */
export async function createEvidencia(
  osId: string,
  input: CreateEvidenciaInput,
): Promise<EvidenciaFoto> {
  const fd = new FormData()
  fd.append('os', osId)
  fd.append('foto', input.file)
  fd.append('fase', input.fase)
  if (input.legenda) fd.append('legenda', input.legenda)
  if (input.checklistItemId) fd.append('checklist_item_id', input.checklistItemId)
  if (input.observacaoId) fd.append('observacao_id', input.observacaoId)
  if (input.adicionalId) fd.append('adicional_id', input.adicionalId)
  if (input.enviadoPorId) fd.append('enviado_por', input.enviadoPorId)
  const rec = await pb
    .collection(COLLECTIONS.OS_EVIDENCIAS)
    .create<OSEvidenciaPB>(fd, { expand: 'enviado_por' })
  // Foto protegida → a URL só renderiza com token (sobe otimista por blob: URL,
  // mas ao concluir trocamos pela URL real do PB, que precisa do token).
  const token = rec.foto ? await pb.files.getToken() : undefined
  return evidenciaToFoto(rec, token)
}

/** Patch de metadados de uma evidência (legenda/vínculos). String vazia LIMPA o campo. */
export interface EvidenciaUpdatePatch {
  legenda?: string
  checklist_item_id?: string
  observacao_id?: string
  adicional_id?: string
}

/** Atualiza legenda/vínculos de uma evidência. Retorna já como EvidenciaFoto. */
export async function updateEvidencia(
  id: string,
  patch: EvidenciaUpdatePatch,
): Promise<EvidenciaFoto> {
  const rec = await pb
    .collection(COLLECTIONS.OS_EVIDENCIAS)
    .update<OSEvidenciaPB>(id, patch, { expand: 'enviado_por' })
  // Foto protegida → renova o token para a URL retornada continuar válida.
  const token = rec.foto ? await pb.files.getToken() : undefined
  return evidenciaToFoto(rec, token)
}

/** Remove uma evidência (o arquivo é apagado junto pelo PB). */
export async function deleteEvidencia(id: string): Promise<void> {
  await pb.collection(COLLECTIONS.OS_EVIDENCIAS).delete(id)
}
