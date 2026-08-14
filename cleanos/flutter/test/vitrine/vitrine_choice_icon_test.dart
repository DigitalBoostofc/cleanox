import 'package:cleanos/vitrine/widgets/vitrine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapas de glifo representam categoria/grupo', () {
    expect(vitrineMacroGlyph('car'), VitrineChoiceGlyph.car);
    expect(vitrineMacroGlyph('cleaning'), VitrineChoiceGlyph.clean);
    expect(vitrineGrupoGlyph('sofa'), VitrineChoiceGlyph.sofa);
    expect(vitrineGrupoGlyph('colchao'), VitrineChoiceGlyph.bed);
    expect(vitrineGrupoGlyph('outros'), VitrineChoiceGlyph.more);
  });

  testWidgets('VitrineChoiceIcon pinta na paleta cyan', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: VitrineChoiceIcon(
              key: Key('choice-car'),
              glyph: VitrineChoiceGlyph.car,
              color: Color(0xFF0EA5B7),
              size: 40,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('choice-car')), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
