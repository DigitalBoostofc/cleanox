/// Hit-area do FAB Agendar na bottom nav da Vitrine.
library;

import 'package:cleanos/vitrine/widgets/vitrine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FAB Agendar: toque no topo do círculo dispara onTap', (
    tester,
  ) async {
    var tapped = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: VitrineBottomNav(
            index: 0,
            onTap: (i) => tapped = i,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fab = find.byKey(const Key('vitrine-nav-agendar'));
    expect(fab, findsOneWidget);

    final box = tester.renderObject<RenderBox>(fab);
    final topLeft = box.localToGlobal(Offset.zero);
    // Ponto perto do topo do hit-box do FAB (antes só o miolo de baixo clicava).
    final topCenter = topLeft + Offset(box.size.width / 2, 8);
    await tester.tapAt(topCenter);
    await tester.pump();
    expect(tapped, 1, reason: 'topo do FAB deve chamar onTap(1)');

    tapped = -1;
    final center = topLeft + Offset(box.size.width / 2, box.size.height / 2);
    await tester.tapAt(center);
    await tester.pump();
    expect(tapped, 1, reason: 'centro do FAB deve chamar onTap(1)');
  });
}
