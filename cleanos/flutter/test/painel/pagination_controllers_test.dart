/// pagination_controllers_test.dart — Bordas da paginação/scroll infinito dos
/// controllers paginados do Painel (item 8 do ciclo): Lançamentos
/// ([FinLancController]) e Avaliações ([AvaliacoesController]).
///
/// Prova, para AMBOS (o padrão loadMore é idêntico): a última página PARA
/// (hasMore=false e não refaz fetch); um erro NO MEIO da paginação preserva os
/// itens já carregados e volta loadingMore→false sem crash; página 1 vazia; e
/// nenhum ID duplicado após 2 loadMore. Usa fakes paginados SEM rede.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/core/repositories/usuarios_repository.dart';
import 'package:cleanos/painel/avaliacoes/avaliacoes_controller.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/lancamentos/fin_lancamentos_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'fakes_painel.dart';

/* ─────────────────── fakes paginados ─────────────────── */

/// Fake do Financeiro que pagina `listLancamentos` a partir de uma lista fixa.
class PagingFinanceiro extends FakeFinanceiro {
  PagingFinanceiro(this.all, {this.failOnPage});
  final List<FinLancamento> all;

  /// Se setado, `listLancamentos(page: failOnPage)` lança (erro no meio).
  final int? failOnPage;
  int fetchCount = 0;

  @override
  Future<PageResult<FinLancamento>> listLancamentos({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data',
  }) async {
    fetchCount++;
    if (failOnPage == page) throw Exception('falha na página $page');
    return _slice(all, page, perPage);
  }
}

/// Fake de Ordens que pagina `list`. Falha só nas PÁGINAS de UI (perPage < 100),
/// nunca no agregado de média por profissional (perPage = _kAggCap = 1000).
class PagingOrdens extends FakePainelOrdens {
  PagingOrdens(this.all, {this.failOnPage});
  final List<OrdemServico> all;
  final int? failOnPage;

  /// Nº de fetches de PÁGINA (exclui o agregado da média).
  int pageFetches = 0;

  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async {
    final isPageFetch = perPage < 100; // o agregado usa perPage 500
    if (isPageFetch) pageFetches++;
    if (isPageFetch && failOnPage == page) {
      throw Exception('falha na página $page');
    }
    return _slice(all, page, perPage);
  }
}

PageResult<T> _slice<T>(List<T> all, int page, int perPage) {
  final start = (page - 1) * perPage;
  final items = start >= all.length
      ? <T>[]
      : all.sublist(start, (start + perPage).clamp(0, all.length));
  final totalPages = all.isEmpty ? 1 : (all.length + perPage - 1) ~/ perPage;
  return PageResult<T>(
    items: items,
    page: page,
    perPage: perPage,
    totalItems: all.length,
    totalPages: totalPages,
  );
}

List<FinLancamento> _lancs(int n) =>
    List.generate(n, (i) => fakeLanc(id: 'l$i', descricao: 'Lanç $i'));

/// Avaliações do profissional 'p1' (todas com nota → entram no agregado).
List<OrdemServico> _avaliacoes(int n) => List.generate(
  n,
  (i) => painelOS(id: 'a$i', status: OSStatus.concluida).copyWith(
    profissional: 'p1',
    avaliacaoNota: 5,
    avaliacaoEm: '2026-07-0${(i % 9) + 1} 13:00:00Z',
  ),
);

/// Fake mínimo de `UsuariosRepository`: devolve uma lista fixa de profissionais.
class FakeUsuarios implements UsuariosRepository {
  FakeUsuarios(this.users);
  final List<User> users;

  @override
  Future<List<User>> list({String? filter, String sort = 'nome'}) async => users;

  Never _unused() => throw UnimplementedError('não usado nos testes');
  @override
  Future<User> getOne(String id) => _unused();
  @override
  Future<User> create(Map<String, dynamic> data, {AvatarUpload? avatar}) => _unused();
  @override
  Future<User> update(String id, Map<String, dynamic> data, {AvatarUpload? avatar}) => _unused();
  @override
  Future<void> delete(String id) => _unused();
  @override
  Future<void> redefinirSenha({
    required String userId,
    required String novaSenha,
    required String adminSenha,
  }) => _unused();
}

final _profP1 = const User(id: 'p1', name: 'Ana', role: Role.profissional);

void main() {
  /* ─────────────────── Lançamentos (FinLancController) ─────────────────── */

  group('Lançamentos: paginação/loadMore', () {
    ProviderContainer container(PagingFinanceiro fake) {
      final c = ProviderContainer(
        overrides: [financeiroRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);
      c.listen(finLancControllerProvider, (_, __) {});
      return c;
    }

    test('última página PARA (hasMore=false) e não refaz fetch', () async {
      final fake = PagingFinanceiro(_lancs(90)); // perPage 40 → 3 páginas
      final ctrl = container(fake).read(finLancControllerProvider.notifier);
      await ctrl.refresh();
      expect(ctrl.state.items.length, kFinLancPerPage);
      expect(ctrl.state.hasMore, isTrue);

      await ctrl.loadMore(); // pág 2 → 80
      await ctrl.loadMore(); // pág 3 → 90
      expect(ctrl.state.items.length, 90);
      expect(ctrl.state.hasMore, isFalse);

      final before = fake.fetchCount;
      await ctrl.loadMore(); // no-op (não há mais páginas)
      expect(fake.fetchCount, before, reason: 'não deve refazer fetch');
      expect(ctrl.state.items.length, 90);
    });

    test('erro no MEIO preserva itens anteriores e zera loadingMore', () async {
      final fake = PagingFinanceiro(_lancs(90), failOnPage: 2);
      final ctrl = container(fake).read(finLancControllerProvider.notifier);
      await ctrl.refresh(); // pág 1 ok
      expect(ctrl.state.items.length, kFinLancPerPage);

      await ctrl.loadMore(); // pág 2 falha
      expect(ctrl.state.items.length, kFinLancPerPage, reason: 'preservados');
      expect(ctrl.state.loadingMore, isFalse);
      expect(ctrl.state.hasMore, isTrue); // page não avançou
    });

    test('página 1 vazia → isEmpty e sem loadMore', () async {
      final fake = PagingFinanceiro(const <FinLancamento>[]);
      final ctrl = container(fake).read(finLancControllerProvider.notifier);
      await ctrl.refresh();
      expect(ctrl.state.items, isEmpty);
      expect(ctrl.state.isEmpty, isTrue);
      expect(ctrl.state.hasMore, isFalse);
    });

    test('sem IDs duplicados após 2 loadMore', () async {
      final fake = PagingFinanceiro(_lancs(90));
      final ctrl = container(fake).read(finLancControllerProvider.notifier);
      await ctrl.refresh();
      await ctrl.loadMore();
      await ctrl.loadMore();
      final ids = ctrl.state.items.map((l) => l.id).toList();
      expect(ids.length, 90);
      expect(ids.toSet().length, ids.length, reason: 'sem duplicatas');
    });

    test('applyStatusLocally troca 1 item sem re-fetch (scroll não pula)',
        () async {
      final fake = PagingFinanceiro(_lancs(90));
      final ctrl = container(fake).read(finLancControllerProvider.notifier);
      await ctrl.refresh();
      await ctrl.loadMore();
      await ctrl.loadMore(); // 90 itens, 3 páginas carregadas
      final fetchAntes = fake.fetchCount;
      final ordemAntes = ctrl.state.items.map((l) => l.id).toList();

      // fakeLanc nasce pago; a mãozinha marca pendente.
      ctrl.applyStatusLocally('l45', LancamentoStatus.pendente);

      // Sem re-fetch → a lista não é reconstruída → scroll preservado.
      expect(fake.fetchCount, fetchAntes, reason: 'não recarrega a lista');
      expect(ctrl.state.items.length, 90);
      expect(
        ctrl.state.items.map((l) => l.id).toList(),
        ordemAntes,
        reason: 'mesma ordem e tamanho',
      );
      expect(
        ctrl.state.items.firstWhere((l) => l.id == 'l45').status,
        LancamentoStatus.pendente,
      );
      // Só o alvo mudou.
      expect(
        ctrl.state.items.where((l) => l.status == LancamentoStatus.pendente).length,
        1,
      );
    });
  });

  /* ─────────────────── Avaliações (AvaliacoesController) ─────────────────── */

  group('Avaliações: acordeão por profissional + paginação das avaliações', () {
    ProviderContainer container(PagingOrdens fake, {List<User>? profs}) {
      final c = ProviderContainer(
        overrides: [
          ordensRepositoryProvider.overrideWithValue(fake),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuarios(profs ?? [_profP1]),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(avaliacoesControllerProvider, (_, __) {});
      return c;
    }

    test('refresh agrega média/total por profissional', () async {
      final fake = PagingOrdens(_avaliacoes(12));
      final ctrl = container(fake).read(avaliacoesControllerProvider.notifier);
      await ctrl.refresh();
      expect(ctrl.state.isEmpty, isFalse);
      final stats = ctrl.state.statsOf('p1');
      expect(stats, isNotNull);
      expect(stats!.total, 12);
      expect(stats.media, 5.0);
      expect(ctrl.state.openId, isNull, reason: 'acordeão começa fechado');
    });

    test(
      'expandir carrega a 1ª página; última página PARA e não refaz fetch',
      () async {
        final fake = PagingOrdens(_avaliacoes(12)); // perPage 5 → 3 páginas
        final ctrl = container(
          fake,
        ).read(avaliacoesControllerProvider.notifier);
        await ctrl.refresh();

        await ctrl.toggle('p1'); // abre → pág 1
        expect(ctrl.state.reviews.length, kAvaliacoesPageSize);
        expect(ctrl.state.reviewsTotal, 12);
        expect(ctrl.state.hasMore, isTrue);

        await ctrl.loadMore(); // pág 2 → 10
        await ctrl.loadMore(); // pág 3 → 12
        expect(ctrl.state.reviews.length, 12);
        expect(ctrl.state.hasMore, isFalse);

        final before = fake.pageFetches;
        await ctrl.loadMore(); // no-op
        expect(fake.pageFetches, before, reason: 'não deve refazer fetch');
      },
    );

    test('erro no MEIO preserva avaliações anteriores e zera loading', () async {
      final fake = PagingOrdens(_avaliacoes(12), failOnPage: 2);
      final ctrl = container(fake).read(avaliacoesControllerProvider.notifier);
      await ctrl.refresh();
      await ctrl.toggle('p1'); // pág 1 ok
      expect(ctrl.state.reviews.length, kAvaliacoesPageSize);

      await ctrl.loadMore(); // pág 2 falha
      expect(
        ctrl.state.reviews.length,
        kAvaliacoesPageSize,
        reason: 'preservadas',
      );
      expect(ctrl.state.reviewsLoading, isFalse);
      expect(ctrl.state.reviewsError, isNotNull);
      expect(ctrl.state.hasMore, isTrue);
    });

    test('fechar o profissional limpa as avaliações', () async {
      final fake = PagingOrdens(_avaliacoes(12));
      final ctrl = container(fake).read(avaliacoesControllerProvider.notifier);
      await ctrl.refresh();
      await ctrl.toggle('p1');
      expect(ctrl.state.reviews, isNotEmpty);
      await ctrl.toggle('p1'); // fecha
      expect(ctrl.state.openId, isNull);
      expect(ctrl.state.reviews, isEmpty);
    });

    test('sem profissionais → isEmpty', () async {
      final fake = PagingOrdens(const <OrdemServico>[]);
      final ctrl = container(
        fake,
        profs: const [],
      ).read(avaliacoesControllerProvider.notifier);
      await ctrl.refresh();
      expect(ctrl.state.isEmpty, isTrue);
    });

    test('sem IDs duplicados após 2 loadMore', () async {
      final fake = PagingOrdens(_avaliacoes(12));
      final ctrl = container(fake).read(avaliacoesControllerProvider.notifier);
      await ctrl.refresh();
      await ctrl.toggle('p1');
      await ctrl.loadMore();
      await ctrl.loadMore();
      final ids = ctrl.state.reviews.map((o) => o.id).toList();
      expect(ids.length, 12);
      expect(ids.toSet().length, ids.length, reason: 'sem duplicatas');
    });
  });
}
