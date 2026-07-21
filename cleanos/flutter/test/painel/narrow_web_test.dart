/// narrow_web_test.dart — Layout fintech em browser estreito (< 600dp).
///
/// Cobre a Opção B do parecer: phone-web (Safari/Chrome mobile) abre
/// app.cleanox.com.br e recebe o mesmo visual fintech do APK; tablet (≥600dp)
/// e desktop mantêm o layout clássico.
///
/// Estratégia de testabilidade: `kIsWeb` é uma `const` de compilação (false
/// na VM de testes). Para exercitar o path web-estreito sem recompilar com
/// `--platform=web`, usamos [isWebPlatformProvider.overrideWithValue(true)] —
/// que é exatamente o que [LoginScreen] lê para derivar `isNarrow`. Os
/// consumidores dentro do shell ([EmptyState], [ChecklistExecucao]) são
/// testados com [isNarrowWebProvider.overrideWithValue(true)] direto (não
/// passam pelo ProviderScope interno do PainelShell).
library;

import 'package:cleanos/core/design/app_surface_provider.dart';
import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/features/login/login_screen.dart';
import 'package:cleanos/shared_widgets_os/checklist_execucao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Monta [LoginScreen] isolado com os overrides dados e a [physicalWidth]
/// desejada (devicePixelRatio = 1 → logical == physical).
Widget _wrapLogin({
  required bool isWeb,
  required double physicalWidth,
  List<Override> extra = const [],
}) {
  return ProviderScope(
    overrides: [
      isFintechCleanProvider.overrideWithValue(false),
      isWebPlatformProvider.overrideWithValue(isWeb),
      ...extra,
    ],
    child: MaterialApp(
      theme: buildLightTheme(), // clássico — LoginScreen sobrepõe para narrow
      home: const LoginScreen(),
    ),
  );
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required bool isWeb,
  required double physicalWidth,
}) async {
  tester.view.physicalSize = Size(physicalWidth, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _wrapLogin(isWeb: isWeb, physicalWidth: physicalWidth),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  group('isNarrowWebProvider — default', () {
    test('sem override: default é false', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(isNarrowWebProvider), isFalse);
    });

    test('isWebPlatformProvider: default é kIsWeb (false na VM de testes)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      // Na VM de testes kIsWeb == false.
      expect(c.read(isWebPlatformProvider), isFalse);
    });
  });

  // ── LoginScreen ────────────────────────────────────────────────────────────

  group('LoginScreen — 390dp (narrow web, < 600dp)', () {
    testWidgets('isWeb=true + 390dp → layout fintech (sem ClxCard, mostra ícone)', (
      tester,
    ) async {
      await _pumpLogin(tester, isWeb: true, physicalWidth: 390);

      // Sem card elevado (layout clássico); logo Cleanox no hero fintech
      expect(find.byType(ClxCard), findsNothing);
      expect(find.byType(CleanoxLogo), findsOneWidget);
      expect(find.text(kAppTagline), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('isWeb=true + 390dp → tema fintech aplicado (cor primary fintech)', (
      tester,
    ) async {
      await _pumpLogin(tester, isWeb: true, physicalWidth: 390);

      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      // O tema local (Theme wrapper de LoginScreen) deve ser o fintech,
      // com primary diferente do clássico.
      expect(
        theme.colorScheme.primary,
        CleanoxColors.fintechLight.primary,
        reason: 'narrow web deve receber tema fintech',
      );
    });

    testWidgets('isWeb=true + 390dp → sem overflow (320dp)', (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapLogin(isWeb: true, physicalWidth: 320));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('LoginScreen — 800dp (tablet web, ≥ 600dp)', () {
    testWidgets('isWeb=true + 800dp → login desktop (não fintech mobile)', (
      tester,
    ) async {
      await _pumpLogin(tester, isWeb: true, physicalWidth: 800);

      // Desktop/tablet web: logo Cleanox; sem sheet fintech mobile.
      expect(find.byType(CleanoxLogo), findsOneWidget);
      expect(find.text(kAppTagline), findsOneWidget);
      expect(find.text('Esqueceu a senha? Fale com o administrador.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('isWeb=true + 800dp → tema clássico mantido', (tester) async {
      await _pumpLogin(tester, isWeb: true, physicalWidth: 800);

      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(
        theme.colorScheme.primary,
        CleanoxColors.light.primary,
        reason: 'tablet web deve manter tema clássico',
      );
    });
  });

  group('LoginScreen — 1280dp (desktop web)', () {
    testWidgets('isWeb=true + 1280dp → login desktop com marca', (tester) async {
      await _pumpLogin(tester, isWeb: true, physicalWidth: 1280);

      expect(find.byType(CleanoxLogo), findsOneWidget);
      expect(find.text(kAppTagline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LoginScreen — não-web (APK, kIsWeb=false)', () {
    testWidgets('isWeb=false + 390dp → layout desktop-login (não é narrow web)', (
      tester,
    ) async {
      await _pumpLogin(tester, isWeb: false, physicalWidth: 390);

      // isFintechClean=false + isWeb=false → path desktop (card flutuante)
      expect(find.byType(CleanoxLogo), findsOneWidget);
      expect(find.text(kAppTagline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── Consumidores dentro do shell ────────────────────────────────────────────

  group('EmptyState — isNarrowWebProvider=true → círculo de fundo fintech', () {
    testWidgets('narrow web mostra ícone dentro de círculo (igual ao APK)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFintechCleanProvider.overrideWithValue(false),
            isNarrowWebProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: buildFintechLightTheme(),
            home: const Scaffold(
              body: EmptyState(title: 'Vazio', message: 'Sem itens.'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Com fintech/narrow: ícone fica dentro de um Container circular (bg3).
      // Procuramos um Container de 72×72 que seja ancestral do ícone.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCircle = containers.any(
        (c) =>
            c.constraints?.minWidth == 72 ||
            (c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).shape == BoxShape.circle),
      );
      expect(hasCircle, isTrue, reason: 'ícone fintech deve ter círculo bg3');
      expect(tester.takeException(), isNull);
    });

    testWidgets('isNarrowWebProvider=false → ícone sem círculo (clássico)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFintechCleanProvider.overrideWithValue(false),
            isNarrowWebProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: EmptyState(title: 'Vazio'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Sem fintech: nenhum Container circular de 72dp.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCircle = containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(hasCircle, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('ChecklistExecucao — isNarrowWebProvider=true → checkbox fintech', () {
    final item = ChecklistExecItem(
      id: 'i1',
      titulo: 'Limpar piso',
      status: ChecklistExecStatus.pendente,
    );

    testWidgets('narrow web mostra checkbox fintech (não Material Checkbox)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFintechCleanProvider.overrideWithValue(false),
            isNarrowWebProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: buildFintechLightTheme(),
            home: Scaffold(
              body: ChecklistExecucao(
                items: [item],
                onChange: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Fintech: usa InkWell+AnimatedContainer customizado, NÃO o Checkbox M3.
      expect(find.byType(Checkbox), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clássico (isNarrowWeb=false) mostra Checkbox Material', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFintechCleanProvider.overrideWithValue(false),
            isNarrowWebProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: ChecklistExecucao(
                items: [item],
                onChange: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Checkbox), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
