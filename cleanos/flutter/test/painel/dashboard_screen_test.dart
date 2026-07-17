/// dashboard_screen_test.dart — Dashboard do Painel: dados / vazio / erro.
library;

import 'package:cleanos/app.dart' show AppSurface;
import 'package:cleanos/core/design/app_surface_provider.dart';
import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
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

    testWidgets(
      'mobile: "Próximos" agrupa por dia (separador) e mostra o profissional',
      (tester) async {
        OrdemServico up(String id, String dataHora, {String? prof}) =>
            OrdemServico(
              id: id,
              nomeCurto: 'Cliente $id',
              bairro: 'Centro',
              tipoServicoNome: 'Higienização',
              dataHora: dataHora,
              status: OSStatus.atribuida,
              valorServico: 200,
              expand: prof == null
                  ? null
                  : OSExpand(
                      profissional: User(
                        id: 'u$id',
                        name: prof,
                        role: Role.profissional,
                      ),
                    ),
            );

        final repo = FakePainelOrdens(
          byIndex: (i) => i == 0
              ? const []
              : [
                  up('a', '2026-07-16 13:00:00Z', prof: 'Ana Prof'),
                  up('b', '2026-07-18 16:00:00Z'), // outro dia, sem profissional
                ],
        );

        await pumpPainel(
          tester,
          const DashboardScreen(),
          overrides: [
            ...painelOverrides(user: painelUser(), repo: repo),
            // Força o hub mobile (easypay), onde vivem os cards "Próximos".
            appSurfaceProvider.overrideWithValue(AppSurface.android),
          ],
        );
        await tester.pump();
        await tester.pump();

        // Dois dias distintos → dois separadores (ícone de calendário).
        expect(find.byIcon(Icons.event_rounded), findsNWidgets(2));
        // Profissional numa linha própria; ausência é explícita.
        expect(find.text('Ana Prof'), findsOneWidget);
        expect(find.text('Sem profissional'), findsOneWidget);
      },
    );

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

    testWidgets(
      'QA-F8: nenhum label dos 4 atalhos de "Acesso rápido" começa com "+" '
      '("Nova OS" e "Novo Cliente" já têm o ícone add — duplicava)',
      (tester) async {
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

        // Os 4 atalhos de "Acesso rápido" (por label — a tela tem outros
        // ClxButton fora dessa seção, ex.: "Ver todas" no cabeçalho).
        const atalhos = {'Nova OS', 'Novo Cliente', 'Ver Agenda', 'Financeiro'};
        final buttons = tester
            .widgetList<ClxButton>(find.byType(ClxButton))
            .where((b) => atalhos.contains(b.label))
            .toList();
        expect(buttons, hasLength(4));
        for (final b in buttons) {
          expect(
            b.label.startsWith('+'),
            isFalse,
            reason: '"${b.label}" não deveria começar com "+"',
          );
        }

        // "Nova OS"/"Novo Cliente" mantêm o ícone add (sem duplicar no texto).
        final novaOs = buttons.firstWhere((b) => b.label == 'Nova OS');
        expect(novaOs.icon, Icons.add_rounded);
        final novoCliente = buttons.firstWhere((b) => b.label == 'Novo Cliente');
        expect(novoCliente.icon, Icons.add_rounded);
      },
    );
  });
}
