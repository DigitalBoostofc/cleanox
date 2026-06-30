/**
 * servicos/seed.ts — Dados iniciais (mock) do catálogo de serviços da Cleanox.
 * 32 serviços: 15 veiculares + 17 residenciais. IDs estáveis (ex: 'svc_veic_essencial').
 *
 * tempoMedioMin é DERIVADO de tempoMedioLabel via parseTempoMedio (limite superior),
 * garantindo que rótulo e minutos nunca divirjam.
 */

import { parseTempoMedio } from './labels'
import type {
  Categoria,
  ChecklistTemplateItem,
  Grupo,
  Servico,
  ServicoStatus,
  TipoValor,
} from './types'

/** Timestamp fixo do seed (determinístico). */
const SEED_TS = '2025-01-01 00:00:00.000Z'

/* ---- Helpers de construção ---- */

interface SeedInput {
  id: string
  categoria: Categoria
  grupo: Grupo
  nome: string
  valorBase: number
  valorBaseMax?: number
  tipoValor: TipoValor
  tempoMedioLabel: string
  observacao?: string
  checklistPadrao?: ChecklistTemplateItem[]
  orientacoesPre?: string
  orientacoesPos?: string
  adicionaisRelacionados?: string[]
  status?: ServicoStatus
}

/** Monta um Servico completo a partir do mínimo, preenchendo defaults. */
function svc(input: SeedInput): Servico {
  return {
    id: input.id,
    categoria: input.categoria,
    grupo: input.grupo,
    nome: input.nome,
    valorBase: input.valorBase,
    valorBaseMax: input.valorBaseMax,
    tipoValor: input.tipoValor,
    tempoMedioMin: parseTempoMedio(input.tempoMedioLabel),
    tempoMedioLabel: input.tempoMedioLabel,
    status: input.status ?? 'ativo',
    observacao: input.observacao,
    checklistPadrao: input.checklistPadrao ?? [],
    orientacoesPre: input.orientacoesPre,
    orientacoesPos: input.orientacoesPos,
    adicionaisRelacionados: input.adicionaisRelacionados ?? [],
    created: SEED_TS,
    updated: SEED_TS,
  }
}

/** Gera itens de checklist com IDs estáveis derivados do serviceId. */
function mkChecklist(serviceId: string, titulos: string[]): ChecklistTemplateItem[] {
  return titulos.map((titulo, i) => ({
    id: `chk_${serviceId}_${i + 1}`,
    titulo,
    ordem: i + 1,
  }))
}

/* ---- Orientações reaproveitadas ---- */

const ORIENT_PRE_PREMIUM =
  'Garantir ponto de energia e ponto de água no local. Remover objetos pessoais do ' +
  'veículo para melhor execução do serviço.'

const ORIENT_POS_PREMIUM =
  'Tempo de secagem de 2 a 6 horas, dependendo do clima e do nível da higienização ' +
  'realizada. Prazo de até 3 dias para relatar qualquer intercorrência.'

const ORIENT_POS_VEICULAR =
  'Tempo de secagem de 2 a 6 horas, dependendo do clima e do nível da higienização. ' +
  'Prazo de até 3 dias para relatar qualquer intercorrência.'

const ORIENT_POS_RESIDENCIAL =
  'Tempo de secagem de 4 a 8 horas. Evite o uso da peça antes da secagem completa. ' +
  'Prazo de até 3 dias para relatar qualquer intercorrência.'

/* ---- Títulos de checklist (transcritos da spec) ---- */

const TIT_ESSENCIAL = [
  'Fotos de antes',
  'Conferência inicial do veículo',
  'Aspiração inicial',
  'Higienização dos bancos',
  'Aspiração do carpete, porta-malas e tapetes',
  'Conferência final',
  'Fotos de depois',
]

const TIT_COMPLETO = [
  'Fotos de antes',
  'Conferência inicial do veículo',
  'Proteção e organização da área de trabalho',
  'Aspiração inicial',
  'Higienização dos bancos',
  'Higienização do teto',
  'Higienização do quebra-sol',
  'Higienização dos cintos',
  'Higienização dos forros das portas',
  'Aspiração do carpete, porta-malas e tapetes',
  'Conferência final',
  'Fotos de depois',
]

const TIT_PREMIUM = [
  'Fotos de antes',
  'Conferência inicial do veículo',
  'Proteção e organização da área de trabalho',
  'Aspiração inicial completa',
  'Higienização dos bancos frente e trás',
  'Higienização do teto',
  'Higienização dos quebra-sóis',
  'Higienização dos cintos de segurança',
  'Higienização dos forros de porta',
  'Higienização do carpete',
  'Higienização do porta-malas',
  'Higienização dos tapetes',
  'Revitalização de painel e partes plásticas',
  'Conferência final',
  'Fotos de depois',
  'Validação com o cliente',
]

/** Checklist mínimo coerente para serviços avulsos veiculares. */
const TIT_AVULSO_VEICULAR = [
  'Fotos de antes',
  'Higienização do item contratado',
  'Conferência final',
  'Fotos de depois',
]

/** Checklist mínimo coerente para peças residenciais. */
const TIT_RESIDENCIAL = [
  'Fotos de antes',
  'Conferência inicial da peça',
  'Pré-tratamento de manchas',
  'Higienização e extração',
  'Conferência final',
  'Fotos de depois',
]

/* ---- VEICULAR (15) ---- */

const VEICULAR: Servico[] = [
  svc({
    id: 'svc_veic_essencial',
    categoria: 'veicular',
    grupo: 'plano',
    nome: 'Cleanox Essencial',
    valorBase: 150,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h30 a 2h',
    observacao: 'Pacote de entrada, focado em bancos + aspiração.',
    checklistPadrao: mkChecklist('svc_veic_essencial', TIT_ESSENCIAL),
    orientacoesPos: ORIENT_POS_VEICULAR,
    adicionaisRelacionados: [
      'svc_veic_muito_sujo',
      'svc_veic_deslocamento',
      'svc_veic_teto',
      'svc_veic_carpete_higien',
    ],
  }),
  svc({
    id: 'svc_veic_completo',
    categoria: 'veicular',
    grupo: 'plano',
    nome: 'Cleanox Completo',
    valorBase: 220,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h30 a 2h30',
    observacao:
      'Inclui bancos, teto, quebra-sol, cintos, forros das portas e aspiração.',
    checklistPadrao: mkChecklist('svc_veic_completo', TIT_COMPLETO),
    orientacoesPos: ORIENT_POS_VEICULAR,
    adicionaisRelacionados: [
      'svc_veic_muito_sujo',
      'svc_veic_deslocamento',
      'svc_veic_painel',
      'svc_veic_carpete_higien',
    ],
  }),
  svc({
    id: 'svc_veic_premium',
    categoria: 'veicular',
    grupo: 'plano',
    nome: 'Cleanox Premium',
    valorBase: 300,
    tipoValor: 'fixo',
    tempoMedioLabel: '3h a 4h',
    observacao:
      'Serviço mais detalhado, adicionando higienização do carpete e revitalização das ' +
      'partes plásticas ao pacote completo.',
    checklistPadrao: mkChecklist('svc_veic_premium', TIT_PREMIUM),
    orientacoesPre: ORIENT_PRE_PREMIUM,
    orientacoesPos: ORIENT_POS_PREMIUM,
    adicionaisRelacionados: ['svc_veic_muito_sujo', 'svc_veic_deslocamento'],
  }),
  svc({
    id: 'svc_veic_completo_promo',
    categoria: 'veicular',
    grupo: 'promocao',
    nome: 'Cleanox Completo - Promoção',
    valorBase: 200,
    tipoValor: 'fixo',
    tempoMedioLabel: '2h',
    observacao: 'Versão promocional do Cleanox Completo.',
    checklistPadrao: mkChecklist('svc_veic_completo_promo', TIT_COMPLETO),
    orientacoesPos: ORIENT_POS_VEICULAR,
    adicionaisRelacionados: ['svc_veic_muito_sujo', 'svc_veic_deslocamento'],
  }),
  svc({
    id: 'svc_veic_premium_promo',
    categoria: 'veicular',
    grupo: 'promocao',
    nome: 'Cleanox Premium - Promoção',
    valorBase: 250,
    tipoValor: 'fixo',
    tempoMedioLabel: '2h a 3h',
    observacao: 'Versão promocional do Cleanox Premium.',
    checklistPadrao: mkChecklist('svc_veic_premium_promo', TIT_PREMIUM),
    orientacoesPre: ORIENT_PRE_PREMIUM,
    orientacoesPos: ORIENT_POS_PREMIUM,
    adicionaisRelacionados: ['svc_veic_muito_sujo', 'svc_veic_deslocamento'],
  }),
  svc({
    id: 'svc_veic_muito_sujo',
    categoria: 'veicular',
    grupo: 'adicional',
    nome: 'Veículo muito sujo',
    valorBase: 50,
    tipoValor: 'variavel',
    tempoMedioLabel: 'Variável',
    observacao:
      'Cobrado adicionalmente caso o veículo apresente excesso de sujeira, exigindo maior ' +
      'esforço, tempo e produtos.',
  }),
  svc({
    id: 'svc_veic_deslocamento',
    categoria: 'veicular',
    grupo: 'adicional',
    nome: 'Taxa de deslocamento',
    valorBase: 30,
    tipoValor: 'variavel',
    tempoMedioLabel: 'Variável',
    observacao:
      'Taxa calculada com base na distância e tempo de deslocamento até o local do cliente.',
  }),
  svc({
    id: 'svc_veic_bancos_frente_tras',
    categoria: 'veicular',
    grupo: 'avulsos',
    nome: 'Higienização de bancos frente e trás',
    valorBase: 130,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h a 1h30',
    checklistPadrao: mkChecklist('svc_veic_bancos_frente_tras', TIT_AVULSO_VEICULAR),
  }),
  svc({
    id: 'svc_veic_bancos_meio',
    categoria: 'veicular',
    grupo: 'avulsos',
    nome: 'Higienização de bancos somente frente ou somente trás',
    valorBase: 100,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h',
    checklistPadrao: mkChecklist('svc_veic_bancos_meio', TIT_AVULSO_VEICULAR),
  }),
  svc({
    id: 'svc_veic_teto',
    categoria: 'veicular',
    grupo: 'avulsos',
    nome: 'Higienização de teto',
    valorBase: 70,
    tipoValor: 'fixo',
    tempoMedioLabel: '40min a 1h',
    checklistPadrao: mkChecklist('svc_veic_teto', TIT_AVULSO_VEICULAR),
  }),
  svc({
    id: 'svc_veic_cintos',
    categoria: 'veicular',
    grupo: 'avulsos',
    nome: 'Higienização dos cintos',
    valorBase: 50,
    tipoValor: 'fixo',
    tempoMedioLabel: '20min a 40min',
    checklistPadrao: mkChecklist('svc_veic_cintos', TIT_AVULSO_VEICULAR),
  }),
  svc({
    id: 'svc_veic_forros_porta',
    categoria: 'veicular',
    grupo: 'avulsos',
    nome: 'Higienização dos forros de porta',
    valorBase: 50,
    tipoValor: 'fixo',
    tempoMedioLabel: '30min a 1h',
    checklistPadrao: mkChecklist('svc_veic_forros_porta', TIT_AVULSO_VEICULAR),
  }),
  svc({
    id: 'svc_veic_painel',
    categoria: 'veicular',
    grupo: 'avulsos',
    nome: 'Revitalização de painel / partes plásticas',
    valorBase: 50,
    tipoValor: 'fixo',
    tempoMedioLabel: '30min a 1h',
    checklistPadrao: mkChecklist('svc_veic_painel', TIT_AVULSO_VEICULAR),
  }),
  svc({
    id: 'svc_veic_carpete_higien',
    categoria: 'veicular',
    grupo: 'avulsos',
    nome: 'Higienização do carpete, porta-malas e tapetes',
    valorBase: 100,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h',
    checklistPadrao: mkChecklist('svc_veic_carpete_higien', TIT_AVULSO_VEICULAR),
  }),
  svc({
    id: 'svc_veic_carpete_asp',
    categoria: 'veicular',
    grupo: 'avulsos',
    nome: 'Aspiração do carpete, porta-malas e tapetes',
    valorBase: 50,
    tipoValor: 'fixo',
    tempoMedioLabel: '30min a 1h',
    checklistPadrao: mkChecklist('svc_veic_carpete_asp', TIT_AVULSO_VEICULAR),
  }),
]

/* ---- RESIDENCIAL (17) ---- */

const RESIDENCIAL: Servico[] = [
  svc({
    id: 'svc_resid_sofa2',
    categoria: 'residencial',
    grupo: 'sofa',
    nome: 'Sofá 2 lugares',
    valorBase: 150,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h a 1h30',
    checklistPadrao: mkChecklist('svc_resid_sofa2', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_sofa3',
    categoria: 'residencial',
    grupo: 'sofa',
    nome: 'Sofá 3 lugares',
    valorBase: 180,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h30 a 2h',
    checklistPadrao: mkChecklist('svc_resid_sofa3', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_sofa_retratil',
    categoria: 'residencial',
    grupo: 'sofa',
    nome: 'Sofá retrátil 2/3 lugares',
    valorBase: 200,
    tipoValor: 'fixo',
    tempoMedioLabel: '2h a 2h30',
    checklistPadrao: mkChecklist('svc_resid_sofa_retratil', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_sofa4',
    categoria: 'residencial',
    grupo: 'sofa',
    nome: 'Sofá 4 lugares',
    valorBase: 230,
    tipoValor: 'variavel',
    tempoMedioLabel: '2h a 3h',
    checklistPadrao: mkChecklist('svc_resid_sofa4', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_sofa56',
    categoria: 'residencial',
    grupo: 'sofa',
    nome: 'Sofá 5/6 lugares',
    valorBase: 250,
    tipoValor: 'variavel',
    tempoMedioLabel: '3h+',
    checklistPadrao: mkChecklist('svc_resid_sofa56', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_colchao_solteiro',
    categoria: 'residencial',
    grupo: 'colchao',
    nome: 'Colchão solteiro',
    valorBase: 120,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h',
    checklistPadrao: mkChecklist('svc_resid_colchao_solteiro', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_colchao_casal',
    categoria: 'residencial',
    grupo: 'colchao',
    nome: 'Colchão casal',
    valorBase: 150,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h a 1h30',
    checklistPadrao: mkChecklist('svc_resid_colchao_casal', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_colchao_queen',
    categoria: 'residencial',
    grupo: 'colchao',
    nome: 'Colchão queen',
    valorBase: 170,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h30 a 2h',
    checklistPadrao: mkChecklist('svc_resid_colchao_queen', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_colchao_king',
    categoria: 'residencial',
    grupo: 'colchao',
    nome: 'Colchão king',
    valorBase: 190,
    tipoValor: 'fixo',
    tempoMedioLabel: '2h',
    checklistPadrao: mkChecklist('svc_resid_colchao_king', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_box_solteiro',
    categoria: 'residencial',
    grupo: 'colchao',
    nome: 'Cama box solteiro',
    valorBase: 120,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h',
    checklistPadrao: mkChecklist('svc_resid_box_solteiro', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_box_casal',
    categoria: 'residencial',
    grupo: 'colchao',
    nome: 'Cama box casal',
    valorBase: 150,
    tipoValor: 'fixo',
    tempoMedioLabel: '1h a 1h30',
    checklistPadrao: mkChecklist('svc_resid_box_casal', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_poltrona',
    categoria: 'residencial',
    grupo: 'outros',
    nome: 'Poltrona',
    valorBase: 50,
    valorBaseMax: 80,
    tipoValor: 'faixa',
    tempoMedioLabel: '30min a 1h',
    checklistPadrao: mkChecklist('svc_resid_poltrona', TIT_RESIDENCIAL),
    orientacoesPos: ORIENT_POS_RESIDENCIAL,
  }),
  svc({
    id: 'svc_resid_cadeira_assento',
    categoria: 'residencial',
    grupo: 'outros',
    nome: 'Cadeira apenas assento',
    valorBase: 20,
    tipoValor: 'fixo',
    tempoMedioLabel: '10min a 20min',
    checklistPadrao: mkChecklist('svc_resid_cadeira_assento', TIT_RESIDENCIAL),
  }),
  svc({
    id: 'svc_resid_cadeira_assento_encosto',
    categoria: 'residencial',
    grupo: 'outros',
    nome: 'Cadeira assento + encosto',
    valorBase: 30,
    tipoValor: 'fixo',
    tempoMedioLabel: '15min a 25min',
    checklistPadrao: mkChecklist('svc_resid_cadeira_assento_encosto', TIT_RESIDENCIAL),
  }),
  svc({
    id: 'svc_resid_puff',
    categoria: 'residencial',
    grupo: 'outros',
    nome: 'Puff',
    valorBase: 30,
    tipoValor: 'fixo',
    tempoMedioLabel: '15min a 30min',
    checklistPadrao: mkChecklist('svc_resid_puff', TIT_RESIDENCIAL),
  }),
  svc({
    id: 'svc_resid_tapete_pequeno',
    categoria: 'residencial',
    grupo: 'outros',
    nome: 'Tapete pequeno',
    valorBase: 60,
    tipoValor: 'variavel',
    tempoMedioLabel: 'Variável',
    checklistPadrao: mkChecklist('svc_resid_tapete_pequeno', TIT_RESIDENCIAL),
  }),
  svc({
    id: 'svc_resid_tapete_grande',
    categoria: 'residencial',
    grupo: 'outros',
    nome: 'Tapete médio/grande',
    valorBase: 120,
    tipoValor: 'variavel',
    tempoMedioLabel: 'Variável',
    checklistPadrao: mkChecklist('svc_resid_tapete_grande', TIT_RESIDENCIAL),
  }),
]

/** Catálogo inicial completo (32 serviços). */
export const SERVICOS_SEED: Servico[] = [...VEICULAR, ...RESIDENCIAL]
