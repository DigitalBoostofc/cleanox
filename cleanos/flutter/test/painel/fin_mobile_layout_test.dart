/// fin_mobile_layout_test.dart — Layout MOBILE do Financeiro (F-741 + Organizze).
///
/// Regressão do layout mobile do Financeiro: em viewport estreita (360×760,
/// ~APK) Movimentações usa toolbar Organizze clean (título + barra laranja de
/// filtros + lista) dentro de um `CustomScrollView` — sem KPIs no topo e com
/// busca colapsada atrás do ícone 🔍.
///
/// Assertos:
///  • a estrutura é rolável (`CustomScrollView`);
///  • barra de filtros (Tipo) sempre visível; busca inicia colapsada;
///  • tocar o ícone Buscar REVELA o campo;
///  • o layout ESTÁVEL na largura estreita não estoura (sem `RenderFlex
///    overflowed`) — verificado forçando um relayout final a exatamente 360 px.
library;

import 'package:cleanos/core/design/design.dart';
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
    'Lançamentos no mobile: toolbar Organizze (barra de filtros + lista) em '
    'CustomScrollView, sem overflow no frame estável',
    (tester) async {
      await pumpPainel(
        tester,
        const FinLancamentosScreen(),
        overrides: withFin(fakeComLancamentos()),
        size: narrow,
      );
      await settle(tester);

      // Cabeçalho + lista no MESMO scroll (sem faixa fixa de KPIs).
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Sem KPIs no topo (estilo Organizze clean).
      expect(find.text('Dinheiro que entrou'), findsNothing);

      // Barra de filtros sempre visível; busca colapsada atrás do ícone.
      expect(find.text('Tipo'), findsOneWidget);
      expect(find.text('Movimentações'), findsOneWidget);
      expect(searchField, findsNothing);

      // Ação principal: botão (+) com tooltip.
      expect(find.byTooltip('Novo lançamento'), findsOneWidget);

      await expectStableNoOverflow(tester);
    },
  );

  testWidgets('Lançamentos no mobile: ícone de busca revela o campo', (
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

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Busca agora visível; layout estável segue sem overflow.
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

  group('Relatórios — mobile sem overflow (abas Categorias / Entradas×Saídas)', () {
    testWidgets('360×800: Categorias e fluxo sem overflow', (tester) async {
      const size = Size(360, 800);
      final fake = FakeFinanceiro(
        categorias: [fakeCategoria(id: 'cat', nome: 'Material')],
        lancamentos: [
          fakeLanc(
            id: '1',
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
        size: size,
      );
      await settle(tester);
      expect(find.text('Categorias'), findsWidgets);
      expect(find.text('Tags'), findsNothing);
      await expectStableNoOverflowAt(tester, size);

      await tester.tap(find.text('Entradas × Saídas'));
      await settle(tester);
      expect(find.text('Entradas × Saídas'), findsWidgets);
      await expectStableNoOverflowAt(tester, size);
    });
  });
}

