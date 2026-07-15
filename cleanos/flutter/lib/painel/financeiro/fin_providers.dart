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
  final filter = finPeriodoFilter(periodo);
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

/// Total de comissões PENDENTES (equipe) — obrigação global, não só do mês.
/// Usado no Painel (compromissos) e KPIs de Movimentações.
final finComissoesPendentesTotalProvider =
    FutureProvider.autoDispose<double>((ref) async {
      final list = await ref.watch(comissaoRepositoryProvider).listComissoes();
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
      filter: "status != 'pago'",
      sort: 'vencimento',
    );
    out.addAll(res.items);
    if (page >= res.totalPages || res.items.isEmpty) break;
    page++;
  }
  return out;
});
