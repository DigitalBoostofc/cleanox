/// dashboard_screen_test.dart — Dashboard do Painel: dados / vazio / erro.
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/painel/dashboard/dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_painel.dart';
import 'painel_test_helpers.dart';

void main() {
  group('DashboardScreen', () {
    testWidgets(
      'com dados: KPIs contam por status e lista mostra atendimentos',
      (tester) async {
        // Chamada 0 = OS de hoje (base dos KPIs); chamada 1 = próximos.
        final repo = FakePainelOrdens(
          byIndex: (i) => i == 0
              ? [
                  painelOS(id: 'a', status: OSStatus.agendada),
                  painelOS(id: 'b', status: OSStatus.agendada),
                  painelOS(id: 'c', status: OSStatus.emAndamento),
                  painelOS(id: 'd', status: OSStatus.concluida, valorPago: 150),
                ]
              : [
                  painelOS(
                    id: 'e',
                    status: OSStatus.atribuida,
                    nomeCurto: 'Carlos S.',
                    bairro: 'Jardins',
                  ),
                ],
        );

        await pumpPainel(
          tester,
          const DashboardScreen(),
          overrides: painelOverrides(user: painelUser(), repo: repo),
        );
        // Resolve o FutureProvider.
        await tester.pump();
        await tester.pump();

        // KPI "Agendadas" = 2.
        expect(find.text('Agendadas'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        // A OS próxima aparece na lista.
        expect(find.textContaining('Carlos S.'), findsOneWidget);
        // Registro pluralizado.
        expect(find.textContaining('1 registro'), findsOneWidget);
      },
    );

    testWidgets('vazio: mostra estado "Nenhum atendimento pendente"', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const DashboardScreen(),
        overrides: painelOverrides(
          user: painelUser(),
          repo: FakePainelOrdens.empty(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nenhum atendimento pendente'), findsOneWidget);
      // KPIs ainda renderizam (todos zerados).
      expect(find.text('Faturamento hoje'), findsOneWidget);
    });

    testWidgets('erro: mostra banner com retry', (tester) async {
      await pumpPainel(
        tester,
        const DashboardScreen(),
        overrides: painelOverrides(
          user: painelUser(),
          repo: FakePainelOrdens.throwing(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('Não foi possível carregar o dashboard'),
        findsOneWidget,
      );
      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });
}
