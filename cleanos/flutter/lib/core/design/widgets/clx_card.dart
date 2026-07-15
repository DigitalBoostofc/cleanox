import 'package:flutter/material.dart';

import '../cleanox_colors.dart';
import '../motion.dart';
import '../tokens.dart';

/// Card base: superfície + borda sutil + raio xl + sombra leve.
/// Hover eleva no desktop ([ClxHoverLift]); toque usa ink.
class ClxCard extends StatelessWidget {
  const ClxCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(ClxSpace.x4),
    this.elevated = false,
    this.animateHover = true,
    this.fill = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Aplica sombra md (destaque).
  final bool elevated;

  /// Elevação no hover (web) — desligar em listas densas se precisar.
  final bool animateHover;

  /// Preenche a altura do pai (cards lado a lado com [IntrinsicHeight]).
  ///
  /// Usa [Container] + [Alignment.topLeft]: com altura frouxa (medição do
  /// IntrinsicHeight) o card dimensiona pelo conteúdo; com altura fixa
  /// (stretch do Row) o fundo estica e o conteúdo fica no topo.
  /// Nunca force `height: infinity` — isso zera/corta o layout no par.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    // Efeito “flutuando” no fundo: sombra em camadas + borda suave.
    final decoration = BoxDecoration(
      color: clx.bg,
      borderRadius: ClxRadii.rXl,
      border: Border.all(color: clx.line.withValues(alpha: 0.85)),
      boxShadow: elevated
          ? [
              ...ClxShadows.md,
              BoxShadow(
                color: clx.primary.withValues(alpha: 0.06),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: clx.ink.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
    );

    Widget card;
    if (onTap == null) {
      if (fill) {
        // Alinhamento no topo + largura total; altura vem do pai (stretch)
        // ou do filho (medição intrinsic) — sem SizedBox(height: infinity).
        card = Container(
          width: double.infinity,
          alignment: Alignment.topLeft,
          padding: padding,
          decoration: decoration,
          child: child,
        );
      } else {
        card = DecoratedBox(
          decoration: decoration,
          child: Padding(padding: padding, child: child),
        );
      }
    } else if (fill) {
      card = Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: ClxRadii.rXl,
            child: Container(
              width: double.infinity,
              alignment: Alignment.topLeft,
              padding: padding,
              child: child,
            ),
          ),
        ),
      );
    } else {
      card = Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: ClxRadii.rXl,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }

    if (!animateHover) return card;
    return ClxHoverLift(child: card);
  }
}
