import 'package:cleanos/vitrine/vitrine_page_layout.dart';
import 'package:cleanos/vitrine/widgets/vitrine_page_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza somente seções visíveis na ordem publicada', (
    tester,
  ) async {
    final layout = VitrinePageLayout.defaults()
        .move(VitrineSectionId.howItWorks, 1)
        .update(VitrineSectionId.categories, visible: false);

    await tester.pumpWidget(
      MaterialApp(
        home: VitrinePageSections(
          layout: layout,
          builder: (_, section) => Text(section.id),
        ),
      ),
    );

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();
    expect(texts.first, VitrineSectionId.hero);
    expect(texts[1], VitrineSectionId.howItWorks);
    expect(texts, isNot(contains(VitrineSectionId.categories)));
    expect(texts, contains(VitrineSectionId.catalog));
  });
}
