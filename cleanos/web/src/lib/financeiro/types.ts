/**
 * financeiro/types.ts — Contrato CANÔNICO do módulo Financeiro do CleanOS.
 *
 * Estes tipos são a FONTE DE VERDADE compartilhada entre as telas do Financeiro
 * (Visão geral, Lançamentos, Contas a pagar/receber, Categorias, Relatórios,
 * Limite de gastos, Contas/Carteiras). As 5+ panes de UI importam DAQUI — os
 * nomes principais (Lancamento, Conta, Categoria, LimiteGasto e seus unions)
 * são ESTÁVEIS e não devem mudar sem alinhar com os consumidores.
 *
 * Por enquanto os dados são MOCKADOS (ver ./seed e ./store, persistidos em
 * localStorage), mas a estrutura já está desenhada para virar coleções
 * PocketBase depois (ver // TODO PB no store). A intenção é que a troca do
 * backend NÃO altere este contrato.
 *
 * ⚠️ Existe outra `Categoria` no domínio Serviços (../servicos/types) e em
 *    ../collections. Esta `Categoria` é a de CATEGORIA FINANCEIRA. Ao importar
 *    as duas no mesmo arquivo, use alias (ex.: `import type { Categoria as
 *    CategoriaFinanceira } from '../lib/financeiro/types'`).
 */

/* ============================================================
 * Unions de domínio
 * ============================================================ */

/** Natureza do lançamento. O SINAL do valor deriva daqui (receita=+, despesa=−). */
export type TipoLancamento = 'receita' | 'despesa'

/** Como o lançamento se repete no tempo. */
export type RecorrenciaTipo = 'unica' | 'fixa' | 'recorrente' | 'parcelada'

/** Situação financeira do lançamento. */
export type LancamentoStatus = 'pago' | 'pendente' | 'previsto' | 'em_atraso'

/** Como o lançamento entrou no sistema (digitado à mão ou gerado por uma OS). */
export type OrigemLancamento = 'manual' | 'via_os'

/** Tipo da conta/carteira onde o dinheiro entra ou sai. */
export type ContaTipo = 'carteira' | 'banco' | 'cartao' | 'caixa'

/* ============================================================
 * Registro base
 * ============================================================ */

/** Campos comuns de auditoria (espelha o PBRecord do PocketBase). */
export interface FinRecord {
  id: string
  /** ISO datetime de criação. */
  created: string
  /** ISO datetime da última alteração. */
  updated: string
}

/* ============================================================
 * Conta / Carteira
 * ============================================================ */

/** Conta ou carteira onde o saldo é movimentado (Carteira, Banco, Cartão, Caixa). */
export interface Conta extends FinRecord {
  nome: string
  tipo: ContaTipo
  /** Saldo no momento do cadastro (base do cálculo). */
  saldoInicial: number
  /** Saldo corrente (saldoInicial ± movimentações). Por ora vem do seed/store. */
  saldoAtual: number
  ativo: boolean
  /**
   * Conta PADRÃO para receita de OS (F-223): o hook OS→Financeiro credita a receita
   * na conta ativa marcada `padrao`. Só UMA conta é padrão por vez (garantido pela
   * rota server-side que desmarca as demais atomicamente).
   */
  padrao?: boolean
  /** Cor de destaque (hex) para o badge/ícone na UI. */
  cor?: string
  /** Nome lógico do ícone (convenção lucide-react) para a UI mapear. */
  icone?: string
}

/* ============================================================
 * Categoria (e subcategoria via parentId)
 * ============================================================ */

/**
 * Categoria financeira. Uma SUBcategoria é uma Categoria com `parentId` apontando
 * para a categoria-mãe (ex.: "Tráfego Pago Google" tem parentId = "cat_marketing").
 * O `tipo` separa categorias de despesa das de receita.
 */
export interface Categoria extends FinRecord {
  nome: string
  tipo: TipoLancamento
  /** Nome lógico do ícone (convenção lucide-react) — a UI mapeia para o componente. */
  icone: string
  /** Cor de fundo do ícone circular (hex). */
  cor: string
  /** ID da categoria-mãe quando este registro é uma subcategoria. */
  parentId?: string
  /** Categoria arquivada (oculta dos novos lançamentos, mantida no histórico). */
  arquivada: boolean
}

/* ============================================================
 * Anexo (comprovante)
 * ============================================================ */

/** Comprovante anexado a um lançamento (imagem/PDF). `url` pode ser data-URL no mock. */
export interface Anexo {
  id: string
  nome: string
  url: string
  /** Tamanho em bytes, quando conhecido. */
  tamanho?: number
}

/* ============================================================
 * Lançamento (receita ou despesa)
 * ============================================================ */

/**
 * Lançamento financeiro — unidade central do módulo.
 *
 * IMPORTANTE: `valor` é SEMPRE positivo; o sinal (entrada/saída) vem de `tipo`.
 * Use os helpers signedValue/formatSigned (../financeiro/labels) para exibição.
 */
export interface Lancamento extends FinRecord {
  tipo: TipoLancamento
  descricao: string
  /** ID da categoria principal (pode ser uma categoria-mãe). */
  categoriaId: string
  /** ID da subcategoria escolhida (filha de categoriaId), quando houver. */
  subcategoriaId?: string
  /** SEMPRE positivo. O sinal vem de `tipo`. */
  valor: number
  /** ID da conta/carteira movimentada. */
  contaId: string
  /** ISO — data de competência/pagamento do lançamento. */
  data: string
  /** ISO — data de vencimento (contas a pagar/receber). */
  vencimento?: string
  status: LancamentoStatus
  recorrencia: RecorrenciaTipo
  /** Parcela corrente (1-based) quando recorrencia === 'parcelada'. */
  parcelaAtual?: number
  /** Total de parcelas quando recorrencia === 'parcelada'. */
  parcelasTotal?: number
  origem: OrigemLancamento
  /* ---- Vínculo com Ordem de Serviço (apenas quando origem === 'via_os') ---- */
  /** ID da OS de origem. */
  osId?: string
  /** Número humano da OS (ex.: "000245"). */
  osNumero?: string
  /** Nome do cliente da OS (denormalizado). */
  clienteNome?: string
  /** Serviço contratado na OS (denormalizado). */
  servicoNome?: string
  /* ---- Extras ---- */
  /** Forma de pagamento (texto livre: "Pix", "Crédito", "Dinheiro"…). */
  formaPagamento?: string
  observacao?: string
  anexos?: Anexo[]
  tags?: string[]
}

/* ============================================================
 * Limite de gastos por categoria
 * ============================================================ */

/**
 * Teto de gasto para uma categoria. O `gastoAtual` NÃO é armazenado — é DERIVADO
 * dos lançamentos no período (ver progressoLimite em ../financeiro/store).
 */
export interface LimiteGasto extends FinRecord {
  /** Categoria (ou subcategoria) sob limite. */
  categoriaId: string
  /** Teto de gasto no período (positivo). */
  limite: number
}

/* ============================================================
 * Inputs de criação/edição (sem campos gerenciados pelo store)
 * ============================================================ */

export type LancamentoInput = Omit<Lancamento, 'id' | 'created' | 'updated'>
export type ContaInput = Omit<Conta, 'id' | 'created' | 'updated'>
export type CategoriaInput = Omit<Categoria, 'id' | 'created' | 'updated'>
export type LimiteInput = Omit<LimiteGasto, 'id' | 'created' | 'updated'>

/* ============================================================
 * Tipos de RESULTADO das derivações (../financeiro/store)
 * Fazem parte do contrato: as panes tipam o estado com eles.
 * ============================================================ */

/** Janela de tempo half-open [start, end) — ISO date 'YYYY-MM-DD' (ou datetime). */
export interface Periodo {
  /** Início inclusivo. */
  start: string
  /** Fim EXCLUSIVO (ex.: primeiro dia do mês seguinte). */
  end: string
}

/** Resultado de resumoPeriodo: totais realizados (status 'pago') do período. */
export interface ResumoPeriodo {
  /** Σ receitas pagas. */
  entradas: number
  /** Σ despesas pagas. */
  saidas: number
  /** entradas − saidas. */
  saldoMes: number
}

/** Grupo de lançamentos de um mesmo dia (Lançamentos estilo Organizze). */
export interface GrupoPorData {
  /** Data 'YYYY-MM-DD' do grupo. */
  data: string
  /** Lançamentos do dia (ordem de inserção do array de origem). */
  itens: Lancamento[]
  /** Soma COM sinal dos itens do dia (receitas − despesas). */
  totalDia: number
}

/** Item de "Contas a pagar/receber": o lançamento + flags derivadas vs. uma data. */
export interface ContaPendente {
  lancamento: Lancamento
  /** Vencimento === data de referência (mesmo dia). */
  vencendoHoje: boolean
  /** Não pago e vencimento anterior à data de referência (ou status 'em_atraso'). */
  emAtraso: boolean
}

/** Progresso de um limite de gasto: quanto já foi gasto vs. o teto. */
export interface ProgressoLimite {
  /** Total gasto (despesas pagas) na categoria do limite. */
  gasto: number
  /** Teto configurado. */
  limite: number
  /** gasto / limite, clampado em [0, 1]. 0 quando limite ≤ 0. */
  pct: number
}
