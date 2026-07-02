/// fin_screens_test.dart — Testes de widget das 7 telas do Financeiro (Onda 4):
/// Visão geral (charts), Lançamentos (CRUD + agrupamento por data), Contas a
/// pagar/receber, Categorias (árvore), Relatórios, Limites (progresso) e
/// Carteiras (saldo) — cobrindo estados vazio/erro/sucesso.
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/carteiras/fin_carteiras_screen.dart';
import 'package:cleanos/painel/financeiro/categorias/fin_categorias_screen.dart';
import 'package:cleanos/painel/financeiro/fin_contas_pagar_receber_screen.dart';
import 'package:cleanos/painel/financeiro/fin_limites_screen.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/fin_relatorios_screen.dart';
import 'package:cleanos/painel/financeiro/fin_visao_geral_screen.dart';
import 'package:cleanos/painel/financeiro/lancamentos/fin_lancamentos_screen.dart';
import 'package:cleanos/painel/financeiro/lancamentos/lancamento_form.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  // Alguns providers do Financeiro resolvem em cascata (repo → futuros).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  List<Override> withFin(FakeFinanceiro fake) => [
    ...painelOverrides(user: painelUser()),
    financeiroRepositoryProvider.overrideWithValue(fake),
  ];

  group('Carteiras', () {
    testWidgets('saldo geral + carteiras', (tester) async {
      final fake = FakeFinanceiro(
        contas: [
          fakeConta(
            id: 'a',
            nome: 'Carteira Loja',
            tipo: ContaTipo.carteira,
            saldoAtual: 100,
          ),
          fakeConta(
            id: 'b',
            nome: 'Banco X',
            tipo: ContaTipo.banco,
            saldoAtual: 50,
          ),
        ],
      );
      await pumpPainel(
        tester,
        const FinCarteirasScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      expect(find.text('Carteira Loja'), findsOneWidget);
      expect(find.text('Banco X'), findsOneWidget);
      expect(find.text('Saldo geral'), findsOneWidget);
      expect(find.text(formatCurrency(150)), findsOneWidget);
    });

    testWidgets('vazio', (tester) async {
      await pumpPainel(
        tester,
        const FinCarteirasScreen(),
        overrides: withFin(FakeFinanceiro()),
      );
      await settle(tester);
      expect(find.text('Nenhuma carteira cadastrada'), findsOneWidget);
    });

    testWidgets('erro com retry', (tester) async {
      await pumpPainel(
        tester,
        const FinCarteirasScreen(),
        overrides: withFin(FakeFinanceiro(fail: true)),
      );
      await settle(tester);
      expect(find.byType(ErrorBanner), findsOneWidget);
    });
  });

  group('Categorias (árvore)', () {
    testWidgets('mostra mãe + conta subcategorias, expande p/ filha', (
      tester,
    ) async {
      final fake = FakeFinanceiro(
        categorias: [
          fakeCategoria(id: 'm', nome: 'Marketing'),
          fakeCategoria(id: 's', nome: 'Google Ads', parentId: 'm'),
        ],
      );
      await pumpPainel(
        tester,
        const FinCategoriasScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      expect(find.text('Marketing'), findsOneWidget);
      expect(find.text('1 subcategoria'), findsOneWidget);

      await tester.tap(find.text('Marketing'));
      await tester.pumpAndSettle();
      expect(find.text('Google Ads'), findsOneWidget);
    });

    testWidgets('vazio', (tester) async {
      await pumpPainel(
        tester,
        const FinCategoriasScreen(),
        overrides: withFin(FakeFinanceiro()),
      );
      await settle(tester);
      expect(find.text('Nenhuma categoria de despesa'), findsOneWidget);
    });
  });

  group('Visão geral (charts)', () {
    testWidgets('KPIs + donut + barras renderizam', (tester) async {
      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'a', saldoAtual: 500)],
        categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
        lancamentos: [
          fakeLanc(id: '1', tipo: TipoLancamento.receita, valor: 300),
          fakeLanc(
            id: '2',
            tipo: TipoLancamento.despesa,
            valor: 120,
            categoriaId: 'cat',
          ),
        ],
      );
      await pumpPainel(
        tester,
        const FinVisaoGeralScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      expect(find.text('Entradas'), findsWidgets);
      expect(find.text('Maiores gastos por categoria'), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('vazio quando não há movimentação', (tester) async {
      await pumpPainel(
        tester,
        const FinVisaoGeralScreen(),
        overrides: withFin(FakeFinanceiro()),
      );
      await settle(tester);
      expect(find.text('Sem movimentações neste mês'), findsOneWidget);
    });
  });

  group('Relatórios', () {
    testWidgets('charts de entradas×saídas + por categoria', (tester) async {
      final fake = FakeFinanceiro(
        categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
        lancamentos: [
          fakeLanc(id: '1', tipo: TipoLancamento.receita, valor: 300),
          fakeLanc(
            id: '2',
            tipo: TipoLancamento.despesa,
            valor: 120,
            categoriaId: 'cat',
          ),
        ],
      );
      await pumpPainel(
        tester,
        const FinRelatoriosScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);
      expect(find.text('Entradas × saídas'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(PieChart), findsWidgets);
    });
  });

  group('Limites (progresso)', () {
    testWidgets('barra de progresso + categoria', (tester) async {
      final fake = FakeFinanceiro(
        categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
        limites: [fakeLimite(id: 'l', categoriaId: 'cat', limite: 200)],
        lancamentos: [
          fakeLanc(
            id: '1',
            tipo: TipoLancamento.despesa,
            valor: 150,
            categoriaId: 'cat',
          ),
        ],
      );
      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      expect(find.text('Material'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('vazio', (tester) async {
      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(FakeFinanceiro()),
      );
      await settle(tester);
      expect(find.text('Nenhum limite definido'), findsOneWidget);
    });
  });

  group('Contas a pagar/receber', () {
    testWidgets('lista despesas em aberto com total', (tester) async {
      final fake = FakeFinanceiro(
        lancamentos: [
          fakeLanc(
            id: '1',
            tipo: TipoLancamento.despesa,
            descricao: 'Fornecedor',
            status: LancamentoStatus.pendente,
            vencimento: '2026-07-20',
          ),
        ],
      );
      await pumpPainel(
        tester,
        const FinContasPagarReceberScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);
      expect(find.text('Total a pagar'), findsOneWidget);
      expect(find.text('Fornecedor'), findsOneWidget);
    });

    testWidgets('vazio quando tudo pago', (tester) async {
      final fake = FakeFinanceiro(
        lancamentos: [fakeLanc(id: '1', status: LancamentoStatus.pago)],
      );
      await pumpPainel(
        tester,
        const FinContasPagarReceberScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);
      expect(find.text('Nada a pagar em aberto'), findsOneWidget);
    });
  });

  group('Lançamentos', () {
    testWidgets('agrupa por data e mostra descrições', (tester) async {
      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'c')],
        categorias: [fakeCategoria(id: 'cat')],
        lancamentos: [
          fakeLanc(id: '1', descricao: 'Compra A', data: '2026-07-10'),
          fakeLanc(
            id: '2',
            descricao: 'Venda B',
            data: '2026-07-08',
            tipo: TipoLancamento.receita,
          ),
        ],
      );
      await pumpPainel(
        tester,
        const FinLancamentosScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      expect(find.text('Compra A'), findsOneWidget);
      expect(find.text('Venda B'), findsOneWidget);
      expect(find.text('10/07/2026'), findsOneWidget);
      expect(find.text('08/07/2026'), findsOneWidget);
    });

    testWidgets('vazio', (tester) async {
      await pumpPainel(
        tester,
        const FinLancamentosScreen(),
        overrides: withFin(FakeFinanceiro()),
      );
      await settle(tester);
      expect(find.text('Nenhum lançamento neste mês'), findsOneWidget);
    });

    testWidgets('validação: salvar vazio mostra erros e não cria', (
      tester,
    ) async {
      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'c', nome: 'Caixa')],
        categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
      );
      await pumpPainel(
        tester,
        const FinLancamentosScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      await tester.tap(find.text('Novo lançamento').first);
      await tester.pumpAndSettle();
      expect(find.byType(LancamentoForm), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Descrição é obrigatória'), findsOneWidget);
      expect(fake.createLancCount, 0);
    });

    testWidgets('validação: valor <= 0 / negativo é rejeitado (não cria)', (
      tester,
    ) async {
      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'c', nome: 'Caixa')],
        categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
      );
      await pumpPainel(
        tester,
        const FinLancamentosScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      await tester.tap(find.text('Novo lançamento').first);
      await tester.pumpAndSettle();

      final descField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText ==
                'Ex.: Compra de material, Recebimento cliente',
      );
      final valorField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0,00',
      );

      // Descrição válida, mas valor NEGATIVO → deve barrar no valor.
      await tester.enterText(descField, 'Compra de material');
      await tester.enterText(valorField, '-10');
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Informe um valor válido'), findsOneWidget);
      expect(find.text('Descrição é obrigatória'), findsNothing);
      expect(fake.createLancCount, 0);

      // Valor ZERO também é inválido (não é > 0).
      await tester.enterText(valorField, '0');
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Informe um valor válido'), findsOneWidget);
      expect(fake.createLancCount, 0);
    });
  });
}
