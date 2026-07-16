/// ordens_controller.dart — Estado/dados da lista de Ordens de Serviço do Painel.
///
/// Espelha `OrdensServico.tsx` com mitigações Flutter Web (§4): filtros aplicados
/// NO SERVIDOR (status/profissional/data) + paginação por `getList` + scroll
/// infinito virtualizado (nunca `getFullList`). Consome a interface congelada
/// `OrdensRepository` (core). Lookups de Nova OS (serviços/profissionais) num
/// provider à parte; clientes são buscados sob demanda (server search).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/servico.dart';
import '../../core/models/user.dart';
import '../../core/repositories/repo_types.dart';
import '../data/painel_filters.dart';
import '../data/painel_providers.dart';

const int kOrdensPerPage = 30;

/// Expand da lista do Painel (mostra o nome do profissional). NÃO precisa de
/// `cliente` — `nome_curto`/`bairro` já vêm denormalizados na OS.
const String _kListExpand = 'profissional,cliente';

/// Filtro ativo da lista: um status (ou `null` = todas) + profissional opcional.
class OrdensFilter {
  const OrdensFilter({this.status, this.profissionalId});
  final OSStatus? status;
  final String? profissionalId;

  OrdensFilter copyWith({Object? status = _s, Object? profissionalId = _s}) =>
      OrdensFilter(
        status: status == _s ? this.status : status as OSStatus?,
        profissionalId: profissionalId == _s
            ? this.profissionalId
            : profissionalId as String?,
      );

  static const Object _s = Object();
}

class OrdensState {
  const OrdensState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.filter = const OrdensFilter(),
    this.page = 0,
    this.totalPages = 1,
    this.totalItems = 0,
  });

  final List<OrdemServico> items;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final OrdensFilter filter;
  final int page;
  final int totalPages;
  final int totalItems;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty;

  OrdensState copyWith({
    List<OrdemServico>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _s,
    OrdensFilter? filter,
    int? page,
    int? totalPages,
    int? totalItems,
  }) => OrdensState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error == _s ? this.error : error as String?,
    filter: filter ?? this.filter,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    totalItems: totalItems ?? this.totalItems,
  );

  static const Object _s = Object();
}

class OrdensController extends StateNotifier<OrdensState> {
  OrdensController(this._ref) : super(const OrdensState()) {
    refresh();
  }

  final Ref _ref;

  String? get _filterExpr => ordensFilter(
    status: state.filter.status,
    profissionalId: state.filter.profissionalId,
  );

  Future<PageResult<OrdemServico>> _fetch(int page) => _ref
      .read(ordensRepositoryProvider)
      .list(
        page: page,
        perPage: kOrdensPerPage,
        filter: _filterExpr,
        sort: '-data_hora',
        expand: _kListExpand,
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
        error: 'Não foi possível carregar as ordens de serviço.',
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

  Future<void> setStatus(OSStatus? status) async {
    if (status == state.filter.status) return;
    state = state.copyWith(filter: state.filter.copyWith(status: status));
    await refresh();
  }

  Future<void> setProfissional(String? profId) async {
    if (profId == state.filter.profissionalId) return;
    state = state.copyWith(
      filter: state.filter.copyWith(profissionalId: profId),
    );
    await refresh();
  }

  /// Cancela uma OS (status → cancelada) e recarrega.
  Future<void> cancelar(String osId) async {
    await _ref.read(ordensRepositoryProvider).update(osId, {
      'status': OSStatus.cancelada.wire,
    });
    await refresh();
  }

  /// Exclui uma OS definitivamente e recarrega. O hook do servidor
  /// (os_delete.pb.js) estorna a receita via_os e remove a comissão antes
  /// de comitar — o Flutter só dispara o delete.
  Future<void> excluir(String osId) async {
    await _ref.read(ordensRepositoryProvider).delete(osId);
    await refresh();
  }
}

final ordensControllerProvider =
    StateNotifierProvider.autoDispose<OrdensController, OrdensState>(
      OrdensController.new,
    );

/// Contagem de OS por status (badges das abas). Espelha o `countByStatus` do React
/// — que deriva da lista completa. Como o Painel Flutter pagina no servidor (§4),
/// contamos via `getList(perPage:1)` lendo `totalItems`, respeitando o filtro de
/// profissional ativo para casar com o que a lista mostra. Invalidado nas mutações.
class OrdensCounts {
  const OrdensCounts({required this.total, required this.porStatus});
  final int total;
  final Map<OSStatus, int> porStatus;

  int of(OSStatus s) => porStatus[s] ?? 0;
}

final ordensCountsProvider = FutureProvider.autoDispose<OrdensCounts>((
  ref,
) async {
  final profId = ref.watch(
    ordensControllerProvider.select((s) => s.filter.profissionalId),
  );
  final repo = ref.watch(ordensRepositoryProvider);

  Future<int> count(OSStatus? status) async {
    final res = await repo.list(
      page: 1,
      perPage: 1,
      filter: ordensFilter(status: status, profissionalId: profId),
      sort: '-data_hora',
    );
    return res.totalItems;
  }

  final total = await count(null);
  final porStatus = <OSStatus, int>{};
  for (final s in OSStatus.all) {
    porStatus[s] = await count(s);
  }
  return OrdensCounts(total: total, porStatus: porStatus);
});

/// Lookups de Nova OS: catálogo ativo de serviços + profissionais.
class OrdensLookups {
  const OrdensLookups({required this.servicos, required this.profissionais});
  final List<ServicoPB> servicos;
  final List<User> profissionais;
}

final ordensLookupsProvider = FutureProvider.autoDispose<OrdensLookups>((
  ref,
) async {
  final servicos = await ref.watch(servicosRepositoryProvider).listAtivos();
  final profs = await ref
      .watch(usuariosRepositoryProvider)
      .list(filter: profissionaisFilter(), sort: 'nome,name');
  return OrdensLookups(servicos: servicos, profissionais: profs);
});
