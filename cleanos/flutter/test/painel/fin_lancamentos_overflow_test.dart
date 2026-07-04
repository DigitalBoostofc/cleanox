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
    'QA-F3: valor do _LancamentoRow NUNCA trunca — é a descrição que cede '
    '(ellipsis) quando o espaço aperta',
    (tester) async {
      final lanc = fakeLanc(
        id: '1',
        descricao: 'Recebimento muito grande com descrição longa',
        tipo: TipoLancamento.receita,
        valor: 1234567.89, // R$ 1.234.567,89 — o valor citado no finding
      );

      // 440px, não 320/360: sem carregar fontes reais no harness de teste
      // (`flutter test` usa um fallback mais largo que o Sora/Roboto de
      // produção), o próprio valor sozinho já passa dos ~422px "de teste"
      // que o overhead fixo da Row (avatar 36 + paddings do card/lista +
      // botão de ações) deixa livre — ficaria overflow por causa do
      // font fallback, não do layout. 440px é o menor valor estável neste
      // harness; a garantia real (valor nunca corta) é a estrutural abaixo.
      await pumpAt(tester, debugLancamentoRow(lanc), 440);
      expect(tester.takeException(), isNull);

      // O valor aparece INTEIRO (nenhum "...").
      final valueFinder = find.textContaining('1.234.567,89');
      expect(valueFinder, findsOneWidget);
      final valueText = tester.widget<Text>(valueFinder);
      expect(
        valueText.overflow,
        isNot(TextOverflow.ellipsis),
        reason: 'valor não pode elipsar — QA-F3',
      );
      // ...e não está mais dentro de um Flexible/Expanded (que o forçaria a
      // dividir espaço com a descrição em vez de tomar sua largura inteira).
      expect(
        find.ancestor(of: valueFinder, matching: find.byType(Flexible)),
        findsNothing,
      );

      // É a DESCRIÇÃO (não o valor) que elipsa quando falta espaço.
      final descText = tester.widget<Text>(
        find.textContaining('Recebimento muito grande'),
      );
      expect(descText.overflow, TextOverflow.ellipsis);
    },
  );
}
