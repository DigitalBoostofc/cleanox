/// painel_shell_test.dart — Casco do Painel + ROTAS ANINHADAS (StatefulShellRoute).
///
/// Cobre: menu por papel (admin vê WhatsApp, gerente não); navegação por rota
/// (Avaliações / Minha Conta); DEEP-LINK direto por seção (`/painel/financeiro`);
/// e o GUARD de papel (gerente barrado de `/painel/whatsapp`).
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/painel/avaliacoes/avaliacoes_screen.dart';
import 'package:cleanos/painel/financeiro/fin_shell.dart';
import 'package:cleanos/painel/shell/painel_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'fakes_painel.dart';
import 'painel_test_helpers.dart';

void main() {
  group('menu por papel (espelha PainelLayout)', () {
    testWidgets('admin vê o item WhatsApp (admin-only)', (tester) async {
      await pumpPainelApp(
        tester,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      // Rail de ícones começa RECOLHIDO (tooltip = rótulo); expande para
      // ver os nomes como texto.
      expect(find.byTooltip('WhatsApp'), findsOneWidget);
      await tester.tap(find.byTooltip('Expandir menu'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Avaliações'), findsOneWidget);
    });

    testWidgets('gerente NÃO vê o item WhatsApp', (tester) async {
      await pumpPainelApp(
        tester,
        user: painelUser(role: Role.gerente),
        repo: FakePainelOrdens.empty(),
      );

      expect(find.byTooltip('WhatsApp'), findsNothing);
      await tester.tap(find.byTooltip('Expandir menu'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Avaliações'), findsOneWidget);
    });

    test('navItemsForRole: admin=9 itens, gerente=8 (sem WhatsApp)', () {
      expect(navItemsForRole(Role.admin).length, kPainelNavItems.length);
      final gerente = navItemsForRole(Role.gerente);
      expect(gerente.length, kPainelNavItems.length - 1);
      expect(gerente.any((i) => i.section == PainelSection.whatsapp), isFalse);
    });

    test('painelPath / painelSectionForLocation (round-trip)', () {
      expect(painelPath(PainelSection.financeiro), '/painel/financeiro');
      expect(
        painelSectionForLocation('/painel/financeiro/lancamentos'),
        PainelSection.financeiro,
      );
      expect(
        painelSectionForLocation('/painel/ordens/os1/execucao'),
        PainelSection.ordens,
      );
      // Fallback → dashboard.
      expect(painelSectionForLocation('/qualquer'), PainelSection.dashboard);
    });
  });

  group('navegação por rota', () {
    testWidgets('tocar em "Avaliações" navega e abre a tela real', (
      tester,
    ) async {
      final router = await pumpPainelApp(
        tester,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
      );

      // Rail recolhido: o item é o ícone com tooltip do rótulo.
      await tester.tap(find.byTooltip('Avaliações'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 12));
      }

      expect(currentLocation(router), '/painel/avaliacoes');
      expect(
        find.text('Este módulo chega numa próxima onda do Painel.'),
        findsNothing,
      );
      // Tela real montada (accordion por profissional) — independe do estado de
      // carga (o repo de usuários não é injetado neste teste de navegação).
      expect(find.byType(AvaliacoesScreen), findsOneWidget);
    });

    testWidgets('rodapé do usuário abre "Minha Conta" (/painel/conta)', (
      tester,
    ) async {
      final router = await pumpPainelApp(
        tester,
        user: painelUser(role: Role.admin, nome: 'Ana Admin'),
        repo: FakePainelOrdens.empty(),
      );

      // Rodapé do rail recolhido: avatar com tooltip = nome do usuário.
      await tester.tap(find.byTooltip('Ana Admin'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 12));
      }

      expect(currentLocation(router), '/painel/conta');
      expect(find.text('Minha conta'), findsOneWidget);
      expect(find.text('Alterar senha'), findsWidgets);
    });
  });

  group('Financeiro por slug de rota (FinTab)', () {
    test('fromSlug resolve o slug de URL (fallback → visão geral)', () {
      expect(FinTab.fromSlug('lancamentos'), FinTab.lancamentos);
      expect(FinTab.fromSlug('carteiras'), FinTab.carteiras);
      expect(FinTab.fromSlug(null), FinTab.visaoGeral);
      expect(FinTab.fromSlug('inexistente'), FinTab.visaoGeral);
      // Round-trip slug de todas as abas.
      for (final t in FinTab.values) {
        expect(FinTab.fromSlug(t.slug), t);
      }
    });

    testWidgets('FinanceiroShell(tabSlug) renderiza a sub-nav das 7 abas', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pocketBaseProvider.overrideWithValue(
              PocketBase('http://127.0.0.1:9'),
            ),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(body: FinanceiroShell(tabSlug: 'lancamentos')),
          ),
        ),
      );
      await tester.pump();

      // A sub-nav (chrome do FinanceiroShell) monta as 7 abas — prova que o
      // alvo do deep-link `/painel/financeiro/:tab` renderiza pela slug.
      expect(find.text('Visão geral'), findsWidgets);
      expect(find.text('Lançamentos'), findsWidgets);
      expect(find.text('Carteiras'), findsOneWidget);
    });
  });

  group('deep-link + guard por papel', () {
    testWidgets('abrir /painel/financeiro direto → aba default (URL)', (
      tester,
    ) async {
      final router = await pumpPainelApp(
        tester,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
        location: '/painel/financeiro',
      );

      // `/painel/financeiro` puro redireciona pra aba default (deep-link resolve).
      expect(currentLocation(router), '/painel/financeiro/visao-geral');
    });

    testWidgets('deep-link direto numa aba do Financeiro mantém a URL', (
      tester,
    ) async {
      final router = await pumpPainelApp(
        tester,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
        location: '/painel/financeiro/lancamentos',
      );

      expect(currentLocation(router), '/painel/financeiro/lancamentos');
    });

    testWidgets('gerente em /painel/whatsapp é barrado → Dashboard', (
      tester,
    ) async {
      final router = await pumpPainelApp(
        tester,
        user: painelUser(role: Role.gerente),
        repo: FakePainelOrdens.empty(),
        location: '/painel/whatsapp',
      );

      // Guard global de papel redireciona o gerente de volta ao Dashboard.
      expect(currentLocation(router), '/painel/dashboard');
    });

    testWidgets('admin em /painel/whatsapp NÃO é barrado', (tester) async {
      final router = await pumpPainelApp(
        tester,
        user: painelUser(role: Role.admin),
        repo: FakePainelOrdens.empty(),
        location: '/painel/whatsapp',
      );

      expect(currentLocation(router), '/painel/whatsapp');
    });
  });
}
