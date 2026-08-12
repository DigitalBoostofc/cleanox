/// Editor visual isolado e preview responsivo do layout global da Vitrine.
library;

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../vitrine_page_layout.dart';

/// Editor controlado: o estado pertence ao chamador e toda alteração é emitida
/// por [onChanged]. Pode ser embutido no CMS sem depender de API ou Riverpod.
class VitrineLayoutEditor extends StatelessWidget {
  const VitrineLayoutEditor({
    super.key,
    required this.layout,
    required this.onChanged,
  });

  final VitrinePageLayout layout;
  final ValueChanged<VitrinePageLayout> onChanged;

  Future<void> _restoreDefaults(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar layout padrão?'),
        content: const Text(
          'A ordem, a visibilidade e as variantes das seções voltarão ao padrão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed == true) onChanged(VitrinePageLayout.defaults());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              const Text(
                'Seções da página',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ClxBrand.navy,
                ),
              ),
              TextButton.icon(
                onPressed: () => _restoreDefaults(context),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Restaurar padrão'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Arraste ou use as setas para organizar a página.',
            style: TextStyle(fontFamily: kFontFamily, color: ClxBrand.muted),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: layout.sections.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              onChanged(layout.move(layout.sections[oldIndex].id, newIndex));
            },
            itemBuilder: (context, index) => _SectionRow(
              key: ValueKey('vitrine-layout-row-${layout.sections[index].id}'),
              section: layout.sections[index],
              index: index,
              sectionCount: layout.sections.length,
              onMove: (newIndex) =>
                  onChanged(layout.move(layout.sections[index].id, newIndex)),
              onVisible: (visible) => onChanged(
                layout.update(layout.sections[index].id, visible: visible),
              ),
              onVariant: (variant) => onChanged(
                layout.update(layout.sections[index].id, variant: variant),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.section,
    required this.index,
    required this.sectionCount,
    required this.onMove,
    required this.onVisible,
    required this.onVariant,
  });

  final VitrinePageSection section;
  final int index;
  final int sectionCount;
  final ValueChanged<int> onMove;
  final ValueChanged<bool> onVisible;
  final ValueChanged<VitrineSectionVariant> onVariant;

  @override
  Widget build(BuildContext context) {
    final required = VitrineSectionId.required.contains(section.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: section.visible ? Colors.white : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final title = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    VitrineSectionId.label(section.id),
                    style: const TextStyle(
                      fontFamily: kFontFamily,
                      fontWeight: FontWeight.w700,
                      color: ClxBrand.navy,
                    ),
                  ),
                  if (required)
                    const Text(
                      'Sempre visível',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 11,
                        color: ClxBrand.muted,
                      ),
                    ),
                ],
              ),
            );
            final drag = ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: ClxBrand.muted,
                ),
              ),
            );
            final visibility = required
                ? const SizedBox.shrink()
                : Switch.adaptive(
                    key: ValueKey('visibility-${section.id}'),
                    value: section.visible,
                    onChanged: onVisible,
                  );
            final variant = DropdownButton<VitrineSectionVariant>(
              key: ValueKey('variant-${section.id}'),
              value: section.variant,
              isExpanded: constraints.maxWidth < 560,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value != null) onVariant(value);
              },
              items: [
                for (final item in VitrineSectionId.variantsFor(section.id))
                  DropdownMenuItem(
                    value: item,
                    child: Text(_variantLabel(item)),
                  ),
              ],
            );
            final arrows = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Mover para cima',
                  onPressed: index == 0 ? null : () => onMove(index - 1),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  tooltip: 'Mover para baixo',
                  onPressed: index == sectionCount - 1
                      ? null
                      : () => onMove(index + 1),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
              ],
            );
            if (constraints.maxWidth < 560) {
              return Column(
                children: [
                  Row(children: [drag, title, visibility]),
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Row(
                      children: [
                        Expanded(child: variant),
                        arrows,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(children: [drag, title, variant, visibility, arrows]);
          },
        ),
      ),
    );
  }
}

/// Preview global sem dependência dos widgets públicos concretos. Ele representa
/// ordem, visibilidade e densidade e permite validar o fluxo inteiro antes de
/// salvar. Em mobile as seções continuam sempre em uma coluna vertical segura.
class VitrineLayoutPreview extends StatefulWidget {
  const VitrineLayoutPreview({super.key, required this.layout});

  final VitrinePageLayout layout;

  @override
  State<VitrineLayoutPreview> createState() => _VitrineLayoutPreviewState();
}

class _VitrineLayoutPreviewState extends State<VitrineLayoutPreview> {
  bool _mobile = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.desktop_windows_rounded),
                label: Text('Desktop'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.phone_iphone_rounded),
                label: Text('Mobile'),
              ),
            ],
            selected: {_mobile},
            onSelectionChanged: (value) {
              setState(() => _mobile = value.first);
            },
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFE8EDF3),
            child: Center(
              child: AnimatedContainer(
                key: const ValueKey('preview-device'),
                duration: const Duration(milliseconds: 180),
                width: _mobile ? 358 : 960,
                constraints: BoxConstraints(
                  maxWidth: _mobile ? 358 : double.infinity,
                ),
                margin: const EdgeInsets.all(16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: ClxBrand.canvas,
                  borderRadius: BorderRadius.circular(_mobile ? 28 : 12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x260B1D34),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  key: ValueKey(_mobile ? 'preview-mobile' : 'preview-desktop'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final section in widget.layout.sections)
                        if (section.visible) _PreviewSection(section: section),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.section});

  final VitrinePageSection section;

  @override
  Widget build(BuildContext context) {
    final hero = section.id == VitrineSectionId.hero;
    final height = switch (section.variant) {
      VitrineSectionVariant.compact => 64.0,
      VitrineSectionVariant.carousel => 112.0,
      VitrineSectionVariant.impact => 144.0,
      VitrineSectionVariant.standard => hero ? 136.0 : 88.0,
    };
    return Container(
      key: ValueKey('preview-section-${section.id}'),
      height: height,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: hero
            ? const LinearGradient(colors: [ClxBrand.navy, ClxBrand.accent2])
            : null,
        color: hero ? null : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: hero ? null : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(
            _sectionIcon(section.id),
            color: hero ? Colors.white : ClxBrand.cyan,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              VitrineSectionId.label(section.id),
              style: TextStyle(
                fontFamily: kFontFamily,
                fontWeight: FontWeight.w800,
                color: hero ? Colors.white : ClxBrand.navy,
              ),
            ),
          ),
          Text(
            _variantLabel(section.variant),
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 11,
              color: hero ? Colors.white70 : ClxBrand.muted,
            ),
          ),
        ],
      ),
    );
  }
}

String _variantLabel(VitrineSectionVariant variant) => switch (variant) {
  VitrineSectionVariant.standard => 'Padrão',
  VitrineSectionVariant.compact => 'Compacta',
  VitrineSectionVariant.carousel => 'Carrossel',
  VitrineSectionVariant.impact => 'Impacto',
};

IconData _sectionIcon(String id) => switch (id) {
  VitrineSectionId.hero => Icons.auto_awesome_rounded,
  VitrineSectionId.categories => Icons.category_outlined,
  VitrineSectionId.featured => Icons.star_outline_rounded,
  VitrineSectionId.catalog => Icons.view_module_outlined,
  VitrineSectionId.howItWorks => Icons.route_outlined,
  VitrineSectionId.cities => Icons.location_city_outlined,
  VitrineSectionId.payment => Icons.payments_outlined,
  VitrineSectionId.finalCta => Icons.campaign_outlined,
  _ => Icons.web_asset_outlined,
};
