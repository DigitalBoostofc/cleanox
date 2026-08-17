import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/formatters/formatters.dart';
import '../vitrine_api.dart';
import 'vitrine_ui.dart';

enum VitrineOfertaLayout { right, left, bottom, overlay }

enum VitrineOfertaNavy { solid, fade, glass }

class VitrineOfertaEstilo {
  const VitrineOfertaEstilo({
    this.layout = VitrineOfertaLayout.right,
    this.split = 0.48,
    this.zoom = 1,
    this.x = 50,
    this.y = 50,
    this.navy = VitrineOfertaNavy.solid,
    this.titulo = '',
    this.badge = '',
    this.showTitle = true,
    this.showPrice = true,
    this.showBadge = true,
    this.showDetalhe = true,
    this.showAdd = true,
    this.showDePor = false,
    this.deValor = 0,
    this.porValor = 0,
  });

  final VitrineOfertaLayout layout;
  final double split;
  final double zoom;
  final double x;
  final double y;
  final VitrineOfertaNavy navy;
  final String titulo;
  final String badge;
  final bool showTitle;
  final bool showPrice;
  final bool showBadge;
  final bool showDetalhe;
  final bool showAdd;
  final bool showDePor;
  final double deValor;
  final double porValor;

  Alignment get align => Alignment((x.clamp(0, 100) - 50) / 50, (y.clamp(0, 100) - 50) / 50);

  VitrineOfertaEstilo copyWith({
    VitrineOfertaLayout? layout,
    double? split,
    double? zoom,
    double? x,
    double? y,
    VitrineOfertaNavy? navy,
    String? titulo,
    String? badge,
    bool? showTitle,
    bool? showPrice,
    bool? showBadge,
    bool? showDetalhe,
    bool? showAdd,
    bool? showDePor,
    double? deValor,
    double? porValor,
  }) => VitrineOfertaEstilo(
    layout: layout ?? this.layout,
    split: split ?? this.split,
    zoom: zoom ?? this.zoom,
    x: x ?? this.x,
    y: y ?? this.y,
    navy: navy ?? this.navy,
    titulo: titulo ?? this.titulo,
    badge: badge ?? this.badge,
    showTitle: showTitle ?? this.showTitle,
    showPrice: showPrice ?? this.showPrice,
    showBadge: showBadge ?? this.showBadge,
    showDetalhe: showDetalhe ?? this.showDetalhe,
    showAdd: showAdd ?? this.showAdd,
    showDePor: showDePor ?? this.showDePor,
    deValor: deValor ?? this.deValor,
    porValor: porValor ?? this.porValor,
  );

  static final _cardRe = RegExp(r'\[\[card:(.*?)\]\]', dotAll: true);
  static final _tfRe = RegExp(r'\[\[tf:([-\d.]+),([-\d.]+)\]\]');

  static VitrineOfertaEstilo parse(String? focoX, String? focoY, String legenda) {
    final m = _cardRe.firstMatch(legenda);
    if (m != null) {
      try {
        final j = jsonDecode(m.group(1)!) as Map<String, dynamic>;
        return VitrineOfertaEstilo(
          layout: VitrineOfertaLayout.values.firstWhere(
            (e) => e.name == '${j['l']}',
            orElse: () => VitrineOfertaLayout.right,
          ),
          split: (j['s'] as num?)?.toDouble() ?? 0.48,
          zoom: (j['z'] as num?)?.toDouble() ?? 1,
          x: (j['x'] as num?)?.toDouble() ?? 50,
          y: (j['y'] as num?)?.toDouble() ?? 50,
          navy: VitrineOfertaNavy.values.firstWhere(
            (e) => e.name == '${j['n']}',
            orElse: () => VitrineOfertaNavy.solid,
          ),
          titulo: '${j['t'] ?? ''}',
          badge: '${j['b'] ?? ''}',
          showTitle: j['st'] != 0 && j['st'] != false,
          showPrice: j['sp'] != 0 && j['sp'] != false,
          showBadge: j['sb'] != 0 && j['sb'] != false,
          showDetalhe: j['sd'] != 0 && j['sd'] != false,
          showAdd: j['sa'] != 0 && j['sa'] != false,
          showDePor: j['dp'] == 1 || j['dp'] == true,
          deValor: (j['de'] as num?)?.toDouble() ?? 0,
          porValor: (j['po'] as num?)?.toDouble() ?? 0,
        );
      } catch (_) {}
    }
    final tf = _tfRe.firstMatch(legenda);
    return VitrineOfertaEstilo(
      zoom: double.tryParse(tf?.group(1) ?? '') ?? 1,
      x: double.tryParse(focoX ?? '') ?? 50,
      y: double.tryParse(focoY ?? '') ?? 50,
    );
  }

  static VitrineOfertaEstilo fromMidia(VitrineMidia? capa) {
    if (capa == null) return const VitrineOfertaEstilo();
    return parse('${capa.focoX}', '${capa.focoY}', capa.legenda);
  }

  String writeInto(String atual) {
    var clean = atual.replaceAll(_cardRe, '').replaceAll(_tfRe, '').trim();
    final tag = '[[card:${jsonEncode({
      'l': layout.name,
      's': double.parse(split.toStringAsFixed(2)),
      'z': double.parse(zoom.toStringAsFixed(2)),
      'x': double.parse(x.toStringAsFixed(1)),
      'y': double.parse(y.toStringAsFixed(1)),
      'n': navy.name,
      't': titulo,
      'b': badge,
      'st': showTitle ? 1 : 0,
      'sp': showPrice ? 1 : 0,
      'sb': showBadge ? 1 : 0,
      'sd': showDetalhe ? 1 : 0,
      'sa': showAdd ? 1 : 0,
      'dp': showDePor ? 1 : 0,
      'de': double.parse(deValor.toStringAsFixed(2)),
      'po': double.parse(porValor.toStringAsFixed(2)),
    })}]]';
    return clean.isEmpty ? tag : '$clean\n$tag';
  }

  String precoPorLabel(String fallback) =>
      porValor > 0 ? formatCurrency(porValor) : fallback;

  String? precoDeLabel(String? fallback) {
    if (!showDePor) return null;
    if (deValor > 0) return formatCurrency(deValor);
    return fallback;
  }

  int? offPctLabel(int? fallback) {
    if (!showDePor) return null;
    if (deValor > porValor && porValor > 0) {
      return (((deValor - porValor) / deValor) * 100).round();
    }
    return fallback;
  }
}

class VitrineOfertaCardVisual extends StatelessWidget {
  const VitrineOfertaCardVisual({
    super.key,
    required this.estilo,
    required this.fotoUrl,
    required this.titulo,
    required this.preco,
    this.precoDe,
    this.offPct,
    this.badge = '',
    this.selected = false,
    this.onAdd,
    this.onDetalhes,
    this.onPanPhoto,
  });

  final VitrineOfertaEstilo estilo;
  final String fotoUrl;
  final String titulo;
  final String preco;
  final String? precoDe;
  final int? offPct;
  final String badge;
  final bool selected;
  final VoidCallback? onAdd;
  final VoidCallback? onDetalhes;
  final void Function(Offset delta, Size box)? onPanPhoto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D34),
        borderRadius: BorderRadius.circular(VitrineUi.rLg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VitrineUi.rLg),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (estilo.layout == VitrineOfertaLayout.overlay ||
                    estilo.layout == VitrineOfertaLayout.bottom)
                  _foto(size)
                else if (estilo.layout == VitrineOfertaLayout.left)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: estilo.split.clamp(0.32, 0.7),
                      child: _foto(size, side: 'left'),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: estilo.split.clamp(0.32, 0.7),
                      child: _foto(size, side: 'right'),
                    ),
                  ),
                _navyLayer(),
                _textLayer(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _foto(Size box, {String side = 'full'}) {
    Widget photo = fotoUrl.isEmpty
        ? const ColoredBox(color: Color(0xFF16304F))
        : Image.network(
            fotoUrl,
            fit: BoxFit.cover,
            alignment: estilo.align,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF16304F)),
          );
    final z = estilo.zoom.clamp(0.8, 2.8);
    if (z != 1) {
      photo = Transform.scale(scale: z, child: photo);
    }
    photo = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanPhoto == null
          ? null
          : (d) => onPanPhoto!(d.delta, box),
      child: photo,
    );
    if (side == 'right') {
      return ClipPath(clipper: const _DiagClip(right: true), child: photo);
    }
    if (side == 'left') {
      return ClipPath(clipper: const _DiagClip(right: false), child: photo);
    }
    return photo;
  }

  Widget _navyLayer() {
    final color = const Color(0xFF0B1D34);
    switch (estilo.layout) {
      case VitrineOfertaLayout.overlay:
        return IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withValues(alpha: estilo.navy == VitrineOfertaNavy.glass ? 0.55 : 0.88),
                  color.withValues(alpha: 0.15),
                ],
              ),
            ),
          ),
        );
      case VitrineOfertaLayout.bottom:
        return Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.48,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    color.withValues(alpha: estilo.navy == VitrineOfertaNavy.glass ? 0.72 : 0.94),
                    color.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
        );
      case VitrineOfertaLayout.left:
      case VitrineOfertaLayout.right:
        if (estilo.navy == VitrineOfertaNavy.fade) {
          return IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: estilo.layout == VitrineOfertaLayout.right
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  end: estilo.layout == VitrineOfertaLayout.right
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  colors: [
                    color,
                    color.withValues(alpha: 0.85),
                    color.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.42, 0.72],
                ),
              ),
            ),
          );
        }
        if (estilo.navy == VitrineOfertaNavy.glass) {
          return IgnorePointer(
            child: Align(
              alignment: estilo.layout == VitrineOfertaLayout.right
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: (1 - estilo.split.clamp(0.32, 0.7) + 0.08).clamp(0.35, 0.75),
                child: ColoredBox(color: color.withValues(alpha: 0.72)),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }

  Widget _textLayer(BuildContext context) {
    final title = estilo.titulo.trim().isEmpty ? titulo : estilo.titulo.trim();
    final phone = VitrineUi.isPhone(context);
    final pad = switch (estilo.layout) {
      VitrineOfertaLayout.right => EdgeInsets.fromLTRB(phone ? 12 : 16, phone ? 10 : 14, phone ? 96 : 118, phone ? 10 : 14),
      VitrineOfertaLayout.left => EdgeInsets.fromLTRB(phone ? 96 : 118, phone ? 10 : 14, phone ? 12 : 16, phone ? 10 : 14),
      VitrineOfertaLayout.bottom => EdgeInsets.fromLTRB(phone ? 12 : 16, phone ? 10 : 14, phone ? 12 : 16, phone ? 10 : 14),
      VitrineOfertaLayout.overlay => EdgeInsets.fromLTRB(phone ? 12 : 16, phone ? 10 : 14, phone ? 12 : 16, phone ? 10 : 14),
    };
    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: estilo.layout == VitrineOfertaLayout.left
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (estilo.showBadge && badge.trim().isNotEmpty)
            _Pill(text: badge.trim().toUpperCase()),
          const Spacer(),
          if (estilo.showTitle)
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: estilo.layout == VitrineOfertaLayout.left
                  ? TextAlign.right
                  : TextAlign.left,
              style: TextStyle(
                fontFamily: kFontFamily,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: phone ? 15 : 18,
                height: 1.15,
              ),
            ),
          if (estilo.showPrice) ...[
            if (precoDe != null) ...[
              const SizedBox(height: 4),
              Text(
                'De $precoDe por',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.white54,
                ),
              ),
            ],
            Text(
              preco,
              style: TextStyle(
                fontFamily: kFontFamily,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: phone ? 18 : 22,
                height: 1.05,
              ),
            ),
            if (offPct != null) ...[
              const SizedBox(height: 6),
              _Pill(text: '$offPct% OFF', filled: true),
            ],
          ],
          if (estilo.showDetalhe) ...[
            SizedBox(height: phone ? 4 : 8),
            TextButton(
              onPressed: onDetalhes,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: ClxBrand.cyan,
              ),
              child: const Text(
                'Ver detalhes',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (estilo.showAdd) ...[
            SizedBox(height: phone ? 4 : 8),
            SizedBox(
              height: phone ? 28 : 34,
              child: FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: selected
                      ? const Color(0xFFDC2626)
                      : ClxBrand.cyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  selected ? 'Remover' : 'Adicionar',
                  style: const TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.filled = false});
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: filled ? null : Border.all(color: Colors.white70),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: filled ? ClxBrand.navy : Colors.white,
        ),
      ),
    );
  }
}

class _DiagClip extends CustomClipper<Path> {
  const _DiagClip({required this.right});
  final bool right;

  @override
  Path getClip(Size size) {
    if (right) {
      return Path()
        ..moveTo(size.width * 0.22, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.78, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _DiagClip old) => old.right != right;
}

String ofertaPrecoLabel(VitrineServico s) => formatCurrency(s.valorBase);

String? ofertaPrecoDe(VitrineServico s) =>
    s.valorBaseMax > s.valorBase ? formatCurrency(s.valorBaseMax) : null;

int? ofertaOffPct(VitrineServico s) {
  if (s.valorBaseMax <= s.valorBase || s.valorBaseMax <= 0) return null;
  final pct = (((s.valorBaseMax - s.valorBase) / s.valorBaseMax) * 100).round();
  return pct > 0 ? pct : null;
}
