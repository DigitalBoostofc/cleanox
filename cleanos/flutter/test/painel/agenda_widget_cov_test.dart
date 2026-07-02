/// agenda_widget_cov_test.dart — Cobertura de RENDERIZAÇÃO das 3 visões da Agenda
/// (Dia / Semana / Mês) no Painel (desktop). Trava contra a regressão histórica de
/// crash "infinite height" na visão SEMANA (resolvida com IntrinsicHeight): cada
/// visão precisa montar SEM exceção de layout/overflow — `tester.takeException()`
/// deve ser `null` mesmo com vários eventos empilhados numa única célula.
///
/// Determinístico e sem rede: OS fixadas em datas explícitas via BRT
/// (`localInputToPBDate`), profissionais e ordens vindos de fakes. Viewport padrão
/// do `pumpPainel` é 1400×900 → aciona as variantes DESKTOP (_WeekView/_MonthView/
/// _DayView), exatamente onde o crash de altura infinita acontecia.
library;

import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/painel/agenda/agenda_controller.dart';
import 'package:cleanos/painel/agenda/agenda_screen.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart' show FakeOrdens;
import 'fakes_onda3.dart';
import 'painel_test_helpers.dart';

void main() {
  // HOJE (BRT, date-only) — âncora inicial do controller. Fixar a partir daqui
  // mantém os testes determinísticos independente de QUANDO rodam: os eventos
  // caem sempre na janela visível (dia/semana/mês) da âncora "hoje".
  final hoje = DateTime.parse(todayLocalDate());

  String dd(int n) => n.toString().padLeft(2, '0');

  /// String UTC do PB (BRT = UTC-3) para [dia] às [hhmm] no relógio de parede BRT.
  String pbAt(DateTime dia, String hhmm) => localInputToPBDate(
    '${dia.year}-${dd(dia.month)}-${dd(dia.day)}T$hhmm',
  );

  /// Sobe a AgendaScreen (desktop) com [seed] de OS e um profissional fake, e
  /// bombeia frames suficientes p/ o `load()` assíncrono do controller assentar.
  Future<void> pumpAgenda(
    WidgetTester tester, {
    List<OrdemServico> seed = const [],
  }) async {
    await pumpPainel(
      tester,
      const AgendaScreen(),
      overrides: [
        ...painelOverrides(user: painelUser(), repo: FakeOrdens(seed: seed)),
        usuariosRepositoryProvider.overrideWithValue(
          FakeUsuariosFull(seed: [fakeUser(id: 'p1', name: 'Bia Prof')]),
        ),
      ],
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  /// Seleciona a visão pela aba do SegmentedButton ('Dia' | 'Semana' | 'Mês') e
  /// deixa o novo `load()` assentar.
  Future<void> selecionarVisao(WidgetTester tester, String aba) async {
    await tester.tap(find.text(aba));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  group('Visão DIA', () {
    testWidgets('renderiza vazia sem exceção de layout', (tester) async {
      await pumpAgenda(tester);
      await selecionarVisao(tester, 'Dia');

      // Grade de horas montada (6h..22h) e nenhum crash de layout.
      expect(find.text('13h'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renderiza com eventos do dia sem exceção', (tester) async {
      await pumpAgenda(
        tester,
        seed: [
          fakeOSAgenda(
            id: 'os1',
            profissionalId: 'p1',
            nomeCurto: 'Carlos S.',
            dataHoraUtc: pbAt(hoje, '13:00'),
          ),
          fakeOSAgenda(
            id: 'os2',
            profissionalId: 'p1',
            nomeCurto: 'Marina L.',
            dataHoraUtc: pbAt(hoje, '15:30'),
          ),
        ],
      );
      await selecionarVisao(tester, 'Dia');

      expect(find.textContaining('Carlos S.'), findsWidgets);
      expect(find.textContaining('Marina L.'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Visão SEMANA (regressão de altura infinita)', () {
    testWidgets('semana vazia: grade renderiza sem exceção', (tester) async {
      // Default do controller já é a visão semana.
      await pumpAgenda(tester);

      // Cabeçalho de dias presente; nenhum crash de layout.
      expect(find.text('Seg'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semana com eventos distribuídos em vários dias', (
      tester,
    ) async {
      final ws = startOfWeek(hoje);
      await pumpAgenda(
        tester,
        seed: [
          fakeOSAgenda(
            id: 'a',
            profissionalId: 'p1',
            nomeCurto: 'Seg Cliente',
            dataHoraUtc: pbAt(addDays(ws, 1), '09:00'),
          ),
          fakeOSAgenda(
            id: 'b',
            profissionalId: 'p1',
            nomeCurto: 'Qua Cliente',
            dataHoraUtc: pbAt(addDays(ws, 3), '14:00'),
          ),
          fakeOSAgenda(
            id: 'c',
            profissionalId: 'p1',
            nomeCurto: 'Sex Cliente',
            dataHoraUtc: pbAt(addDays(ws, 5), '17:00'),
          ),
        ],
      );

      expect(find.textContaining('Qua Cliente'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'muitos eventos empilhados na MESMA célula não crasham (IntrinsicHeight)',
      (tester) async {
        // Cenário que antes estourava altura infinita: N eventos no mesmo
        // dia/hora, empilhados numa célula dentro do scroll vertical da semana.
        final seed = [
          for (var i = 0; i < 16; i++)
            fakeOSAgenda(
              id: 'stack$i',
              profissionalId: 'p1',
              nomeCurto: 'Empilhado $i',
              dataHoraUtc: pbAt(hoje, '13:00'),
            ),
        ];
        await pumpAgenda(tester, seed: seed);

        // Renderizou a pilha sem exceção de layout — o IntrinsicHeight segura.
        expect(find.textContaining('Empilhado'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Visão MÊS', () {
    testWidgets('renderiza a grade do mês sem exceção', (tester) async {
      await pumpAgenda(tester);
      await selecionarVisao(tester, 'Mês');

      // Cabeçalho dos dias da semana (Dom..Sáb) presente.
      expect(find.text('Dom'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('navegação ‹/› muda o período exibido sem quebrar', (
      tester,
    ) async {
      await pumpAgenda(tester);
      await selecionarVisao(tester, 'Mês');

      final anchorMes = DateTime(hoje.year, hoje.month, 1);
      final labelAtual = agendaPeriodLabel(AgendaView.mes, anchorMes);
      final labelProx = agendaPeriodLabel(
        AgendaView.mes,
        DateTime(hoje.year, hoje.month + 1, 1),
      );

      // Sanidade: os rótulos de mês adjacente são de fato distintos.
      expect(labelAtual, isNot(labelProx));
      expect(find.text(labelAtual), findsOneWidget);

      // Avança um mês.
      await tester.tap(find.byTooltip('Próximo'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.text(labelProx), findsOneWidget);
      expect(find.text(labelAtual), findsNothing);
      expect(tester.takeException(), isNull);

      // Volta um mês → de novo o período inicial.
      await tester.tap(find.byTooltip('Anterior'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.text(labelAtual), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Alternância entre visões', () {
    testWidgets('Semana → Dia → Mês → Semana em sequência sem exceção', (
      tester,
    ) async {
      await pumpAgenda(
        tester,
        seed: [
          fakeOSAgenda(
            id: 'os1',
            profissionalId: 'p1',
            nomeCurto: 'Cliente X',
            dataHoraUtc: pbAt(hoje, '10:00'),
          ),
        ],
      );

      // Começa em SEMANA (default).
      expect(find.text('Seg'), findsWidgets);
      expect(tester.takeException(), isNull);

      await selecionarVisao(tester, 'Dia');
      expect(find.text('13h'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await selecionarVisao(tester, 'Mês');
      expect(find.text('Dom'), findsWidgets);
      expect(tester.takeException(), isNull);

      await selecionarVisao(tester, 'Semana');
      expect(find.text('Seg'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
