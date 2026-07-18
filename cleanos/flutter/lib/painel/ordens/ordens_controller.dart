/// ordens_controller.dart — Estado/dados da lista de Ordens de Serviço do Painel.
///
/// Espelha `OrdensServico.tsx` com mitigações Flutter Web (§4): filtros aplicados
/// NO SERVIDOR (status/profissional/data) + paginação por `getList` + scroll
/// infinito virtualizado (nunca `getFullList`). Consome a interface congelada
/// `OrdensRepository` (core). Lookups de Nova OS (serviços/profissionais) num
/// provider à parte; clientes são buscados sob demanda (server search).
///
/// Ordenação é **por aba de status** (pedido do dono, 18/07/2026): cada status
/// (e "Todas") guarda a sua própria [OrdensSort], persistida em
/// SharedPreferences — trocar a ordenação em Agendada não afeta Concluída.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/formatters/formatters.dart';
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

/// Período da lista de OS (feedback do dono, 16/07: as contagens cresceriam
/// para sempre — o dia a dia é a semana corrente; o resto é exceção).
enum OrdensPeriodo {
  hoje,
  semana,
  mes,
  tudo;

  String get label => switch (this) {
    OrdensPeriodo.hoje => 'Hoje',
    OrdensPeriodo.semana => 'Esta semana',
    OrdensPeriodo.mes => 'Este mês',
    OrdensPeriodo.tudo => 'Tudo',
  };
}

/// Janela [inicio, fim) do período em strings UTC do PB — `null` para "Tudo".
/// Dias/semana/mês calculados em BRT (G-8: fuso só nos formatters).
DateRange? ordensPeriodoRange(OrdensPeriodo periodo, {DateTime? now}) {
  switch (periodo) {
    case OrdensPeriodo.hoje:
      final b = getBrtDayBounds(now: now);
      return DateRange(b.todayStart, b.tomorrowStart);
    case OrdensPeriodo.semana:
      return getBrtWeekBounds(now: now);
    case OrdensPeriodo.mes:
      final brt = (now ?? DateTime.now()).toUtc().subtract(kBrtOffset);
      return getBrtMonthBounds(brt.year, brt.month);
    case OrdensPeriodo.tudo:
      return null;
  }
}

/// Ordenação da lista de OS. Aplicada NO SERVIDOR (campo `sort` do PB).
///
/// Defaults:
/// - abas abertas: **data mais próxima primeiro** (pedido 16/07);
/// - aba **Concluída**: **conclusão mais recente primeiro** (pedido 18/07) —
///   usa `concluida_em` (carimbo da transição), fallback `-updated`.
enum OrdensSort {
  dataAsc,
  dataDesc,
  clienteAsc,
  clienteDesc,
  conclusaoDesc;

  String get wire => switch (this) {
    OrdensSort.dataAsc => 'data_hora',
    OrdensSort.dataDesc => '-data_hora',
    // nome_curto é o nome do cliente denormalizado na OS (server-side).
    OrdensSort.clienteAsc => 'nome_curto',
    OrdensSort.clienteDesc => '-nome_curto',
    // Ordem em que o profissional CONCLUIU (não a data agendada).
    OrdensSort.conclusaoDesc => '-concluida_em,-updated',
  };

  String get label => switch (this) {
    OrdensSort.dataAsc => 'Data — mais próxima primeiro',
    OrdensSort.dataDesc => 'Data — mais distante primeiro',
    OrdensSort.clienteAsc => 'Cliente — A a Z',
    OrdensSort.clienteDesc => 'Cliente — Z a A',
    OrdensSort.conclusaoDesc => 'Conclusão — mais recente primeiro',
  };

  /// Parse estável do [name] do enum (prefs). Null se desconhecido.
  static OrdensSort? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in OrdensSort.values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

/// Chave de aba para preferência de ordenação: wire do status ou `all`.
String ordensSortTabKey(OSStatus? status) => status?.wire ?? 'all';

/// Prefixo das chaves em SharedPreferences (`ordens_sort_agendada`, …).
const String kOrdensSortPrefsPrefix = 'ordens_sort_';

/// Filtro ativo da lista: um status (ou `null` = todas) + período +
/// profissional opcional.
///
/// Defaults (pedido do dono, 16/07): a tela abre em **Agendadas** da
/// **semana corrente** — é onde ele decide quem atribuir 1–2 dias antes.
class OrdensFilter {
  const OrdensFilter({
    this.status = OSStatus.agendada,
    this.periodo = OrdensPeriodo.semana,
    this.sort = OrdensSort.dataAsc,
    this.profissionalId,
  });
  final OSStatus? status;
  final OrdensPeriodo periodo;
  final OrdensSort sort;
  final String? profissionalId;

  OrdensFilter copyWith({
    Object? status = _s,
    OrdensPeriodo? periodo,
    OrdensSort? sort,
    Object? profissionalId = _s,
  }) => OrdensFilter(
    status: status == _s ? this.status : status as OSStatus?,
    periodo: periodo ?? this.periodo,
    sort: sort ?? this.sort,
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
    _init();
  }

  final Ref _ref;

  /// Ordenação por aba (status wire | `all`). Sobrevive a trocas de aba e a
  /// reloads; espelhada em SharedPreferences.
  final Map<String, OrdensSort> _sortByTab = {};

  /// Preferência salva da aba, ou default.
  ///
  /// Aba **Concluída** é FIXA em [OrdensSort.conclusaoDesc] (pedido do dono
  /// 18/07: ordem em que o profissional concluiu, mais recentes primeiro).
  OrdensSort _sortFor(OSStatus? status) {
    if (status == OSStatus.concluida) return OrdensSort.conclusaoDesc;
    final key = ordensSortTabKey(status);
    final saved = _sortByTab[key];
    if (saved != null) return saved;
    return OrdensSort.dataAsc;
  }

  Future<void> _init() async {
    await _loadSortPrefs();
    final sort = _sortFor(state.filter.status);
    if (sort != state.filter.sort) {
      state = state.copyWith(filter: state.filter.copyWith(sort: sort));
    }
    await refresh();
  }

  Future<void> _loadSortPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = <String>[
        'all',
        for (final s in OSStatus.all) s.wire,
      ];
      for (final k in keys) {
        final parsed = OrdensSort.tryParse(
          prefs.getString('$kOrdensSortPrefsPrefix$k'),
        );
        if (parsed != null) _sortByTab[k] = parsed;
      }
    } catch (_) {
      /* prefs indisponíveis — segue com defaults */
    }
  }

  Future<void> _saveSortPref(String tabKey, OrdensSort sort) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$kOrdensSortPrefsPrefix$tabKey', sort.name);
    } catch (_) {
      /* best-effort */
    }
  }

  String? get _filterExpr {
    final range = ordensPeriodoRange(state.filter.periodo);
    return ordensFilter(
      status: state.filter.status,
      profissionalId: state.filter.profissionalId,
      dataInicio: range?.start,
      dataFim: range?.end,
    );
  }

  Future<PageResult<OrdemServico>> _fetch(int page) => _ref
      .read(ordensRepositoryProvider)
      .list(
        page: page,
        perPage: kOrdensPerPage,
        filter: _filterExpr,
        sort: state.filter.sort.wire,
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
    // Restaura a ordenação desta ABA (default: dataAsc se nunca escolheu).
    final sort = _sortFor(status);
    state = state.copyWith(
      filter: state.filter.copyWith(status: status, sort: sort),
    );
    await refresh();
  }

  Future<void> setPeriodo(OrdensPeriodo periodo) async {
    if (periodo == state.filter.periodo) return;
    state = state.copyWith(filter: state.filter.copyWith(periodo: periodo));
    await refresh();
  }

  Future<void> setSort(OrdensSort sort) async {
    // Concluída: não deixa mudar — sempre mais recente primeiro.
    if (state.filter.status == OSStatus.concluida) {
      sort = OrdensSort.conclusaoDesc;
    }
    final tab = ordensSortTabKey(state.filter.status);
    _sortByTab[tab] = sort;
    await _saveSortPref(tab, sort);
    if (sort == state.filter.sort) return;
    state = state.copyWith(filter: state.filter.copyWith(sort: sort));
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
  // Badges contam SÓ o período ativo — senão os números crescem para sempre
  // e a aba vira ruído (feedback do dono, 16/07).
  final periodo = ref.watch(
    ordensControllerProvider.select((s) => s.filter.periodo),
  );
  final repo = ref.watch(ordensRepositoryProvider);
  final range = ordensPeriodoRange(periodo);

  Future<int> count(OSStatus? status) async {
    final res = await repo.list(
      page: 1,
      perPage: 1,
      filter: ordensFilter(
        status: status,
        profissionalId: profId,
        dataInicio: range?.start,
        dataFim: range?.end,
      ),
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
