/**
 * os/relatorioOS.ts — Montagem do RELATÓRIO FINAL da OS ao cliente.
 *
 * Pega os dados crus da execução (snapshot do serviço, adicionais, checklist,
 * evidências e observações do profissional) e produz um {@link RelatorioOS}
 * pronto para pré-visualizar, enviar por WhatsApp ou virar PDF.
 *
 * Toda a lógica é PURA e síncrona — não toca rede nem DOM. As regras financeiras
 * reaproveitam {@link calcTotalOS} para ficar consistentes com o resto da OS.
 *
 * Os dados vêm da OS REAL no PocketBase (service_snapshot, checklist_exec,
 * adicionais e observacoes_prof em `ordens_servico`; evidências em `os_evidencias`
 * com URLs reais). Estas funções permanecem puras: o caller (página de execução /
 * modal) é quem materializa o {@link BuildRelatorioOSInput} a partir do registro PB.
 * O ENVIO em si é server-side (POST /api/cleanos/os/{id}/relatorio, infra uazapi);
 * {@link buildWhatsAppMessage} serve a pré-visualização/cópia no cliente.
 */

import type {
  ChecklistExecItem,
  EvidenciaFoto,
  ObservacaoProfissional,
  RelatorioOS,
  ServiceSnapshot,
  ServicoAdicionalOS,
} from '../servicos/types'
import {
  RELATORIO_PRAZO_DIAS,
  RELATORIO_TEXTO_PADRAO,
  aprovacaoLabel,
  formatTempoMedio,
} from '../servicos/labels'
import { calcTotalOS } from '../servicos/store'
import { formatCurrency, formatDateTime } from '../collections'

/** Entrada de {@link buildRelatorioOS}. Campos derivados são calculados aqui. */
export interface BuildRelatorioOSInput {
  osId: string
  numeroOS?: string
  clienteNome: string
  clienteTelefone?: string
  enderecoCompleto?: string
  bairro?: string
  profissionalNome?: string
  /** ISO datetime do agendamento/execução. */
  dataHora: string
  snapshot: ServiceSnapshot
  adicionais: ServicoAdicionalOS[]
  checklist: ChecklistExecItem[]
  evidencias: EvidenciaFoto[]
  observacoes: ObservacaoProfissional[]
  descontos?: number
  avaliacaoNota?: number
}

/**
 * Um adicional entra na cobrança (e no relatório do cliente) quando está
 * 'aprovado' ou 'nao_requer'. 'aguardando'/'recusado' não contam.
 * Mesma regra de {@link calcTotalOS}.
 */
function isAdicionalCobravel(a: ServicoAdicionalOS): boolean {
  return a.aprovacao === 'aprovado' || a.aprovacao === 'nao_requer'
}

/**
 * Monta o pacote {@link RelatorioOS} a partir dos dados da execução.
 *
 * Regras:
 *  - `observacoesVisiveis` = só observações com `visivelCliente === true`.
 *  - `adicionais` = só os cobráveis (aprovado/nao_requer) — é o que o cliente vê.
 *  - `valorPrincipal` = snapshot.valorBase.
 *  - `valorAdicionais` = Σ (valor × quantidade) dos adicionais cobráveis.
 *  - `valorTotal` = calcTotalOS(principal, adicionais, descontos) (nunca negativo).
 *  - `orientacoesPos` = snapshot.orientacoesPosServico.
 *  - `textoPadrao` / `prazoIntercorrenciaDias` = constantes do módulo.
 *  - `geradoEm` = agora (ISO).
 */
export function buildRelatorioOS(input: BuildRelatorioOSInput): RelatorioOS {
  const adicionaisCobraveis = input.adicionais.filter(isAdicionalCobravel)

  const valorPrincipal = input.snapshot.valorBase
  const valorAdicionais = adicionaisCobraveis.reduce(
    (sum, a) => sum + a.valor * a.quantidade,
    0,
  )
  const valorTotal = calcTotalOS(
    valorPrincipal,
    input.adicionais,
    input.descontos,
  )

  return {
    osId: input.osId,
    numeroOS: input.numeroOS,

    clienteNome: input.clienteNome,
    clienteTelefone: input.clienteTelefone,
    enderecoCompleto: input.enderecoCompleto,
    bairro: input.bairro,
    profissionalNome: input.profissionalNome,
    dataHora: input.dataHora,

    snapshot: input.snapshot,
    adicionais: adicionaisCobraveis,

    checklist: input.checklist,
    evidencias: input.evidencias,
    observacoesVisiveis: input.observacoes.filter((o) => o.visivelCliente),
    orientacoesPos: input.snapshot.orientacoesPosServico,

    valorPrincipal,
    valorAdicionais,
    descontos: input.descontos,
    valorTotal,

    textoPadrao: RELATORIO_TEXTO_PADRAO,
    prazoIntercorrenciaDias: RELATORIO_PRAZO_DIAS,

    avaliacaoNota: input.avaliacaoNota,
    geradoEm: new Date().toISOString(),
  }
}

/**
 * Link de avaliação enviado ao cliente. Aponta para o domínio real de produção
 * (app.cleanox.com.br) na rota /avaliar/{osId}.
 */
export function avaliacaoLink(rel: RelatorioOS): string {
  return `https://app.cleanox.com.br/avaliar/${encodeURIComponent(rel.osId)}`
}

/**
 * Texto formatado para envio por WhatsApp (emojis discretos, markdown leve do
 * WhatsApp com *negrito*). Resume serviço, adicionais, total, checklist
 * executado, orientações pós, prazo de intercorrência e link de avaliação.
 */
export function buildWhatsAppMessage(rel: RelatorioOS): string {
  const lines: string[] = []

  const numero = rel.numeroOS ? ` Nº ${rel.numeroOS}` : ''
  lines.push(`🧼 *Cleanox — Relatório de Serviço${numero}*`)
  lines.push('')
  lines.push(`Olá, ${rel.clienteNome}! Seu serviço foi concluído. ✅`)
  lines.push('Segue o resumo do que foi executado:')
  lines.push('')

  /* Serviço principal */
  lines.push(`🛠️ *Serviço:* ${rel.snapshot.nome}`)
  const tempo = formatTempoMedio(
    rel.snapshot.tempoMedioMin,
    rel.snapshot.tempoMedioLabel,
  )
  if (tempo) lines.push(`⏱️ Tempo médio: ${tempo}`)
  lines.push(`📅 Data: ${formatDateTime(rel.dataHora)}`)
  if (rel.profissionalNome) {
    lines.push(`👤 Profissional: ${rel.profissionalNome}`)
  }
  lines.push('')

  /* Adicionais (só os cobráveis, já filtrados na montagem) */
  if (rel.adicionais.length > 0) {
    lines.push('➕ *Serviços adicionais:*')
    for (const a of rel.adicionais) {
      const qtd = a.quantidade > 1 ? ` (x${a.quantidade})` : ''
      const subtotal = formatCurrency(a.valor * a.quantidade)
      lines.push(`   • ${a.nome}${qtd} — ${subtotal} · ${aprovacaoLabel(a.aprovacao)}`)
    }
    lines.push('')
  }

  /* Resumo financeiro */
  lines.push('💰 *Resumo financeiro:*')
  lines.push(`   Serviço: ${formatCurrency(rel.valorPrincipal)}`)
  if (rel.valorAdicionais > 0) {
    lines.push(`   Adicionais: ${formatCurrency(rel.valorAdicionais)}`)
  }
  if (rel.descontos && rel.descontos > 0) {
    lines.push(`   Descontos: -${formatCurrency(rel.descontos)}`)
  }
  lines.push(`   *Total: ${formatCurrency(rel.valorTotal)}*`)
  lines.push('')

  /* Checklist executado */
  const concluidos = rel.checklist.filter((c) => c.status === 'concluido')
  const pendentes = rel.checklist.filter((c) => c.status !== 'concluido')
  if (rel.checklist.length > 0) {
    lines.push(
      `📋 *Checklist executado* (${concluidos.length}/${rel.checklist.length}):`,
    )
    for (const item of concluidos) {
      lines.push(`   ✓ ${item.titulo}`)
    }
    for (const item of pendentes) {
      lines.push(`   ◻️ ${item.titulo} (pendente)`)
    }
    lines.push('')
  }

  /* Observações visíveis ao cliente */
  if (rel.observacoesVisiveis.length > 0) {
    lines.push('📝 *Observações:*')
    for (const obs of rel.observacoesVisiveis) {
      lines.push(`   • ${obs.texto}`)
    }
    lines.push('')
  }

  /* Orientações pós-serviço */
  if (rel.orientacoesPos && rel.orientacoesPos.trim()) {
    lines.push('🧴 *Orientações pós-serviço:*')
    lines.push(`   ${rel.orientacoesPos.trim()}`)
    lines.push('')
  }

  /* Prazo de intercorrência */
  lines.push(
    `⏳ Você tem até *${rel.prazoIntercorrenciaDias} dias* para relatar ` +
      'qualquer falha ou intercorrência. Conte com a gente!',
  )
  lines.push('')

  /* Avaliação */
  lines.push(`⭐ Avalie nosso atendimento: ${avaliacaoLink(rel)}`)
  lines.push('')
  lines.push('Obrigado por escolher a Cleanox! 💙')

  return lines.join('\n')
}
