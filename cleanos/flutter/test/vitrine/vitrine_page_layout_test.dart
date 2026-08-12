import 'package:cleanos/vitrine/vitrine_page_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VitrinePageLayout', () {
    test('fallback inclui todas as seções canônicas em ordem segura', () {
      final layout = VitrinePageLayout.fromJson(null);

      expect(layout.sections.map((item) => item.id), VitrineSectionId.all);
      expect(layout.sections.first.id, VitrineSectionId.hero);
      expect(layout.sections.first.visible, isTrue);
    });

    test('normaliza ids desconhecidos, duplicados e variantes inválidas', () {
      final layout = VitrinePageLayout.fromJson({
        'v': 1,
        'sections': [
          {'id': 'featured', 'visible': false, 'variant': 'compact'},
          {'id': 'featured', 'visible': true, 'variant': 'impact'},
          {'id': 'unknown', 'visible': true},
          {'id': 'hero', 'variant': 'quebrado'},
        ],
      });

      expect(
        layout.sections.map((item) => item.id).toSet(),
        VitrineSectionId.all.toSet(),
      );
      expect(layout.byId(VitrineSectionId.featured)?.visible, isFalse);
      expect(
        layout.byId(VitrineSectionId.hero)?.variant,
        VitrineSectionVariant.standard,
      );
    });

    test('reordena sem perder seções e permite ocultar bloco opcional', () {
      final initial = VitrinePageLayout.defaults();
      final moved = initial
          .move(VitrineSectionId.howItWorks, 1)
          .update(VitrineSectionId.cities, visible: false);

      expect(moved.sections[1].id, VitrineSectionId.howItWorks);
      expect(moved.byId(VitrineSectionId.cities)?.visible, isFalse);
      expect(moved.sections.length, VitrineSectionId.all.length);
    });

    test('hero e catálogo não podem ser ocultados', () {
      final layout = VitrinePageLayout.defaults()
          .update(VitrineSectionId.hero, visible: false)
          .update(VitrineSectionId.catalog, visible: false);

      expect(layout.byId(VitrineSectionId.hero)?.visible, isTrue);
      expect(layout.byId(VitrineSectionId.catalog)?.visible, isTrue);
    });

    test('serialização preserva ordem, visibilidade e variante', () {
      final original = VitrinePageLayout.defaults()
          .move(VitrineSectionId.finalCta, 2)
          .update(
            VitrineSectionId.featured,
            variant: VitrineSectionVariant.carousel,
          );

      final decoded = VitrinePageLayout.fromJson(original.toJson());

      expect(decoded.toJson(), original.toJson());
    });
  });
}
