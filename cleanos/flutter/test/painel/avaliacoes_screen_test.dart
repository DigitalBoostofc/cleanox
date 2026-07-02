/// avaliacoes_screen_test.dart — Avaliações do Painel (Onda 5): acordeão por
/// profissional (média no cabeçalho, avaliações ao expandir), vazio e erro.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/avaliacoes/avaliacoes_screen.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'fakes_onda5.dart';
import 'painel_test_helpers.dart';

/// OS avaliada do profissional [profId] (o acordeão agrega por esse campo).
OrdemServico _avaliacaoDe(
  String profId, {
  required String id,
  double nota = 5,
  String? motivo,
  String nomeCurto = 'Carlos S.',
  String servico = 'Higienização de sofá',
}) => fakeAvaliacaoOS(
  id: id,
  nota: nota,
  motivo: motivo,
  nomeCurto: nomeCurto,
  servico: servico,
).copyWith(profissional: profId);

const _pedro = User(id: 'p1', name: 'Pedro Santos', role: Role.profissional);

void main() {
  group('AvaliacoesScreen (acordeão)', () {
    testWidgets('cabeçalho mostra o profissional; expandir revela as avaliações', (
      tester,
    ) async {
      final ordens = FakeOrdens(
        seed: [
          _avaliacaoDe('p1', id: 'a', nota: 5, servico: 'Higienização de sofá'),
          _avaliacaoDe(
            'p1',
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
          ordensRepositoryProvider.overrideWithValue(ordens),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuariosRepo(const [_pedro]),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      // Cabeçalho do acordeão: nome do profissional (fechado ainda).
      expect(find.text('Pedro Santos'), findsOneWidget);
      expect(find.text('Higienização de sofá'), findsNothing);

      // Expande → carrega as avaliações do profissional.
      await tester.tap(find.text('Pedro Santos'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Higienização de sofá'), findsOneWidget);
      expect(find.text('Limpeza de colchão'), findsOneWidget);
      expect(find.text('Atrasou bastante'), findsOneWidget);
    });

    testWidgets('vazio: nenhum profissional cadastrado', (tester) async {
      await pumpPainel(
        tester,
        const AvaliacoesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          ordensRepositoryProvider.overrideWithValue(FakeOrdens()),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuariosRepo(const []),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nenhum profissional cadastrado'), findsOneWidget);
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
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuariosRepo(const [_pedro]),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorBanner), findsOneWidget);
    });

    testWidgets('média: cabeçalho mostra a média das notas do profissional', (
      tester,
    ) async {
      final ordens = FakeOrdens(
        seed: [
          _avaliacaoDe('p1', id: 'a', nota: 5),
          _avaliacaoDe('p1', id: 'b', nota: 4),
          _avaliacaoDe('p1', id: 'c', nota: 3),
        ],
      );
      await pumpPainel(
        tester,
        const AvaliacoesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          ordensRepositoryProvider.overrideWithValue(ordens),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuariosRepo(const [_pedro]),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      // (5 + 4 + 3) / 3 = 4.0 — média + contagem no cabeçalho do acordeão.
      expect(find.textContaining('4.0'), findsOneWidget);
      expect(find.textContaining('3 avaliações'), findsOneWidget);
    });
  });
}
