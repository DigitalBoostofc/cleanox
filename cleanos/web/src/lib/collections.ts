/**
 * collections.ts — Contrato CANÔNICO de coleções do PocketBase (fonte: cleanos/pb/README.md)
 * ÚNICO ponto de verdade dos nomes de coleções e tipos no frontend.
 */

// Tipos camelCase do domínio Serviços/OS (fonte de verdade em ./servicos/types).
// Import SÓ de tipo (apagado no build) — usado para tipar os campos JSON da OS e
// o catálogo rico (ServicoPB). Não cria ciclo de runtime.
import type {
  Categoria,
  Grupo,
  TipoValor,
  ServicoStatus,
  FaseFoto,
  ChecklistTemplateItem,
  ServiceSnapshot,
  ChecklistExecItem,
  ServicoAdicionalOS,
  ObservacaoProfissional,
} from './servicos/types'
import type {
  Anexo,
  ContaTipo,
  LancamentoStatus,
  OrigemLancamento,
  RecorrenciaTipo,
  TipoLancamento,
} from './financeiro/types'

/* ---- Nomes das coleções ---- */
export const COLLECTIONS = {
  USERS: 'users',
  CLIENTES: 'clientes',
  SERVICOS: 'servicos',
  ORDENS_SERVICO: 'ordens_servico',
  CONFIG_ATUACAO: 'config_atuacao',
  DISPONIBILIDADE: 'disponibilidade',
  OS_EVIDENCIAS: 'os_evidencias',
} as const

export type CollectionName = (typeof COLLECTIONS)[keyof typeof COLLECTIONS]

/* ---- Papéis de usuário ---- */
export type Role = 'admin' | 'gerente' | 'profissional'

/* ---- Status da Ordem de Serviço ---- */
export type OSStatus =
  | 'agendada'
  | 'atribuida'
  | 'em_andamento'
  | 'concluida'
  | 'cancelada'

export const OS_STATUS_LIST: OSStatus[] = [
  'agendada',
  'atribuida',
  'em_andamento',
  'concluida',
  'cancelada',
]

/* ---- Formas de pagamento ---- */
export type FormaPagamento = 'debito' | 'credito' | 'pix_maquininha'

/* ---- Status do repasse ---- */
export type RepasseStatus = 'pendente' | 'pago'

/* ---- Base record ---- */
export interface PBRecord {
  id: string
  created: string
  updated: string
}

/* ---- users (auth) ---- */
export interface User extends PBRecord {
  /** campo auth padrão */
  name: string
  email: string
  role: Role
  /** nome de exibição do colaborador (campo extra) */
  nome?: string
  verified?: boolean
  emailVisibility?: boolean
}

/* ---- clientes — 🔒 COFRE (profissional NEGADO na API) ---- */
export interface Cliente extends PBRecord {
  nome: string
  sobrenome?: string
  /** SENSÍVEL — nunca exposto ao profissional */
  telefone: string
  email?: string
  endereco_rua?: string
  endereco_numero?: string
  endereco_complemento?: string
  /** seguro — vira `bairro` na OS via hook */
  endereco_bairro: string
  endereco_cidade?: string
  endereco_estado?: string
  endereco_cep?: string
  ativo: boolean
  observacoes?: string
}

/* ---- disponibilidade (admin/gerente, por profissional) ---- */
export interface DisponibilidadeDia {
  ativo: boolean
  /** 'HH:MM' */
  inicio: string
  /** 'HH:MM' */
  fim: string
}

export interface Disponibilidade extends PBRecord {
  /** Relation → users */
  profissional: string
  duracao_min: number
  /** Array de 7 itens: índice 0 = Dom … 6 = Sáb */
  dias: [DisponibilidadeDia, DisponibilidadeDia, DisponibilidadeDia, DisponibilidadeDia, DisponibilidadeDia, DisponibilidadeDia, DisponibilidadeDia]
}

/* ---- config_atuacao (singleton, admin/gerente) ---- */
export interface ConfigAtuacaoCidade {
  nome: string
  principal: boolean
  bairros: string[]
}

export interface ConfigAtuacao extends PBRecord {
  estado: string
  cidades: ConfigAtuacaoCidade[]
}

/* ---- servicos (catálogo simples — LEGADO) ---- */
export interface Servico extends PBRecord {
  nome: string
  descricao?: string
  /** PLACEHOLDER — gate G-03 em aberto */
  preco_base: number
  ativo: boolean
  /** Taxonomia — presente na coleção PB desde migration 1700000008 */
  categoria?: Categoria | ''
  grupo?: Grupo | ''
}

/* ---- servicos (catálogo RICO) — contrato PB snake_case (Migrations 8 e 9) ----
 * O `Servico` legado acima continua válido para o catálogo simples. Este é o
 * shape RICO completo do módulo Serviços: taxonomia, valores, tempo médio,
 * checklist padrão e orientações. Campos legados são mantidos SINCRONIZADOS:
 *   preco_base = valor_base · ativo = (status === 'ativo').
 * Linhas ainda não enriquecidas (placeholders) podem trazer selects vazios ('').
 */
export interface ServicoPB extends PBRecord {
  /** referência estável (ex.: 'svc_veic_essencial') — única via índice parcial */
  slug: string
  categoria: Categoria | ''
  grupo: Grupo | ''
  nome: string
  /** descrição legada (opcional; o módulo rico usa `observacao`) */
  descricao?: string
  /** valor base canônico (ou limite inferior quando tipo_valor === 'faixa') */
  valor_base: number
  /** limite superior — usado quando tipo_valor === 'faixa' (0 = sem máximo) */
  valor_base_max?: number
  tipo_valor: TipoValor | ''
  /** tempo médio em minutos (limite superior; 0 = Variável) */
  tempo_medio_min?: number
  /** rótulo humano do tempo médio, ex.: '1h30 a 2h' */
  tempo_medio_label?: string
  status: ServicoStatus | ''
  observacao?: string
  /** itens do checklist padrão (template do serviço) */
  checklist_padrao?: ChecklistTemplateItem[]
  orientacoes_pre?: string
  orientacoes_pos?: string
  /** slugs de serviços adicionais sugeridos junto deste */
  adicionais_relacionados?: string[]
  /** 🔁 legado sincronizado = valor_base */
  preco_base: number
  /** 🔁 legado sincronizado = (status === 'ativo') */
  ativo: boolean
}

/* ---- ordens_servico ---- */
export interface OrdemServico extends PBRecord {
  /** Relation → clientes (ID opaco) */
  cliente: string
  /** "Carlos S." — denormalizado por hook */
  nome_curto: string
  /** endereco_bairro do cliente — denormalizado por hook */
  bairro: string
  /** Relation → servicos (ID) */
  servico?: string
  /** snapshot do nome do serviço — denormalizado por hook */
  tipo_servico_nome?: string
  /** ISO datetime UTC */
  data_hora: string
  /** Relation → users (ID) */
  profissional?: string
  status: OSStatus
  /** required:false no schema PB */
  valor_servico?: number
  /** Endereço completo — só preenchido quando status === 'em_andamento' */
  endereco_liberado?: string
  /** Preenchido pelo profissional ao concluir */
  valor_pago?: number
  forma_pagamento?: FormaPagamento
  /** Gerenciado manualmente pelo admin */
  repasse_status?: RepasseStatus
  repasse_valor?: number
  /** Preenchido pelo backend ao enviar aviso via WhatsApp */
  aviso_a_caminho_em?: string
  /** Nota do cliente (1–5), preenchida pelo backend após pesquisa */
  avaliacao_nota?: number
  /** Motivo informado pelo cliente em notas 1–3 */
  avaliacao_motivo?: string
  /** ISO datetime de quando o cliente respondeu a pesquisa */
  avaliacao_em?: string
  /** ISO datetime de quando a pesquisa foi enviada pelo backend */
  avaliacao_solicitada_em?: string
  observacoes?: string
  /* ---- campos RICOS do módulo Serviços/OS (Migration 8, JSON) ---- */
  /** snapshot IMUTÁVEL do serviço no instante da seleção (não muda se o catálogo mudar) */
  service_snapshot?: ServiceSnapshot
  /** checklist executável, marcável pelo profissional durante a execução */
  checklist_exec?: ChecklistExecItem[]
  /** serviços adicionais lançados dentro da OS */
  adicionais?: ServicoAdicionalOS[]
  /** observações técnicas do profissional — NÃO confundir com `observacoes` (texto livre) */
  observacoes_prof?: ObservacaoProfissional[]
  /** desconto (R$) aplicado no resumo financeiro da execução; abatido no total/relatório */
  descontos?: number
  /** ISO datetime de quando o relatório final foi enviado ao cliente */
  relatorio_enviado_em?: string
  expand?: {
    cliente?: Cliente
    profissional?: User
    servico?: Servico
  }
}

/* ---- os_evidencias — 🔒 COFRE (profissional só vê evidências de OS atribuídas a ele) ----
 * Fotos antes/durante/depois vinculadas a uma OS (Migration 8). `cascadeDelete`:
 * apagar a OS apaga automaticamente suas evidências. Vínculos opcionais permitem
 * amarrar a foto a um item do checklist, observação ou adicional específico.
 */
export interface OSEvidenciaPB extends PBRecord {
  /** Relation → ordens_servico (ID opaco) */
  os: string
  /** nome do arquivo de imagem (1 por registro, até ~5MB) */
  foto?: string
  fase?: FaseFoto | ''
  legenda?: string
  /** vínculo opcional a um item do checklist de execução (id dentro de checklist_exec) */
  checklist_item_id?: string
  /** vínculo opcional a uma observação do profissional (id dentro de observacoes_prof) */
  observacao_id?: string
  /** vínculo opcional a um serviço adicional (id dentro de adicionais) */
  adicional_id?: string
  /** Relation → users (ID) — quem enviou a foto */
  enviado_por?: string
  expand?: {
    os?: OrdemServico
    enviado_por?: User
  }
}

/* ---- Labels ---- */

export function osStatusLabel(status: OSStatus): string {
  const labels: Record<OSStatus, string> = {
    agendada: 'Agendada',
    atribuida: 'Atribuída',
    em_andamento: 'Em andamento',
    concluida: 'Concluída',
    cancelada: 'Cancelada',
  }
  return labels[status]
}

export function formaPagamentoLabel(forma: FormaPagamento): string {
  const labels: Record<FormaPagamento, string> = {
    debito: 'Débito',
    credito: 'Crédito',
    pix_maquininha: 'Pix (maquininha)',
  }
  return labels[forma]
}

export function repasseStatusLabel(s: RepasseStatus): string {
  return s === 'pago' ? 'Repassado' : 'Pendente'
}

export function userDisplayName(u?: { nome?: string; name?: string } | null): string {
  return (u?.nome && u.nome.trim()) || u?.name || '—'
}

/* ---- Formatadores ---- */

export function formatCurrency(value: number): string {
  return value.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
}

export function formatDate(iso: string): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('pt-BR')
}

export function formatDateTime(iso: string): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function formatTime(iso: string): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

/** Extrai só a parte YYYY-MM-DD de uma string ISO para uso em <input type="date"> */
export function toDateInputValue(iso: string): string {
  if (!iso) return ''
  return iso.slice(0, 10)
}

/** Converte <input type="datetime-local"> value (horário local BRT) para formato PB (UTC) */
export function localInputToPBDate(value: string): string {
  if (!value) return ''
  // new Date() interpreta o value como horário local; .toISOString() converte para UTC
  return new Date(value).toISOString().replace('T', ' ').slice(0, 19)
}

/** Converte data PB (UTC) para valor do <input type="datetime-local"> (horário local) */
export function pbDateToLocalInput(iso: string): string {
  if (!iso) return ''
  // Normaliza separador e força interpretação UTC (sem Z, Node parseia como local)
  const normalized = iso.replace(' ', 'T')
  const d = new Date(normalized.endsWith('Z') ? normalized : normalized + 'Z')
  const pad = (n: number) => String(n).padStart(2, '0')
  return (
    `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
    `T${pad(d.getHours())}:${pad(d.getMinutes())}`
  )
}

/** Limites UTC do dia corrente para filtros PB — calendário UTC puro (legado) */
export function getUtcDayBounds() {
  const now = new Date()
  const p = (n: number) => String(n).padStart(2, '0')
  const y = now.getUTCFullYear()
  const m = p(now.getUTCMonth() + 1)
  const d = p(now.getUTCDate())
  const tom = new Date(Date.UTC(y, now.getUTCMonth(), now.getUTCDate() + 1))
  return {
    todayStart: `${y}-${m}-${d} 00:00:00`,
    tomorrowStart: `${tom.getUTCFullYear()}-${p(tom.getUTCMonth() + 1)}-${p(tom.getUTCDate())} 00:00:00`,
  }
}

/** Limites do dia corrente baseados no calendário LOCAL (BRT = UTC-3).
 *  Converte meia-noite local para string UTC do PocketBase. */
export function getBrtDayBounds() {
  const now = new Date()
  const p = (n: number) => String(n).padStart(2, '0')
  const toUtcStr = (d: Date) =>
    `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:00`
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
  return { todayStart: toUtcStr(today), tomorrowStart: toUtcStr(tomorrow) }
}

/** Limites do mês (year, month) baseados no calendário LOCAL (BRT).
 *  month é 0-based (igual a Date.getMonth()). */
export function getBrtMonthBounds(year: number, month: number) {
  const p = (n: number) => String(n).padStart(2, '0')
  const toUtcStr = (d: Date) =>
    `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:00`
  return {
    start: toUtcStr(new Date(year, month, 1)),
    end: toUtcStr(new Date(year, month + 1, 1)),
  }
}

/** Formata horário de um ISO/PB datetime para exibição HH:MM */
export function formatHour(iso: string): string {
  if (!iso) return '--:--'
  return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
}

/* ---- Telefone BR ---- */

/** Máscara progressiva BR: (DD) NNNNN-NNNN (celular) ou (DD) NNNN-NNNN (fixo). */
export function maskPhoneBR(value: string): string {
  const digits = value.replace(/\D/g, '').slice(0, 11)
  const n = digits.length
  if (n === 0) return ''
  if (n <= 2) return `(${digits}`
  if (n <= 6) return `(${digits.slice(0, 2)}) ${digits.slice(2)}`
  if (n <= 10) return `(${digits.slice(0, 2)}) ${digits.slice(2, 6)}-${digits.slice(6)}`
  return `(${digits.slice(0, 2)}) ${digits.slice(2, 7)}-${digits.slice(7)}`
}

/** Retorna apenas os dígitos de um telefone (para validação/armazenamento). */
export function onlyDigitsPhone(value: string): string {
  return value.replace(/\D/g, '')
}

/** Data de hoje no fuso local como "YYYY-MM-DD" — para uso em <input type="date" min> */
export function todayLocalDate(): string {
  const now = new Date()
  const p = (n: number) => String(n).padStart(2, '0')
  return `${now.getFullYear()}-${p(now.getMonth() + 1)}-${p(now.getDate())}`
}

/* ---- Nome ---- */

/** Divide um nome completo no primeiro espaço: primeira palavra → nome, restante → sobrenome. */
export function splitNome(nomeCompleto: string): { nome: string; sobrenome: string } {
  const trimmed = nomeCompleto.trim()
  if (!trimmed) return { nome: '', sobrenome: '' }
  const idx = trimmed.indexOf(' ')
  if (idx === -1) return { nome: trimmed, sobrenome: '' }
  return { nome: trimmed.slice(0, idx), sobrenome: trimmed.slice(idx + 1).trim() }
}

/* ---- CEP BR ---- */

/* ---- Disponibilidade — geração de slots ---- */

/**
 * Gera os horários disponíveis para um profissional em um dia.
 * @param dia - config do dia (ativo, inicio 'HH:MM', fim 'HH:MM')
 * @param duracaoMin - duração de cada slot em minutos
 * @param horariosOcupados - 'HH:MM'[] de OS já agendadas (mesmo prof+data, não canceladas, OS em edição excluída)
 * @returns 'HH:MM'[] disponíveis, ordenados, ou [] se dia inativo
 */
export function gerarSlotsDisponiveis(
  dia: DisponibilidadeDia,
  duracaoMin: number,
  horariosOcupados: string[],
): string[] {
  if (!dia.ativo || duracaoMin <= 0) return []
  const toMin = (hhmm: string): number => {
    const [h, m] = hhmm.split(':').map(Number)
    return h * 60 + m
  }
  const inicioMin = toMin(dia.inicio)
  const fimMin = toMin(dia.fim)
  if (inicioMin >= fimMin) return []
  const ocupadosMin = horariosOcupados.map(toMin)
  const slots: string[] = []
  let cur = inicioMin
  while (cur + duracaoMin <= fimMin) {
    const colide = ocupadosMin.some(
      (o) => cur < o + duracaoMin && o < cur + duracaoMin,
    )
    if (!colide) {
      const h = Math.floor(cur / 60)
      const m = cur % 60
      slots.push(`${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`)
    }
    cur += 15
  }
  return slots
}

/** Máscara de CEP: NNNNN-NNN */
export function maskCEP(value: string): string {
  const digits = value.replace(/\D/g, '').slice(0, 8)
  if (digits.length <= 5) return digits
  return `${digits.slice(0, 5)}-${digits.slice(5)}`
}

/* ---- Módulo Financeiro — nomes das coleções e tipos PB (snake_case) ---- */

export const FIN_COLLECTIONS = {
  CONTAS: 'fin_contas',
  CATEGORIAS: 'fin_categorias',
  LANCAMENTOS: 'fin_lancamentos',
  LIMITES: 'fin_limites',
} as const

export interface FinContaPB extends PBRecord {
  nome: string
  tipo: ContaTipo
  saldo_inicial: number
  saldo_atual: number
  ativo: boolean
  /** Conta padrão para receita de OS (F-223 / migration 16). */
  padrao?: boolean
  cor?: string
  icone?: string
}

export interface FinCategoriaPB extends PBRecord {
  nome: string
  tipo: TipoLancamento
  icone?: string
  cor?: string
  parent_id?: string
  arquivada: boolean
}

export interface FinLancamentoPB extends PBRecord {
  tipo: TipoLancamento
  descricao: string
  categoria_id: string
  subcategoria_id?: string
  valor: number
  conta_id: string
  data: string
  vencimento?: string
  status: LancamentoStatus
  recorrencia: RecorrenciaTipo
  parcela_atual?: number
  parcelas_total?: number
  origem: OrigemLancamento
  os_id?: string
  os_numero?: string
  cliente_nome?: string
  servico_nome?: string
  forma_pagamento?: string
  observacao?: string
  tags?: string[]
  anexos?: Anexo[]
}

export interface FinLimitePB extends PBRecord {
  categoria_id: string
  limite: number
}
