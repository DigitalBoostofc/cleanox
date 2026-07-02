import 'package:flutter/material.dart';

import '../tokens.dart';

/// Chip/pílula colorida (grupos de serviço, tags). `color` é o texto/realce;
/// `background` default = color com 12% de opacidade.
class ClxChip extends StatelessWidget {
  const ClxChip({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? color.withValues(alpha: 0.12);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? ClxSpace.x2 : ClxSpace.x3,
        vertical: dense ? 2 : ClxSpace.x1,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: ClxRadii.rPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: ClxSpace.x1),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
