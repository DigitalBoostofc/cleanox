import 'package:flutter/material.dart';

import '../cleanox_colors.dart';
import '../tokens.dart';
import 'spinner.dart';

/// Variantes visuais do botão.
enum ClxButtonVariant { primary, secondary, ghost, danger }

/// Botão base do CleanOS. Estados: normal / loading / disabled.
///
/// Toque mínimo 48dp (Android). Enquanto `loading`, fica desabilitado e mostra
/// spinner no lugar do conteúdo (largura preservada).
class ClxButton extends StatelessWidget {
  const ClxButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ClxButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ClxButtonVariant variant;
  final IconData? icon;
  final bool loading;

  /// Ocupa a largura total disponível.
  final bool expand;

  bool get _disabled => onPressed == null || loading;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final (bg, fg, border) = switch (variant) {
      ClxButtonVariant.primary => (clx.primary, clx.onPrimary, null),
      ClxButtonVariant.secondary => (clx.accent, Colors.white, null),
      ClxButtonVariant.ghost => (Colors.transparent, clx.ink2, clx.line2),
      ClxButtonVariant.danger => (clx.error, Colors.white, null),
    };

    final child = loading
        ? Spinner(size: 18, color: fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: ClxSpace.x2),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: fg),
                ),
              ),
            ],
          );

    return Opacity(
      opacity: _disabled && !loading ? 0.5 : 1,
      child: Semantics(
        button: true,
        enabled: !_disabled,
        label: label,
        child: Material(
          color: bg,
          borderRadius: ClxRadii.rPill,
          child: InkWell(
            onTap: _disabled ? null : onPressed,
            borderRadius: ClxRadii.rPill,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: ClxLayout.minTouchTarget,
              ),
              width: expand ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x5),
              decoration: BoxDecoration(
                borderRadius: ClxRadii.rPill,
                border: border == null ? null : Border.all(color: border),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
