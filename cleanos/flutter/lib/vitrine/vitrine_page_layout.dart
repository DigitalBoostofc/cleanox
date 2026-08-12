/// Modelo controlado do layout da página pública da Vitrine.
library;

abstract final class VitrineSectionId {
  static const hero = 'hero';
  static const categories = 'categories';
  static const featured = 'featured';
  static const catalog = 'catalog';
  static const howItWorks = 'how_it_works';
  static const cities = 'cities';
  static const payment = 'payment';
  static const finalCta = 'final_cta';

  static const all = <String>[
    hero,
    categories,
    featured,
    catalog,
    howItWorks,
    cities,
    payment,
    finalCta,
  ];

  static const required = <String>{hero, catalog};

  static List<VitrineSectionVariant> variantsFor(String id) => switch (id) {
    featured => VitrineSectionVariant.values,
    hero || finalCta => const [
      VitrineSectionVariant.standard,
      VitrineSectionVariant.compact,
      VitrineSectionVariant.impact,
    ],
    _ => const [VitrineSectionVariant.standard, VitrineSectionVariant.compact],
  };

  static VitrineSectionVariant normalizeVariant(
    String id,
    VitrineSectionVariant variant,
  ) => variantsFor(id).contains(variant)
      ? variant
      : VitrineSectionVariant.standard;

  static String label(String id) => switch (id) {
    hero => 'Capa principal',
    categories => 'Categorias',
    featured => 'Serviços em destaque',
    catalog => 'Catálogo',
    howItWorks => 'Como funciona',
    cities => 'Cidades atendidas',
    payment => 'Pagamento',
    finalCta => 'Chamada final',
    _ => id,
  };
}

enum VitrineSectionVariant {
  standard,
  compact,
  carousel,
  impact;

  static VitrineSectionVariant parse(Object? value) => switch ('$value') {
    'compact' => compact,
    'carousel' => carousel,
    'impact' => impact,
    _ => standard,
  };
}

class VitrinePageSection {
  const VitrinePageSection({
    required this.id,
    this.visible = true,
    this.variant = VitrineSectionVariant.standard,
  });

  final String id;
  final bool visible;
  final VitrineSectionVariant variant;

  VitrinePageSection copyWith({
    bool? visible,
    VitrineSectionVariant? variant,
  }) => VitrinePageSection(
    id: id,
    visible: VitrineSectionId.required.contains(id)
        ? true
        : visible ?? this.visible,
    variant: VitrineSectionId.normalizeVariant(id, variant ?? this.variant),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'visible': visible,
    'variant': variant.name,
  };
}

class VitrinePageLayout {
  const VitrinePageLayout(this.sections);

  final List<VitrinePageSection> sections;

  factory VitrinePageLayout.defaults() => VitrinePageLayout([
    for (final id in VitrineSectionId.all) VitrinePageSection(id: id),
  ]);

  factory VitrinePageLayout.fromJson(Map<String, dynamic>? json) {
    final raw = json?['sections'];
    if (raw is! List) return VitrinePageLayout.defaults();
    final seen = <String>{};
    final sections = <VitrinePageSection>[];
    for (final value in raw) {
      if (value is! Map) continue;
      final id = '${value['id'] ?? ''}';
      if (!VitrineSectionId.all.contains(id) || !seen.add(id)) continue;
      sections.add(
        VitrinePageSection(
          id: id,
          visible: VitrineSectionId.required.contains(id)
              ? true
              : value['visible'] != false,
          variant: VitrineSectionId.normalizeVariant(
            id,
            VitrineSectionVariant.parse(value['variant']),
          ),
        ),
      );
    }
    for (final id in VitrineSectionId.all) {
      if (seen.add(id)) sections.add(VitrinePageSection(id: id));
    }
    return VitrinePageLayout(sections);
  }

  VitrinePageSection? byId(String id) {
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  VitrinePageLayout move(String id, int index) {
    final next = [...sections];
    final current = next.indexWhere((section) => section.id == id);
    if (current < 0) return this;
    final item = next.removeAt(current);
    next.insert(index.clamp(0, next.length), item);
    return VitrinePageLayout(next);
  }

  VitrinePageLayout update(
    String id, {
    bool? visible,
    VitrineSectionVariant? variant,
  }) => VitrinePageLayout([
    for (final section in sections)
      if (section.id == id)
        section.copyWith(visible: visible, variant: variant)
      else
        section,
  ]);

  Map<String, dynamic> toJson() => {
    'v': 1,
    'sections': [for (final section in sections) section.toJson()],
  };
}
