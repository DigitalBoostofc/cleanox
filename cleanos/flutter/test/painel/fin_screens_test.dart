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

    // Regressão: dono reportou (QA 03/07, APK 1.2.0+6) que uma categoria nova
    // "não aparecia" na lista. Causa raiz: o form de Nova categoria sempre
    // criava com tipo=despesa (default fixo no initState), ignorando o toggle
    // Despesas|Receitas da tela — então criar na aba Receitas gerava uma
    // categoria de despesa, invisível na aba corrente.
    testWidgets('nova categoria criada na aba Receitas aparece com tipo receita '
        '(sem trocar de aba manualmente)', (tester) async {
      final fake = FakeFinanceiro(
        categorias: [
          fakeCategoria(
            id: 'd',
            nome: 'Salários',
            tipo: TipoLancamento.despesa,
          ),
          fakeCategoria(id: 'r', nome: 'Vendas', tipo: TipoLancamento.receita),
        ],
      );
      await pumpPainel(
        tester,
        const FinCategoriasScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      // Troca para a aba Receitas.
      await tester.tap(find.text('Receitas'));
      await tester.pumpAndSettle();
      expect(find.text('Vendas'), findsOneWidget);

      // Abre o form pelo botão da toolbar (único nesta aba — lista não vazia).
      await tester.tap(find.widgetWithText(ClxButton, 'Nova categoria'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Comissões');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await settle(tester);

      // A categoria deve ter nascido como RECEITA (aba corrente), não despesa.
      expect(fake.lastCreateCategoria?['tipo'], TipoLancamento.receita.wire);
      // E deve aparecer na lista imediatamente, sem trocar de aba.
      expect(find.text('Comissões'), findsOneWidget);
    });

    // Mesmo fluxo acima, mas pelo botão "Nova categoria" do ESTADO VAZIO (não
    // o da toolbar) — call site distinto que o reviewer apontou como gap de
    // cobertura: também precisa herdar o tipo da aba corrente.
    testWidgets(
      'nova categoria via botão do estado vazio (aba Receitas) nasce com '
      'tipo receita',
      (tester) async {
        final fake = FakeFinanceiro(); // sem categorias: vazio nas 2 abas.
        await pumpPainel(
          tester,
          const FinCategoriasScreen(),
          overrides: withFin(fake),
        );
        await settle(tester);
        expect(find.text('Nenhuma categoria de despesa'), findsOneWidget);

        // Troca para a aba Receitas (permanece vazia).
        await tester.tap(find.text('Receitas'));
        await tester.pumpAndSettle();
        expect(find.text('Nenhuma categoria de receita'), findsOneWidget);

        // Abre o form pelo botão do EMPTY STATE, não o da toolbar.
        await tester.tap(
          find.descendant(
            of: find.byType(EmptyState),
            matching: find.widgetWithText(ClxButton, 'Nova categoria'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'Consultoria');
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();
        await settle(tester);

        expect(fake.lastCreateCategoria?['tipo'], TipoLancamento.receita.wire);
        expect(find.text('Consultoria'), findsOneWidget);
      },
    );
  });

  group('Visão geral (charts)', () {
    testWidgets('KPIs + donuts (gastos + origem) renderizam', (tester) async {
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

      // Layout Organizze: totais do mês + maiores gastos + receitas por origem.
      expect(find.text('Receitas no mês atual'), findsOneWidget);
      expect(find.text('Despesas no mês atual'), findsOneWidget);
      expect(find.text('Maiores gastos do mês'), findsOneWidget);
      expect(find.text('Receitas por origem'), findsOneWidget);
      expect(find.text('Saldo geral'), findsOneWidget);
      expect(find.byType(PieChart), findsWidgets);
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
      // Aba default (Categorias): donuts por categoria.
      expect(find.byType(PieChart), findsWidgets);
      // Troca para a aba de fluxo (Entradas × Saídas) → barras.
      await tester.tap(find.text('Entradas × Saídas'));
      await settle(tester);
      expect(find.byType(BarChart), findsOneWidget);
    });

    // Desktop preserva a tabela densa (só o mobile vira cards — ver
    // fin_mobile_layout_test.dart).
    testWidgets('desktop: aba Contas mantém a tabela com colunas', (
      tester,
    ) async {
      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'c', nome: 'Caixa', saldoAtual: 500)],
        lancamentos: [
          fakeLanc(
            id: '1',
            tipo: TipoLancamento.receita,
            valor: 300,
            contaId: 'c',
          ),
          fakeLanc(
            id: '2',
            tipo: TipoLancamento.despesa,
            valor: 120,
            contaId: 'c',
          ),
        ],
      );
      await pumpPainel(
        tester,
        const FinRelatoriosScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      // No desktop o filtro "Contas" do header e a aba "Contas" coexistem;
      // a aba é a última no widget tree (renderizada depois do header).
      await tester.tap(find.text('Contas').last);
      await settle(tester);

      expect(find.text('Conta'), findsOneWidget);
      expect(find.text('Entradas'), findsOneWidget);
      expect(find.text('Saídas'), findsOneWidget);
      expect(find.text('Saldo atual'), findsOneWidget);
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
      // Aba default "A pagar" sem pendências → estado vazio.
      expect(find.text('Nenhuma conta a pagar no período.'), findsOneWidget);
    });

    group(
      'review: painel de filtros junto ao header + Salvar filtro (feedback dono)',
      () {
        const narrow = Size(360, 800);

        testWidgets(
          'painel abre logo abaixo do header, antes dos cards de totais',
          (tester) async {
            await pumpPainel(
              tester,
              const FinContasPagarReceberScreen(),
              overrides: withFin(FakeFinanceiro()),
              size: narrow,
            );
            await settle(tester);

            await tester.tap(find.text('Filtros'));
            await tester.pump();

            final panelTop = tester.getTopLeft(find.text('Tipo')).dy;
            final firstCardTop = tester
                .getTopLeft(find.text('Total a pagar'))
                .dy;
            expect(
              panelTop,
              lessThan(firstCardTop),
              reason:
                  'painel de filtros precisa vir ANTES dos cards de totais no mobile',
            );
          },
        );

        testWidgets(
          'tocar "Salvar filtro" colapsa o painel e mostra "Filtro aplicado"',
          (tester) async {
            await pumpPainel(
              tester,
              const FinContasPagarReceberScreen(),
              overrides: withFin(FakeFinanceiro()),
              size: narrow,
            );
            await settle(tester);

            await tester.tap(find.text('Filtros'));
            await tester.pump();
            expect(find.text('Tipo'), findsOneWidget);

            await tester.tap(find.text('Salvar filtro'));
            await tester.pump();

            // Painel colapsado (campos de filtro somem)...
            expect(find.text('Tipo'), findsNothing);
            // ...e o toast de confirmação aparece.
            expect(find.text('Filtro aplicado'), findsOneWidget);

            // Consome o timer do toast antes do fim do teste.
            await tester.pump(const Duration(milliseconds: 2600));
          },
        );

        testWidgets('o toast "Filtro aplicado" some sozinho depois do tempo', (
          tester,
        ) async {
          await pumpPainel(
            tester,
            const FinContasPagarReceberScreen(),
            overrides: withFin(FakeFinanceiro()),
            size: narrow,
          );
          await settle(tester);

          await tester.tap(find.text('Filtros'));
          await tester.pump();
          await tester.tap(find.text('Salvar filtro'));
          await tester.pump();
          expect(find.text('Filtro aplicado'), findsOneWidget);

          await tester.pump(const Duration(milliseconds: 2600));
          expect(find.text('Filtro aplicado'), findsNothing);
        });

        testWidgets(
          'botão "Filtros" continua ativo (preenchido) com filtro != padrão '
          'depois de Salvar',
          (tester) async {
            final fake = FakeFinanceiro(
              categorias: [fakeCategoria(id: 'c', nome: 'Material')],
            );
            await pumpPainel(
              tester,
              const FinContasPagarReceberScreen(),
              overrides: withFin(fake),
              size: narrow,
            );
            await settle(tester);

            await tester.tap(find.text('Filtros'));
            await tester.pump();

            // Muda o filtro de Tipo pra algo != padrão.
            await tester.tap(find.text('Todos os tipos'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Despesas (a pagar)').last);
            await tester.pumpAndSettle();

            await tester.tap(find.text('Salvar filtro'));
            await tester.pump();

            final filtrosMaterial = tester.widget<Material>(
              find
                  .ancestor(
                    of: find.text('Filtros'),
                    matching: find.byType(Material),
                  )
                  .first,
            );
            final scheme = Theme.of(
              tester.element(find.text('Filtros')),
            ).colorScheme;
            expect(filtrosMaterial.color, scheme.secondaryContainer);

            // Consome o timer do toast antes do fim do teste.
            await tester.pump(const Duration(milliseconds: 2600));
          },
        );
      },
    );
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
      expect(find.text('10/07/26'), findsOneWidget);
      expect(find.text('08/07/26'), findsOneWidget);
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

    // Regressão: mesmo padrão do bug de Categorias (commit 540321f) — o botão
    // "Novo lançamento" da toolbar não herdava o filtro Receitas/Despesas da
    // tela (não passava `initialTipo`), então criar um lançamento com o
    // filtro em Receitas nascia como despesa (default fixo do form) e sumia
    // da lista até trocar o filtro manualmente.
    testWidgets('novo lançamento com filtro em Receitas nasce com tipo receita '
        '(sem trocar o tipo manualmente no form)', (tester) async {
      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'c', nome: 'Caixa')],
        categorias: [
          fakeCategoria(
            id: 'd',
            nome: 'Salários',
            tipo: TipoLancamento.despesa,
          ),
          fakeCategoria(id: 'r', nome: 'Vendas', tipo: TipoLancamento.receita),
        ],
        lancamentos: [
          fakeLanc(id: '1', descricao: 'Aluguel', tipo: TipoLancamento.despesa),
        ],
      );
      await pumpPainel(
        tester,
        const FinLancamentosScreen(),
        overrides: withFin(fake),
      );
      await settle(tester);

      // Filtra por Receitas na toolbar.
      await tester.tap(find.text('Receitas'));
      await tester.pumpAndSettle();

      // Abre o form pelo botão "Novo lançamento" (da toolbar).
      await tester.tap(find.text('Novo lançamento').first);
      await tester.pumpAndSettle();
      expect(find.byType(LancamentoForm), findsOneWidget);

      // O form já deve nascer com "Receita" selecionada (herdada do
      // filtro), sem precisar tocar no SegmentedButton manualmente.
      final segmented = tester.widget<SegmentedButton<TipoLancamento>>(
        find.byType(SegmentedButton<TipoLancamento>),
      );
      expect(segmented.selected, {TipoLancamento.receita});

      // Preenche o mínimo pra salvar sem alterar o tipo.
      final descField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText ==
                'Ex.: Compra de material, Recebimento cliente',
      );
      final valorField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0,00',
      );
      await tester.enterText(descField, 'Comissão de venda');
      await tester.enterText(valorField, '150');
      await tester.pump();

      // Conta (dropdown de String).
      final contaDropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(contaDropdown);
      await tester.tap(contaDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Caixa').last);
      await tester.pumpAndSettle();

      // Categoria unificada (árvore): só "Vendas" (receita) deve aparecer —
      // prova que _tipo já é receita antes de qualquer interação manual.
      final catPicker = find.byKey(const ValueKey('fin-categoria-tree-picker'));
      await tester.ensureVisible(catPicker);
      await tester.tap(catPicker);
      await tester.pumpAndSettle();
      expect(find.text('Salários'), findsNothing);
      await tester.tap(find.text('Vendas').last);
      await tester.pumpAndSettle();

      final salvarBtn = find.text('Salvar');
      await tester.ensureVisible(salvarBtn);
      await tester.tap(salvarBtn);
      await tester.pumpAndSettle();
      await settle(tester);

      // Deve ter sido criado como RECEITA (filtro corrente), não despesa.
      expect(fake.lastCreateLanc?['tipo'], TipoLancamento.receita.wire);
      // E aparece na lista (fake replica o reload real do PocketBase).
      expect(find.text('Comissão de venda'), findsOneWidget);
    });
  });
}
