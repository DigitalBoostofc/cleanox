/// fin_fintech_reskin_test.dart — Reskin "Fintech Clean" (Onda 3, doc 12) da
/// Visão geral do Financeiro no APK: `FintechBalanceHero` no lugar do card de
/// KPI "Saldo geral" quando `isFintechCleanProvider` é true, e não-regressão
/// total da Web (`isFintechCleanProvider` false, default nos testes existentes).
library;

import 'package:cleanos/core/design/app_surface_provider.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/design/widgets/clx_card.dart';
import 'package:cleanos/painel/financeiro/fin_common.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/fin_visao_geral_screen.dart';
import 'package:cleanos/painel/financeiro/fintech/fintech_balance_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Sobe [FinVisaoGeralScreen] com o [ThemeData] e a [isFintechCleanProvider]
  /// escolhidos — diferente de `pumpPainel` (que fixa `buildLightTheme()`),
  /// necessário aqui pra provar o tema Fintech Clean de verdade.
  Future<void> pumpVisaoGeral(
    WidgetTester tester, {
    required ThemeData theme,
    required bool fintech,
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...painelOverrides(user: painelUser()),
          financeiroRepositoryProvider.overrideWithValue(FakeFinanceiro()),
          isFintechCleanProvider.overrideWithValue(fintech),
        ],
        child: MaterialApp(
          theme: theme,
          home: const Scaffold(body: FinVisaoGeralScreen()),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  Future<void> expectStableNoOverflowAt(
    WidgetTester tester,
    Size target, {
    required Size away,
  }) async {
    while (tester.takeException() != null) {}
    tester.view.physicalSize = away;
    await tester.pump();
    while (tester.takeException() != null) {}
    tester.view.physicalSize = target;
    await tester.pump();
    await tester.pump();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Overflow no layout estável a ${target.width.toInt()} px de largura',
    );
  }

  group('Visão geral · fintech (APK, isFintechCleanProvider=true)', () {
    testWidgets(
      'mostra o hero de saldo geral (não duplica o card na grade)',
      (tester) async {
        await pumpVisaoGeral(
          tester,
          theme: buildFintechLightTheme(),
          fintech: true,
        );

        expect(find.byType(FintechBalanceHero), findsOneWidget);
        expect(find.text('SALDO GERAL'), findsOneWidget);
        // Não duplica: o rótulo minúsculo do card de KPI antigo não aparece.
        expect(find.text('Saldo geral'), findsNothing);

        // Os outros 3 KPIs do mês continuam presentes.
        expect(find.text('Entradas do mês'), findsOneWidget);
        expect(find.text('Saídas do mês'), findsOneWidget);
        expect(find.text('Saldo do mês'), findsOneWidget);
      },
    );

    testWidgets(
      '"Saldo do mês" usa a variante wide (linha inteira, valor à direita)',
      (tester) async {
        await pumpVisaoGeral(
          tester,
          theme: buildFintechLightTheme(),
          fintech: true,
        );

        final saldoMesCardFinder = find.ancestor(
          of: find.text('Saldo do mês'),
          matching: find.byType(FinKpiCard),
        );
        final card = tester.widget<FinKpiCard>(saldoMesCardFinder);
        expect(card.wide, isTrue);

        // wide: layout raiz em Row (não Column) — label à esquerda, valor à
        // direita — diferente do Column dos outros dois cards (não-wide).
        final directChild = tester.widget<ClxCard>(
          find.descendant(
            of: saldoMesCardFinder,
            matching: find.byType(ClxCard),
          ),
        ).child;
        expect(directChild, isA<Row>());
      },
    );

    testWidgets('valor do hero usa o token display (34/800)', (tester) async {
      await pumpVisaoGeral(
        tester,
        theme: buildFintechLightTheme(),
        fintech: true,
      );

      final hero = tester.widget<FintechBalanceHero>(
        find.byType(FintechBalanceHero),
      );
      final valueText = tester.widget<Text>(
        find.descendant(
          of: find.byType(FintechBalanceHero),
          matching: find.text(hero.value),
        ),
      );
      expect(valueText.style?.fontSize, 34);
      expect(valueText.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('sem overflow a 360x800 (claro)', (tester) async {
      await pumpVisaoGeral(
        tester,
        theme: buildFintechLightTheme(),
        fintech: true,
        size: const Size(360, 800),
      );
      await expectStableNoOverflowAt(
        tester,
        const Size(360, 800),
        away: const Size(400, 800),
      );
    });

    testWidgets('sem overflow a 320x800 (fronteira mínima)', (tester) async {
      await pumpVisaoGeral(
        tester,
        theme: buildFintechLightTheme(),
        fintech: true,
        size: const Size(320, 800),
      );
      await expectStableNoOverflowAt(
        tester,
        const Size(320, 800),
        away: const Size(360, 800),
      );
    });

    testWidgets('sem overflow a 360x800 (escuro)', (tester) async {
      await pumpVisaoGeral(
        tester,
        theme: buildFintechDarkTheme(),
        fintech: true,
        size: const Size(360, 800),
      );
      await expectStableNoOverflowAt(
        tester,
        const Size(360, 800),
        away: const Size(400, 800),
      );
    });
  });

  group('Visão geral · Web (isFintechCleanProvider=false) — não-regressão', () {
    testWidgets(
      'preserva os 4 KPIs originais (incluindo Saldo geral na grade) sem hero',
      (tester) async {
        await pumpVisaoGeral(
          tester,
          theme: buildLightTheme(),
          fintech: false,
          size: const Size(1400, 900),
        );

        expect(find.byType(FintechBalanceHero), findsNothing);
        expect(find.text('Saldo geral'), findsOneWidget);
        expect(find.text('Entradas do mês'), findsOneWidget);
        expect(find.text('Saídas do mês'), findsOneWidget);
        expect(find.text('Saldo do mês'), findsOneWidget);
      },
    );

    testWidgets(
      'mobile estreito (360px) sem surface fintech: layout de grade antigo, sem hero',
      (tester) async {
        await pumpVisaoGeral(
          tester,
          theme: buildLightTheme(),
          fintech: false,
          size: const Size(360, 800),
        );

        expect(find.byType(FintechBalanceHero), findsNothing);
        expect(find.text('Saldo geral'), findsOneWidget);
        await expectStableNoOverflowAt(
          tester,
          const Size(360, 800),
          away: const Size(400, 800),
        );
      },
    );
  });
}
