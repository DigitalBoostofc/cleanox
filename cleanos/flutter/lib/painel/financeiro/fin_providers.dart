/// fin_providers.dart — Providers Riverpod da camada de dados do Financeiro.
///
/// Vivem DENTRO da pasta `financeiro/` (chunk deferred) para não pesar no bundle
/// inicial do Painel. Injetam a impl PB da interface congelada
/// `FinanceiroRepository` (via o `pocketBaseProvider` do core) SEM tocar o core.
///
/// Conjuntos pequenos (contas/categorias/limites) → `FutureProvider` que faz uma
/// leitura direta. Os LANÇAMENTOS DO PERÍODO (base dos agregados de Visão Geral/
/// Relatórios/Limites) são carregados PAGINADOS ([_fetchLancamentosDoPeriodo]):
/// nunca `getFullList`, sempre `getList` página a página até esgotar o período.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/financeiro.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import '../data/painel_providers.dart' show comissaoRepositoryProvider;
import '../data/pb_financeiro_repository.dart';
import 'fin_derivations.dart';
import 'fin_filters.dart';

/// Repositório do Financeiro. Tipado pela interface do Painel
/// ([FinanceiroPanelRepository]) — expõe os extras (transferir/ajustarSaldo) e
/// permite injetar um fake nos testes sem tocar PocketBase.
final financeiroRepositoryProvider = Provider<FinanceiroPanelRepository>(
  (ref) => PbFinanceiroRepository(ref.watch(pocketBaseProvider)),
);

/// Contas/carteiras (conjunto pequeno). `autoDispose`: recarrega ao reentrar.
final finContasProvider = FutureProvider.autoDispose<List<FinConta>>(
  (ref) => ref.watch(financeiroRepositoryProvider).listContas(),
);

/// Categorias (árvore categoria/subcategoria via parentId).
final finCategoriasProvider = FutureProvider.autoDispose<List<FinCategoria>>(
  (ref) => ref.watch(financeiroRepositoryProvider).listCategorias(),
);

/// Limites de gasto por categoria.
final finLimitesProvider = FutureProvider.autoDispose<List<FinLimite>>(
  (ref) => ref.watch(financeiroRepositoryProvider).listLimites(),
);

/// Metas de caixa (fin_objetivos).
final finObjetivosProvider = FutureProvider.autoDispose<List<FinObjetivo>>(
  (ref) => ref.watch(financeiroRepositoryProvider).listObjetivos(),
);

/* ─────────────────────── período selecionado (mês, BRT) ─────────────────────── */

/// Mês selecionado nos painéis de agregado (Visão geral / Relatórios / Limites).
class FinPeriod {
  const FinPeriod(this.year, this.month);

  final int year;

  /// 1..12.
  final int month;

  /// Mês corrente em BRT (nunca o fuso do device — gate G-8).
  factory FinPeriod.currentBrt() {
    final hoje = todayLocalDate(); // 'YYYY-MM-DD' em BRT
    return FinPeriod(
      int.parse(hoje.substring(0, 4)),
      int.parse(hoje.substring(5, 7)),
    );
  }

  Periodo get periodo => mesPeriodo(year, month);

  FinPeriod shift(int deltaMonths) {
    final m0 = (month - 1) + deltaMonths;
    final y = year + (m0 >= 0 ? m0 ~/ 12 : (m0 - 11) ~/ 12);
    final m = m0 % 12;
    return FinPeriod(y, (m < 0 ? m + 12 : m) + 1);
  }

  static const _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  String get label => '${_meses[month - 1]} $year';

  @override
  bool operator ==(Object other) =>
      other is FinPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// Estado do seletor de período (compartilhado pelas telas de agregado).
final finPeriodProvider = StateProvider<FinPeriod>(
  (ref) => FinPeriod.currentBrt(),
);

/* ─────────────────────── lançamentos do período (paginado) ─────────────────────── */

const int _kFinPageSize = 200;

/// Carrega TODOS os lançamentos de um período, PAGINANDO (`getList`) até esgotar.
/// Bounded pelo período (não é uma lista de UI infinita) — seguro para agregar.
/// Antes, materializa ocorrências de fixas/recorrentes faltantes no período.
Future<List<FinLancamento>> _fetchLancamentosDoPeriodo(
  FinanceiroPanelRepository repo,
  Periodo periodo, {
  bool ensureRecorrencias = true,
}) async {
  if (ensureRecorrencias) {
    await repo.ensureRecorrenciasNoPeriodo(periodo);
  }
  // Período + sem comissão 1:1 legada (Equipe acumula; repasse só no pagamento).
  final filter =
      '${finPeriodoFilter(periodo)} && ${finExcludeComissaoPorOsFilter()}';
  final out = <FinLancamento>[];
  var page = 1;
  while (true) {
    final res = await repo.listLancamentos(
      page: page,
      perPage: _kFinPageSize,
      filter: filter,
      sort: '-data',
    );
    out.addAll(res.items);
    if (page >= res.totalPages || res.items.isEmpty) break;
    page++;
  }
  return out;
}

/// Lançamentos do período selecionado (base dos agregados). Reexecuta quando o
/// período muda. Garante que fixas/recorrentes já existam no mês.
final finPeriodLancamentosProvider =
    FutureProvider.autoDispose<List<FinLancamento>>((ref) {
      final repo = ref.watch(financeiroRepositoryProvider);
      final period = ref.watch(finPeriodProvider);
      return _fetchLancamentosDoPeriodo(repo, period.periodo);
    });

/// Resumo REALIZADO (status 'pago') do mês ANTERIOR ao selecionado — base do
/// `trend` (variação vs. mês anterior) dos KPIs de Lançamentos/Relatórios.
/// Carrega o período anterior PAGINADO (bounded pelo mês).
final finPrevPeriodResumoProvider = FutureProvider.autoDispose<ResumoPeriodo>((
  ref,
) async {
  final repo = ref.watch(financeiroRepositoryProvider);
  final prev = ref.watch(finPeriodProvider).shift(-1);
  final lancs = await _fetchLancamentosDoPeriodo(repo, prev.periodo);
  return resumoPeriodo(lancs);
});

/// Lançamentos dos ÚLTIMOS 6 MESES até o mês selecionado — base dos Relatórios
/// (fluxo de caixa 6m + período atual + comparativo com o mês anterior). Fetch
/// PAGINADO limitado à janela de 6 meses (nunca `getFullList`).
final finRelatorioLancamentosProvider =
    FutureProvider.autoDispose<List<FinLancamento>>((ref) {
      final repo = ref.watch(financeiroRepositoryProvider);
      final period = ref.watch(finPeriodProvider);
      final inicio = period.shift(-5).periodo;
      final fim = period.periodo;
      return _fetchLancamentosDoPeriodo(
        repo,
        Periodo(inicio.start, fim.end),
      );
    });

/// Extrato de comissões (Equipe) — base do relatório "Incluir não pagas" e KPIs.
final finComissoesProvider =
    FutureProvider.autoDispose<List<ProfComissao>>((ref) {
      return ref.watch(comissaoRepositoryProvider).listComissoes();
    });

/// Profissionais (nomes) para descrever comissões sintéticas no relatório.
final finProfissionaisProvider = FutureProvider.autoDispose<List<User>>((ref) {
  return ref.watch(comissaoRepositoryProvider).listProfissionais();
});

/// Total de comissões PENDENTES (equipe) — obrigação global, não só do mês.
/// Usado no Painel (compromissos) e KPIs de Movimentações.
final finComissoesPendentesTotalProvider =
    FutureProvider.autoDispose<double>((ref) async {
      final list = await ref.watch(finComissoesProvider.future);
      var cents = 0;
      for (final c in list) {
        if (c.status == ComissaoStatus.pendente) {
          cents += (c.valorComissao * 100).round();
        }
      }
      return cents / 100.0;
    });

/// TODOS os lançamentos EM ABERTO (status != pago), paginando. Base de "Contas a
/// pagar/receber" — bounded pelos itens não quitados (não é lista infinita de
/// UI). Ordenados por vencimento asc no servidor.
///
/// Inclui comissões **pendentes** da equipe como despesas sintéticas `previsto`
/// em Equipe → Profissionais (mesmo contrato do relatório "Incluir não pagas"),
/// para o total a pagar refletir a obrigação acumulada.
final finPendentesProvider = FutureProvider.autoDispose<List<FinLancamento>>((
  ref,
) async {
  final repo = ref.watch(financeiroRepositoryProvider);
  final out = <FinLancamento>[];
  var page = 1;
  while (true) {
    final res = await repo.listLancamentos(
      page: page,
      perPage: _kFinPageSize,
      filter: "status != 'pago' && ${finExcludeComissaoPorOsFilter()}",
      sort: 'vencimento',
    );
    out.addAll(res.items);
    if (page >= res.totalPages || res.items.isEmpty) break;
    page++;
  }

  // Comissões pendentes → a pagar (Equipe / Profissionais).
  try {
    final comissoes = await ref.watch(finComissoesProvider.future);
    final categorias = await ref.watch(finCategoriasProvider.future);
    final contas = await ref.watch(finContasProvider.future);
    final profs = await ref.watch(finProfissionaisProvider.future);
    final nomePorProf = {
      for (final u in profs)
        if (u.displayName.trim().isNotEmpty) u.id: u.displayName.trim(),
    };
    var contaPadrao = '';
    for (final c in contas) {
      if (c.ativo) {
        contaPadrao = c.id;
        break;
      }
    }
    final previstos = finComissoesPendentesComoLancamentos(
      comissoes: comissoes,
      categorias: categorias,
      profissionais: profs,
      nomePorProfId: nomePorProf,
      contaId: contaPadrao,
    );
    if (previstos.isNotEmpty) {
      final ids = {for (final l in out) l.id};
      out.addAll(previstos.where((l) => !ids.contains(l.id)));
      out.sort((a, b) {
        final va = (a.vencimento?.isNotEmpty ?? false) ? a.vencimento! : a.data;
        final vb = (b.vencimento?.isNotEmpty ?? false) ? b.vencimento! : b.data;
        return va.compareTo(vb);
      });
    }
  } catch (_) {
    // Best-effort: se falhar extrato/categorias, mantém só fin_lancamentos.
  }

  return out;
});
