/// fintech_balance_hero.dart — Hero de saldo estilo Easypay (gradiente + glow).
library;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// Card com gradiente petrol→teal e valor em destaque.
class FintechBalanceHero extends StatelessWidget {
  const FintechBalanceHero({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.icon = Icons.account_balance_wallet_outlined,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;

    return ClxFadeSlide(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x5,
          vertical: ClxSpace.x5,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              clx.accent,
              Color.lerp(clx.accent, clx.primary, 0.5)!,
              clx.primary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: clx.primary.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -36,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: ClxSpace.x1),
                    Text(
                      label.toUpperCase(),
                      style: tt.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ClxSpace.x1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.displayLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
