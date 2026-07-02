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
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/avaliacoes/avaliacoes_controller.dart';
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
/// nunca no agregado de média (perPage = _kAggCap = 500).
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

List<OrdemServico> _ordens(int n) =>
    List.generate(n, (i) => painelOS(id: 'a$i', status: OSStatus.concluida));

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
  });

  /* ─────────────────── Avaliações (AvaliacoesController) ─────────────────── */

  group('Avaliações: paginação/loadMore (mesmo padrão)', () {
    ProviderContainer container(PagingOrdens fake) {
      final c = ProviderContainer(
        overrides: [ordensRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);
      c.listen(avaliacoesControllerProvider, (_, __) {});
      return c;
    }

    test(
      'última página PARA (hasMore=false) e não refaz fetch de página',
      () async {
        final fake = PagingOrdens(_ordens(50)); // perPage 20 → 3 páginas
        final ctrl = container(
          fake,
        ).read(avaliacoesControllerProvider.notifier);
        await ctrl.refresh();
        expect(ctrl.state.items.length, kAvaliacoesPerPage);
        expect(ctrl.state.hasMore, isTrue);

        await ctrl.loadMore(); // pág 2 → 40
        await ctrl.loadMore(); // pág 3 → 50
        expect(ctrl.state.items.length, 50);
        expect(ctrl.state.hasMore, isFalse);

        final before = fake.pageFetches;
        await ctrl.loadMore(); // no-op
        expect(fake.pageFetches, before, reason: 'não deve refazer fetch');
      },
    );

    test('erro no MEIO preserva itens anteriores e zera loadingMore', () async {
      final fake = PagingOrdens(_ordens(50), failOnPage: 2);
      final ctrl = container(fake).read(avaliacoesControllerProvider.notifier);
      await ctrl.refresh(); // pág 1 + agregado ok
      expect(ctrl.state.items.length, kAvaliacoesPerPage);

      await ctrl.loadMore(); // pág 2 falha
      expect(
        ctrl.state.items.length,
        kAvaliacoesPerPage,
        reason: 'preservados',
      );
      expect(ctrl.state.loadingMore, isFalse);
      expect(ctrl.state.hasMore, isTrue);
    });

    test('página 1 vazia → isEmpty', () async {
      final fake = PagingOrdens(const <OrdemServico>[]);
      final ctrl = container(fake).read(avaliacoesControllerProvider.notifier);
      await ctrl.refresh();
      expect(ctrl.state.items, isEmpty);
      expect(ctrl.state.isEmpty, isTrue);
      expect(ctrl.state.hasMore, isFalse);
    });

    test('sem IDs duplicados após 2 loadMore', () async {
      final fake = PagingOrdens(_ordens(50));
      final ctrl = container(fake).read(avaliacoesControllerProvider.notifier);
      await ctrl.refresh();
      await ctrl.loadMore();
      await ctrl.loadMore();
      final ids = ctrl.state.items.map((o) => o.id).toList();
      expect(ids.length, 50);
      expect(ids.toSet().length, ids.length, reason: 'sem duplicatas');
    });
  });
}
