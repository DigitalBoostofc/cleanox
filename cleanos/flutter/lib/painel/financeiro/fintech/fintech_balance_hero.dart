/// fintech_balance_hero.dart — Hero de saldo estilo Easypay (gradiente + glow).
library;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// Card com gradiente navy→teal e valor em destaque.
///
/// [trailing] (ex.: botão olho) e [footer] (ex.: chips receita/despesa) ficam
/// dentro do card para a Carteira APK parecer um app de finanças de verdade.
class FintechBalanceHero extends StatelessWidget {
  const FintechBalanceHero({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.icon = Icons.account_balance_wallet_outlined,
    this.trailing,
    this.footer,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData icon;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;

    return ClxFadeSlide(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              clx.accent,
              Color.lerp(clx.accent, clx.primary, 0.55)!,
              clx.primary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: clx.primary.withValues(alpha: 0.32),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              right: 36,
              bottom: -48,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        style: tt.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.displayLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                    height: 1.05,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 16),
                  footer!,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
