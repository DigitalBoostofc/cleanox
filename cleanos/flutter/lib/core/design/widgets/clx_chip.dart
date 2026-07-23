import 'package:flutter/material.dart';

import '../tokens.dart';

/// Chip/pílula colorida (grupos de serviço, tags). `color` é o texto/realce;
/// `background` default = color com ~28% de opacidade + borda suave (contraste).
class ClxChip extends StatelessWidget {
  const ClxChip({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.icon,
    this.dense = false,
    this.bordered = true,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;
  final bool dense;

  /// Borda na cor da etiqueta (mais legível em fundo escuro/claro).
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? color.withValues(alpha: 0.28);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? ClxSpace.x2 : ClxSpace.x3,
        vertical: dense ? 3 : ClxSpace.x1 + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: ClxRadii.rPill,
        border: bordered
            ? Border.all(color: color.withValues(alpha: 0.55), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: ClxSpace.x1),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style:
                  (dense
                          ? Theme.of(context).textTheme.labelSmall
                          : Theme.of(context).textTheme.labelMedium)
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
