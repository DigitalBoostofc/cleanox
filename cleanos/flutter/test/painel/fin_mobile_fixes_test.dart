/// fin_mobile_fixes_test.dart — Regressão dos 5 bugs de UI mobile reportados
/// pelo dono após instalar o APK (viewport estreito, ~360×800):
///
///  1. Visão geral: ações rápidas em grade fixa 2x2 (Nova receita/Nova despesa
///     em cima, Transferência/Importar embaixo) em vez do Wrap 3+1.
///  2. Contas a pagar/receber: painel de filtros inicia COLAPSADO no mobile
///     (não mais aberto por padrão) e o botão "Filtros" fica preenchido
///     quando o painel está aberto.
///  3. Carteiras: header (título + botões) não estoura em Column — o título
///     não deve mais colapsar para texto vertical.
///  4. Limites: header (período + "Novo limite") não corta o botão fora do
///     viewport.
///  5. Categorias: header (toggle Despesas/Receitas + "Nova categoria") não
///     corta o botão fora do viewport.
library;

import 'package:cleanos/painel/financeiro/carteiras/fin_carteiras_screen.dart';
import 'package:cleanos/painel/financeiro/categorias/fin_categorias_screen.dart';
import 'package:cleanos/painel/financeiro/fin_contas_pagar_receber_screen.dart';
import 'package:cleanos/painel/financeiro/fin_limites_screen.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/fin_visao_geral_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  const narrow = Size(360, 800);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Mesma técnica de `fin_mobile_layout_test.dart`: força um relayout limpo
  /// exatamente em [narrow], onde overflow real re-emitiria a exceção.
  Future<void> expectStableNoOverflow(WidgetTester tester) async {
    while (tester.takeException() != null) {}
    tester.view.physicalSize = const Size(400, 800);
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

  testWidgets(
    'Visão geral no mobile: ações rápidas em grade 2x2 (receita/despesa em '
    'cima, transferência/importar embaixo), sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinVisaoGeralScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      final receitaY = tester.getTopLeft(find.text('Nova receita')).dy;
      final despesaY = tester.getTopLeft(find.text('Nova despesa')).dy;
      final transferenciaY = tester.getTopLeft(find.text('Transferência')).dy;
      final importarY = tester.getTopLeft(find.text('Importar')).dy;

      // Tolerância de poucos pixels: o Row centraliza (crossAxisAlignment
      // padrão), então rótulos que quebram em 2 linhas (ex.: "Transferência")
      // deslocam o topo do texto em relação a um rótulo de 1 linha na MESMA
      // linha visual.
      expect(
        (despesaY - receitaY).abs(),
        lessThan(5),
        reason: 'Receita e despesa na mesma linha',
      );
      expect(
        (importarY - transferenciaY).abs(),
        lessThan(5),
        reason: 'Transferência e importar na mesma linha',
      );
      expect(
        transferenciaY,
        greaterThan(receitaY + 5),
        reason: 'Segunda linha abaixo da primeira',
      );

      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Contas a pagar/receber no mobile: filtros iniciam colapsados e o botão '
    '"Filtros" revela o painel ao tocar, sem overflow',
    (tester) async {
      await pumpPainel(
        tester,
        const FinContasPagarReceberScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      // Painel colapsado por padrão no mobile (bug reportado: vinha aberto).
      expect(find.text('Limpar filtros'), findsNothing);

      await tester.tap(find.text('Filtros'));
      await settle(tester);

      expect(find.text('Limpar filtros'), findsOneWidget);
      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Carteiras no mobile: header não estoura (título permanece legível, não '
    'vira texto vertical) e os botões continuam acessíveis',
    (tester) async {
      await pumpPainel(
        tester,
        const FinCarteirasScreen(),
        overrides: withFin(
          FakeFinanceiro(contas: [fakeConta(id: 'a', nome: 'Caixa')]),
        ),
        size: narrow,
      );
      await settle(tester);

      expect(find.text('Carteiras e contas'), findsOneWidget);
      expect(find.text('Nova carteira'), findsOneWidget);
      // Texto vertical (1 caractere por linha) resultaria numa largura ínfima;
      // o título deve ocupar largura razoável do título completo.
      final titleWidth = tester.getSize(find.text('Carteiras e contas')).width;
      expect(titleWidth, greaterThan(80));

      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Limites no mobile: header quebra em coluna e "Novo limite" não é '
    'cortado fora do viewport',
    (tester) async {
      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      expect(find.text('Novo limite'), findsWidgets);
      await expectStableNoOverflow(tester);
    },
  );

  testWidgets(
    'Categorias no mobile: header quebra em coluna e "Nova categoria" não é '
    'cortado fora do viewport',
    (tester) async {
      await pumpPainel(
        tester,
        const FinCategoriasScreen(),
        overrides: withFin(FakeFinanceiro()),
        size: narrow,
      );
      await settle(tester);

      expect(find.text('Nova categoria'), findsWidgets);
      await expectStableNoOverflow(tester);
    },
  );
}
