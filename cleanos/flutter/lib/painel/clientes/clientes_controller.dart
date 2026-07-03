/// clientes_controller.dart — Estado/dados da lista de Clientes do Painel.
///
/// Espelha `Clientes.tsx`, mas com PAGINAÇÃO NO SERVIDOR (mitigação Flutter Web §4):
/// a lista nunca faz `getFullList` — carrega página a página (`getList`) e acumula
/// no scroll infinito. A busca refaz a query no servidor (filtro `~` seguro via
/// `clienteSearchFilter`). Consome só a interface congelada `ClientesRepository`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/cliente.dart';
import '../../core/repositories/repo_types.dart';
import '../data/painel_filters.dart';
import '../data/painel_providers.dart';

/// Tamanho de página do servidor (denso o suficiente p/ desktop, leve p/ mobile).
const int kClientesPerPage = 30;

class ClientesState {
  const ClientesState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.query = '',
    this.page = 0,
    this.totalPages = 1,
    this.totalItems = 0,
  });

  final List<Cliente> items;

  /// Carregando a PRIMEIRA página (reset/busca) — mostra o spinner central.
  final bool loading;

  /// Carregando a PRÓXIMA página (scroll infinito) — mostra o rodapé.
  final bool loadingMore;
  final String? error;
  final String query;
  final int page;
  final int totalPages;
  final int totalItems;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty;

  ClientesState copyWith({
    List<Cliente>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    String? query,
    int? page,
    int? totalPages,
    int? totalItems,
  }) => ClientesState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error == _sentinel ? this.error : error as String?,
    query: query ?? this.query,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    totalItems: totalItems ?? this.totalItems,
  );

  static const Object _sentinel = Object();
}

class ClientesController extends StateNotifier<ClientesState> {
  ClientesController(this._ref) : super(const ClientesState()) {
    refresh();
  }

  final Ref _ref;

  /// Recarrega a partir da página 1 com a busca atual (reset).
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
        error: 'Não foi possível carregar os clientes.',
      );
    }
  }

  /// Aplica um novo termo de busca (refaz a query no servidor).
  Future<void> setQuery(String query) async {
    if (query == state.query) return;
    state = state.copyWith(query: query);
    await refresh();
  }

  /// Carrega a próxima página e ANEXA (scroll infinito). No-op se não há mais.
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
      // Falha ao paginar não descarta o que já temos; só para o indicador.
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Alterna `ativo` de um cliente (atualização otimista + patch local).
  Future<void> toggleAtivo(Cliente c) async {
    final novo = !c.ativo;
    // Otimista: reflete já na lista.
    _patchLocal(c.id, c.copyWith(ativo: novo));
    try {
      await _ref.read(clientesRepositoryProvider).update(c.id, {'ativo': novo});
    } catch (_) {
      // Reverte em caso de erro.
      _patchLocal(c.id, c);
      state = state.copyWith(error: 'Não foi possível atualizar o status.');
    }
  }

  void _patchLocal(String id, Cliente updated) {
    state = state.copyWith(
      items: [
        for (final it in state.items)
          if (it.id == id) updated else it,
      ],
    );
  }

  Future<PageResult<Cliente>> _fetch(int page) => _ref
      .read(clientesRepositoryProvider)
      .list(
        page: page,
        perPage: kClientesPerPage,
        filter: clienteSearchFilter(state.query),
        sort: 'nome,sobrenome',
      );
}

/// Controller da lista (autoDispose: recarrega ao reentrar na seção).
final clientesControllerProvider =
    StateNotifierProvider.autoDispose<ClientesController, ClientesState>(
      ClientesController.new,
    );
