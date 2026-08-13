import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';

/// Intervalo do carrossel automático nas fotos do serviço (Vitrine).
const Duration kVitrineFotoCarouselInterval = Duration(seconds: 4);

/// Normaliza texto para busca (minúsculas + sem acento).
String vitrineFoldBusca(String input) {
  const from =
      'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final b = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase();
}

/// Busca por **palavras** no nome (e título comercial).
/// Todas as palavras da query precisam aparecer no nome (ordem livre).
bool vitrineMatchesBuscaNome({
  required String nome,
  required String tituloComercial,
  required String query,
}) {
  final q = query.trim();
  if (q.isEmpty) return true;
  final hay = vitrineFoldBusca(
    '${nome.trim()} ${tituloComercial.trim()}'.trim(),
  );
  if (hay.isEmpty) return false;
  final tokens = vitrineFoldBusca(q)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty);
  for (final t in tokens) {
    if (!hay.contains(t)) return false;
  }
  return true;
}

/// Macro da vitrine a partir do cadastro do serviço.
String? vitrineMacroCategoriaOf({
  required String categoria,
  required String grupo,
  required String nome,
}) {
  final c = categoria.trim().toLowerCase();
  final g = grupo.trim().toLowerCase();
  final n = nome.trim().toLowerCase();
  if (c == 'veicular' ||
      c == 'automotiva' ||
      c == 'auto' ||
      c.contains('veic') ||
      c.contains('auto')) {
    return 'veicular';
  }
  if (c == 'residencial' ||
      c == 'residencia' ||
      c.contains('resid') ||
      c.contains('domic')) {
    return 'residencial';
  }
  if (g.contains('auto') ||
      g == 'plano' ||
      g == 'promocao' ||
      g == 'promoção' ||
      g == 'avulsos' ||
      g == 'adicional') {
    return 'veicular';
  }
  const fam = {
    'sofa',
    'sofá',
    'colchao',
    'colchão',
    'poltrona',
    'tapete',
    'cadeira',
    'cama',
  };
  if (fam.contains(g) || fam.any(g.contains)) return 'residencial';
  if (n.contains('cleanox') ||
      n.contains('banco') ||
      n.contains('veículo') ||
      n.contains('veiculo')) {
    return 'veicular';
  }
  if (n.contains('sofá') ||
      n.contains('sofa') ||
      n.contains('colch') ||
      n.contains('cama') ||
      n.contains('poltrona') ||
      n.contains('tapete')) {
    return 'residencial';
  }
  return null;
}

class VitrineCatalogoPersonalizavel extends StatefulWidget {
  const VitrineCatalogoPersonalizavel({
    required this.servicos,
    required this.bootstrap,
    required this.selectedIds,
    required this.onToggle,
    this.initialCategoria,
    this.initialGroup,
    this.initialQuery,
    this.showHeader = true,
    this.showCategoryChips = true,
    super.key,
  });

  final List<VitrineServico> servicos;
  final VitrineBootstrap bootstrap;
  final Set<String> selectedIds;
  final ValueChanged<VitrineServico> onToggle;

  /// Macro: `residencial` | `veicular` (categoria do serviço).
  final String? initialCategoria;

  /// Legado: grupo/família (não exibido; mantido só p/ deep-links antigos).
  final String? initialGroup;

  /// Texto inicial do campo “Buscar serviço” (ex.: home → catálogo).
  final String? initialQuery;

  /// Card navy “SERVIÇOS CLEANOX” + busca. Home pode omitir se o header for
  /// renderizado à parte.
  final bool showHeader;

  /// Chips só de categoria: Estética automotiva / Higienização residencial.
  /// (Sem chips de família sofa/colchão.)
  final bool showCategoryChips;

  @override
  State<VitrineCatalogoPersonalizavel> createState() =>
      _VitrineCatalogoPersonalizavelState();
}

class _VitrineCatalogoPersonalizavelState
    extends State<VitrineCatalogoPersonalizavel> {
  String _query = '';
  late String _categoria;
  late String _group;
  late final TextEditingController _buscaController;

  @override
  void initState() {
    super.initState();
    _categoria = (widget.initialCategoria ?? '').trim().toLowerCase();
    _group = (widget.initialGroup ?? '').trim().toLowerCase();
    _query = (widget.initialQuery ?? '').trim();
    _buscaController = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VitrineCatalogoPersonalizavel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategoria != widget.initialCategoria) {
      _categoria = (widget.initialCategoria ?? '').trim().toLowerCase();
    }
    if (oldWidget.initialGroup != widget.initialGroup) {
      _group = (widget.initialGroup ?? '').trim().toLowerCase();
    }
    if (oldWidget.initialQuery != widget.initialQuery) {
      final next = (widget.initialQuery ?? '').trim();
      if (next != _query) {
        _query = next;
        if (_buscaController.text != next) {
          _buscaController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      }
    }
  }

  bool _matchesCategoria(VitrineServico servico, String cat) {
    if (cat.isEmpty) return true;
    final want = cat.trim().toLowerCase();
    final c = servico.categoria.trim().toLowerCase();
    final g = servico.grupo.trim().toLowerCase();
    final nome = '${servico.nome} ${servico.tituloComercial}'.toLowerCase();

    if (c == want) return true;

    if (want == 'veicular' || want == 'automotiva' || want == 'auto') {
      if (c == 'veicular' ||
          c == 'automotiva' ||
          c == 'auto' ||
          c.contains('veic') ||
          c.contains('auto')) {
        return true;
      }
      // Nunca misturar residencial marcado.
      if (c == 'residencial' || c.contains('resid') || c.contains('domic')) {
        return false;
      }
      // Fallback só se categoria vazia: planos/avulsos automotivos + nomes típicos.
      if (c.isEmpty) {
        if (g == 'plano' ||
            g == 'promocao' ||
            g == 'promoção' ||
            g == 'avulsos' ||
            g == 'adicional' ||
            g.contains('auto')) {
          return true;
        }
        return nome.contains('veículo') ||
            nome.contains('veiculo') ||
            nome.contains('cleanox') ||
            nome.contains('banco') ||
            nome.contains('carpete') ||
            nome.contains('teto') ||
            nome.contains('cinto') ||
            nome.contains('painel') ||
            nome.contains('porta-malas');
      }
      return false;
    }

    if (want == 'residencial' || want == 'residencia') {
      if (c == 'residencial' ||
          c == 'residencia' ||
          c.contains('resid') ||
          c.contains('domic')) {
        return true;
      }
      if (c == 'veicular' ||
          c.contains('veic') ||
          c.contains('auto') ||
          c == 'automotiva') {
        return false;
      }
      const familias = {
        'sofa',
        'sofá',
        'colchao',
        'colchão',
        'poltrona',
        'tapete',
        'cadeira',
        'cama',
        'outros',
      };
      if (familias.contains(g) || familias.any(g.contains)) return true;
      if (c.isEmpty) {
        return nome.contains('sofá') ||
            nome.contains('sofa') ||
            nome.contains('colch') ||
            nome.contains('cama') ||
            nome.contains('poltrona') ||
            nome.contains('tapete') ||
            nome.contains('cadeira') ||
            nome.contains('puff');
      }
      return false;
    }

    return false;
  }

  bool _matchesFamilia(VitrineServico servico, String familia) {
    final needle = familia.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final g = servico.grupo.toLowerCase();
    final nome = servico.nome.toLowerCase();
    final titulo = servico.tituloComercial.toLowerCase();
    if (g == needle || g.contains(needle)) return true;
    // Prefixos comuns (auto → automotivo, imper → impermeabilização).
    return nome.contains(needle) || titulo.contains(needle);
  }

  List<VitrineServico> get _byCategoria => [
    for (final s in widget.servicos)
      if (_matchesCategoria(s, _categoria)) s,
  ];

  List<VitrineServico> get _filtered {
    final byFamily = [
      for (final servico in _byCategoria)
        if (_matchesFamilia(servico, _group)) servico,
    ];
    // Família sem match → não esvazia o catálogo (atalhos legados / typos).
    final base =
        (_group.isNotEmpty && byFamily.isEmpty) ? _byCategoria : byFamily;
    return [
      for (final servico in base)
        if (vitrineMatchesBuscaNome(
          nome: servico.nome,
          tituloComercial: servico.tituloComercial,
          query: _query,
        ))
          servico,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 680;
        final gap = mobile ? 12.0 : 18.0;
        final half = math.max(0, (constraints.maxWidth - gap) / 2).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader)
              _CatalogHeader(
                categoria: _categoria,
                controller: _buscaController,
                onSearch: (value) => setState(() => _query = value),
                onClearCategoria: _categoria.isEmpty
                    ? null
                    : () => setState(() {
                        _categoria = '';
                        _group = '';
                      }),
              ),
            if (widget.showCategoryChips) ...[
              SizedBox(height: widget.showHeader ? 14 : 0),
              SingleChildScrollView(
                key: const Key('vitrine-catalogo-category-chips'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      key: const Key('vitrine-chip-veicular'),
                      label: 'Estética automotiva',
                      selected: _categoria == 'veicular',
                      onTap: () => setState(() {
                        _categoria = 'veicular';
                        _group = '';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      key: const Key('vitrine-chip-residencial'),
                      label: 'Higienização residencial',
                      selected: _categoria == 'residencial',
                      onTap: () => setState(() {
                        _categoria = 'residencial';
                        _group = '';
                      }),
                    ),
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
  const _CatalogHeader({
    required this.onSearch,
    required this.categoria,
    required this.controller,
    this.onClearCategoria,
  });

  final ValueChanged<String> onSearch;
  final String categoria;
  final TextEditingController controller;
  final VoidCallback? onClearCategoria;

  @override
  Widget build(BuildContext context) {
    final macro = categoria == 'veicular'
        ? 'Estética automotiva'
        : categoria == 'residencial'
        ? 'Higienização residencial'
        : 'Todos os serviços';
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
                macro,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: narrow ? 22 : 28,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (categoria.isNotEmpty) ...[
                const SizedBox(height: 7),
                const Text(
                  'Filtre por família abaixo ou busque pelo nome do serviço.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
              if (onClearCategoria != null) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onClearCategoria,
                  style: TextButton.styleFrom(
                    foregroundColor: ClxBrand.cyan,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Ver todas as categorias'),
                ),
              ],
            ],
          );
          final search = TextField(
            key: const Key('vitrine-catalogo-busca'),
            controller: controller,
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: ClxBrand.navy),
            decoration: InputDecoration(
              hintText: 'Buscar serviço',
              helperText: 'Busca palavras do nome do serviço',
              helperStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search, color: ClxBrand.cyan),
              suffixIcon: controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        controller.clear();
                        onSearch('');
                      },
                      icon: const Icon(Icons.close, color: ClxBrand.muted),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 16), search],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 20),
              SizedBox(width: 280, child: search),
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
    super.key,
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
