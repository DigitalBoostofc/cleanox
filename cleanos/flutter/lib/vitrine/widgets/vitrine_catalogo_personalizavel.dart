import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';

/// Intervalo do carrossel automático nas fotos do serviço (Vitrine).
const Duration kVitrineFotoCarouselInterval = Duration(seconds: 4);

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
    // Fotos só do cadastro do serviço (painel). Sem editor de mídia na Vitrine.
    final media = bootstrap.midiaDoServico(servico.id);
    return switch (servico.layout) {
      VitrineServicoLayout.destaque => _DestaqueCard(
        key: Key('vitrine-layout-destaque-${servico.id}'),
        servico: servico,
        media: media,
        selected: selected,
        mobile: mobile,
        onToggle: onToggle,
      ),
      VitrineServicoLayout.fotografico => _FotograficoCard(
        key: Key('vitrine-layout-fotografico-${servico.id}'),
        servico: servico,
        media: media,
        selected: selected,
        onToggle: onToggle,
      ),
      VitrineServicoLayout.antesDepois => _AntesDepoisCard(
        key: Key('vitrine-layout-antes_depois-${servico.id}'),
        servico: servico,
        before: _pair(bootstrap, servico.id).$1,
        after: _pair(bootstrap, servico.id).$2,
        media: media,
        selected: selected,
        mobile: mobile,
        onToggle: onToggle,
      ),
      VitrineServicoLayout.compacto => _CompactoCard(
        key: Key('vitrine-layout-compacto-${servico.id}'),
        servico: servico,
        media: media,
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
    required this.selected,
    required this.mobile,
    required this.onToggle,
    super.key,
  });

  final VitrineServico servico;
  final List<VitrineMidia> media;
  final bool selected;
  final bool mobile;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final vertical = _useVerticalCommercialLayout(context, servico, mobile);
    final photo = _ServicePhotoCarousel(
      media: media,
      icon: _groupIcon(servico.grupo),
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
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final VitrineServico servico;
  final List<VitrineMidia> media;
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
          child: _ServicePhotoCarousel(
            media: media,
            icon: _groupIcon(servico.grupo),
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
    required this.media,
    required this.selected,
    required this.mobile,
    required this.onToggle,
    super.key,
  });

  final VitrineServico servico;
  final VitrineMidia? before;
  final VitrineMidia? after;
  final List<VitrineMidia> media;
  final bool selected;
  final bool mobile;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final vertical = _useVerticalCommercialLayout(context, servico, mobile);
    final hasPair = before != null && after != null;
    final photo = hasPair
        ? _comparison(height: vertical ? (mobile ? 230.0 : 300.0) : null)
        : _ServicePhotoCarousel(
            media: media,
            icon: _groupIcon(servico.grupo),
          );
    return _CardShell(
      selected: selected,
      child: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasPair)
                  photo
                else
                  SizedBox(height: mobile ? 230 : 300, child: photo),
                _content(),
              ],
            )
          : SizedBox(
              height: 330,
              child: Row(
                children: [
                  Expanded(flex: 6, child: photo),
                  Expanded(flex: 5, child: _content()),
                ],
              ),
            ),
    );
  }

  Widget _comparison({double? height}) => SizedBox(
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
    required this.media,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final VitrineServico servico;
  final List<VitrineMidia> media;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => _CardShell(
    selected: selected,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 52,
              height: 52,
              child: media.isEmpty
                  ? Container(
                      color: const Color(0xFFE8F4F6),
                      child: Icon(
                        _groupIcon(servico.grupo),
                        color: ClxBrand.cyan,
                      ),
                    )
                  : _ServicePhotoCarousel(
                      media: media,
                      icon: _groupIcon(servico.grupo),
                      showDots: false,
                    ),
            ),
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
          FilledButton(
            key: Key('vitrine-add-${servico.id}'),
            style: FilledButton.styleFrom(
              backgroundColor:
                  selected ? const Color(0xFFDC2626) : ClxBrand.cyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: onToggle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? Icons.remove : Icons.add, size: 18),
                const SizedBox(width: 6),
                Text(selected ? 'Remover' : 'Adicionar'),
              ],
            ),
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
    final label = selected
        ? 'Remover'
        : (servico.ctaComercial.trim().isEmpty
              ? 'Adicionar'
              : servico.ctaComercial);
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
          style: FilledButton.styleFrom(
            backgroundColor:
                selected ? const Color(0xFFDC2626) : ClxBrand.cyan,
            foregroundColor: Colors.white,
          ),
          onPressed: onToggle,
          child: Row(
            mainAxisSize: stacked ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? Icons.remove : Icons.add),
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

/// Uma foto ou carrossel automático em loop contínuo (sempre desliza à esquerda).
class _ServicePhotoCarousel extends StatefulWidget {
  const _ServicePhotoCarousel({
    required this.media,
    required this.icon,
    this.showDots = true,
  });

  final List<VitrineMidia> media;
  final IconData icon;
  final bool showDots;

  @override
  State<_ServicePhotoCarousel> createState() => _ServicePhotoCarouselState();
}

class _ServicePhotoCarouselState extends State<_ServicePhotoCarousel> {
  /// Multiplicador grande: PageView infinito para o wrap última→primeira
  /// animar sempre "para a esquerda" (índice só sobe).
  static const int _loopBase = 1000;

  PageController? _controller;
  Timer? _timer;
  int _page = 0;

  int get _n => widget.media.length;

  int get _realIndex => _n == 0 ? 0 : _page % _n;

  int get _startPage => _n <= 1 ? 0 : _n * _loopBase;

  @override
  void initState() {
    super.initState();
    _bootstrapController();
  }

  void _bootstrapController() {
    _timer?.cancel();
    _controller?.dispose();
    _controller = null;
    if (_n <= 1) {
      _page = 0;
      return;
    }
    _page = _startPage;
    _controller = PageController(initialPage: _page);
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _ServicePhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.length != widget.media.length) {
      _bootstrapController();
      setState(() {});
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_n < 2) return;
    _timer = Timer.periodic(kVitrineFotoCarouselInterval, (_) {
      final c = _controller;
      if (!mounted || c == null || !c.hasClients) return;
      // Sempre +1: wrap visual via itemBuilder % n, sem voltar o PageView.
      c.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return _PhotoFallback(icon: widget.icon);
    }
    if (widget.media.length == 1) {
      return _ServicePhoto(media: widget.media.first, icon: widget.icon);
    }
    final controller = _controller;
    if (controller == null) {
      return _ServicePhoto(media: widget.media.first, icon: widget.icon);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller,
          // itemCount null = infinito → nextPage nunca “volta” na última.
          onPageChanged: (value) => setState(() => _page = value),
          itemBuilder: (context, index) => _ServicePhoto(
            media: widget.media[index % _n],
            icon: widget.icon,
          ),
        ),
        if (widget.showDots)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _n; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _realIndex ? 16 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _realIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
      ],
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
