/// servicos_controller.dart — Estado/dados do catálogo de Serviços do Painel.
///
/// Espelha `ServicosListPage.tsx`, mas com PAGINAÇÃO + FILTROS NO SERVIDOR
/// (mitigação Flutter Web §4): busca por nome (`~`) e filtros categoria/grupo (`=`)
/// refazem a query paginada (`getList`) — nunca `getFullList` numa lista de UI.
/// Consome só a interface congelada `ServicosRepository` (core). Ações: toggle de
/// status (otimista), duplicar e excluir.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/servico.dart';
import '../../core/repositories/repo_types.dart';
import '../data/painel_filters.dart';
import '../data/painel_providers.dart';
import 'servicos_labels.dart';

const int kServicosPerPage = 30;

class ServicosState {
  const ServicosState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.search = '',
    this.categoria,
    this.grupo,
    this.page = 0,
    this.totalPages = 1,
    this.totalItems = 0,
  });

  final List<ServicoPB> items;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final String search;
  final Categoria? categoria;
  final Grupo? grupo;
  final int page;
  final int totalPages;
  final int totalItems;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty;
  bool get hasFilters =>
      search.trim().isNotEmpty || categoria != null || grupo != null;

  ServicosState copyWith({
    List<ServicoPB>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _s,
    String? search,
    Object? categoria = _s,
    Object? grupo = _s,
    int? page,
    int? totalPages,
    int? totalItems,
  }) => ServicosState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error == _s ? this.error : error as String?,
    search: search ?? this.search,
    categoria: categoria == _s ? this.categoria : categoria as Categoria?,
    grupo: grupo == _s ? this.grupo : grupo as Grupo?,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    totalItems: totalItems ?? this.totalItems,
  );

  static const Object _s = Object();
}

class ServicosController extends StateNotifier<ServicosState> {
  ServicosController(this._ref) : super(const ServicosState()) {
    refresh();
  }

  final Ref _ref;

  String? get _filter => servicosFilter(
    search: state.search,
    categoria: state.categoria?.wire,
    grupo: state.grupo?.wire,
  );

  Future<PageResult<ServicoPB>> _fetch(int page) => _ref
      .read(servicosRepositoryProvider)
      .list(
        page: page,
        perPage: kServicosPerPage,
        filter: _filter,
        sort: 'nome',
      );

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
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
        error: 'Não foi possível carregar os serviços.',
      );
    }
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

  Future<void> setSearch(String search) async {
    if (search == state.search) return;
    state = state.copyWith(search: search);
    await refresh();
  }

  Future<void> setCategoria(Categoria? c) async {
    if (c == state.categoria) return;
    state = state.copyWith(categoria: c);
    await refresh();
  }

  Future<void> setGrupo(Grupo? g) async {
    if (g == state.grupo) return;
    state = state.copyWith(grupo: g);
    await refresh();
  }

  /// Alterna ativo/inativo (otimista + patch local; reverte em erro).
  Future<void> toggleStatus(ServicoPB s) async {
    final novo = s.status == ServicoStatus.ativo
        ? ServicoStatus.inativo
        : ServicoStatus.ativo;
    _patchLocal(
      s.id,
      s.copyWith(status: novo, ativo: novo == ServicoStatus.ativo),
    );
    try {
      await _ref.read(servicosRepositoryProvider).update(s.id, {
        'status': novo.wire,
        'ativo': novo == ServicoStatus.ativo, // 🔁 legado sincronizado
      });
    } catch (_) {
      _patchLocal(s.id, s);
      state = state.copyWith(error: 'Não foi possível atualizar o status.');
    }
  }

  /// Exclui um serviço e recarrega. Lança em falha (o caller trata via banner/toast).
  Future<void> delete(String id) async {
    await _ref.read(servicosRepositoryProvider).delete(id);
    await refresh();
  }

  /// Duplica um serviço (nome + " (cópia)", slug novo resolvido no repo) e recarrega.
  /// Lança em falha. Espelha `duplicateServico`.
  Future<void> duplicate(ServicoPB s) async {
    final payload = servicoToPayload(s)..['nome'] = '${s.nome} (cópia)';
    await _ref.read(servicosRepositoryProvider).create(payload);
    await refresh();
  }

  void _patchLocal(String id, ServicoPB updated) {
    state = state.copyWith(
      items: [
        for (final it in state.items)
          if (it.id == id) updated else it,
      ],
    );
  }
}

final servicosControllerProvider =
    StateNotifierProvider.autoDispose<ServicosController, ServicosState>(
      ServicosController.new,
    );
