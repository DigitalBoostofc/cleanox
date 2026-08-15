library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_principal_screen.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/lancamentos/fin_lancamentos_controller.dart';
import 'package:cleanos/painel/financeiro/lancamentos/fin_transacoes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  Future<GoRouter> pumpDashboard(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/painel/financeiro/principal',
      routes: [
        GoRoute(
          path: '/painel/financeiro/principal',
          builder: (_, __) => const Scaffold(body: FinPrincipalScreen()),
        ),
        GoRoute(
          path: '/painel/financeiro/transacoes',
          builder: (_, state) =>
              Text('tipo=${state.uri.queryParameters['tipo']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    final fake = FakeFinanceiro(
      contas: [fakeConta(id: 'caixa', saldoAtual: 100)],
      lancamentos: [
        fakeLanc(id: 'r', tipo: TipoLancamento.receita, valor: 300),
        fakeLanc(id: 'd', tipo: TipoLancamento.despesa, valor: 120),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...painelOverrides(user: painelUser()),
          financeiroRepositoryProvider.overrideWithValue(fake),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(useMaterial3: true),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    return router;
  }

  testWidgets('card Receitas abre Extrato com filtro receita', (tester) async {
    final router = await pumpDashboard(tester);

    await tester.tap(find.text('Receitas').first);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/painel/financeiro/transacoes?tipo=receita',
    );
  });

  testWidgets('card Despesas abre Extrato com filtro despesa', (tester) async {
    final router = await pumpDashboard(tester);

    await tester.tap(find.text('Despesas').first);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/painel/financeiro/transacoes?tipo=despesa',
    );
  });

  testWidgets('Extrato aplica o filtro recebido pelo deep link', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ...painelOverrides(user: painelUser()),
        financeiroRepositoryProvider.overrideWithValue(FakeFinanceiro()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FinTransacoesScreen(initialTipo: TipoLancamento.despesa),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(
      container.read(finLancControllerProvider).filters.tipo,
      TipoLancamento.despesa,
    );
  });

  testWidgets('Extrato tem o botão de adicionar bonificação', (tester) async {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...painelOverrides(user: painelUser()),
          financeiroRepositoryProvider.overrideWithValue(FakeFinanceiro()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FinTransacoesScreen()),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.byKey(const Key('fin-transacoes-bonificacao')), findsOneWidget);
    expect(find.byTooltip('Adicionar bonificação'), findsOneWidget);
  });
}
