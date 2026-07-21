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
    final r = context.clxR;
    final tt = Theme.of(context).textTheme;

    return ClxFadeSlide(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(r.s(20), r.s(20), r.s(16), r.s(18)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.r(28)),
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
              blurRadius: r.s(32),
              offset: Offset(0, r.s(14)),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -r.s(28),
              top: -r.s(40),
              child: Container(
                width: r.s(150),
                height: r.s(150),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              right: r.s(36),
              bottom: -r.s(48),
              child: Container(
                width: r.s(100),
                height: r.s(100),
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
                      size: r.s(15),
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    SizedBox(width: r.s(8)),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        style: tt.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          fontSize: r.sp(11),
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                SizedBox(height: r.s(10)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.displayLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w800,
                    // sp() já inclui textScale; desliga scaler no Text para não
                    // dobrar (style.fontSize * textScaler).
                    fontSize: r.sp(34),
                    height: 1.05,
                  ),
                  textScaler: TextScaler.noScaling,
                ),
                if (hint != null) ...[
                  SizedBox(height: r.s(4)),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      fontSize: r.sp(12),
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
                ],
                if (footer != null) ...[
                  SizedBox(height: r.s(16)),
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
