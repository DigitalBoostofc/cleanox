/// agenda_screen_test.dart — Grade densa da Agenda + montagem pura da grade.
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/painel/agenda/agenda_controller.dart';
import 'package:cleanos/painel/agenda/agenda_screen.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart' show FakeOrdens;
import 'fakes_onda3.dart';
import 'painel_test_helpers.dart';

void main() {
  group('buildAgendaGrid (puro)', () {
    test('cruza disponibilidade (livre) com OS (ocupado)', () {
      const date = '2026-07-01'; // quarta-feira
      final prof = fakeUser(id: 'p1');
      final grid = buildAgendaGrid(
        date: date,
        profissionais: [prof],
        dispByProf: {
          'p1': fakeDisponibilidade(
            id: 'd1',
            profissional: 'p1',
            duracaoMin: 60,
            inicio: '08:00',
            fim: '10:00',
          ),
        },
        osList: [
          fakeOSAgenda(
            id: 'os1',
            profissionalId: 'p1',
            dataHoraUtc: '2026-07-01 11:00:00', // 08:00 BRT
          ),
        ],
      );

      expect(grid.times, contains('08:00'));
      expect(grid.cell('p1', '08:00').kind, AgendaCellKind.ocupado);
      expect(grid.cell('p1', '08:15').kind, AgendaCellKind.livre);
      expect(grid.totalOcupados, 1);
    });

    test('dia inativo → sem slots livres', () {
      const date = '2026-07-01';
      final grid = buildAgendaGrid(
        date: date,
        profissionais: [fakeUser(id: 'p1')],
        dispByProf: {
          'p1': fakeDisponibilidade(
            id: 'd1',
            profissional: 'p1',
            diasAtivos: List<bool>.filled(7, false),
          ),
        },
        osList: const [],
      );
      expect(grid.isEmpty, isTrue);
    });
  });

  group('AgendaScreen (calendário)', () {
    // OS de HOJE (BRT) para cair na janela visível de forma
    // determinística, independente da data em que o teste roda.
    String hojeAs(String hhmm) =>
        localInputToPBDate('${todayLocalDate()}T$hhmm');

    testWidgets('abre por padrão no Dia de hoje e renderiza a OS', (
      tester,
    ) async {
      ignoreBenignAgendaOverflows();
      await pumpPainel(
        tester,
        const AgendaScreen(),
        overrides: [
          ...painelOverrides(
            user: painelUser(),
            repo: FakeOrdens(
              seed: [
                fakeOSAgenda(
                  id: 'os1',
                  profissionalId: 'p1',
                  nomeCurto: 'Carlos S.',
                  dataHoraUtc: hojeAs('13:00'),
                ),
              ],
            ),
          ),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuariosFull(
              seed: [fakeUser(id: 'p1', name: 'Bia Prof')],
            ),
          ),
        ],
      );
      await tester.pump(); // dispara load
      await tester.pump();
      await tester.pump();

      final viewSelector = tester.widget<SegmentedButton<AgendaView>>(
        find.byType(SegmentedButton<AgendaView>),
      );
      expect(viewSelector.selected, {AgendaView.dia});
      expect(find.textContaining('— Hoje'), findsOneWidget);
      expect(find.textContaining('Carlos S.'), findsWidgets);
      expectNoFatalLayoutException(tester);
    });

    testWidgets('dia de hoje vazio: grade renderiza sem eventos', (tester) async {
      await pumpPainel(
        tester,
        const AgendaScreen(),
        overrides: [
          ...painelOverrides(user: painelUser(), repo: FakeOrdens()),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuariosFull(seed: [fakeUser(id: 'p1', name: 'Bia Prof')]),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('— Hoje'), findsOneWidget);
      expect(find.textContaining('Carlos S.'), findsNothing);
    });

    testWidgets('toolbar tem Nova OS à esquerda (como em Ordens)', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const AgendaScreen(),
        overrides: [
          ...painelOverrides(user: painelUser(), repo: FakeOrdens()),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuariosFull(seed: [fakeUser(id: 'p1', name: 'Bia Prof')]),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('agenda-nova-os')), findsOneWidget);
      expect(find.text('Nova OS'), findsOneWidget);
      // À esquerda da data: o botão vem antes do chevron "Anterior".
      final nova = tester.getTopLeft(find.byKey(const ValueKey('agenda-nova-os')));
      final prev = tester.getTopLeft(find.byTooltip('Anterior'));
      expect(nova.dx, lessThan(prev.dx));
    });

    testWidgets(
      'legenda por profissional + avatar em OS atribuída (pedido do dono)',
      (tester) async {
        ignoreBenignAgendaOverflows();
        await pumpPainel(
          tester,
          const AgendaScreen(),
          overrides: [
            ...painelOverrides(
              user: painelUser(),
              repo: FakeOrdens(
                seed: [
                  fakeOSAgenda(
                    id: 'os1',
                    profissionalId: 'p1',
                    nomeCurto: 'Carlos S.',
                    dataHoraUtc: hojeAs('13:00'),
                    status: OSStatus.atribuida,
                    profExpand: fakeUser(id: 'p1', name: 'Bia Prof'),
                  ),
                ],
              ),
            ),
            usuariosRepositoryProvider.overrideWithValue(
              FakeUsuariosFull(seed: [fakeUser(id: 'p1', name: 'Bia Prof')]),
            ),
          ],
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Legenda: cor = profissional (não mais status).
        expect(find.text('Cor = profissional:'), findsOneWidget);
        expect(find.text('Bia Prof'), findsWidgets);
        expect(find.textContaining('check = concluída'), findsOneWidget);

        // Avatar do profissional presente no evento (OS atribuída).
        expect(find.byType(UserAvatar), findsWidgets);
        expect(
          find.byTooltip('Bia Prof'),
          findsWidgets,
          reason: 'o avatar do bloco deve identificar o profissional',
        );

        // Canto INFERIOR direito (pedido do dono, 16/07).
        final pos = tester.widget<Positioned>(
          find
              .ancestor(
                of: find.byTooltip('Bia Prof').first,
                matching: find.byType(Positioned),
              )
              .first,
        );
        expect(pos.bottom, 0, reason: 'avatar ancorado embaixo');
        expect(pos.right, 0, reason: 'avatar ancorado à direita');
        expect(pos.top, isNull, reason: 'não pode voltar pro topo');
        expectNoFatalLayoutException(tester);
      },
    );

    testWidgets('erro: falha ao carregar OS → banner', (tester) async {
      await pumpPainel(
        tester,
        const AgendaScreen(),
        overrides: [
          ...painelOverrides(
            user: painelUser(),
            repo: FakeOrdens(failList: true),
          ),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuariosFull(seed: [fakeUser(id: 'p1', name: 'Bia Prof')]),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorBanner), findsOneWidget);
    });
  });
}
