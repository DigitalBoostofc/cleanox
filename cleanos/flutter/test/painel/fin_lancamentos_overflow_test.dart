/// fin_lancamentos_overflow_test.dart — F-742: o `_DayHeader` (cabeçalho de dia)
/// e o valor do `_LancamentoRow` não podem estourar a Row com totais longos
/// (ex.: R$ 12.345.678,90) em larguras muito estreitas (≤360 px).
///
/// Os widgets são exercitados ISOLADAMENTE (via `debugDayHeader`/
/// `debugLancamentoRow`, @visibleForTesting) para não misturar com a toolbar do
/// Financeiro — cujo layout mobile é escopo de F-741, fora desta correção.
library;

import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_derivations.dart';
import 'package:cleanos/painel/financeiro/lancamentos/fin_lancamentos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget child, double width) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('F-742: _DayHeader com total longo não estoura a 320px', (
    tester,
  ) async {
    final grupo = GrupoPorData(
      data: '2026-07-10',
      itens: [
        fakeLanc(id: '1', tipo: TipoLancamento.receita, valor: 12345678.90),
        fakeLanc(id: '2', tipo: TipoLancamento.receita, valor: 111111111.11),
      ],
      totalDia: 123456790.01, // +R$ 123.456.790,01 — total propositalmente longo
    );

    await pumpAt(tester, debugDayHeader(grupo), 320);

    // A data renderiza e NÃO houve RenderFlex overflow.
    expect(find.text('10/07/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'F-742: valor longo do _LancamentoRow é protegido (Flexible + ellipsis)',
    (tester) async {
      final lanc = fakeLanc(
        id: '1',
        descricao: 'Recebimento muito grande com descrição longa',
        tipo: TipoLancamento.receita,
        valor: 987654321.98, // R$ 987.654.321,98 — valor propositalmente longo
      );

      // Largura confortável p/ os chips (o overflow interno do ClxChip em
      // larguras minúsculas é pré-existente e DISTINTO de F-742). Aqui o foco é
      // o Text de VALOR, que agora encolhe com ellipsis em vez de estourar.
      await pumpAt(tester, debugLancamentoRow(lanc), 420);
      expect(tester.takeException(), isNull);

      // O valor está envolto em Flexible e elipsa (a proteção do fix F-742).
      final valueText = tester.widget<Text>(
        find.textContaining('987.654.321'),
      );
      expect(valueText.overflow, TextOverflow.ellipsis);
      expect(
        find.ancestor(
          of: find.textContaining('987.654.321'),
          matching: find.byType(Flexible),
        ),
        findsWidgets,
      );
    },
  );
}
