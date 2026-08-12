import 'package:cleanos/vitrine/widgets/vitrine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('macro choice mostra 2 cards grandes', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    var residencial = false;
    var automotiva = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VitrineMacroChoice(
            onResidencial: () => residencial = true,
            onAutomotiva: () => automotiva = true,
          ),
        ),
      ),
    );

    expect(find.text('O que você procura?'), findsNothing); // título fica na home
    expect(find.text('Higienização residencial'), findsOneWidget);
    expect(find.text('Estética automotiva'), findsOneWidget);
    expect(find.byKey(const Key('vitrine-macro-residencial')), findsOneWidget);
    expect(find.byKey(const Key('vitrine-macro-automotiva')), findsOneWidget);

    await tester.tap(find.byKey(const Key('vitrine-macro-residencial')));
    await tester.pump();
    expect(residencial, isTrue);

    await tester.tap(find.byKey(const Key('vitrine-macro-automotiva')));
    await tester.pump();
    expect(automotiva, isTrue);
  });
}
