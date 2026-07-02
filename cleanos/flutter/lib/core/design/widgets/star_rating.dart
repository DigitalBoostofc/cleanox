import 'package:flutter/material.dart';

import '../cleanox_colors.dart';

/// Estrelas de avaliação (1–5). Somente leitura por padrão; passe [onChanged]
/// para torná-lo interativo (input). Suporta meia-estrela na exibição.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.max = 5,
    this.size = 20,
    this.color,
    this.onChanged,
  });

  final double value;
  final int max;
  final double size;
  final Color? color;

  /// Se fornecido, cada estrela vira alvo de toque (retorna 1..max).
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.clx.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final pos = i + 1;
        final IconData icon;
        if (value >= pos) {
          icon = Icons.star_rounded;
        } else if (value >= pos - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        final star = Icon(icon, size: size, color: c);
        if (onChanged == null) return star;
        return Semantics(
          button: true,
          label: '$pos de $max estrelas',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged!(pos),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: star,
            ),
          ),
        );
      }),
    );
  }
}
