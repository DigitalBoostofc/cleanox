/// clx_button_test.dart — F-700: o `ClxButton` (botão de bloco usado por todas
/// as telas, incl. o CTA "Entrar" do login) deve renderizar em formato PILL,
/// consistente com os button themes MD3 do ThemeData (StadiumBorder). O raio
/// arredonda totalmente as pontas → raio efetivo ≥ metade da altura mínima
/// (toque de 48dp), o que o antigo `ClxRadii.rMd` (=10px) NÃO satisfazia.
library;

import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/tokens.dart';
import 'package:cleanos/core/design/widgets/clx_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

/// Raio uniforme (px) da BoxDecoration do container interno do botão.
double _decorationRadius(WidgetTester tester) {
  final container = tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(ClxButton),
          matching: find.byType(Container),
        ),
      )
      .firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).borderRadius != null,
      );
  final radius = (container.decoration as BoxDecoration).borderRadius!
      .resolve(TextDirection.ltr);
  return radius.topLeft.x;
}

void main() {
  testWidgets('ClxButton renderiza como PILL — raio ≥ metade da altura mínima '
      '(48dp), não o rMd=10px', (tester) async {
    await _pump(tester, ClxButton(label: 'Entrar', onPressed: () {}));

    // Pill = pontas semicirculares: o raio arredonda a altura inteira do
    // toque mínimo (48dp). rPill=100 ≥ 24; o antigo rMd=10 falharia aqui.
    expect(
      _decorationRadius(tester),
      greaterThanOrEqualTo(ClxLayout.minTouchTarget / 2),
      reason: 'ClxButton deveria ser pill (StadiumBorder), não rMd=10px',
    );

    // Label continua visível e inteiro (o pill não corta o texto).
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('ClxButton full-width (expand) ocupa a largura e continua pill',
      (tester) async {
    await _pump(
      tester,
      const ClxButton(label: 'Entrar', expand: true, onPressed: null),
    );

    // expand:true → ocupa toda a largura disponível…
    expect(tester.getSize(find.byType(ClxButton)).width, 800);
    // …e as pontas seguem semicirculares (pill full-width MD3 correto).
    expect(
      _decorationRadius(tester),
      greaterThanOrEqualTo(ClxLayout.minTouchTarget / 2),
    );
    expect(find.text('Entrar'), findsOneWidget);
  });
}
