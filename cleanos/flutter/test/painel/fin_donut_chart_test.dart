/// fin_donut_chart_test.dart — QA-F7: no mobile (largura < 360, legenda
/// empilhada abaixo do donut), o donut renderizava colado à ESQUERDA do card
/// (feedback do dono, screenshot a 360dp) — o card usa `Column`
/// `crossAxisAlignment: start`, e o `FinDonutChart` não preenchia a largura
/// disponível, então shrink-wrapava no filho mais largo e ficava à esquerda.
/// Fix: `CrossAxisAlignment.stretch` + `Center` no donut; a legenda continua
/// alinhada à esquerda (ela já tem seu próprio `start`).
library;

import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/widgets/widgets.dart';
import 'package:cleanos/painel/financeiro/charts/fin_charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduz a moldura real do card (`ClxCard` com `Column` de
/// `crossAxisAlignment: start`, igual às `_GastosCard`/`_ReceitasCard` de
/// `fin_visao_geral_screen.dart`) — o bug só aparecia com ESTA moldura, não
/// com o `FinDonutChart` isolado num container qualquer.
Future<void> _pumpDonutInCard(
  WidgetTester tester,
  List<FinSlice> slices, {
  double width = 360,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: ClxCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Maiores gastos do mês'),
                  const SizedBox(height: 16),
                  FinDonutChart(slices: slices, centerLabel: 'Gastos'),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const _slices = [
  FinSlice(label: 'Limpeza', value: 300, color: Colors.teal),
  FinSlice(label: 'Manutenção', value: 150, color: Colors.orange),
  FinSlice(label: 'Outros', value: 50, color: Colors.grey),
];

void main() {
  testWidgets(
    'QA-F7: a 360x800, o center-x do donut == center-x do card',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpDonutInCard(tester, _slices);
      expect(tester.takeException(), isNull);

      final cardCenterX = tester.getCenter(find.byType(ClxCard)).dx;
      final donutCenterX = tester.getCenter(find.byType(PieChart)).dx;
      expect(donutCenterX, closeTo(cardCenterX, 2));
    },
  );

  testWidgets(
    'QA-F7: continua centralizado com uma 2ª lista de slices (receitas por origem)',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpDonutInCard(tester, const [
        FinSlice(label: 'Via OS', value: 500, color: Colors.teal),
        FinSlice(label: 'Avulso', value: 200, color: Colors.blue),
      ]);
      expect(tester.takeException(), isNull);

      final cardCenterX = tester.getCenter(find.byType(ClxCard)).dx;
      final donutCenterX = tester.getCenter(find.byType(PieChart)).dx;
      expect(donutCenterX, closeTo(cardCenterX, 2));
    },
  );

  testWidgets(
    'a legenda continua alinhada à esquerda (não centralizada junto)',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpDonutInCard(tester, _slices);

      final cardLeft = tester.getTopLeft(find.byType(ClxCard)).dx;
      final legendaLeft = tester.getTopLeft(find.text('Limpeza')).dx;
      // A legenda fica perto da borda esquerda do CONTEÚDO do card (só o
      // padding do ClxCard + o dot de cor + o gap separam), bem menos do que
      // ficaria se estivesse centralizada.
      expect(legendaLeft - cardLeft, lessThan(60));
    },
  );
}
