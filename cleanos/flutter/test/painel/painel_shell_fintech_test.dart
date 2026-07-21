/// painel_shell_fintech_test.dart — Casco Easypay do APK: tema + bottom nav
/// Início · Clientes · FAB · OS · Carteira, hamburger no header com foto no Menu.
library;

import 'package:cleanos/app.dart';
import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/cleanox_colors.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/widgets/user_avatar.dart';
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
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 12));
  }
  return container.read(routerProvider);
}

CleanoxColors _clxOf(WidgetTester tester) => Theme.of(
  tester.element(find.byType(Scaffold).first),
).extension<CleanoxColors>()!;

Future<void> _settleNav(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 12));
  }
}

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
      // Primary unificado na paleta Cleanox; fintech diverge em success/bg.
      expect(clx.primary, CleanoxColors.fintechLight.primary);
      expect(clx.primary, CleanoxColors.light.primary);
      expect(clx.onPrimary, CleanoxColors.fintechLight.onPrimary);
      expect(clx.success, CleanoxColors.fintechLight.success);
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
        // Mesmo cyan de marca; hierarquia fintech vs clássico em outros tokens.
        expect(clx.bg2, CleanoxColors.light.bg2);
        // Desktop shell Shakuro: título da seção no top bar (marca só no ícone).
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Início'), findsNothing);
      },
    );
  });

  group('bottom nav Easypay (Início · Clientes · FAB · OS · Carteira)', () {
    testWidgets(
      'renderiza Início/Clientes/OS/Carteira + FAB e navega para Carteira',
      (tester) async {
        final handle = tester.ensureSemantics();
        final router = await _pumpCleanosApp(
          tester,
          surface: AppSurface.android,
          user: painelUser(role: Role.admin),
          repo: FakePainelOrdens.empty(),
        );

        expect(find.byKey(const ValueKey('nav-inicio')), findsOneWidget);
        expect(find.byKey(const ValueKey('nav-clientes')), findsOneWidget);
        expect(find.byKey(const ValueKey('nav-os')), findsOneWidget);
        expect(find.byKey(const ValueKey('nav-carteira')), findsOneWidget);
        expect(find.byKey(const ValueKey('nav-menu-header')), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsWidgets);

        // Menu saiu da barra (foi pro hamburger no header).
        expect(find.byKey(const ValueKey('nav-menu')), findsNothing);
        expect(find.byKey(const ValueKey('nav-agenda')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('nav-carteira')));
        await _settleNav(tester);

        expect(currentLocation(router), '/painel/financeiro/visao-geral');
        handle.dispose();
      },
    );

    testWidgets('FAB abre sheet de criação com Nova OS', (tester) async {
      await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      await tester.tap(find.byKey(const ValueKey('nav-fab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('O que você quer fazer?'), findsOneWidget);
      expect(find.text('Novo cliente'), findsOneWidget);
      expect(find.text('Nova receita'), findsOneWidget);
      expect(find.text('Nova despesa'), findsOneWidget);
      // "Nova OS" também existe no hub — no sheet basta o subtítulo.
      expect(find.textContaining('Agendar atendimento'), findsOneWidget);
    });

    testWidgets('bottom nav também no tamanho tablet (sem NavigationRail)', (
      tester,
    ) async {
      await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
        size: const Size(900, 1200),
      );

      expect(find.text('Início'), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('tela Menu (hamburger no header)', () {
    testWidgets(
      'admin vê foto + Agenda/Serviços/Avaliações/Usuários/WhatsApp (sem Conta duplicada)',
      (tester) async {
        await _pumpCleanosApp(
          tester,
          surface: AppSurface.android,
          user: painelUser(role: Role.admin),
          repo: FakePainelOrdens.empty(),
        );

        await tester.tap(find.byKey(const ValueKey('nav-menu-header')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Foto/avatar do usuário no menu (não no header).
        expect(find.byType(UserAvatar), findsWidgets);
        // "Minha conta" só no card da foto (não na lista como item).
        expect(find.text('Minha conta'), findsOneWidget);
        expect(find.text('Minha Conta'), findsNothing);
        expect(find.text('Agenda'), findsOneWidget);
        expect(find.text('Serviços'), findsOneWidget);
        expect(find.text('Avaliações'), findsOneWidget);
        expect(find.text('Usuários'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
        // Clientes e OS saíram do menu (estão na barra).
        expect(find.text('Ordens de Serviço'), findsNothing);
        expect(find.text('Dashboard'), findsNothing);
        expect(find.text('Sair da conta'), findsOneWidget);
      },
    );

    testWidgets('gerente NÃO vê WhatsApp no Menu', (tester) async {
      await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.gerente),
        repo: FakePainelOrdens.empty(),
      );

      await tester.tap(find.byKey(const ValueKey('nav-menu-header')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Serviços'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
    });

    testWidgets('tocar num item do Menu navega e fecha a lista', (
      tester,
    ) async {
      final router = await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      await tester.tap(find.byKey(const ValueKey('nav-menu-header')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Usuários'));
      await tester.tap(find.text('Usuários'));
      await _settleNav(tester);

      expect(currentLocation(router), '/painel/usuarios');
    });

    testWidgets('Menu tem toggle de tema claro/escuro (QA-F2)', (
      tester,
    ) async {
      await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      await tester.tap(find.byKey(const ValueKey('nav-menu-header')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Tema escuro'), findsOneWidget);

      await tester.tap(find.text('Tema escuro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      expect(find.text('Tema claro'), findsOneWidget);
    });
  });

  group('Início selecionado na abertura', () {
    testWidgets('abrir o app deixa rota no Dashboard e Carteira navega', (
      tester,
    ) async {
      final router = await _pumpCleanosApp(
        tester,
        surface: AppSurface.android,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      expect(currentLocation(router), '/painel/dashboard');

      await tester.tap(find.byKey(const ValueKey('nav-carteira')));
      await _settleNav(tester);

      expect(currentLocation(router), '/painel/financeiro/visao-geral');
    });
  });
}
