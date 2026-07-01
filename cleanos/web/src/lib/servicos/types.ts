/**
 * servicos/types.ts — Contrato CANÔNICO do domínio "Serviços" e da integração Serviço → OS.
 *
 * Estes tipos são a FONTE DE VERDADE compartilhada entre as telas de Serviços,
 * o cadastro/edição, a OS (snapshot, checklist, adicionais, evidências, observações)
 * e o relatório final ao cliente. Outras panes importam DAQUI.
 *
 * Por enquanto os dados são MOCKADOS (ver ./seed e ./store), mas a estrutura já está
 * desenhada para virar coleções PocketBase depois (ver // TODO PB no store).
 *
 * ⚠️ Note que existe um `Servico` "placeholder" no catálogo legado em ../collections.ts
 *    (coleção `servicos` do PB). Este `Servico` é o modelo RICO do novo módulo. Ao importar
 *    os dois no mesmo arquivo, use alias (ex: `import type { Servico as ServicoCatalogo } ...`).
 */

/* ---- Taxonomia do serviço ---- */

/** Categoria macro do serviço. */
export type Categoria = 'veicular' | 'residencial'

/** Grupo/agrupador comercial dentro da categoria. */
export type Grupo =
  | 'plano'
  | 'promocao'
  | 'adicional'
  | 'avulsos'
  | 'sofa'
  | 'colchao'
  | 'outros'

/** Como o valor base deve ser interpretado. */
export type TipoValor = 'fixo' | 'faixa' | 'variavel'

/** Status de publicação do serviço no catálogo. */
export type ServicoStatus = 'ativo' | 'inativo'

/* ---- Checklist padrão (template no cadastro do serviço) ---- */

/** Item do checklist PADRÃO definido no cadastro do serviço (template). */
export interface ChecklistTemplateItem {
  id: string
  titulo: string
  /** Ordem de exibição/execução (1-based). */
  ordem: number
  /** Se true, o item DEVE estar concluído antes de concluir a OS. */
  obrigatorio?: boolean
}

/* ---- Serviço (catálogo rico) ---- */

/** Serviço cadastrado no catálogo. Alimenta orçamento, agendamento e OS. */
export interface Servico {
  id: string
  categoria: Categoria
  grupo: Grupo
  nome: string
  /** Valor base (ou limite inferior quando tipoValor === 'faixa'). */
  valorBase: number
  /** Limite superior — usado quando tipoValor === 'faixa'. */
  valorBaseMax?: number
  tipoValor: TipoValor
  /** Tempo médio em minutos (limite superior parseado); undefined p/ 'Variável'. */
  tempoMedioMin?: number
  /** Rótulo humano do tempo médio, ex "1h30 a 2h", "Variável". */
  tempoMedioLabel: string
  status: ServicoStatus
  /** Observação comercial/técnica exibida ao atendente. */
  observacao?: string
  checklistPadrao: ChecklistTemplateItem[]
  orientacoesPre?: string
  orientacoesPos?: string
  /** IDs de outros serviços (grupos adicional/avulsos/outros) sugeridos junto deste. */
  adicionaisRelacionados: string[]
  created: string
  updated: string
}

/* ---- Snapshot do serviço dentro da OS ---- */

/**
 * Cópia congelada dos dados do serviço no momento em que ele é selecionado na OS.
 * A OS NÃO referencia o serviço original — guarda este snapshot — para que alterações
 * futuras no cadastro NÃO afetem OS antigas.
 */
export interface ServiceSnapshot {
  serviceId: string
  nome: string
  categoria: Categoria
  grupo: Grupo
  valorBase: number
  valorBaseMax?: number
  tipoValor: TipoValor
  tempoMedioMin?: number
  tempoMedioLabel: string
  /** Equivale a Servico.observacao no instante da captura. */
  observacaoTecnica?: string
  checklistPadrao: ChecklistTemplateItem[]
  /** Equivale a Servico.orientacoesPre no instante da captura. */
  orientacoesPreServico?: string
  /** Equivale a Servico.orientacoesPos no instante da captura. */
  orientacoesPosServico?: string
  /** ISO datetime de quando o snapshot foi capturado. */
  capturedAt: string
}

/* ---- Checklist de execução (na OS, marcável pelo profissional) ---- */

export type ChecklistExecStatus = 'pendente' | 'concluido'

/** Item executável do checklist DENTRO da OS (derivado do snapshot). */
export interface ChecklistExecItem {
  id: string
  titulo: string
  status: ChecklistExecStatus
  observacao?: string
  /** ISO datetime de conclusão. */
  concluidoEm?: string
  /** ID/nome do profissional que concluiu. */
  concluidoPor?: string
  /** IDs de EvidenciaFoto vinculadas a este item. */
  fotosIds?: string[]
  /** Propagado do template: se true, bloqueia conclusão da OS enquanto pendente. */
  obrigatorio?: boolean
}

/* ---- Serviços adicionais na OS ---- */

export type AprovacaoStatus = 'nao_requer' | 'aguardando' | 'aprovado' | 'recusado'

/** Serviço extra adicionado dentro de uma OS (pode ou não vir do catálogo). */
export interface ServicoAdicionalOS {
  id: string
  /** Presente quando o adicional veio do catálogo de serviços. */
  serviceId?: string
  nome: string
  categoria?: Categoria
  grupo?: Grupo
  valor: number
  tipoValor: TipoValor
  quantidade: number
  /** Motivo da cobrança (ex "Excesso de sujeira"). */
  motivo?: string
  observacao?: string
  aprovacao: AprovacaoStatus
}

/* ---- Evidências (fotos antes/durante/depois) ---- */

export type FaseFoto = 'antes' | 'durante' | 'depois'

/** Foto/evidência anexada à OS, opcionalmente vinculada a um item/observação/adicional. */
export interface EvidenciaFoto {
  id: string
  /** objectURL / base64 no mock; futuramente URL do arquivo no PB. */
  url: string
  fase: FaseFoto
  legenda?: string
  /** ISO datetime do envio. */
  criadoEm: string
  enviadoPor?: string
  /** Vínculo opcional a um item do checklist de execução. */
  checklistItemId?: string
  /** Vínculo opcional a uma observação do profissional. */
  observacaoId?: string
  /** Vínculo opcional a um serviço adicional. */
  adicionalId?: string
}

/* ---- Observações do profissional ---- */

export type ObservacaoTipo =
  | 'geral'
  | 'ponto'
  | 'limitacao'
  | 'recomendacao'
  | 'intercorrencia'
  | 'revisao'

/** Observação técnica registrada pelo profissional na OS. */
export interface ObservacaoProfissional {
  id: string
  texto: string
  /** Se true, aparece no relatório final ao cliente. */
  visivelCliente: boolean
  tipo?: ObservacaoTipo
  criadoPor?: string
  /** ISO datetime. */
  criadoEm: string
  /** IDs de EvidenciaFoto vinculadas. */
  fotosIds?: string[]
}

/* ---- Relatório final ao cliente ---- */

/**
 * Pacote pronto para gerar/enviar o resumo da OS ao cliente (digital, WhatsApp ou PDF).
 * Agrega tudo que o cliente precisa ver: dados da OS, snapshot do serviço, adicionais
 * aprovados, checklist executado, evidências, observações visíveis, orientações pós,
 * texto padrão e o prazo de 3 dias para relatar intercorrências.
 */
export interface RelatorioOS {
  osId: string
  /** Número/código humano da OS, se houver. */
  numeroOS?: string

  /* dados do atendimento */
  clienteNome: string
  clienteTelefone?: string
  enderecoCompleto?: string
  bairro?: string
  profissionalNome?: string
  /** ISO datetime do agendamento/execução. */
  dataHora: string

  /* serviço principal (congelado) */
  snapshot: ServiceSnapshot

  /* adicionais (apenas os que contam para o cliente, ex aprovados/não-requer) */
  adicionais: ServicoAdicionalOS[]

  /* execução */
  checklist: ChecklistExecItem[]
  evidencias: EvidenciaFoto[]
  /** Somente observações com visivelCliente === true. */
  observacoesVisiveis: ObservacaoProfissional[]
  orientacoesPos?: string

  /* valores */
  valorPrincipal: number
  valorAdicionais: number
  descontos?: number
  valorTotal: number

  /* rodapé padrão */
  textoPadrao: string
  /** Prazo (em dias) para o cliente relatar intercorrências. Padrão: 3. */
  prazoIntercorrenciaDias: number

  /* feedback do cliente */
  avaliacaoNota?: number
  /** ISO datetime de quando o relatório foi gerado. */
  geradoEm: string
}

/** Entrada de criação de serviço (sem campos gerenciados pela store). */
export type ServicoInput = Omit<Servico, 'id' | 'created' | 'updated'>
