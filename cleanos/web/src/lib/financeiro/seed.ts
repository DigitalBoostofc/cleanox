/**
 * financeiro/seed.ts — Dados MOCK iniciais do módulo Financeiro (Junho/2026).
 *
 * Coerentes com a spec (categorias, exemplos de lançamentos, contas, limites) e
 * com as telas de referência (Organizze/Mobills). Tudo com IDs ESTÁVEIS e datas
 * FIXAS em ISO (nada de Date.now()) — assim o seed é determinístico e testável.
 *
 * Convenção de categorização dos lançamentos:
 *   `categoriaId` = categoria-MÃE (ex.: cat_produtos, cat_marketing, cat_equipe)
 *   `subcategoriaId` = subcategoria específica (ex.: cat_produtos_quimicos)
 * Limites podem ser definidos tanto na mãe quanto na subcategoria — progressoLimite
 * (./store) casa por categoriaId OU subcategoriaId.
 */

import type { Categoria, Conta, Lancamento, LimiteGasto } from './types'

/** Timestamp fixo usado em created/updated dos registros estruturais (contas/categorias/limites). */
const SEED_TS = '2026-06-01T08:00:00.000Z'

/* ============================================================
 * Contas / Carteiras
 * ============================================================ */

export const CONTAS_SEED: Conta[] = [
  {
    id: 'conta_carteira',
    nome: 'Carteira',
    tipo: 'carteira',
    saldoInicial: 500,
    saldoAtual: 306.16,
    ativo: true,
    cor: '#10B981',
    icone: 'wallet',
    created: SEED_TS,
    updated: SEED_TS,
  },
  {
    id: 'conta_inter',
    nome: 'Banco Inter',
    tipo: 'banco',
    saldoInicial: 8000,
    saldoAtual: 6450,
    ativo: true,
    cor: '#FF7A00',
    icone: 'landmark',
    created: SEED_TS,
    updated: SEED_TS,
  },
  {
    id: 'conta_nubank',
    nome: 'Nubank',
    tipo: 'banco',
    saldoInicial: 3000,
    saldoAtual: 3250,
    ativo: true,
    cor: '#820AD1',
    icone: 'landmark',
    created: SEED_TS,
    updated: SEED_TS,
  },
  {
    id: 'conta_cartao',
    nome: 'Cartão Empresarial',
    tipo: 'cartao',
    saldoInicial: 0,
    saldoAtual: -1179.9,
    ativo: true,
    cor: '#1F2937',
    icone: 'credit-card',
    created: SEED_TS,
    updated: SEED_TS,
  },
  {
    id: 'conta_caixa',
    nome: 'Caixa físico',
    tipo: 'caixa',
    saldoInicial: 300,
    saldoAtual: 300,
    ativo: true,
    cor: '#64748B',
    icone: 'banknote',
    created: SEED_TS,
    updated: SEED_TS,
  },
]

/* ============================================================
 * Categorias (despesas e receitas; subcategorias via parentId)
 * `icone` = nome lógico (convenção lucide-react) p/ a UI mapear.
 * ============================================================ */

export const CATEGORIAS_SEED: Categoria[] = [
  /* ---- Despesas ---- */
  // Produtos
  { id: 'cat_produtos', nome: 'Produtos', tipo: 'despesa', icone: 'spray-can', cor: '#0E9F9C', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_produtos_quimicos', nome: 'Produtos químicos', tipo: 'despesa', icone: 'flask-conical', cor: '#0E9F9C', parentId: 'cat_produtos', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_produtos_insumos', nome: 'Insumos', tipo: 'despesa', icone: 'package', cor: '#14B8A6', parentId: 'cat_produtos', arquivada: false, created: SEED_TS, updated: SEED_TS },
  // Equipamentos
  { id: 'cat_equipamentos', nome: 'Equipamentos', tipo: 'despesa', icone: 'wrench', cor: '#6366F1', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_equipamentos_maquinas', nome: 'Máquinas', tipo: 'despesa', icone: 'cog', cor: '#6366F1', parentId: 'cat_equipamentos', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_equipamentos_acessorios', nome: 'Acessórios', tipo: 'despesa', icone: 'plug', cor: '#818CF8', parentId: 'cat_equipamentos', arquivada: false, created: SEED_TS, updated: SEED_TS },
  // Equipe
  { id: 'cat_equipe', nome: 'Equipe', tipo: 'despesa', icone: 'users', cor: '#F59E0B', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_equipe_profissionais', nome: 'Profissionais', tipo: 'despesa', icone: 'user-check', cor: '#F59E0B', parentId: 'cat_equipe', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_equipe_comissoes', nome: 'Comissões', tipo: 'despesa', icone: 'hand-coins', cor: '#FBBF24', parentId: 'cat_equipe', arquivada: false, created: SEED_TS, updated: SEED_TS },
  // Sócios / Retiradas
  { id: 'cat_socios', nome: 'Sócios / Retiradas', tipo: 'despesa', icone: 'briefcase', cor: '#8B5CF6', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_socios_dennis', nome: 'Dennis', tipo: 'despesa', icone: 'user', cor: '#8B5CF6', parentId: 'cat_socios', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_socios_diego', nome: 'Diego', tipo: 'despesa', icone: 'user', cor: '#A78BFA', parentId: 'cat_socios', arquivada: false, created: SEED_TS, updated: SEED_TS },
  // Impostos e Taxas
  { id: 'cat_impostos', nome: 'Impostos e Taxas', tipo: 'despesa', icone: 'landmark', cor: '#64748B', arquivada: false, created: SEED_TS, updated: SEED_TS },
  // Marketing
  { id: 'cat_marketing', nome: 'Marketing', tipo: 'despesa', icone: 'megaphone', cor: '#EC4899', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_marketing_google', nome: 'Tráfego Pago Google', tipo: 'despesa', icone: 'search', cor: '#EA4335', parentId: 'cat_marketing', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_marketing_meta', nome: 'Tráfego Pago Meta', tipo: 'despesa', icone: 'thumbs-up', cor: '#1877F2', parentId: 'cat_marketing', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_marketing_criativos', nome: 'Materiais criativos', tipo: 'despesa', icone: 'palette', cor: '#F472B6', parentId: 'cat_marketing', arquivada: false, created: SEED_TS, updated: SEED_TS },
  // Transporte
  { id: 'cat_transporte', nome: 'Transporte', tipo: 'despesa', icone: 'truck', cor: '#0EA5E9', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_transporte_combustivel', nome: 'Combustível', tipo: 'despesa', icone: 'fuel', cor: '#F97316', parentId: 'cat_transporte', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_transporte_manutencao', nome: 'Manutenção', tipo: 'despesa', icone: 'wrench', cor: '#0EA5E9', parentId: 'cat_transporte', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_transporte_uber', nome: 'Uber', tipo: 'despesa', icone: 'car', cor: '#111827', parentId: 'cat_transporte', arquivada: false, created: SEED_TS, updated: SEED_TS },
  // Avulsas (despesa)
  { id: 'cat_compras', nome: 'Compras', tipo: 'despesa', icone: 'shopping-cart', cor: '#22C55E', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_assinaturas', nome: 'Assinaturas e sistemas', tipo: 'despesa', icone: 'monitor', cor: '#3B82F6', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_alimentacao', nome: 'Alimentação', tipo: 'despesa', icone: 'utensils', cor: '#EF4444', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_aluguel', nome: 'Aluguel', tipo: 'despesa', icone: 'home', cor: '#10B981', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_contabilidade', nome: 'Contabilidade', tipo: 'despesa', icone: 'calculator', cor: '#64748B', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_taxas_bancarias', nome: 'Taxas bancárias', tipo: 'despesa', icone: 'banknote', cor: '#94A3B8', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_outros', nome: 'Outros', tipo: 'despesa', icone: 'circle-dashed', cor: '#9CA3AF', arquivada: false, created: SEED_TS, updated: SEED_TS },

  /* ---- Receitas ---- */
  { id: 'cat_servico_automotivo', nome: 'Serviço Automotivo', tipo: 'receita', icone: 'car', cor: '#0EA5A4', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_servico_residencial', nome: 'Serviço Residencial', tipo: 'receita', icone: 'home', cor: '#10B981', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_aporte_socios', nome: 'Aporte dos Sócios', tipo: 'receita', icone: 'piggy-bank', cor: '#14B8A6', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_emprestimos', nome: 'Empréstimos', tipo: 'receita', icone: 'hand-coins', cor: '#22C55E', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_reembolsos', nome: 'Reembolsos', tipo: 'receita', icone: 'rotate-ccw', cor: '#34D399', arquivada: false, created: SEED_TS, updated: SEED_TS },
  { id: 'cat_outras_receitas', nome: 'Outras receitas', tipo: 'receita', icone: 'plus-circle', cor: '#2DD4BF', arquivada: false, created: SEED_TS, updated: SEED_TS },
]

/* ============================================================
 * Lançamentos (Junho/2026) — cobre todos os tipos/status/origens
 * `created`/`updated` = a própria `data` (determinístico).
 * ============================================================ */

export const LANCAMENTOS_SEED: Lancamento[] = [
  /* ---- Receitas via OS ---- */
  {
    id: 'lanc_seed_01', tipo: 'receita', descricao: 'OS #000245 - Cleanox Premium',
    categoriaId: 'cat_servico_automotivo', valor: 300, contaId: 'conta_inter',
    data: '2026-06-03T14:30:00.000Z', status: 'pago', recorrencia: 'unica', origem: 'via_os',
    osId: 'os_000245', osNumero: '000245', clienteNome: 'Carlos S.', servicoNome: 'Cleanox Premium',
    formaPagamento: 'Pix', created: '2026-06-03T14:30:00.000Z', updated: '2026-06-03T14:30:00.000Z',
  },
  {
    id: 'lanc_seed_02', tipo: 'receita', descricao: 'OS #000251 - Sofá 3 lugares',
    categoriaId: 'cat_servico_residencial', valor: 180, contaId: 'conta_inter',
    data: '2026-06-07T10:00:00.000Z', status: 'pago', recorrencia: 'unica', origem: 'via_os',
    osId: 'os_000251', osNumero: '000251', clienteNome: 'Marina L.', servicoNome: 'Higienização Sofá 3 lugares',
    formaPagamento: 'Crédito', created: '2026-06-07T10:00:00.000Z', updated: '2026-06-07T10:00:00.000Z',
  },
  {
    id: 'lanc_seed_03', tipo: 'receita', descricao: 'OS #000260 - Cleanox Plus',
    categoriaId: 'cat_servico_automotivo', valor: 250, contaId: 'conta_nubank',
    data: '2026-06-15T16:45:00.000Z', status: 'pago', recorrencia: 'unica', origem: 'via_os',
    osId: 'os_000260', osNumero: '000260', clienteNome: 'Rafael T.', servicoNome: 'Cleanox Plus',
    formaPagamento: 'Débito', created: '2026-06-15T16:45:00.000Z', updated: '2026-06-15T16:45:00.000Z',
  },
  {
    id: 'lanc_seed_04', tipo: 'receita', descricao: 'OS #000259 - Colchão casal',
    categoriaId: 'cat_servico_residencial', valor: 160, contaId: 'conta_inter',
    data: '2026-06-28T09:00:00.000Z', vencimento: '2026-06-28', status: 'previsto', recorrencia: 'unica', origem: 'via_os',
    osId: 'os_000259', osNumero: '000259', clienteNome: 'João P.', servicoNome: 'Higienização Colchão casal',
    created: '2026-06-22T09:00:00.000Z', updated: '2026-06-22T09:00:00.000Z',
  },

  /* ---- Receitas manuais ---- */
  {
    id: 'lanc_seed_05', tipo: 'receita', descricao: 'Aporte dos sócios',
    categoriaId: 'cat_aporte_socios', valor: 1500, contaId: 'conta_inter',
    data: '2026-06-01T12:00:00.000Z', status: 'pago', recorrencia: 'unica', origem: 'manual',
    observacao: 'Aporte para capital de giro', created: '2026-06-01T12:00:00.000Z', updated: '2026-06-01T12:00:00.000Z',
  },
  {
    id: 'lanc_seed_06', tipo: 'receita', descricao: 'Reembolso de material',
    categoriaId: 'cat_reembolsos', valor: 120, contaId: 'conta_inter',
    data: '2026-06-20T11:00:00.000Z', vencimento: '2026-06-20', status: 'pendente', recorrencia: 'unica', origem: 'manual',
    created: '2026-06-14T11:00:00.000Z', updated: '2026-06-14T11:00:00.000Z',
  },

  /* ---- Despesas pagas (entram em gastos/limites) ---- */
  {
    id: 'lanc_seed_07', tipo: 'despesa', descricao: 'Google Ads',
    categoriaId: 'cat_marketing', subcategoriaId: 'cat_marketing_google', valor: 450, contaId: 'conta_cartao',
    data: '2026-06-05T08:00:00.000Z', status: 'pago', recorrencia: 'recorrente', origem: 'manual',
    formaPagamento: 'Crédito', created: '2026-06-05T08:00:00.000Z', updated: '2026-06-05T08:00:00.000Z',
  },
  {
    id: 'lanc_seed_08', tipo: 'despesa', descricao: 'Meta Ads',
    categoriaId: 'cat_marketing', subcategoriaId: 'cat_marketing_meta', valor: 350, contaId: 'conta_cartao',
    data: '2026-06-05T08:05:00.000Z', status: 'pago', recorrencia: 'recorrente', origem: 'manual',
    formaPagamento: 'Crédito', created: '2026-06-05T08:05:00.000Z', updated: '2026-06-05T08:05:00.000Z',
  },
  {
    id: 'lanc_seed_09', tipo: 'despesa', descricao: 'Fornecedor CleanTech',
    categoriaId: 'cat_produtos', subcategoriaId: 'cat_produtos_quimicos', valor: 980, contaId: 'conta_inter',
    data: '2026-06-08T15:20:00.000Z', status: 'pago', recorrencia: 'unica', origem: 'manual',
    observacao: 'Produtos de limpeza profissionais', created: '2026-06-08T15:20:00.000Z', updated: '2026-06-08T15:20:00.000Z',
  },
  {
    id: 'lanc_seed_10', tipo: 'despesa', descricao: 'Combustível',
    categoriaId: 'cat_transporte', subcategoriaId: 'cat_transporte_combustivel', valor: 155.34, contaId: 'conta_carteira',
    data: '2026-06-10T07:30:00.000Z', status: 'pago', recorrencia: 'unica', origem: 'manual',
    formaPagamento: 'Débito', created: '2026-06-10T07:30:00.000Z', updated: '2026-06-10T07:30:00.000Z',
  },
  {
    id: 'lanc_seed_11', tipo: 'despesa', descricao: 'Folha da equipe',
    categoriaId: 'cat_equipe', subcategoriaId: 'cat_equipe_profissionais', valor: 3250, contaId: 'conta_inter',
    data: '2026-06-05T18:00:00.000Z', status: 'pago', recorrencia: 'fixa', origem: 'manual',
    created: '2026-06-05T18:00:00.000Z', updated: '2026-06-05T18:00:00.000Z',
  },
  {
    id: 'lanc_seed_12', tipo: 'despesa', descricao: 'Taxa bancária',
    categoriaId: 'cat_taxas_bancarias', valor: 20, contaId: 'conta_inter',
    data: '2026-06-02T03:00:00.000Z', status: 'pago', recorrencia: 'recorrente', origem: 'manual',
    created: '2026-06-02T03:00:00.000Z', updated: '2026-06-02T03:00:00.000Z',
  },
  {
    id: 'lanc_seed_13', tipo: 'despesa', descricao: 'Uber para atendimento',
    categoriaId: 'cat_transporte', subcategoriaId: 'cat_transporte_uber', valor: 38.5, contaId: 'conta_carteira',
    data: '2026-06-12T13:10:00.000Z', status: 'pago', recorrencia: 'unica', origem: 'manual',
    created: '2026-06-12T13:10:00.000Z', updated: '2026-06-12T13:10:00.000Z',
  },
  {
    id: 'lanc_seed_14', tipo: 'despesa', descricao: 'Assinatura sistema (hospedagem)',
    categoriaId: 'cat_assinaturas', valor: 99.9, contaId: 'conta_cartao',
    data: '2026-06-04T06:00:00.000Z', status: 'pago', recorrencia: 'recorrente', origem: 'manual',
    formaPagamento: 'Crédito', created: '2026-06-04T06:00:00.000Z', updated: '2026-06-04T06:00:00.000Z',
  },
  {
    id: 'lanc_seed_15', tipo: 'despesa', descricao: 'Retirada - Dennis',
    categoriaId: 'cat_socios', subcategoriaId: 'cat_socios_dennis', valor: 800, contaId: 'conta_inter',
    data: '2026-06-20T17:00:00.000Z', status: 'pago', recorrencia: 'unica', origem: 'manual',
    created: '2026-06-20T17:00:00.000Z', updated: '2026-06-20T17:00:00.000Z',
  },
  {
    id: 'lanc_seed_16', tipo: 'despesa', descricao: 'Retirada - Diego',
    categoriaId: 'cat_socios', subcategoriaId: 'cat_socios_diego', valor: 800, contaId: 'conta_inter',
    data: '2026-06-20T17:05:00.000Z', status: 'pago', recorrencia: 'unica', origem: 'manual',
    created: '2026-06-20T17:05:00.000Z', updated: '2026-06-20T17:05:00.000Z',
  },
  {
    id: 'lanc_seed_17', tipo: 'despesa', descricao: 'Máquina extratora (parcela 1/10)',
    categoriaId: 'cat_equipamentos', subcategoriaId: 'cat_equipamentos_maquinas', valor: 280, contaId: 'conta_cartao',
    data: '2026-06-01T10:00:00.000Z', status: 'pago', recorrencia: 'parcelada', parcelaAtual: 1, parcelasTotal: 10, origem: 'manual',
    formaPagamento: 'Crédito', created: '2026-06-01T10:00:00.000Z', updated: '2026-06-01T10:00:00.000Z',
  },

  /* ---- Despesas em aberto (contas a pagar) ---- */
  {
    id: 'lanc_seed_18', tipo: 'despesa', descricao: 'Aluguel',
    categoriaId: 'cat_aluguel', valor: 1200, contaId: 'conta_inter',
    data: '2026-07-05T00:00:00.000Z', vencimento: '2026-07-05', status: 'pendente', recorrencia: 'fixa', origem: 'manual',
    created: '2026-06-01T09:00:00.000Z', updated: '2026-06-01T09:00:00.000Z',
  },
  {
    id: 'lanc_seed_19', tipo: 'despesa', descricao: 'Manutenção do extrator',
    categoriaId: 'cat_equipamentos', subcategoriaId: 'cat_equipamentos_maquinas', valor: 320, contaId: 'conta_inter',
    data: '2026-06-18T00:00:00.000Z', vencimento: '2026-06-18', status: 'em_atraso', recorrencia: 'unica', origem: 'manual',
    created: '2026-06-12T09:00:00.000Z', updated: '2026-06-12T09:00:00.000Z',
  },
  {
    id: 'lanc_seed_20', tipo: 'despesa', descricao: 'Parcela do equipamento (2/10)',
    categoriaId: 'cat_equipamentos', subcategoriaId: 'cat_equipamentos_maquinas', valor: 280, contaId: 'conta_cartao',
    data: '2026-06-25T00:00:00.000Z', vencimento: '2026-06-25', status: 'previsto', recorrencia: 'parcelada', parcelaAtual: 2, parcelasTotal: 10, origem: 'manual',
    created: '2026-06-01T10:05:00.000Z', updated: '2026-06-01T10:05:00.000Z',
  },
]

/* ============================================================
 * Limites de gasto (gastoAtual é DERIVADO — ver progressoLimite)
 * ============================================================ */

export const LIMITES_SEED: LimiteGasto[] = [
  { id: 'lim_marketing_google', categoriaId: 'cat_marketing_google', limite: 600, created: SEED_TS, updated: SEED_TS },
  { id: 'lim_marketing_meta', categoriaId: 'cat_marketing_meta', limite: 500, created: SEED_TS, updated: SEED_TS },
  { id: 'lim_produtos', categoriaId: 'cat_produtos', limite: 1500, created: SEED_TS, updated: SEED_TS },
  { id: 'lim_equipamentos', categoriaId: 'cat_equipamentos', limite: 1000, created: SEED_TS, updated: SEED_TS },
  { id: 'lim_combustivel', categoriaId: 'cat_transporte_combustivel', limite: 400, created: SEED_TS, updated: SEED_TS },
  { id: 'lim_equipe', categoriaId: 'cat_equipe', limite: 4000, created: SEED_TS, updated: SEED_TS },
]
