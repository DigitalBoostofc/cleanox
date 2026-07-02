/// fin_charts.dart — Gráficos do Financeiro em `fl_chart` (canvas, leve — nada
/// que injete HTML; mitigação Flutter Web §4).
///
/// [FinDonutChart] (donut com legenda) e [FinBarChart] (barras rotuladas). Cores
/// vêm da série do tema (`CleanoxColors.finSeries`) ou de cores explícitas, nunca
/// hardcoded. Estados vazios são responsabilidade da tela que os usa.
library;

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
                  style: TextStyle(
                    color: clx.ink3,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                formatCurrency(total),
                style: TextStyle(
                  color: clx.ink,
                  fontSize: 14,
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
                    style: TextStyle(color: clx.ink2, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: ClxSpace.x2),
                Text(
                  total > 0 ? '${(s.value / total * 100).round()}%' : '0%',
                  style: TextStyle(
                    color: clx.ink3,
                    fontSize: 12,
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

/* ─────────────────────── barras ─────────────────────── */

/// Barras verticais rotuladas (ex.: entradas × saídas, ou série mensal).
class FinBarChart extends StatelessWidget {
  const FinBarChart({super.key, required this.slices, this.height = 220});

  final List<FinSlice> slices;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
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
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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
                      style: TextStyle(color: clx.ink3, fontSize: 11),
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
