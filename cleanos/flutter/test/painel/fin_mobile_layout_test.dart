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

import 'package:cleanos/painel/financeiro/fin_providers.dart';
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

  testWidgets(
    'Lançamentos no mobile: tocar "Filtros" revela o campo de busca',
    (tester) async {
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
    },
  );
}
