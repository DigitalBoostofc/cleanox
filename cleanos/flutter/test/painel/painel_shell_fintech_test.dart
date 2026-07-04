/// painel_shell_fintech_test.dart — Bifurcação Fintech Clean do APK (doc 12,
/// Onda 1): tema aplicado por `AppSurface`, bottom nav de 5 itens (Clientes ·
/// Ordens de Serviço · Agenda · Financeiro · Mais — Dashboard mudou pro topo
/// do "Mais", feedback do dono/QA-F6) e a lista "Mais" com guard de papel.
/// Sobe o `CleanosApp` de verdade (não só `PainelShell` isolado) pra provar a
/// bifurcação de `app.dart` ponta a ponta.
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
import 'package:flutter/rendering.dart';
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
    testWidgets(
      'renderiza Clientes/OS/Agenda/Financeiro/Mais (Dashboard saiu da '
      'barra, QA-F6) e navega pelos diretos',
      (tester) async {
        final router = await _pumpCleanosApp(
          tester,
          surface: AppSurface.android,
          user: painelUser(role: Role.admin),
          repo: FakePainelOrdens.empty(),
        );

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Dashboard'), findsNothing);
        expect(find.text('Clientes'), findsOneWidget);
        expect(find.text('OS'), findsOneWidget);
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
      },
    );

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
    testWidgets(
      'admin vê Dashboard (primeiro item, QA-F6)/Serviços/Avaliações/'
      'Usuários/WhatsApp/Conta',
      (tester) async {
        await _pumpCleanosApp(
          tester,
          surface: AppSurface.android,
          user: painelUser(role: Role.admin),
          repo: FakePainelOrdens.empty(),
        );

        await tester.tap(find.text('Mais'));
        await tester.pump();

        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Serviços'), findsOneWidget);
        expect(find.text('Avaliações'), findsOneWidget);
        expect(find.text('Usuários'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
        expect(find.text('Minha Conta'), findsOneWidget);

        // Dashboard é o PRIMEIRO item da lista (acima de Serviços).
        final dashboardTop = tester.getTopLeft(find.text('Dashboard')).dy;
        final servicosTop = tester.getTopLeft(find.text('Serviços')).dy;
        expect(dashboardTop, lessThan(servicosTop));
      },
    );

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

    testWidgets(
      'QA-F2: tela "Mais" tem o toggle de tema claro/escuro (único no '
      'casco fintech — o _TopBar com o botão de tema não é montado aqui)',
      (tester) async {
        await _pumpCleanosApp(
          tester,
          surface: AppSurface.android,
          user: painelUser(role: Role.admin),
          repo: FakePainelOrdens.empty(),
        );

        await tester.tap(find.text('Mais'));
        await tester.pump();

        expect(find.text('Tema escuro'), findsOneWidget);

        await tester.tap(find.text('Tema escuro'));
        // MaterialApp anima claro↔escuro (`themeAnimationDuration`, 300ms —
        // ClxMotion.standardDuration); pumpAndSettle espera a AnimatedTheme
        // terminar antes de checar o brightness resultante.
        await tester.pumpAndSettle();

        expect(
          Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
          Brightness.dark,
        );
        expect(find.text('Tema claro'), findsOneWidget);
      },
    );
  });

  group('QA-F6: Dashboard sem destino direto → barra sem seleção', () {
    /// Cor resolvida (via `IconTheme` ambiente) de cada ícone de destino da
    /// `NavigationBar`, na mesma ordem em que aparecem na barra.
    List<Color?> destinationIconColors(WidgetTester tester) {
      final iconFinder = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(Icon),
      );
      return [
        for (var i = 0; i < iconFinder.evaluate().length; i++)
          IconTheme.of(tester.element(iconFinder.at(i))).color,
      ];
    }

    testWidgets(
      'abrir o app mostra Dashboard com NENHUM item da barra selecionado',
      (tester) async {
        await _pumpCleanosApp(
          tester,
          surface: AppSurface.android,
          user: painelUser(role: Role.admin),
          repo: FakePainelOrdens.empty(),
        );

        // Cai no Dashboard (rota inicial inalterada) — Dashboard não está
        // mais na barra, e nem "Mais" está marcado.
        final colors = destinationIconColors(tester);
        final clx = _clxOf(tester);
        // Todos os ícones (incl. "Mais") na MESMA cor "não selecionada" —
        // nenhum item aparenta estar ativo.
        expect(colors.toSet(), {clx.ink3});
      },
    );

    testWidgets(
      'Mais > Dashboard também deixa a barra sem seleção',
      (tester) async {
        await _pumpCleanosApp(
          tester,
          surface: AppSurface.android,
          user: painelUser(role: Role.admin),
          repo: FakePainelOrdens.empty(),
        );

        // Navega pra outra seção primeiro (Financeiro, direta) — prova que
        // dá pra SAIR do estado "sem seleção" e...
        await tester.tap(find.text('Financeiro'));
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 12));
        }
        final clx = _clxOf(tester);
        expect(
          destinationIconColors(tester).toSet().contains(clx.primary),
          isTrue,
          reason: 'Financeiro precisa aparecer selecionado antes do teste',
        );

        // ...voltar pra Dashboard via Mais > Dashboard restaura "sem seleção".
        await tester.tap(find.text('Mais'));
        await tester.pump();
        await tester.tap(find.text('Dashboard'));
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 12));
        }

        expect(destinationIconColors(tester).toSet(), {clx.ink3});
      },
    );

    testWidgets(
      'review: nenhuma aba é anunciada como selecionada (semântica, não só '
      'visual) quando a barra está sem seleção; a seção ativa continua '
      'anunciada corretamente',
      (tester) async {
        final handle = tester.ensureSemantics();

        await _pumpCleanosApp(
          tester,
          surface: AppSurface.android,
          user: painelUser(role: Role.admin),
          repo: FakePainelOrdens.empty(),
        );

        // Dashboard (sem seleção, QA-F6): nenhum nó de semântica em toda a
        // árvore tem a flag `isSelected` — nem o índice fixo (0, Clientes)
        // que a `NavigationBar` interna usa só pra satisfazer seu assert.
        expect(find.semantics.byFlag(SemanticsFlag.isSelected), findsNothing);

        // Financeiro (seção ativa): o nó correto continua anunciado como
        // selecionado normalmente — a barra "sem seleção" não regrediu isso.
        await tester.tap(find.text('Financeiro'));
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 12));
        }
        expect(
          tester.getSemantics(find.text('Financeiro')),
          containsSemantics(isSelected: true, isButton: true),
        );

        handle.dispose();
      },
    );
  });
}
