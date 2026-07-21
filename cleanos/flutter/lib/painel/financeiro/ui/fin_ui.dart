/// fin_ui.dart — Kit visual do Financeiro v2 (Cleanox, dark-friendly).
///
/// Cards, headers, KPIs e CTAs no estilo das referências Mobills, com tokens
/// Cleanox (`clx`) — sem roxo hardcoded.
library;

import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/formatters/formatters.dart';

/// Card padrão do dashboard (superfície elevada + padding).
class FinCard extends StatelessWidget {
  const FinCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ClxSpace.x4),
    this.onTap,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Sombra suave (mobile fintech).
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(elevated ? 20 : ClxRadii.lg);
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? clx.bg : clx.bg,
        borderRadius: radius,
        border: Border.all(color: clx.line.withValues(alpha: dark ? 0.9 : 1)),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: clx.ink.withValues(alpha: dark ? 0.22 : 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: body,
      ),
    );
  }
}

/// Título de seção + ação opcional à direita (dashboard v2).
class FinDashSectionHeader extends StatelessWidget {
  const FinDashSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailing,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: clx.ink2,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (trailing != null)
            InkWell(
              onTap: onTrailing,
              borderRadius: ClxRadii.rSm,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ClxSpace.x2,
                  vertical: ClxSpace.x1,
                ),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: clx.primary,
                        fontWeight: FontWeight.w700,
                      ),
                  child: trailing!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// KPI compacto (desktop row / mobile mini-card).
class FinKpiTile extends StatelessWidget {
  const FinKpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return FinCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x3,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: ClxSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: clx.ink3,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: valueColor ?? clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: clx.ink3, size: 20),
        ],
      ),
    );
  }
}

/// Empty state com CTA (planejamento / objetivos / favoritas).
class FinEmptyCta extends StatelessWidget {
  const FinEmptyCta({
    super.key,
    required this.message,
    this.hint,
    this.icon = Icons.inbox_outlined,
    this.ctaLabel,
    this.onCta,
  });

  final String message;
  final String? hint;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return FinCard(
      child: Column(
        children: [
          Icon(icon, size: 36, color: clx.ink3),
          const SizedBox(height: ClxSpace.x3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (hint != null) ...[
            const SizedBox(height: ClxSpace.x2),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: clx.ink3,
                  ),
            ),
          ],
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: ClxSpace.x4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCta,
                child: Text(ctaLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Valor monetário com cor semântica (receita / despesa / neutro).
class FinMoneyText extends StatelessWidget {
  const FinMoneyText(
    this.amount, {
    super.key,
    this.style,
    this.signed = false,
  });

  final double amount;
  final TextStyle? style;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final color = amount > 0
        ? clx.finIncome
        : amount < 0
            ? clx.finExpense
            : clx.ink;
    final text = signed && amount > 0
        ? '+${formatCurrency(amount)}'
        : formatCurrency(amount);
    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Seletor de mês compacto (‹ Julho ›). [pill] = estilo fintech mobile.
class FinMonthBar extends StatelessWidget {
  const FinMonthBar({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.center = true,
    this.pill = false,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool center;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final r = context.clxR;
    final row = Row(
      mainAxisSize: center || pill ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment:
          center || pill ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      children: [
        _MonthArrow(onTap: onPrev, icon: Icons.chevron_left_rounded),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.s(10)),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  fontSize: r.sp(14),
                ),
          ),
        ),
        _MonthArrow(onTap: onNext, icon: Icons.chevron_right_rounded),
      ],
    );

    if (!pill) {
      return center ? Center(child: row) : row;
    }

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(6), vertical: r.s(4)),
        decoration: BoxDecoration(
          color: clx.bg,
          borderRadius: ClxRadii.rPill,
          border: Border.all(color: clx.line),
          boxShadow: [
            BoxShadow(
              color: clx.ink.withValues(alpha: 0.05),
              blurRadius: r.s(10),
              offset: Offset(0, r.s(4)),
            ),
          ],
        ),
        child: row,
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.onTap, required this.icon});
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final r = context.clxR;
    final side = r.s(36).clamp(32.0, 44.0);
    return Material(
      color: clx.bg3.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: side,
          height: side,
          child: Icon(icon, color: clx.ink2, size: r.s(22)),
        ),
      ),
    );
  }
}
