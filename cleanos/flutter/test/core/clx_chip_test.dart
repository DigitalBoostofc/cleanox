/// clx_chip_test.dart — F-743: o `Row` interno do `ClxChip` (componente
/// compartilhado) não pode estourar quando o pai (ex.: uma célula do `Wrap`)
/// dá menos largura que a largura intrínseca de ícone+label. O label passa a
/// encolher com ellipsis em vez de gerar `RenderFlex overflowed`.
library;

import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/design/widgets/clx_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAt(WidgetTester tester, Widget child, double width) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('F-743: ClxChip com label longo em container estreito não '
      'estoura e elipsa', (tester) async {
    const longo =
        'Origem de campanha promocional de fim de ano muito comprida';
    // Célula bem estreita (simula o Wrap a ≤320px): menor que a largura
    // intrínseca de ícone+label.
    await _pumpAt(
      tester,
      const ClxChip(label: longo, color: Colors.teal, icon: Icons.campaign),
      120,
    );

    // Sem RenderFlex overflow.
    expect(tester.takeException(), isNull);

    // O label está protegido: encolhe com ellipsis.
    final text = tester.widget<Text>(find.text(longo));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(
      find.ancestor(of: find.text(longo), matching: find.byType(Flexible)),
      findsOneWidget,
    );
  });

  testWidgets('F-743: chip curto mantém aparência (não estica em espaço '
      'sobrando)', (tester) async {
    // Constraint FROUXA (Align, sem SizedBox apertado) → o chip sobra espaço.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ClxChip(label: 'Pix', color: Colors.teal),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // mainAxisSize.min preservado: o chip encolhe ao conteúdo, não à tela.
    final chipSize = tester.getSize(find.byType(ClxChip));
    expect(chipSize.width, lessThan(300));
  });
}
