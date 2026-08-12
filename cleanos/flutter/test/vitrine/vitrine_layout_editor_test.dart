import 'package:cleanos/vitrine/admin/vitrine_layout_editor.dart';
import 'package:cleanos/vitrine/vitrine_page_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child, {Size size = const Size(1200, 900)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('controles reordenam e preservam layout controlado', (
    tester,
  ) async {
    var layout = VitrinePageLayout.defaults();

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => VitrineLayoutEditor(
            layout: layout,
            onChanged: (next) => setState(() => layout = next),
          ),
        ),
      ),
    );

    final categories = find.byKey(
      const ValueKey('vitrine-layout-row-categories'),
    );
    expect(categories, findsOneWidget);

    await tester.tap(
      find.descendant(
        of: categories,
        matching: find.byTooltip('Mover para cima'),
      ),
    );
    await tester.pump();

    expect(layout.sections.first.id, VitrineSectionId.categories);
    expect(layout.sections[1].id, VitrineSectionId.hero);
  });

  testWidgets('edita visibilidade e variante sem ocultar seções obrigatórias', (
    tester,
  ) async {
    var layout = VitrinePageLayout.defaults();

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => VitrineLayoutEditor(
            layout: layout,
            onChanged: (next) => setState(() => layout = next),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('visibility-hero')), findsNothing);
    expect(find.text('Sempre visível'), findsNWidgets(2));

    final cities = find.byKey(const ValueKey('vitrine-layout-row-cities'));
    await tester.tap(
      find.descendant(
        of: cities,
        matching: find.byKey(const ValueKey('visibility-cities')),
      ),
    );
    await tester.pump();
    expect(layout.byId(VitrineSectionId.cities)?.visible, isFalse);

    await tester.tap(
      find.descendant(
        of: cities,
        matching: find.byKey(const ValueKey('variant-cities')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compacta').last);
    await tester.pumpAndSettle();
    expect(
      layout.byId(VitrineSectionId.cities)?.variant,
      VitrineSectionVariant.compact,
    );
  });

  testWidgets('restaurar padrão pede confirmação e emite defaults', (
    tester,
  ) async {
    var layout = VitrinePageLayout.defaults()
        .move(VitrineSectionId.finalCta, 0)
        .update(VitrineSectionId.cities, visible: false);

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => VitrineLayoutEditor(
            layout: layout,
            onChanged: (next) => setState(() => layout = next),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Restaurar padrão'));
    await tester.pumpAndSettle();
    expect(find.text('Restaurar layout padrão?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Restaurar'));
    await tester.pumpAndSettle();

    expect(layout.toJson(), VitrinePageLayout.defaults().toJson());
  });

  testWidgets('editor mantém controles utilizáveis em largura mobile', (
    tester,
  ) async {
    var layout = VitrinePageLayout.defaults();

    await tester.pumpWidget(
      app(
        SizedBox(
          width: 390,
          child: StatefulBuilder(
            builder: (context, setState) => VitrineLayoutEditor(
              layout: layout,
              onChanged: (next) => setState(() => layout = next),
            ),
          ),
        ),
        size: const Size(390, 844),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('variant-hero')), findsOneWidget);
    expect(find.byTooltip('Mover para baixo'), findsWidgets);
  });

  testWidgets('editor não estoura em 390 px com texto 2x', (tester) async {
    var layout = VitrinePageLayout.defaults();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      app(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: StatefulBuilder(
            builder: (context, setState) => VitrineLayoutEditor(
              layout: layout,
              onChanged: (next) => setState(() => layout = next),
            ),
          ),
        ),
        size: const Size(390, 844),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Restaurar padrão'), findsOneWidget);
    final title = tester.getRect(find.text('Seções da página'));
    final restore = tester.getRect(find.text('Restaurar padrão'));
    expect(restore.right, lessThanOrEqualTo(390));
    expect(restore.top, greaterThanOrEqualTo(title.top));
  });

  testWidgets(
    'preview omite invisíveis e alterna desktop/mobile com ordem vertical',
    (tester) async {
      final layout = VitrinePageLayout.defaults()
          .move(VitrineSectionId.finalCta, 1)
          .update(VitrineSectionId.cities, visible: false)
          .update(
            VitrineSectionId.featured,
            variant: VitrineSectionVariant.carousel,
          );

      await tester.pumpWidget(app(VitrineLayoutPreview(layout: layout)));
      expect(find.byKey(const ValueKey('preview-desktop')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('preview-section-cities')),
        findsNothing,
      );
      expect(find.text('Carrossel'), findsOneWidget);

      final heroTop = tester
          .getTopLeft(find.byKey(const ValueKey('preview-section-hero')))
          .dy;
      final ctaTop = tester
          .getTopLeft(find.byKey(const ValueKey('preview-section-final_cta')))
          .dy;
      expect(heroTop, lessThan(ctaTop));

      await tester.tap(find.text('Mobile'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview-mobile')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('preview-device'))).width,
        lessThanOrEqualTo(390),
      );
    },
  );
}
