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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: clx.bg3.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 1 : 0.55),
        borderRadius: ClxRadii.rLg,
        border: Border.all(color: clx.line),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rLg,
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

/// Seletor de mês compacto (‹ Julho › ou chip dropdown).
class FinMonthBar extends StatelessWidget {
  const FinMonthBar({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.center = true,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final row = Row(
      mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment:
          center ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: onPrev,
          icon: Icon(Icons.chevron_left_rounded, color: clx.ink2),
        ),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: onNext,
          icon: Icon(Icons.chevron_right_rounded, color: clx.ink2),
        ),
      ],
    );
    return center ? Center(child: row) : row;
  }
}
