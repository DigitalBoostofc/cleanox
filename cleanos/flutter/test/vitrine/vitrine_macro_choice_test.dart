import 'package:cleanos/vitrine/widgets/vitrine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('macro: automotiva aparece primeiro por padrão', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VitrineMacroChoice(
            onResidencial: () {},
            onAutomotiva: () {},
          ),
        ),
      ),
    );

    final auto = tester.getTopLeft(
      find.byKey(const Key('vitrine-macro-automotiva')),
    );
    final resid = tester.getTopLeft(
      find.byKey(const Key('vitrine-macro-residencial')),
    );
    expect(auto.dy, lessThan(resid.dy));
    expect(find.text('Estética automotiva'), findsOneWidget);
    expect(find.text('Higienização residencial'), findsOneWidget);
    // Ícone default de limpeza no residencial
    expect(find.byIcon(Icons.cleaning_services_outlined), findsOneWidget);
    expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
  });

  testWidgets('macro: textos e ordem do CMS', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VitrineMacroChoice(
            autoPrimeiro: false,
            residencialTitulo: 'Casa limpa',
            residencialSubtitulo: 'Sofás e colchões',
            residencialIcone: 'sofa',
            automotivaTitulo: 'Carro brilhante',
            automotivaSubtitulo: 'Bancos e teto',
            automotivaIcone: 'garage',
            onResidencial: () {},
            onAutomotiva: () {},
          ),
        ),
      ),
    );

    expect(find.text('Casa limpa'), findsOneWidget);
    expect(find.text('Carro brilhante'), findsOneWidget);
    expect(find.byIcon(Icons.weekend_outlined), findsOneWidget);
    expect(find.byIcon(Icons.garage_outlined), findsOneWidget);

    final resid = tester.getTopLeft(
      find.byKey(const Key('vitrine-macro-residencial')),
    );
    final auto = tester.getTopLeft(
      find.byKey(const Key('vitrine-macro-automotiva')),
    );
    // side by side: resid first (left)
    expect(resid.dx, lessThan(auto.dx));
  });
}
