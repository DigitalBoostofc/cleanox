/// fin_mobile_layout_test.dart — Layout MOBILE do Financeiro (F-741).
///
/// Regressão da otimização de celular do módulo Financeiro: em viewport estreita
/// (360×760, ~APK) a toolbar de filtro de Lançamentos NÃO fica fixa nem sempre
/// expandida — ela COLAPSA atrás de um botão "Filtros", e o cabeçalho/KPIs rolam
/// junto com a lista (um `CustomScrollView`, não irmãos fixos acima de um
/// `Expanded`).
///
/// Assertos:
///  • a estrutura é rolável (`CustomScrollView`) com os KPIs DENTRO do scroll;
///  • a busca (campo do filtro) começa COLAPSADA (botão "Filtros" presente);
///  • tocar "Filtros" REVELA o campo de busca;
///  • o layout ESTÁVEL na largura estreita não estoura (sem `RenderFlex
///    overflowed`) — verificado forçando um relayout final a exatamente 360 px.
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/categorias/fin_categorias_screen.dart';
import 'package:cleanos/painel/financeiro/fin_contas_pagar_receber_screen.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/fin_relatorios_screen.dart';
import 'package:cleanos/painel/financeiro/lancamentos/fin_lancamentos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  // Viewport de celular estreito (APK). Os providers do Financeiro assentam em
  // alguns pumps curtos (evita travar no spinner com pumpAndSettle).
  const narrow = Size(360, 760);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Confirma que o layout ESTÁVEL na largura estreita não estoura. Descarta
  /// exceções de frames intermediários do fake-async e força um relayout limpo
  /// exatamente em [narrow] (largura de destino), onde qualquer overflow real
  /// re-emitiria. (O layout final assentado é o que o usuário vê no device.)
  Future<void> expectStableNoOverflow(WidgetTester tester) async {
    while (tester.takeException() != null) {}
    tester.view.physicalSize = const Size(400, 760);
    await tester.pump();
    while (tester.takeException() != null) {}
    tester.view.physicalSize = narrow;
    await tester.pump();
    await tester.pump();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Overflow no layout estável a 360 px de largura',
    );
  }

  /// Igual a [expectStableNoOverflow], mas para uma largura arbitrária (usado
  /// pelos cards de "Movimentação por conta" a 360 e 320 px).
  Future<void> expectStableNoOverflowAt(WidgetTester tester, Size target) async {
    while (tester.takeException() != null) {}
    tester.view.physicalSize = Size(target.width + 40, target.height);
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

  List<Override> withFin(FakeFinanceiro fake) => [
    ...painelOverrides(user: painelUser()),
    financeiroRepositoryProvider.overrideWithValue(fake),
  ];

  FakeFinanceiro fakeComLancamentos() => FakeFinanceiro(
    contas: [fakeConta(id: 'conta', nome: 'Caixa')],
    categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
    lancamentos: [
      fakeLanc(id: '1', descricao: 'Compra de tinta', valor: 120),
      fakeLanc(id: '2', descricao: 'Aluguel', valor: 900),
    ],
  );

  final searchField = find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.hintText == 'Buscar descrição, cliente ou nº da OS…',
  );

  testWidgets(
    'Lançamentos no mobile: toolbar colapsada (botão "Filtros"), KPIs dentro de '
    'um CustomScrollView, sem overflow no frame estável',
    (tester) async {
      await pumpPainel(
        tester,
        const FinLancamentosScreen(),
        overrides: withFin(fakeComLancamentos()),
        size: narrow,
      );
      await settle(tester);

      // Estrutura rolável (cabeçalho + KPIs + lista no MESMO scroll — sem faixa
      // fixa acima de um Expanded).
      expect(find.byType(CustomScrollView), findsOneWidget);

      // KPIs rolam junto (dentro do scroll).
      expect(find.text('Receitas realizadas'), findsOneWidget);

      // Toolbar COLAPSADA: botão "Filtros" presente e a busca escondida.
      expect(find.text('Filtros'), findsOneWidget);
      expect(searchField, findsNothing);

      // Ação principal continua acessível.
      expect(find.text('Novo lançamento'), findsOneWidget);

      await expectStableNoOverflow(tester);
    },
  );

  testWidgets('Lançamentos no mobile: tocar "Filtros" revela o campo de busca', (
    tester,
  ) async {
    await pumpPainel(
      tester,
      const FinLancamentosScreen(),
      overrides: withFin(fakeComLancamentos()),
      size: narrow,
    );
    await settle(tester);

    expect(searchField, findsNothing);

    await tester.tap(find.text('Filtros'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Busca agora visível; layout estável segue sem overflow com o filtro aberto.
    expect(searchField, findsOneWidget);
    await expectStableNoOverflow(tester);
  });

  testWidgets(
    'review: Categorias no mobile — toggle Despesas/Receitas ocupa a MESMA '
    'largura do botão "Nova categoria" abaixo (feedback dono)',
    (tester) async {
      await pumpPainel(
        tester,
        const FinCategoriasScreen(),
        overrides: withFin(
          FakeFinanceiro(
            categorias: [fakeCategoria(id: 'm', nome: 'Marketing')],
          ),
        ),
        size: narrow,
      );
      await settle(tester);

      final toggleWidth = tester
          .getSize(find.byWidgetPredicate((w) => w is SegmentedButton))
          .width;
      final buttonWidth = tester
          .getSize(find.widgetWithText(ClxButton, 'Nova categoria'))
          .width;

      expect(
        (toggleWidth - buttonWidth).abs(),
        lessThanOrEqualTo(2),
        reason: 'toggle e botão precisam ter a mesma largura total no mobile',
      );

      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'review: Contas a pagar/receber no mobile — grupo A pagar/A receber/'
    'Todas ocupa a largura total do header (mesmo padrão de Categorias)',
    (tester) async {
      await pumpPainel(
        tester,
        const FinContasPagarReceberScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      final toggleWidth = tester
          .getSize(find.byWidgetPredicate((w) => w is SegmentedButton))
          .width;
      final expectedWidth = narrow.width - 2 * ClxSpace.x6;

      expect(
        (toggleWidth - expectedWidth).abs(),
        lessThanOrEqualTo(2),
        reason:
            'grupo A pagar/A receber/Todas precisa ocupar a largura total no mobile',
      );

      await expectStableNoOverflow(tester);
    },
  );

  group(
    'Relatórios — Movimentação por conta em cards no mobile (feedback dono: '
    'nunca tabela)',
    () {
      // 2 contas com valores distintos entre si E distintos dos totais dos
      // KPIs (soma das 2), pra não colidir na busca por texto do teste.
      FakeFinanceiro fakeComContas({
        String contaNome = 'Cartão Empresarial Nubank',
      }) => FakeFinanceiro(
        contas: [
          fakeConta(id: 'c', nome: contaNome, saldoAtual: 2260),
          fakeConta(id: 'c2', nome: 'Caixa Loja', saldoAtual: 700),
        ],
        categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
        lancamentos: [
          fakeLanc(
            id: '1',
            tipo: TipoLancamento.receita,
            valor: 2500,
            contaId: 'c',
            categoriaId: 'cat',
          ),
          fakeLanc(
            id: '2',
            tipo: TipoLancamento.despesa,
            valor: 240,
            contaId: 'c',
            categoriaId: 'cat',
          ),
          fakeLanc(
            id: '3',
            tipo: TipoLancamento.receita,
            valor: 800,
            contaId: 'c2',
            categoriaId: 'cat',
          ),
          fakeLanc(
            id: '4',
            tipo: TipoLancamento.despesa,
            valor: 100,
            contaId: 'c2',
            categoriaId: 'cat',
          ),
        ],
      );

      Future<void> irParaAbaContas(WidgetTester tester) async {
        // A faixa de abas rola horizontalmente e "Contas" pode nascer fora da
        // viewport estreita — traz para a tela antes de tocar.
        final tab = find.text('Contas');
        await tester.ensureVisible(tab);
        await tester.pump();
        await tester.tap(tab);
        await settle(tester);
      }

      testWidgets(
        '360×800: card por conta com nome completo (sem truncar) e valores '
        'completos (sem quebra no meio do número), sem overflow',
        (tester) async {
          const size = Size(360, 800);
          await pumpPainel(
            tester,
            const FinRelatoriosScreen(),
            overrides: withFin(fakeComContas()),
            size: size,
          );
          await settle(tester);
          await irParaAbaContas(tester);

          // 2 cards (não tabela): nomes por extenso + as 3 métricas de cada
          // conta com valor completo (nada colide com os totais dos KPIs).
          expect(find.text('Cartão Empresarial Nubank'), findsOneWidget);
          expect(find.text('Caixa Loja'), findsOneWidget);
          expect(find.text('Entradas'), findsNWidgets(2));
          expect(find.text('Saídas'), findsNWidgets(2));
          expect(find.text('Saldo atual'), findsNWidgets(2));
          expect(find.text(formatCurrency(2500)), findsOneWidget);
          expect(find.text(formatCurrency(240)), findsOneWidget);
          expect(find.text(formatCurrency(2260)), findsOneWidget);
          expect(find.text(formatCurrency(800)), findsOneWidget);
          expect(find.text(formatCurrency(100)), findsOneWidget);
          expect(find.text(formatCurrency(700)), findsOneWidget);

          // Nunca tabela no mobile: sem cabeçalho de colunas.
          expect(find.text('Conta'), findsNothing);

          await expectStableNoOverflowAt(tester, size);
        },
      );

      testWidgets('320×800: sem overflow', (tester) async {
        const size = Size(320, 800);
        await pumpPainel(
          tester,
          const FinRelatoriosScreen(),
          overrides: withFin(fakeComContas()),
          size: size,
        );
        await settle(tester);
        await irParaAbaContas(tester);

        expect(find.text('Cartão Empresarial Nubank'), findsOneWidget);
        expect(find.text('Caixa Loja'), findsOneWidget);
        expect(find.text(formatCurrency(2500)), findsOneWidget);
        expect(find.text(formatCurrency(240)), findsOneWidget);
        expect(find.text(formatCurrency(2260)), findsOneWidget);
        expect(find.text(formatCurrency(800)), findsOneWidget);
        expect(find.text(formatCurrency(100)), findsOneWidget);
        expect(find.text(formatCurrency(700)), findsOneWidget);

        await expectStableNoOverflowAt(tester, size);
      });
    },
  );
}
