/// Carrinho no cabeçalho navy (substitui o FAB da barra inferior).
library;

import 'package:cleanos/vitrine/widgets/vitrine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ícone do carrinho no hero abre o toque', (tester) async {
    var tapped = 0;
    final busca = TextEditingController();
    addTearDown(busca.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VitrineNavyBrowseHeader(
            veicular: true,
            controller: busca,
            onBack: () {},
            onSearch: (_) {},
            onClear: () {},
            onCart: () => tapped++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cart = find.byKey(const Key('vitrine-nav-agendar'));
    expect(cart, findsOneWidget);
    await tester.tap(cart);
    await tester.pump();
    expect(tapped, 1);
  });
}
