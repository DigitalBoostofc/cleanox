import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanos/vitrine/widgets/vitrine_ui.dart';

void main() {
  const items = [
    VitrineCatItem(icon: Icons.weekend_outlined, label: 'Sofá'),
    VitrineCatItem(icon: Icons.bed_outlined, label: 'Colchão'),
    VitrineCatItem(icon: Icons.chair_outlined, label: 'Poltrona'),
    VitrineCatItem(icon: Icons.layers_outlined, label: 'Tapete'),
    VitrineCatItem(icon: Icons.directions_car_outlined, label: 'Automóvel'),
    VitrineCatItem(icon: Icons.auto_awesome, label: 'Impermeab.'),
    VitrineCatItem(icon: Icons.event_seat_outlined, label: 'Cadeira'),
    VitrineCatItem(icon: Icons.add, label: 'Mais'),
  ];

  Future<void> pumpGrid(WidgetTester tester, double width) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: VitrineCategoryGrid(items: items, onTap: (_) {}),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('categorias permanecem compactas no desktop', (tester) async {
    await pumpGrid(tester, 1100);

    final size = tester.getSize(find.byType(VitrineCategoryGrid));
    expect(size.height, lessThanOrEqualTo(120));
    expect(find.text('Sofá'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);
  });

  testWidgets('categorias mantêm quatro colunas no mobile', (tester) async {
    await pumpGrid(tester, 350);

    final first = tester.getTopLeft(find.text('Sofá'));
    final fifth = tester.getTopLeft(find.text('Automóvel'));
    expect(fifth.dy, greaterThan(first.dy));
    expect(
      tester.getSize(find.byType(VitrineCategoryGrid)).height,
      lessThan(210),
    );
  });

  testWidgets('conteúdo público fica centralizado e limitado no desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VitrineContentFrame(
            maxWidth: 1180,
            child: ColoredBox(key: Key('content'), color: Colors.cyan),
          ),
        ),
      ),
    );

    final content = tester.getRect(find.byKey(const Key('content')));
    expect(content.width, 1180);
    expect(content.center.dx, 720);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('content'))).width, 390);
  });

  testWidgets('hero sem foto ganha composição visual apenas no desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VitrineHeroCard(
            title: 'Agende seu serviço',
            subtitle: 'Escolha os serviços e agende.',
            cta: 'Agendar agora',
            onCta: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('vitrine-hero-art')), findsOneWidget);

    tester.view.physicalSize = const Size(850, 800);
    await tester.pump();
    expect(find.byKey(const Key('vitrine-hero-art')), findsNothing);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(find.byKey(const Key('vitrine-hero-art')), findsNothing);
  });

  testWidgets('topbar mantém wordmark legível no fundo claro', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VitrineLightTopBar()),
      ),
    );

    expect(find.text('CLEANOX', findRichText: true), findsOneWidget);
  });

  testWidgets('saudação não depende de fonte de emoji', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VitrineGreeting())),
    );

    expect(find.text('Olá'), findsOneWidget);
    expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
  });
}
