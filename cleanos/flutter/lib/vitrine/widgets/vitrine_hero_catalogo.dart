import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Texto e posição do cabeçalho navy da estética automotiva.
class VitrineHeroCatalogo {
  const VitrineHeroCatalogo({
    this.titulo = defaultTitulo,
    this.destaque = defaultDestaque,
    this.x = 4,
    this.y = 12,
  });

  static const defaultTitulo = 'O que vamos fazer no seu carro hoje?';
  static const defaultDestaque = 'carro';

  final String titulo;
  final String destaque;
  final double x;
  final double y;

  factory VitrineHeroCatalogo.parse(Object? raw) {
    Map<String, dynamic>? m;
    if (raw is Map<String, dynamic>) {
      m = raw;
    } else if (raw is Map) {
      m = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) m = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    if (m == null) return const VitrineHeroCatalogo();
    return VitrineHeroCatalogo(
      titulo: '${m['t'] ?? m['titulo'] ?? defaultTitulo}'.trim().isEmpty
          ? defaultTitulo
          : '${m['t'] ?? m['titulo']}'.trim(),
      destaque: '${m['h'] ?? m['destaque'] ?? defaultDestaque}',
      x: _pct(m['x'], 4),
      y: _pct(m['y'], 12),
    );
  }

  Map<String, dynamic> toJson() => {
        't': titulo,
        'h': destaque,
        'x': x,
        'y': y,
      };

  String encode() => jsonEncode(toJson());

  VitrineHeroCatalogo copyWith({
    String? titulo,
    String? destaque,
    double? x,
    double? y,
  }) =>
      VitrineHeroCatalogo(
        titulo: titulo ?? this.titulo,
        destaque: destaque ?? this.destaque,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  static double _pct(Object? v, double fallback) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n == null) return fallback;
    return n.clamp(0, 92);
  }
}

InlineSpan vitrineHeroTituloSpan(
  VitrineHeroCatalogo hero, {
  required double fontSize,
}) {
  final style = TextStyle(
    color: Colors.white,
    fontFamily: kFontFamily,
    fontSize: fontSize,
    height: 1.12,
    fontWeight: FontWeight.w800,
  );
  final title = hero.titulo.trim().isEmpty
      ? VitrineHeroCatalogo.defaultTitulo
      : hero.titulo.trim();
  final hit = hero.destaque.trim();
  if (hit.isEmpty) return TextSpan(text: title, style: style);
  final i = title.toLowerCase().indexOf(hit.toLowerCase());
  if (i < 0) return TextSpan(text: title, style: style);
  return TextSpan(
    style: style,
    children: [
      TextSpan(text: title.substring(0, i)),
      TextSpan(
        text: title.substring(i, i + hit.length),
        style: const TextStyle(color: ClxBrand.cyan),
      ),
      TextSpan(text: title.substring(i + hit.length)),
    ],
  );
}

/// Área título + carro. Texto em % (x/y) para o dono posicionar.
class VitrineHeroCatalogoStage extends StatelessWidget {
  const VitrineHeroCatalogoStage({
    super.key,
    required this.hero,
    required this.height,
    this.editable = false,
    this.onMoved,
    this.fontSize = 22,
  });

  final VitrineHeroCatalogo hero;
  final double height;
  final bool editable;
  final ValueChanged<Offset>? onMoved;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final left = (w * hero.x / 100).clamp(0.0, w - 24);
          final top = (h * hero.y / 100).clamp(0.0, h - 24);
          final text = Text.rich(
            vitrineHeroTituloSpan(hero, fontSize: fontSize),
          );
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/vitrine/hero_carro_diagonal.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: w * 0.58,
                child: editable
                    ? GestureDetector(
                        onPanUpdate: (d) {
                          final nx = ((left + d.delta.dx) / w * 100).clamp(0, 80);
                          final ny = ((top + d.delta.dy) / h * 100).clamp(0, 80);
                          onMoved?.call(Offset(nx.toDouble(), ny.toDouble()));
                        },
                        child: text,
                      )
                    : IgnorePointer(child: text),
              ),
            ],
          );
        },
      ),
    );
  }
}
