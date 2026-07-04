/// painel_shell_fintech_test.dart — Bifurcação Fintech Clean do APK (doc 12,
/// Onda 1): tema aplicado por `AppSurface`, bottom nav de 5 itens (Dashboard ·
/// Ordens de Serviço · Agenda · Financeiro · Mais) e a lista "Mais" com guard
/// de papel. Sobe o `CleanosApp` de verdade (não só `PainelShell` isolado) pra
/// provar a bifurcação de `app.dart` ponta a ponta.
///
/// Não-regressão: `AppSurface.painel` continua com o `ThemeData` clássico e a
/// sidebar/rail — os 52 arquivos de teste pré-existentes (que montam
/// `MaterialApp.router` direto, sem passar por `CleanosApp`) provam isso pro
/// resto do Painel; este arquivo cobre especificamente a bifurcação nova.
library;

import 'package:cleanos/app.dart';
import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/cleanox_colors.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/ordens_repository.dart';
import 'package:cleanos/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../profissional/fakes.dart';
import 'fakes_painel.dart';
import 'painel_test_helpers.dart';

/// Sobe o `CleanosApp` real (com `surface`) autenticado como [user], igual ao
/// que os três `main_*.dart` fazem — sem tocar rede (PB/auth/storage fakes).
Future<GoRouter> _pumpCleanosApp(
  WidgetTester tester, {
  required AppSurface surface,
  required User user,
  OrdensRepository? repo,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(FakeAuthService(user)),
      pocketBaseProvider.overrideWithValue(PocketBase('http://127.0.0.1:9')),
      themeStorageProvider.overrideWithValue(FakeSecureStorage()),
      if (repo != null) ordensRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: CleanosApp(surface: surface),
    ),
  );
  // redirect: /login → /painel → /painel/dashboard + libs deferred.
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 12));
  }
  return container.read(routerProvider);
}

/// `CleanoxColors` (extensão de tema) do primeiro `MaterialApp` encontrado.
CleanoxColors _clxOf(WidgetTester tester) => Theme.of(
  tester.element(find.byType(Scaffold).first),
).extension<CleanoxColors>()!;

void main() {
  group('bifurcação de tema (app.dart)', () {
    testWidgets('surface=android aplica o tema Fintech Clean', (
      tester,
    ) async {
      await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      final clx = _clxOf(tester);
      expect(clx.primary, CleanoxColors.fintechLight.primary);
      expect(clx.primary, isNot(CleanoxColors.light.primary));
      expect(clx.onPrimary, CleanoxColors.fintechLight.onPrimary);
    });

    testWidgets(
      'surface=painel (Web) continua com o tema clássico — não-regressão',
      (tester) async {
        await _pumpCleanosApp(
          tester,
          surface: AppSurface.painel,
          user: painelUser(role: Role.admin),
          repo: FakePainelOrdens.empty(),
          size: const Size(1400, 900),
        );

        final clx = _clxOf(tester);
        expect(clx.primary, CleanoxColors.light.primary);
        expect(clx.primary, isNot(CleanoxColors.fintechLight.primary));
        // Web mantém a sidebar (marca "CleanOS"), não a bottom nav fintech.
        expect(find.text('CleanOS'), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );
  });

  group('bottom nav fintech (5 itens)', () {
    testWidgets('renderiza os 5 destinos e navega pelos diretos', (
      tester,
    ) async {
      final router = await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Ordens de Serviço'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Financeiro'), findsOneWidget);
      expect(find.text('Mais'), findsOneWidget);

      // Financeiro (não Agenda): já tem os fixes de overflow mobile
      // (bda7b11/7744973); Agenda/Avaliações ainda não foram adaptadas pra
      // largura de telefone — reskin de conteúdo é escopo da Onda 3, não
      // desta fundação (doc 12 §4).
      await tester.tap(find.text('Financeiro'));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 12));
      }

      expect(currentLocation(router), '/painel/financeiro/visao-geral');
    });

    testWidgets('bottom nav também no tamanho tablet (P-2: sem NavigationRail no APK)', (
      tester,
    ) async {
      await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
        size: const Size(900, 1200),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('tela "Mais"', () {
    testWidgets('admin vê Serviços/Clientes/Avaliações/Usuários/WhatsApp/Conta', (
      tester,
    ) async {
      await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      await tester.tap(find.text('Mais'));
      await tester.pump();

      expect(find.text('Serviços'), findsOneWidget);
      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Avaliações'), findsOneWidget);
      expect(find.text('Usuários'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Minha Conta'), findsOneWidget);
    });

    testWidgets('gerente NÃO vê WhatsApp na lista "Mais" (guard de papel)', (
      tester,
    ) async {
      await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.gerente),
        repo: FakePainelOrdens.empty(),
      );

      await tester.tap(find.text('Mais'));
      await tester.pump();

      expect(find.text('Serviços'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
    });

    testWidgets('tocar num item da lista navega e volta a mostrar o conteúdo', (
      tester,
    ) async {
      final router = await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      await tester.tap(find.text('Mais'));
      await tester.pump();
      // Usuários: já tem breakpoint mobile (cards <720px) — Avaliações
      // (accordion) ainda não foi adaptada pra largura de telefone (Onda 3).
      await tester.tap(find.text('Usuários'));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 12));
      }

      expect(currentLocation(router), '/painel/usuarios');
      // Voltou a mostrar o conteúdo real (não a lista "Mais" de novo).
      expect(find.text('Minha Conta'), findsNothing);
    });
  });
}
