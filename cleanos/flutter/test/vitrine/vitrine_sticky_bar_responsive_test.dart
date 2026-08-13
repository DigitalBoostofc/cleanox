import 'package:cleanos/vitrine/widgets/vitrine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sticky bar não estoura em largura de celular estreito', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: VitrineStickyBar(
              totalLabel: '1 item selecionado',
              totalCaption: 'Valor estimado',
              totalValue: 'R\$ 250,00',
              buttonLabel: 'Continuar',
              onPressed: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1 item selecionado'), findsOneWidget);
    expect(find.text('Valor estimado'), findsOneWidget);
    expect(find.text('R\$ 250,00'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);

    // Sem overflow RenderFlex.
    final overflows = tester
        .widgetList(find.byType(VitrineStickyBar))
        .toList();
    expect(overflows, isNotEmpty);
  });

  testWidgets('sticky bar respeita textScaler grande', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: VitrineStickyBar(
                totalLabel: '12 itens selecionados',
                totalCaption: 'Valor estimado',
                totalValue: 'R\$ 1.250,00',
                buttonLabel: 'Continuar',
                onPressed: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('R\$'), findsOneWidget);
  });
}
