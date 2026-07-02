/// avaliacoes_screen_test.dart — Avaliações do Painel (Onda 5): lista, vazio,
/// erro e média.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/painel/avaliacoes/avaliacoes_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'fakes_onda5.dart';
import 'painel_test_helpers.dart';

void main() {
  group('AvaliacoesScreen', () {
    testWidgets('lista: renderiza as OS avaliadas com serviço/cliente/motivo', (
      tester,
    ) async {
      final repo = FakeOrdens(
        seed: [
          fakeAvaliacaoOS(
            id: 'a',
            nota: 5,
            servico: 'Higienização de sofá',
            nomeCurto: 'Carlos S.',
          ),
          fakeAvaliacaoOS(
            id: 'b',
            nota: 2,
            servico: 'Limpeza de colchão',
            nomeCurto: 'Ana P.',
            motivo: 'Atrasou bastante',
          ),
        ],
      );
      await pumpPainel(
        tester,
        const AvaliacoesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          ordensRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Higienização de sofá'), findsOneWidget);
      expect(find.text('Limpeza de colchão'), findsOneWidget);
      expect(find.text('Carlos S.'), findsOneWidget);
      expect(find.text('Atrasou bastante'), findsOneWidget);
    });

    testWidgets('vazio: estado sem avaliações', (tester) async {
      await pumpPainel(
        tester,
        const AvaliacoesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          ordensRepositoryProvider.overrideWithValue(FakeOrdens()),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nenhuma avaliação ainda'), findsOneWidget);
    });

    testWidgets('erro: banner com retry', (tester) async {
      await pumpPainel(
        tester,
        const AvaliacoesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          ordensRepositoryProvider.overrideWithValue(
            FakeOrdens(failList: true),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorBanner), findsOneWidget);
    });

    testWidgets('média: calcula a média das notas do conjunto', (tester) async {
      final repo = FakeOrdens(
        seed: [
          fakeAvaliacaoOS(id: 'a', nota: 5),
          fakeAvaliacaoOS(id: 'b', nota: 4),
          fakeAvaliacaoOS(id: 'c', nota: 3),
        ],
      );
      await pumpPainel(
        tester,
        const AvaliacoesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          ordensRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump();

      // (5 + 4 + 3) / 3 = 4.0
      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('3 avaliações'), findsOneWidget);
    });
  });
}
