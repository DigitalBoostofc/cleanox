/// fin_kpi_card_test.dart — QA-F4: labels/hint de KPI truncavam a 360px
/// ("Entradas do ...", "Despesas realiza..."). Fix barato: maxLines:2 (em vez
/// de 1) no label e no hint, nas duas variantes (grade 2x2 e `wide`).
library;

import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/painel/financeiro/fin_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAt(WidgetTester tester, Widget child, double width) async {
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

void main() {
  testWidgets(
    'QA-F4: card 2x2 (não-wide) — label e hint aceitam 2 linhas, sem overflow a 360px',
    (tester) async {
      await _pumpAt(
        tester,
        const FinKpiCard(
          label: 'Entradas do mês',
          value: 'R\$ 0,00',
          color: Colors.green,
          hint: 'Receitas realizadas',
        ),
        170, // ~ metade de 360px (2 colunas), como na grade real
      );

      expect(tester.takeException(), isNull);
      final label = tester.widget<Text>(find.text('Entradas do mês'));
      expect(label.maxLines, 2);
      final hint = tester.widget<Text>(find.text('Receitas realizadas'));
      expect(hint.maxLines, 2);
    },
  );

  testWidgets(
    'QA-F4: variante wide — label e hint também aceitam 2 linhas',
    (tester) async {
      await _pumpAt(
        tester,
        const FinKpiCard(
          label: 'Saldo do mês bem mais longo que o normal',
          value: 'R\$ 0,00',
          color: Colors.green,
          hint: 'Disponível em contas',
          wide: true,
        ),
        360,
      );

      expect(tester.takeException(), isNull);
      final label = tester.widget<Text>(
        find.text('Saldo do mês bem mais longo que o normal'),
      );
      expect(label.maxLines, 2);
      final hint = tester.widget<Text>(find.text('Disponível em contas'));
      expect(hint.maxLines, 2);
    },
  );
}
