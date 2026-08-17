import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../vitrine_api.dart';
import 'vitrine_catalogo_personalizavel.dart';
import 'vitrine_oferta_estilo.dart';
import 'vitrine_servico_detalhes_sheet.dart';
import 'vitrine_ui.dart';

/// Serviços da faixa “Ofertas em destaque”: só estrela da categoria.
List<VitrineServico> ofertasDestaqueDaCategoria({
  required List<VitrineServico> catalogo,
  required String categoria,
  List<VitrineServico> fallback = const [],
  int max = 3,
}) {
  final want = categoria.trim().toLowerCase();
  bool sameCat(VitrineServico s) {
    final got = vitrineMacroCategoriaOf(
      categoria: s.categoria,
      grupo: s.grupo,
      nome: s.nome,
    );
    if (want.isEmpty) return true;
    return got == want;
  }

  final starred = catalogo.where((s) => s.vitrineDestaque && sameCat(s)).toList()
    ..sort((a, b) => a.vitrineOrdem.compareTo(b.vitrineOrdem));
  return starred.take(max).toList();
}

/// Faixa marketplace: carrossel com o próximo card asomando à direita.
class VitrineOfertasDestaque extends StatefulWidget {
  const VitrineOfertasDestaque({
    super.key,
    required this.servicos,
    required this.bootstrap,
    required this.titulo,
    required this.cta,
    required this.onVerTodas,
    required this.onTapServico,
    this.selectedIds = const {},
  });

  final List<VitrineServico> servicos;
  final VitrineBootstrap bootstrap;
  final String titulo;
  final String cta;
  final VoidCallback onVerTodas;
  final ValueChanged<VitrineServico> onTapServico;
  final Set<String> selectedIds;

  @override
  State<VitrineOfertasDestaque> createState() => _VitrineOfertasDestaqueState();
}

class _VitrineOfertasDestaqueState extends State<VitrineOfertasDestaque> {
  late final PageController _pages;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicos = widget.servicos;
    if (servicos.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('vitrine-ofertas-destaque'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: ClxBrand.cyan,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.titulo.trim().isEmpty
                    ? 'Ofertas em destaque'
                    : widget.titulo,
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ClxBrand.navy,
                ),
              ),
            ),
            TextButton(
              key: const Key('vitrine-ofertas-ver-todas'),
              onPressed: widget.onVerTodas,
              child: Text(
                widget.cta.trim().isEmpty || widget.cta.trim() == 'Ver todos'
                    ? 'Ver todas'
                    : widget.cta,
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w700,
                  color: ClxBrand.muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 248,
          child: PageView.builder(
            controller: _pages,
            padEnds: false,
            itemCount: servicos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final s = servicos[i];
              return Padding(
                padding: EdgeInsets.only(right: i == servicos.length - 1 ? 0 : 10),
                child: _HeroOfferCard(
                  servico: s,
                  capa: widget.bootstrap.capaDoServico(s.id),
                  selected: widget.selectedIds.contains(s.id),
                  onAdd: () => widget.onTapServico(s),
                  onDetalhes: () => showVitrineServicoDetalhes(
                    context,
                    servico: s,
                    media: widget.bootstrap.midiaDoServico(s.id),
                    selected: widget.selectedIds.contains(s.id),
                    onToggle: () => widget.onTapServico(s),
                  ),
                ),
              );
            },
          ),
        ),
        if (servicos.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < servicos.length; i++)
                Container(
                  width: i == _page ? 14 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _page
                        ? ClxBrand.cyan
                        : ClxBrand.navy.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeroOfferCard extends StatelessWidget {
  const _HeroOfferCard({
    required this.servico,
    required this.capa,
    required this.selected,
    required this.onAdd,
    required this.onDetalhes,
  });

  final VitrineServico servico;
  final VitrineMidia? capa;
  final bool selected;
  final VoidCallback onAdd;
  final VoidCallback onDetalhes;

  @override
  Widget build(BuildContext context) {
    final estilo = VitrineOfertaEstilo.fromMidia(capa);
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VitrineUi.rLg),
        child: VitrineOfertaCardVisual(
          key: Key('vitrine-oferta-hero-${servico.id}'),
          estilo: estilo,
          fotoUrl: capa?.url ?? '',
          titulo: servico.tituloComercial,
          preco: estilo.precoPorLabel(ofertaPrecoLabel(servico)),
          precoDe: estilo.precoDeLabel(ofertaPrecoDe(servico)),
          offPct: estilo.offPctLabel(ofertaOffPct(servico)),
          badge: estilo.badge.trim().isEmpty
              ? servico.vitrineBadge
              : estilo.badge,
          selected: selected,
          onAdd: onAdd,
          onDetalhes: onDetalhes,
        ),
      ),
    );
  }
}
