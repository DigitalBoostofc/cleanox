/**
 * collections.ts — Contrato CANÔNICO de coleções do PocketBase (fonte: cleanos/pb/README.md)
 * ÚNICO ponto de verdade dos nomes de coleções e tipos no frontend.
 */

/* ---- Nomes das coleções ---- */
export const COLLECTIONS = {
  USERS: 'users',
  CLIENTES: 'clientes',
  SERVICOS: 'servicos',
  ORDENS_SERVICO: 'ordens_servico',
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
  endereco_cep?: string
  ativo: boolean
  observacoes?: string
}

/* ---- servicos (catálogo) ---- */
export interface Servico extends PBRecord {
  nome: string
  descricao?: string
  /** PLACEHOLDER — gate G-03 em aberto */
  preco_base: number
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
  observacoes?: string
  expand?: {
    cliente?: Cliente
    profissional?: User
    servico?: Servico
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

/** Limites UTC do dia corrente para filtros PB (convenção UTC-3 = BRT) */
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

/** Formata horário de um ISO/PB datetime para exibição HH:MM */
export function formatHour(iso: string): string {
  if (!iso) return '--:--'
  return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
}
