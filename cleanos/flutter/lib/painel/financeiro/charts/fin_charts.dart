/// fin_charts.dart — Gráficos do Financeiro em `fl_chart` (canvas, leve — nada
/// que injete HTML; mitigação Flutter Web §4).
///
/// [FinDonutChart] (donut com legenda) e [FinBarChart] (barras rotuladas). Cores
/// vêm da série do tema (`CleanoxColors.finSeries`) ou de cores explícitas, nunca
/// hardcoded. Estados vazios são responsabilidade da tela que os usa.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/formatters/formatters.dart';

/// Uma fatia/barra: rótulo + valor (sempre ≥ 0) + cor.
class FinSlice {
  const FinSlice({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;
}

/// Distribui [n] cores da série do tema (cicla se precisar).
List<Color> finSeriesColors(BuildContext context, int n) {
  final series = context.clx.finSeries;
  return [for (var i = 0; i < n; i++) series[i % series.length]];
}

/* ─────────────────────── donut ─────────────────────── */

/// Donut com legenda lateral. Mostra o total no centro. Aceita ≥ 1 fatia com
/// valor > 0; a tela deve tratar o caso "tudo zero" com um estado vazio.
class FinDonutChart extends StatelessWidget {
  const FinDonutChart({
    super.key,
    required this.slices,
    this.centerLabel,
    this.size = 180,
  });

  final List<FinSlice> slices;

  /// Rótulo curto no centro (ex.: "Gastos"). O total é sempre exibido abaixo.
  final String? centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final positivas = slices.where((s) => s.value > 0).toList();
    final total = positivas.fold<double>(0, (a, s) => a + s.value);

    final chart = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: size * 0.28,
              startDegreeOffset: -90,
              sections: [
                for (final s in positivas)
                  PieChartSectionData(
                    value: s.value,
                    color: s.color,
                    radius: size * 0.20,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (centerLabel != null)
                Text(
                  centerLabel!,
                  style: tt.labelSmall?.copyWith(
                    color: clx.ink3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                formatCurrency(total),
                style: tt.bodyLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in positivas)
          Padding(
            padding: const EdgeInsets.only(bottom: ClxSpace.x2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: ClxRadii.rSm,
                  ),
                ),
                const SizedBox(width: ClxSpace.x2),
                Flexible(
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: clx.ink2),
                  ),
                ),
                const SizedBox(width: ClxSpace.x2),
                Text(
                  total > 0 ? '${(s.value / total * 100).round()}%' : '0%',
                  style: tt.labelMedium?.copyWith(
                    color: clx.ink3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        // Empilha em telas estreitas; lado a lado no desktop.
        if (c.maxWidth < 360) {
          return Column(
            children: [
              chart,
              const SizedBox(height: ClxSpace.x4),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: ClxSpace.x5),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

/* ─────────────────────── barras agrupadas (fluxo de caixa) ─────────────────────── */

/// Grupo (mês) do fluxo de caixa: receitas × despesas × lucro. Espelha `BarGroup`
/// de `components/BarChart.tsx`.
class FinBarGroup {
  const FinBarGroup({
    required this.label,
    required this.receitas,
    required this.despesas,
    this.lucro,
  });
  final String label;
  final double receitas;
  final double despesas;

  /// Lucro/prejuízo (pode ser negativo). Quando nulo, a série não é desenhada.
  final double? lucro;
}

/// Barras AGRUPADAS por período (receitas/despesas/lucro por mês), com baseline
/// no zero (suporta lucro negativo) e legenda embutida. Espelha o `BarChart` do
/// web. Cores da paleta de feedback do tema — nada hardcoded.
class FinGroupedBarChart extends StatelessWidget {
  const FinGroupedBarChart({super.key, required this.groups, this.height = 240});

  final List<FinBarGroup> groups;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final hasLucro = groups.any((g) => g.lucro != null);

    // Faixa de valores (inclui zero e negativos de lucro).
    var maxV = 0.0;
    var minV = 0.0;
    for (final g in groups) {
      maxV = [maxV, g.receitas, g.despesas, g.lucro ?? 0].reduce(math.max);
      minV = [minV, g.lucro ?? 0].reduce(math.min);
    }
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.2;
    final minY = minV < 0 ? minV * 1.2 : 0.0;

    BarChartRodData rod(double v, Color c) => BarChartRodData(
      toY: v,
      color: c,
      width: hasLucro ? 7 : 10,
      borderRadius: const BorderRadius.all(Radius.circular(2)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              minY: minY,
              groupsSpace: 14,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => clx.accent,
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    formatCurrency(rod.toY),
                    tt.labelMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= groups.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: ClxSpace.x1),
                        child: Text(
                          groups[i].label,
                          style: tt.labelSmall?.copyWith(color: clx.ink3),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: clx.line, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < groups.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      rod(groups[i].receitas, clx.finIncome),
                      rod(groups[i].despesas, clx.finExpense),
                      if (hasLucro) rod(groups[i].lucro ?? 0, clx.info),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ClxSpace.x3),
        Wrap(
          spacing: ClxSpace.x4,
          runSpacing: ClxSpace.x2,
          children: [
            _LegendDot(color: clx.finIncome, label: 'Receitas'),
            _LegendDot(color: clx.finExpense, label: 'Despesas'),
            if (hasLucro) _LegendDot(color: clx.info, label: 'Lucro / Prejuízo'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: ClxRadii.rSm),
        ),
        const SizedBox(width: ClxSpace.x2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: clx.ink2),
        ),
      ],
    );
  }
}

/* ─────────────────────── barras ─────────────────────── */

/// Barras verticais rotuladas (ex.: entradas × saídas, ou série mensal).
class FinBarChart extends StatelessWidget {
  const FinBarChart({super.key, required this.slices, this.height = 220});

  final List<FinSlice> slices;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final maxV = slices.fold<double>(0, (a, s) => s.value > a ? s.value : a);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.2;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => clx.accent,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                formatCurrency(rod.toY),
                tt.labelMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= slices.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: ClxSpace.x1),
                    child: Text(
                      slices[i].label,
                      style: tt.labelSmall?.copyWith(color: clx.ink3),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: clx.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < slices.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: slices[i].value,
                    color: slices[i].color,
                    width: 26,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(ClxRadii.sm),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
