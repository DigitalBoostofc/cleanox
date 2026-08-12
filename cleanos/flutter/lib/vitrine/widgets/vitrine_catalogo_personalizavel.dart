import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';

class VitrineCatalogoPersonalizavel extends StatefulWidget {
  const VitrineCatalogoPersonalizavel({
    required this.servicos,
    required this.bootstrap,
    required this.selectedIds,
    required this.onToggle,
    this.initialGroup,
    super.key,
  });

  final List<VitrineServico> servicos;
  final VitrineBootstrap bootstrap;
  final Set<String> selectedIds;
  final ValueChanged<VitrineServico> onToggle;
  final String? initialGroup;

  @override
  State<VitrineCatalogoPersonalizavel> createState() =>
      _VitrineCatalogoPersonalizavelState();
}

class _VitrineCatalogoPersonalizavelState
    extends State<VitrineCatalogoPersonalizavel> {
  String _query = '';
  late String _group;

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup ?? '';
  }

  @override
  void didUpdateWidget(covariant VitrineCatalogoPersonalizavel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialGroup != widget.initialGroup) {
      _group = widget.initialGroup ?? '';
    }
  }

  bool _matchesGroup(VitrineServico servico, String filter) {
    final needle = filter.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return servico.grupo.toLowerCase().contains(needle) ||
        servico.categoria.toLowerCase().contains(needle) ||
        servico.nome.toLowerCase().contains(needle) ||
        servico.tituloComercial.toLowerCase().contains(needle);
  }

  List<VitrineServico> get _filtered {
    final query = _query.trim().toLowerCase();
    final groupMatches = _group.isEmpty
        ? const <String>{}
        : {
            for (final servico in widget.servicos)
              if (_matchesGroup(servico, _group)) servico.id,
          };
    final applyGroup = _group.isNotEmpty && groupMatches.isNotEmpty;
    return [
      for (final servico in widget.servicos)
        if ((!applyGroup || groupMatches.contains(servico.id)) &&
            (query.isEmpty ||
                servico.tituloComercial.toLowerCase().contains(query) ||
                servico.descricaoComercial.toLowerCase().contains(query) ||
                servico.grupo.toLowerCase().contains(query)))
          servico,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String>[];
    for (final servico in widget.servicos) {
      final group = servico.grupo.trim();
      if (group.isNotEmpty && !groups.contains(group)) groups.add(group);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 680;
        final gap = mobile ? 12.0 : 18.0;
        final half = math.max(0, (constraints.maxWidth - gap) / 2).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CatalogHeader(onSearch: (value) => setState(() => _query = value)),
            if (groups.isNotEmpty) ...[
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _group.isEmpty,
                      onTap: () => setState(() => _group = ''),
                    ),
                    for (final group in groups) ...[
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: _groupLabel(group),
                        selected: _group == group,
                        onTap: () => setState(() => _group = group),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_filtered.isEmpty)
              const _EmptyCatalog()
            else
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final servico in _filtered)
                    SizedBox(
                      width:
                          mobile ||
                              servico.layout == VitrineServicoLayout.destaque ||
                              servico.layout == VitrineServicoLayout.antesDepois
                          ? constraints.maxWidth
                          : half,
                      child: _ServiceLayout(
                        servico: servico,
                        bootstrap: widget.bootstrap,
                        selected: widget.selectedIds.contains(servico.id),
                        mobile: mobile,
                        onToggle: () => widget.onToggle(servico),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ClxBrand.navy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 620;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SERVIÇOS CLEANOX',
                style: TextStyle(
                  color: ClxBrand.cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Encontre o cuidado certo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: narrow ? 25 : 32,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Cada serviço mostra o resultado do jeito que melhor explica o cuidado.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          );
          final search = TextField(
            key: const Key('vitrine-catalogo-busca'),
            onChanged: onSearch,
            style: const TextStyle(color: ClxBrand.navy),
            decoration: InputDecoration(
              hintText: 'Buscar serviço',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 18), search],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: title),
              const SizedBox(width: 36),
              Expanded(flex: 2, child: search),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: ClxBrand.navy,
      labelStyle: TextStyle(
        color: selected ? Colors.white : ClxBrand.navy,
        fontWeight: FontWeight.w700,
      ),
      side: const BorderSide(color: Color(0xFFDCE5EC)),
      backgroundColor: Colors.white,
      showCheckmark: false,
    );
  }
}

class _ServiceLayout extends StatelessWidget {
  const _ServiceLayout({
    required this.servico,
    required this.bootstrap,
    required this.selected,
    required this.mobile,
    required this.onToggle,
  });

  final VitrineServico servico;
  final VitrineBootstrap bootstrap;
  final bool selected;
  final bool mobile;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final gallery = bootstrap.midiaDoServico(servico.id);
    final openGallery = gallery.isEmpty
        ? null
        : () => showDialog<void>(
            context: context,
            builder: (_) =>
                _VitrineGalleryDialog(servico: servico, media: gallery),
          );
    return switch (servico.layout) {
      VitrineServicoLayout.destaque => _DestaqueCard(
        key: Key('vitrine-layout-destaque-${servico.id}'),
        servico: servico,
        media: bootstrap.capaDoServico(servico.id),
        galleryCount: gallery.length,
        onOpenGallery: openGallery,
        selected: selected,
        mobile: mobile,
        onToggle: onToggle,
      ),
      VitrineServicoLayout.fotografico => _FotograficoCard(
        key: Key('vitrine-layout-fotografico-${servico.id}'),
        servico: servico,
        media: bootstrap.capaDoServico(servico.id),
        galleryCount: gallery.length,
        onOpenGallery: openGallery,
        selected: selected,
        onToggle: onToggle,
      ),
      VitrineServicoLayout.antesDepois => _AntesDepoisCard(
        key: Key('vitrine-layout-antes_depois-${servico.id}'),
        servico: servico,
        before: _pair(bootstrap, servico.id).$1,
        after: _pair(bootstrap, servico.id).$2,
        galleryCount: gallery.length,
        onOpenGallery: openGallery,
        selected: selected,
        mobile: mobile,
        onToggle: onToggle,
      ),
      VitrineServicoLayout.compacto => _CompactoCard(
        key: Key('vitrine-layout-compacto-${servico.id}'),
        servico: servico,
        galleryCount: gallery.length,
        onOpenGallery: openGallery,
        selected: selected,
        onToggle: onToggle,
      ),
    };
  }

  (VitrineMidia?, VitrineMidia?) _pair(VitrineBootstrap bootstrap, String id) {
    final before = bootstrap.midiaDoServico(id, papel: 'antes');
    final after = bootstrap.midiaDoServico(id, papel: 'depois');
    if (before.isEmpty || after.isEmpty) {
      return (
        before.isEmpty ? null : before.first,
        after.isEmpty ? null : after.first,
      );
    }
    final first = before.first;
    final matching = after.where(
      (item) => first.parId.isNotEmpty && item.parId == first.parId,
    );
    return (first, matching.isEmpty ? after.first : matching.first);
  }
}

class _DestaqueCard extends StatelessWidget {
  const _DestaqueCard({
    required this.servico,
    required this.media,
    required this.galleryCount,
    required this.onOpenGallery,
    required this.selected,
    required this.mobile,
    required this.onToggle,
    super.key,
  });

  final VitrineServico servico;
  final VitrineMidia? media;
  final int galleryCount;
  final VoidCallback? onOpenGallery;
  final bool selected;
  final bool mobile;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final vertical = _useVerticalCommercialLayout(context, servico, mobile);
    final photo = _PhotoGalleryAction(
      serviceId: servico.id,
      count: galleryCount,
      onOpen: onOpenGallery,
      child: _ServicePhoto(media: media, icon: _groupIcon(servico.grupo)),
    );
    final content = _ServiceContent(
      servico: servico,
      selected: selected,
      onToggle: onToggle,
      prominent: true,
    );
    return _CardShell(
      selected: selected,
      child: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: mobile ? 230 : 300, child: photo),
                content,
              ],
            )
          : SizedBox(
              height: 330,
              child: Row(
                children: [
                  Expanded(flex: 6, child: photo),
                  Expanded(flex: 5, child: content),
                ],
              ),
            ),
    );
  }
}

bool _useVerticalCommercialLayout(
  BuildContext context,
  VitrineServico servico,
  bool mobile,
) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return mobile ||
      scale > 1.3 ||
      servico.tituloComercial.length > 70 ||
      servico.descricaoComercial.length > 180 ||
      servico.ctaComercial.length > 24;
}

class _FotograficoCard extends StatelessWidget {
  const _FotograficoCard({
    required this.servico,
    required this.media,
    required this.galleryCount,
    required this.onOpenGallery,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final VitrineServico servico;
  final VitrineMidia? media;
  final int galleryCount;
  final VoidCallback? onOpenGallery;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => _CardShell(
    selected: selected,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: _PhotoGalleryAction(
            serviceId: servico.id,
            count: galleryCount,
            onOpen: onOpenGallery,
            child: _ServicePhoto(media: media, icon: _groupIcon(servico.grupo)),
          ),
        ),
        _ServiceContent(
          servico: servico,
          selected: selected,
          onToggle: onToggle,
        ),
      ],
    ),
  );
}

class _AntesDepoisCard extends StatelessWidget {
  const _AntesDepoisCard({
    required this.servico,
    required this.before,
    required this.after,
    required this.galleryCount,
    required this.onOpenGallery,
    required this.selected,
    required this.mobile,
    required this.onToggle,
    super.key,
  });

  final VitrineServico servico;
  final VitrineMidia? before;
  final VitrineMidia? after;
  final int galleryCount;
  final VoidCallback? onOpenGallery;
  final bool selected;
  final bool mobile;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final vertical = _useVerticalCommercialLayout(context, servico, mobile);
    return _CardShell(
      selected: selected,
      child: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _comparison(height: mobile ? 230 : 300),
                _content(),
              ],
            )
          : SizedBox(
              height: 330,
              child: Row(
                children: [
                  Expanded(flex: 6, child: _comparison()),
                  Expanded(flex: 5, child: _content()),
                ],
              ),
            ),
    );
  }

  Widget _comparison({double? height}) => _PhotoGalleryAction(
    serviceId: servico.id,
    count: galleryCount,
    onOpen: onOpenGallery,
    child: SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: _LabeledPhoto(label: 'ANTES', media: before),
          ),
          Expanded(
            child: _LabeledPhoto(label: 'DEPOIS', media: after),
          ),
        ],
      ),
    ),
  );

  Widget _content() => _ServiceContent(
    servico: servico,
    selected: selected,
    onToggle: onToggle,
    prominent: true,
  );
}

class _CompactoCard extends StatelessWidget {
  const _CompactoCard({
    required this.servico,
    required this.galleryCount,
    required this.onOpenGallery,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final VitrineServico servico;
  final int galleryCount;
  final VoidCallback? onOpenGallery;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => _CardShell(
    selected: selected,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F6),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_groupIcon(servico.grupo), color: ClxBrand.cyan),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servico.tituloComercial,
                  style: const TextStyle(
                    color: ClxBrand.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_priceText(servico).isNotEmpty)
                  Text(
                    _priceText(servico),
                    style: const TextStyle(color: ClxBrand.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (onOpenGallery != null)
            IconButton(
              key: Key('vitrine-gallery-${servico.id}'),
              tooltip: galleryCount == 1
                  ? 'Ver foto'
                  : 'Ver $galleryCount fotos',
              onPressed: onOpenGallery,
              icon: const Icon(Icons.photo_library_outlined),
            ),
          IconButton.filled(
            key: Key('vitrine-add-${servico.id}'),
            tooltip: selected ? 'Remover' : servico.ctaComercial,
            onPressed: onToggle,
            icon: Icon(selected ? Icons.check : Icons.add),
          ),
        ],
      ),
    ),
  );
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.selected});

  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: selected ? ClxBrand.cyan : const Color(0xFFDCE5EC),
        width: selected ? 2 : 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x100B1D34),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

class _ServiceContent extends StatelessWidget {
  const _ServiceContent({
    required this.servico,
    required this.selected,
    required this.onToggle,
    this.prominent = false,
  });

  final VitrineServico servico;
  final bool selected;
  final VoidCallback onToggle;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(prominent ? 24 : 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: prominent
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (servico.vitrineBadge.trim().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              servico.vitrineBadge.trim().toUpperCase(),
              style: const TextStyle(
                color: ClxBrand.cyan,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          servico.tituloComercial,
          style: TextStyle(
            color: ClxBrand.navy,
            fontSize: prominent ? 25 : 19,
            height: 1.12,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (servico.descricaoComercial.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            servico.descricaoComercial,
            maxLines: prominent ? 4 : 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ClxBrand.muted, height: 1.45),
          ),
        ],
        const SizedBox(height: 16),
        _ServiceActions(
          servico: servico,
          selected: selected,
          onToggle: onToggle,
        ),
      ],
    ),
  );
}

class _ServiceActions extends StatelessWidget {
  const _ServiceActions({
    required this.servico,
    required this.selected,
    required this.onToggle,
  });

  final VitrineServico servico;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = selected ? 'Adicionado' : servico.ctaComercial;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 420 || scale > 1.3 || label.length > 24;
        final price = Text(
          _priceText(servico),
          style: const TextStyle(
            color: ClxBrand.navy,
            fontWeight: FontWeight.w800,
          ),
        );
        final button = FilledButton(
          key: Key('vitrine-add-${servico.id}'),
          onPressed: onToggle,
          child: Row(
            mainAxisSize: stacked ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? Icons.check : Icons.add),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_priceText(servico).isNotEmpty) price,
              if (_priceText(servico).isNotEmpty) const SizedBox(height: 12),
              button,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: price),
            const SizedBox(width: 12),
            Flexible(flex: 2, child: button),
          ],
        );
      },
    );
  }
}

class _ServicePhoto extends StatelessWidget {
  const _ServicePhoto({required this.media, required this.icon});

  final VitrineMidia? media;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (media == null || media!.url.isEmpty) return _PhotoFallback(icon: icon);
    return Image.network(
      media!.url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment(media!.alignmentX, media!.alignmentY),
      errorBuilder: (_, __, ___) => _PhotoFallback(icon: icon),
    );
  }
}

class _PhotoGalleryAction extends StatelessWidget {
  const _PhotoGalleryAction({
    required this.serviceId,
    required this.count,
    required this.onOpen,
    required this.child,
  });

  final String serviceId;
  final int count;
  final VoidCallback? onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onOpen == null) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          top: 12,
          right: 12,
          child: FilledButton.tonalIcon(
            key: Key('vitrine-gallery-$serviceId'),
            onPressed: onOpen,
            icon: const Icon(Icons.photo_library_outlined, size: 17),
            label: Text(count == 1 ? 'Ver foto' : '$count fotos'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .92),
              foregroundColor: ClxBrand.navy,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

class _VitrineGalleryDialog extends StatefulWidget {
  const _VitrineGalleryDialog({required this.servico, required this.media});

  final VitrineServico servico;
  final List<VitrineMidia> media;

  @override
  State<_VitrineGalleryDialog> createState() => _VitrineGalleryDialogState();
}

class _VitrineGalleryDialogState extends State<_VitrineGalleryDialog> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final target = (_index + delta).clamp(0, widget.media.length - 1).toInt();
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 600;
    return Dialog(
      insetPadding: EdgeInsets.all(mobile ? 12 : 40),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: math.min(size.height - (mobile ? 24 : 80), 720),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Galeria · ${widget.servico.tituloComercial}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ClxBrand.navy,
                        fontSize: mobile ? 18 : 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar galeria',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.media.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final item = widget.media[index];
                  return ColoredBox(
                    color: ClxBrand.navy,
                    child: Column(
                      children: [
                        Expanded(
                          child: SizedBox.expand(
                            child: _ServicePhoto(
                              media: item,
                              icon: _groupIcon(widget.servico.grupo),
                            ),
                          ),
                        ),
                        if (item.legenda.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                            child: Text(
                              item.legenda,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Foto anterior',
                    onPressed: _index == 0 ? null : () => _move(-1),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      '${_index + 1} de ${widget.media.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ClxBrand.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('vitrine-gallery-next'),
                    tooltip: 'Próxima foto',
                    onPressed: _index >= widget.media.length - 1
                        ? null
                        : () => _move(1),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledPhoto extends StatelessWidget {
  const _LabeledPhoto({required this.label, required this.media});

  final String label;
  final VitrineMidia? media;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _ServicePhoto(media: media, icon: Icons.auto_awesome),
      Positioned(
        left: 8,
        bottom: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: label == 'DEPOIS' ? ClxBrand.cyan : ClxBrand.navy,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ),
      ),
    ],
  );
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF102B48), ClxBrand.navy],
      ),
    ),
    child: Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Color(0x1FFFFFFF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 38),
      ),
    ),
  );
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDCE5EC)),
    ),
    child: const Column(
      children: [
        Icon(Icons.search_off, color: ClxBrand.cyan, size: 34),
        SizedBox(height: 10),
        Text(
          'Nenhum serviço encontrado',
          style: TextStyle(color: ClxBrand.navy, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

String _priceText(VitrineServico servico) => switch (servico.precoModo) {
  VitrinePrecoModo.valor => formatCurrency(servico.valorBase),
  VitrinePrecoModo.aPartirDe =>
    'A partir de ${formatCurrency(servico.valorBase)}',
  VitrinePrecoModo.sobAvaliacao => 'Sob avaliação',
  VitrinePrecoModo.ocultar => '',
};

String _groupLabel(String group) {
  final normalized = group.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'Outros';
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

IconData _groupIcon(String group) {
  final value = group.toLowerCase();
  if (value.contains('sofa')) return Icons.weekend_outlined;
  if (value.contains('colch')) return Icons.bed_outlined;
  if (value.contains('carro') || value.contains('auto')) {
    return Icons.directions_car_outlined;
  }
  if (value.contains('tapete')) return Icons.layers_outlined;
  if (value.contains('cadeira') || value.contains('poltrona')) {
    return Icons.chair_outlined;
  }
  return Icons.auto_awesome;
}
