/// avaliacoes_controller.dart — Estado/dados das Avaliações do Painel.
///
/// Lista as OS já avaliadas (`avaliacao_nota >= 1`) com mitigações Flutter Web
/// (§4): filtros aplicados NO SERVIDOR (nota/período), paginação por `getList` +
/// scroll infinito virtualizado (nunca `getFullList`). Consome a interface
/// congelada `OrdensRepository` (core) — NÃO altera o core.
///
/// A MÉDIA e o total do cabeçalho vêm de uma leitura de AGREGADO separada e
/// limitada (mesma estratégia do web, que busca só as notas para agregar): a
/// lista visível continua paginada; o agregado percorre o conjunto filtrado
/// inteiro (dataset pequeno — o backend documenta < ~50 OS/mês).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/repositories/repo_types.dart';
import '../data/painel_filters.dart';

/// Tamanho da página da lista visível (virtualizada).
const int kAvaliacoesPerPage = 20;

/// Teto do agregado de média/total. Cobre folgadamente o volume real (o backend
/// documenta < ~50 avaliações/mês). Se algum dia estourar, a média passa a ser
/// sobre as [_kAggCap] mais recentes — [AvaliacoesState.mediaAproximada] sinaliza.
const int _kAggCap = 500;

/// Presets de período (filtra por `avaliacao_em`, quando a OS foi avaliada).
enum AvaliacoesPeriodo { todos, ultimos7, ultimos30, esteMes }

extension AvaliacoesPeriodoLabel on AvaliacoesPeriodo {
  String get label => switch (this) {
    AvaliacoesPeriodo.todos => 'Todo período',
    AvaliacoesPeriodo.ultimos7 => 'Últimos 7 dias',
    AvaliacoesPeriodo.ultimos30 => 'Últimos 30 dias',
    AvaliacoesPeriodo.esteMes => 'Este mês',
  };
}

/// Formata um instante como string UTC do PocketBase ('yyyy-MM-dd HH:mm:ss.000Z'),
/// no mesmo layout de largura fixa dos valores gravados — comparável por `>=`.
String _pbUtcString(DateTime dt) {
  final d = dt.toUtc();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${p(d.month)}-${p(d.day)} '
      '${p(d.hour)}:${p(d.minute)}:${p(d.second)}.000Z';
}

/// Limite inferior [desde] (string UTC do PB) do [periodo], ou `null` para "todos".
String? periodoDesde(AvaliacoesPeriodo periodo, {DateTime? now}) {
  final agora = now ?? DateTime.now();
  return switch (periodo) {
    AvaliacoesPeriodo.todos => null,
    AvaliacoesPeriodo.ultimos7 => _pbUtcString(
      agora.subtract(const Duration(days: 7)),
    ),
    AvaliacoesPeriodo.ultimos30 => _pbUtcString(
      agora.subtract(const Duration(days: 30)),
    ),
    AvaliacoesPeriodo.esteMes => _esteMesDesde(agora),
  };
}

String _esteMesDesde(DateTime nowUtc) {
  // Início do mês corrente em BRT, já como string UTC do PB.
  final brt = nowUtc.toUtc().subtract(kBrtOffset);
  return getBrtMonthBounds(brt.year, brt.month).start;
}

class AvaliacoesState {
  const AvaliacoesState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.nota,
    this.periodo = AvaliacoesPeriodo.todos,
    this.page = 0,
    this.totalPages = 1,
    this.totalItems = 0,
    this.media,
    this.mediaAproximada = false,
  });

  final List<OrdemServico> items;
  final bool loading;
  final bool loadingMore;
  final String? error;

  /// Filtro de nota exata (1..5) ou `null` = todas.
  final int? nota;
  final AvaliacoesPeriodo periodo;

  final int page;
  final int totalPages;
  final int totalItems;

  /// Média das notas do conjunto FILTRADO (agregado), ou `null` se sem dados.
  final double? media;

  /// A média foi calculada sobre um recorte limitado (conjunto > [_kAggCap]).
  final bool mediaAproximada;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty;
  bool get hasFilters => nota != null || periodo != AvaliacoesPeriodo.todos;

  AvaliacoesState copyWith({
    List<OrdemServico>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _s,
    Object? nota = _s,
    AvaliacoesPeriodo? periodo,
    int? page,
    int? totalPages,
    int? totalItems,
    Object? media = _s,
    bool? mediaAproximada,
  }) => AvaliacoesState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error == _s ? this.error : error as String?,
    nota: nota == _s ? this.nota : nota as int?,
    periodo: periodo ?? this.periodo,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    totalItems: totalItems ?? this.totalItems,
    media: media == _s ? this.media : media as double?,
    mediaAproximada: mediaAproximada ?? this.mediaAproximada,
  );

  static const Object _s = Object();
}

class AvaliacoesController extends StateNotifier<AvaliacoesState> {
  AvaliacoesController(this._ref, {DateTime? now})
    : _now = now,
      super(const AvaliacoesState()) {
    refresh();
  }

  final Ref _ref;
  final DateTime? _now;

  String get _filter => avaliacoesFilter(
    nota: state.nota,
    desde: periodoDesde(state.periodo, now: _now),
  );

  Future<PageResult<OrdemServico>> _fetchPage(int page) => _ref
      .read(ordensRepositoryProvider)
      .list(
        page: page,
        perPage: kAvaliacoesPerPage,
        filter: _filter,
        sort: '-avaliacao_em',
        // Só o profissional (nome). `nome_curto`/`tipo_servico_nome` já vêm na OS.
        expand: 'profissional',
      );

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      // Página visível + agregado (média/total) do conjunto filtrado.
      final page1 = await _fetchPage(1);
      final agg = await _fetchAggregate();
      state = state.copyWith(
        items: page1.items,
        loading: false,
        page: page1.page,
        totalPages: page1.totalPages,
        totalItems: page1.totalItems,
        media: agg.media,
        mediaAproximada: agg.aproximada,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Não foi possível carregar as avaliações.',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final res = await _fetchPage(state.page + 1);
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

  Future<void> setNota(int? nota) async {
    if (nota == state.nota) return;
    state = state.copyWith(nota: nota);
    await refresh();
  }

  Future<void> setPeriodo(AvaliacoesPeriodo periodo) async {
    if (periodo == state.periodo) return;
    state = state.copyWith(periodo: periodo);
    await refresh();
  }

  /// Agregado de média/total: lê o conjunto FILTRADO (limitado a [_kAggCap]) e
  /// calcula a média das notas. `getList` (não `getFullList`), página única.
  Future<({double? media, bool aproximada})> _fetchAggregate() async {
    final res = await _ref
        .read(ordensRepositoryProvider)
        .list(
          page: 1,
          perPage: _kAggCap,
          filter: _filter,
          sort: '-avaliacao_em',
        );
    final notas = res.items
        .map((o) => o.avaliacaoNota)
        .whereType<double>()
        .where((n) => n >= 1)
        .toList();
    if (notas.isEmpty) return (media: null, aproximada: false);
    final soma = notas.fold<double>(0, (a, b) => a + b);
    return (
      media: soma / notas.length,
      aproximada: res.totalItems > res.items.length,
    );
  }
}

final avaliacoesControllerProvider =
    StateNotifierProvider.autoDispose<AvaliacoesController, AvaliacoesState>(
      (ref) => AvaliacoesController(ref),
    );
