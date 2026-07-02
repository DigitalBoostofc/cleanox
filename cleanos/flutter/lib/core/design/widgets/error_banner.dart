import 'package:flutter/material.dart';

import '../cleanox_colors.dart';
import '../tokens.dart';
import 'clx_button.dart';

/// Banner de erro com retry (estratégia "online-first com estados graciosos"
/// do blueprint §5). Use para falhas de rede/permissão nas listas.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.all(ClxSpace.x4),
      decoration: BoxDecoration(
        color: clx.errorBg,
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.error_outline_rounded, color: clx.error, size: 22),
          const SizedBox(width: ClxSpace.x3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: clx.ink2, fontSize: 14),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: ClxSpace.x3),
            ClxButton(
              label: 'Tentar de novo',
              variant: ClxButtonVariant.ghost,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
