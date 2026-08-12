import 'package:cleanos/vitrine/widgets/vitrine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('light topbar and step header share logo size', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              VitrineLightTopBar(),
              VitrineLightStepHeader(stepLabel: '1 · Serviços'),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));

    final logos = t.widgetList<VitrineBrandLogo>(find.byType(VitrineBrandLogo));
    expect(logos.length, 2);

    final boxes =
        t.renderObjectList<RenderBox>(find.byType(VitrineBrandLogo)).toList();
    expect(boxes.length, 2);
    expect(boxes[0].size, equals(boxes[1].size));
    expect(boxes[0].size.height, VitrineUi.logoH);
    expect(boxes[0].size.width, VitrineUi.logoW);
  });
}
