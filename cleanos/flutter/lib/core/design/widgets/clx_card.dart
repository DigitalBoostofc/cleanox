import 'package:flutter/material.dart';

import '../cleanox_colors.dart';
import '../tokens.dart';

/// Card base do CleanOS: superfície + borda sutil + raio lg. Clicável opcional
/// (a linha/card de lista abre o modal de edição — convenção do web).
class ClxCard extends StatelessWidget {
  const ClxCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(ClxSpace.x4),
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Aplica sombra sm (destaque). Padrão é flat + borda.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final decoration = BoxDecoration(
      color: clx.bg,
      borderRadius: ClxRadii.rLg,
      border: Border.all(color: clx.line),
      boxShadow: elevated ? ClxShadows.sm : null,
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      );
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: ClxRadii.rLg,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
