/// avaliacoes_controller.dart — Estado/dados das Avaliações do Painel.
///
/// Espelha `Avaliacoes.tsx`: acordeão POR PROFISSIONAL. Carrega os profissionais
/// (`role = 'profissional'`) e agrega a média/total de estrelas de cada um a partir
/// das OS já avaliadas (`avaliacao_nota >= 1`). Os profissionais são ordenados por
/// média (desc); quem ainda não tem avaliação vai ao fim (por nome). Ao expandir um
/// profissional, carrega as avaliações DELE paginadas (5/página, `getList`, nunca
/// `getFullList`) com "Ver mais". Consome só a interface congelada
/// `OrdensRepository`/`UsuariosRepository` (core) — NÃO altera o core.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';
import '../data/painel_filters.dart';
import '../data/painel_providers.dart';

/// Tamanho da página das avaliações de um profissional (espelha `PAGE_SIZE`).
const int kAvaliacoesPageSize = 5;

/// Teto do agregado de média/total por profissional. Cobre folgadamente o volume
/// real (o backend documenta < ~50 avaliações/mês). `getList` (não `getFullList`).
const int _kAggCap = 1000;

/// Média + total de avaliações de um profissional.
class RatingStats {
  const RatingStats({required this.media, required this.total});
  final double media;
  final int total;
}

class AvaliacoesState {
  const AvaliacoesState({
    this.profissionais = const [],
    this.ratingByProf = const {},
    this.loading = true,
    this.error,
    this.openId,
    this.reviews = const [],
    this.reviewsPage = 1,
    this.reviewsTotal = 0,
    this.reviewsLoading = false,
    this.reviewsError,
  });

  final List<User> profissionais;

  /// ratingByProf[profId] → média/total. Ausência = sem avaliações ainda.
  final Map<String, RatingStats> ratingByProf;
  final bool loading;
  final String? error;

  /// Profissional expandido no acordeão (null = todos fechados).
  final String? openId;

  /// Avaliações carregadas do profissional expandido (acumuladas).
  final List<OrdemServico> reviews;
  final int reviewsPage;
  final int reviewsTotal;
  final bool reviewsLoading;
  final String? reviewsError;

  bool get isEmpty => profissionais.isEmpty;
  bool get hasMore => reviews.length < reviewsTotal;

  RatingStats? statsOf(String profId) => ratingByProf[profId];

  AvaliacoesState copyWith({
    List<User>? profissionais,
    Map<String, RatingStats>? ratingByProf,
    bool? loading,
    Object? error = _s,
    Object? openId = _s,
    List<OrdemServico>? reviews,
    int? reviewsPage,
    int? reviewsTotal,
    bool? reviewsLoading,
    Object? reviewsError = _s,
  }) => AvaliacoesState(
    profissionais: profissionais ?? this.profissionais,
    ratingByProf: ratingByProf ?? this.ratingByProf,
    loading: loading ?? this.loading,
    error: error == _s ? this.error : error as String?,
    openId: openId == _s ? this.openId : openId as String?,
    reviews: reviews ?? this.reviews,
    reviewsPage: reviewsPage ?? this.reviewsPage,
    reviewsTotal: reviewsTotal ?? this.reviewsTotal,
    reviewsLoading: reviewsLoading ?? this.reviewsLoading,
    reviewsError: reviewsError == _s
        ? this.reviewsError
        : reviewsError as String?,
  );

  static const Object _s = Object();
}

class AvaliacoesController extends StateNotifier<AvaliacoesState> {
  AvaliacoesController(this._ref) : super(const AvaliacoesState()) {
    refresh();
  }

  final Ref _ref;

  /// Token que invalida cargas de avaliações em voo quando o usuário troca o
  /// profissional expandido (espelha o `reviewsFetchKeyRef` do React).
  int _reviewsToken = 0;

  Future<void> refresh() async {
    state = state.copyWith(
      loading: true,
      error: null,
      openId: null,
      reviews: const [],
      reviewsPage: 1,
      reviewsTotal: 0,
    );
    try {
      // Profissionais + OS avaliadas (para agregar média/total por profissional).
      final profs = await _ref
          .read(usuariosRepositoryProvider)
          .list(filter: profissionaisFilter(), sort: 'name');

      final avaliadas = await _ref
          .read(ordensRepositoryProvider)
          .list(
            page: 1,
            perPage: _kAggCap,
            filter: avaliacoesFilter(),
            sort: '-avaliacao_em',
          );

      // Agrega soma/total por profissional → média.
      final soma = <String, double>{};
      final total = <String, int>{};
      for (final os in avaliadas.items) {
        final pid = os.profissional;
        final nota = os.avaliacaoNota;
        if (pid == null || pid.isEmpty || nota == null || nota < 1) continue;
        soma[pid] = (soma[pid] ?? 0) + nota;
        total[pid] = (total[pid] ?? 0) + 1;
      }
      final ratingByProf = <String, RatingStats>{
        for (final pid in total.keys)
          pid: RatingStats(media: soma[pid]! / total[pid]!, total: total[pid]!),
      };

      // Ordena: com avaliação primeiro (média desc); sem avaliação por nome.
      final ordered = [...profs]..sort((a, b) {
        final ra = ratingByProf[a.id];
        final rb = ratingByProf[b.id];
        if (ra != null && rb != null) return rb.media.compareTo(ra.media);
        if (ra != null) return -1;
        if (rb != null) return 1;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });

      state = state.copyWith(
        profissionais: ordered,
        ratingByProf: ratingByProf,
        loading: false,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Não foi possível carregar os profissionais.',
      );
    }
  }

  /// Abre/fecha o profissional [profId] no acordeão. Ao abrir, carrega a 1ª página.
  Future<void> toggle(String profId) {
    if (state.openId == profId) {
      _reviewsToken++;
      state = state.copyWith(
        openId: null,
        reviews: const [],
        reviewsPage: 1,
        reviewsTotal: 0,
        reviewsError: null,
      );
      return Future.value();
    }
    state = state.copyWith(
      openId: profId,
      reviews: const [],
      reviewsPage: 1,
      reviewsTotal: 0,
      reviewsError: null,
    );
    return _loadReviews(profId, 1, reset: true);
  }

  /// Carrega mais uma página de avaliações do profissional aberto.
  Future<void> loadMore() {
    final open = state.openId;
    if (open == null || state.reviewsLoading || !state.hasMore) {
      return Future.value();
    }
    return _loadReviews(open, state.reviewsPage + 1, reset: false);
  }

  Future<void> _loadReviews(
    String profId,
    int page, {
    required bool reset,
  }) async {
    final token = ++_reviewsToken;
    state = state.copyWith(reviewsLoading: true, reviewsError: null);
    try {
      final res = await _ref
          .read(ordensRepositoryProvider)
          .list(
            page: page,
            perPage: kAvaliacoesPageSize,
            filter:
                'profissional = ${pbStringLiteral(profId)} && avaliacao_nota >= 1',
            sort: '-avaliacao_em',
          );
      // Descarta se o usuário trocou de profissional durante a carga.
      if (token != _reviewsToken || state.openId != profId) return;
      state = state.copyWith(
        reviews: reset ? res.items : [...state.reviews, ...res.items],
        reviewsPage: res.page,
        reviewsTotal: res.totalItems,
        reviewsLoading: false,
      );
    } catch (_) {
      if (token != _reviewsToken || state.openId != profId) return;
      state = state.copyWith(
        reviewsLoading: false,
        reviewsError: 'Não foi possível carregar as avaliações.',
      );
    }
  }
}

final avaliacoesControllerProvider =
    StateNotifierProvider.autoDispose<AvaliacoesController, AvaliacoesState>(
      AvaliacoesController.new,
    );
