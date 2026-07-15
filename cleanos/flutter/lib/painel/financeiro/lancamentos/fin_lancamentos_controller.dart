/// fin_lancamentos_controller.dart — Estado/dados da lista de Lançamentos.
///
/// PAGINAÇÃO NO SERVIDOR (mitigação Flutter Web §4): `getList` página a página +
/// scroll infinito, nunca `getFullList`. O mês vem do [finPeriodProvider]
/// (compartilhado); os filtros locais (busca/tipo/status/conta) refazem a query.
/// O agrupamento por DIA é derivado na tela ([agruparPorData]).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/financeiro.dart';
import '../../../core/repositories/repo_types.dart';
import '../fin_filters.dart';
import '../fin_providers.dart';

const int kFinLancPerPage = 40;

/// Filtros locais da lista (além do mês/período).
class FinLancFilters {
  const FinLancFilters({
    this.search = '',
    this.tipo,
    this.status,
    this.contaId,
    this.categoriaId,
  });

  final String search;
  final TipoLancamento? tipo;
  final LancamentoStatus? status;
  final String? contaId;
  final String? categoriaId;

  FinLancFilters copyWith({
    String? search,
    Object? tipo = _s,
    Object? status = _s,
    Object? contaId = _s,
    Object? categoriaId = _s,
  }) => FinLancFilters(
    search: search ?? this.search,
    tipo: tipo == _s ? this.tipo : tipo as TipoLancamento?,
    status: status == _s ? this.status : status as LancamentoStatus?,
    contaId: contaId == _s ? this.contaId : contaId as String?,
    categoriaId: categoriaId == _s ? this.categoriaId : categoriaId as String?,
  );

  bool get hasAny =>
      search.trim().isNotEmpty ||
      tipo != null ||
      status != null ||
      (contaId?.isNotEmpty ?? false) ||
      (categoriaId?.isNotEmpty ?? false);

  static const Object _s = Object();
}

class FinLancState {
  const FinLancState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.filters = const FinLancFilters(),
    this.page = 0,
    this.totalPages = 1,
    this.totalItems = 0,
  });

  final List<FinLancamento> items;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final FinLancFilters filters;
  final int page;
  final int totalPages;
  final int totalItems;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty;

  FinLancState copyWith({
    List<FinLancamento>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _s,
    FinLancFilters? filters,
    int? page,
    int? totalPages,
    int? totalItems,
  }) => FinLancState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error == _s ? this.error : error as String?,
    filters: filters ?? this.filters,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    totalItems: totalItems ?? this.totalItems,
  );

  static const Object _s = Object();
}

class FinLancController extends StateNotifier<FinLancState> {
  FinLancController(this._ref) : super(const FinLancState()) {
    // Recarrega quando o mês selecionado muda.
    _ref.listen<FinPeriod>(finPeriodProvider, (_, __) => refresh());
    refresh();
  }

  final Ref _ref;

  String? _buildFilter() {
    final period = _ref.read(finPeriodProvider).periodo;
    final f = state.filters;
    return finLancamentosFilter(
      periodo: period,
      search: f.search,
      tipo: f.tipo,
      status: f.status,
      contaId: f.contaId,
      categoriaId: f.categoriaId,
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      // Fixa/recorrente: materializa ocorrências do mês antes de listar.
      final period = _ref.read(finPeriodProvider).periodo;
      await _ref
          .read(financeiroRepositoryProvider)
          .ensureRecorrenciasNoPeriodo(period);
      final res = await _fetch(1);
      state = state.copyWith(
        items: res.items,
        loading: false,
        page: res.page,
        totalPages: res.totalPages,
        totalItems: res.totalItems,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Não foi possível carregar os lançamentos.',
      );
    }
  }

  Future<void> setFilters(FinLancFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final res = await _fetch(state.page + 1);
      state = state.copyWith(
        items: [...state.items, ...res.items],
        loadingMore: false,
        page: res.page,
        totalPages: res.totalPages,
        totalItems: res.totalItems,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<PageResult<FinLancamento>> _fetch(int page) => _ref
      .read(financeiroRepositoryProvider)
      .listLancamentos(
        page: page,
        perPage: kFinLancPerPage,
        filter: _buildFilter(),
        sort: '-data',
      );
}

final finLancControllerProvider =
    StateNotifierProvider.autoDispose<FinLancController, FinLancState>(
      FinLancController.new,
    );
