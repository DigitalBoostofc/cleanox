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
    this.id,
  });
  final String label;
  final double value;
  final Color color;

  /// Id opcional (ex.: categoria) para callback de clique.
  final String? id;
}

/// Distribui [n] cores da série do tema (cicla se precisar).
List<Color> finSeriesColors(BuildContext context, int n) {
  final series = context.clx.finSeries;
  return [for (var i = 0; i < n; i++) series[i % series.length]];
}

/* ─────────────────────── donut ─────────────────────── */

/// Donut com legenda opcional, animação de entrada, hover (destaca fatia +
/// detalhe no centro) e clique ([onSectionTap]).
///
/// Aceita ≥ 1 fatia com valor > 0; a tela trata o caso "tudo zero".
class FinDonutChart extends StatefulWidget {
  const FinDonutChart({
    super.key,
    required this.slices,
    this.centerLabel,
    this.size = 180,
    this.showLegend = true,
    this.interactive = true,
    this.onSectionTap,
  });

  final List<FinSlice> slices;

  /// Rótulo curto no centro quando nada está em hover (ex.: "Despesas").
  final String? centerLabel;
  final double size;

  /// Legenda lateral / abaixo. Em Relatórios fica `false` (lista já é a legenda).
  final bool showLegend;

  /// Hover/toque destaca a fatia e mostra nome, valor e % no centro.
  final bool interactive;

  /// Clique na fatia (índice em [slices] com value > 0, mesma ordem).
  final ValueChanged<FinSlice>? onSectionTap;

  @override
  State<FinDonutChart> createState() => _FinDonutChartState();
}

class _FinDonutChartState extends State<FinDonutChart> {
  int _touched = -1;

  List<FinSlice> get _positivas =>
      widget.slices.where((s) => s.value > 0).toList();

  double get _total => _positivas.fold<double>(0, (a, s) => a + s.value);

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final positivas = _positivas;
    final total = _total;
    final touched =
        _touched >= 0 && _touched < positivas.length ? _touched : -1;
    final touchSlice = touched >= 0 ? positivas[touched] : null;

    final chart = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: ClxMotion.emphasizedDuration,
            curve: ClxMotion.emphasized,
            builder: (context, t, _) {
              final baseR = widget.size * 0.20 * (0.55 + 0.45 * t);
              final hotR = widget.size * 0.24 * (0.55 + 0.45 * t);
              return PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: widget.size * 0.28,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    enabled: widget.interactive,
                    touchCallback: (event, response) {
                      if (!widget.interactive) return;
                      final idx =
                          response?.touchedSection?.touchedSectionIndex ?? -1;
                      final valid = idx >= 0 && idx < positivas.length;
                      if (event is FlTapUpEvent && valid) {
                        widget.onSectionTap?.call(positivas[idx]);
                      }
                      final next = (!event.isInterestedForInteractions ||
                              !valid)
                          ? -1
                          : idx;
                      if (next != _touched) {
                        setState(() => _touched = next);
                      }
                    },
                  ),
                  sections: [
                    for (var i = 0; i < positivas.length; i++)
                      PieChartSectionData(
                        value: positivas[i].value,
                        color: positivas[i].color,
                        radius: i == touched ? hotR : baseR,
                        showTitle: false,
                        borderSide: i == touched
                            ? BorderSide(
                                color: clx.bg.withValues(alpha: 0.9),
                                width: 2,
                              )
                            : BorderSide.none,
                      ),
                  ],
                ),
                duration: ClxMotion.shortDuration,
                curve: ClxMotion.standard,
              );
            },
          ),
          // Centro: total ou detalhe da fatia em hover.
          IgnorePointer(
            child: AnimatedSwitcher(
              duration: ClxMotion.shortDuration,
              switchInCurve: ClxMotion.emphasized,
              switchOutCurve: Curves.easeIn,
              child: touchSlice == null
                  ? _CenterTotal(
                      key: const ValueKey('total'),
                      label: widget.centerLabel,
                      total: total,
                    )
                  : _CenterDetail(
                      key: ValueKey('d-$touched'),
                      slice: touchSlice,
                      total: total,
                    ),
            ),
          ),
        ],
      ),
    );

    if (!widget.showLegend) {
      return Center(child: chart);
    }

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < positivas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: ClxSpace.x2),
            child: MouseRegion(
              onEnter: widget.interactive
                  ? (_) => setState(() => _touched = i)
                  : null,
              onExit: widget.interactive
                  ? (_) => setState(() => _touched = -1)
                  : null,
              child: GestureDetector(
                onTap: () => widget.onSectionTap?.call(positivas[i]),
                child: Opacity(
                  opacity: touched < 0 || touched == i ? 1 : 0.45,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: positivas[i].color,
                          borderRadius: ClxRadii.rSm,
                        ),
                      ),
                      const SizedBox(width: ClxSpace.x2),
                      Flexible(
                        child: Text(
                          positivas[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(color: clx.ink2),
                        ),
                      ),
                      const SizedBox(width: ClxSpace.x2),
                      Text(
                        total > 0
                            ? '${(positivas[i].value / total * 100).round()}%'
                            : '0%',
                        style: tt.labelMedium?.copyWith(
                          color: clx.ink3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    // LayoutBuilder OK aqui — não combinar com IntrinsicHeight no pai
    // (IntrinsicHeight não mede LayoutBuilder).
    return LayoutBuilder(
      builder: (context, c) {
        // Empilha em telas estreitas; lado a lado no desktop.
        if (c.maxWidth < 360) {
          // QA-F7: stretch + Center evita donut colado à esquerda do card.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: chart),
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

class _CenterTotal extends StatelessWidget {
  const _CenterTotal({super.key, this.label, required this.total});

  final String? label;
  final double total;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label!,
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
    );
  }
}

class _CenterDetail extends StatelessWidget {
  const _CenterDetail({super.key, required this.slice, required this.total});

  final FinSlice slice;
  final double total;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final pct = total > 0 ? slice.value / total * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slice.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: tt.labelMedium?.copyWith(
              color: slice.color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatCurrency(slice.value),
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            '${pct.toStringAsFixed(1).replaceAll('.', ',')}%',
            style: tt.labelSmall?.copyWith(
              color: clx.ink3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── entradas × saídas (Organizze) ─────────────────────── */

/// Um bucket do relatório Entradas × Saídas (dia / semana / mês / acumulado).
class FinFluxoBucket {
  const FinFluxoBucket({
    required this.label,
    required this.entradas,
    required this.saidas,
    required this.resultado,
    required this.saldo,
  });

  final String label;
  final double entradas;
  final double saidas;
  final double resultado;

  /// Saldo acumulado até este bucket (soma dos resultados).
  final double saldo;
}

/// Gráfico Organizze: barras Entradas (verde) + Saídas (vermelho) e linha Saldo.
class FinEntradasSaidasChart extends StatefulWidget {
  const FinEntradasSaidasChart({
    super.key,
    required this.buckets,
    this.height = 280,
  });

  final List<FinFluxoBucket> buckets;
  final double height;

  @override
  State<FinEntradasSaidasChart> createState() => _FinEntradasSaidasChartState();
}

class _FinEntradasSaidasChartState extends State<FinEntradasSaidasChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final buckets = widget.buckets;
    if (buckets.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Sem movimentação no período.',
            style: tt.bodyMedium?.copyWith(color: clx.ink3),
          ),
        ),
      );
    }

    var maxV = 0.0;
    var minV = 0.0;
    for (final b in buckets) {
      maxV = math.max(maxV, math.max(b.entradas, b.saidas));
      maxV = math.max(maxV, b.saldo);
      minV = math.min(minV, b.saldo);
      minV = math.min(minV, 0);
    }
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.15;
    final minY = minV < 0 ? minV * 1.15 : 0.0;
    final saldoColor = clx.info.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: ClxSpace.x4,
            children: [
              _LegendDot(color: clx.finIncome, label: 'Entradas'),
              _LegendDot(color: clx.finExpense, label: 'Saídas'),
              _LegendDot(color: saldoColor, label: 'Saldo'),
            ],
          ),
        ),
        const SizedBox(height: ClxSpace.x3),
        SizedBox(
          height: widget.height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: ClxMotion.emphasizedDuration,
            curve: ClxMotion.emphasized,
            builder: (context, t, _) {
              return Stack(
                children: [
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      minY: minY,
                      groupsSpace: 12,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          final idx =
                              response?.spot?.touchedBarGroupIndex ?? -1;
                          final valid = idx >= 0 && idx < buckets.length;
                          if (event is FlTapUpEvent ||
                              event is FlPointerHoverEvent) {
                            final next = valid ? idx : -1;
                            if (next != _touched) {
                              setState(() => _touched = next);
                            }
                          }
                          if (!event.isInterestedForInteractions &&
                              _touched != -1) {
                            setState(() => _touched = -1);
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => clx.bg2,
                          tooltipBorder: BorderSide(color: clx.line),
                          getTooltipItem: (group, _, rod, rodIndex) {
                            final i = group.x.toInt();
                            if (i < 0 || i >= buckets.length) return null;
                            final b = buckets[i];
                            final title = rodIndex == 0
                                ? 'Entradas'
                                : 'Saídas';
                            final val =
                                rodIndex == 0 ? b.entradas : b.saidas;
                            return BarTooltipItem(
                              '$title\n${formatCurrency(val)}',
                              tt.labelMedium!.copyWith(
                                color: clx.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
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
                              if (i < 0 || i >= buckets.length) {
                                return const SizedBox.shrink();
                              }
                              // Poucos rótulos se muitos buckets (diário).
                              if (buckets.length > 14 && i % 3 != 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  buckets[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelSmall?.copyWith(
                                    color: clx.ink3,
                                    fontSize: 10,
                                  ),
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
                        for (var i = 0; i < buckets.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 3,
                            barRods: [
                              BarChartRodData(
                                toY: buckets[i].entradas * t,
                                color: clx.finIncome,
                                width: buckets.length > 20 ? 5 : 10,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2),
                                ),
                              ),
                              BarChartRodData(
                                toY: buckets[i].saidas * t,
                                color: clx.finExpense,
                                width: buckets.length > 20 ? 5 : 10,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    duration: ClxMotion.shortDuration,
                    curve: ClxMotion.standard,
                  ),
                  // Linha de saldo sobre as barras.
                  LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      minX: -0.5,
                      maxX: buckets.length - 0.5,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => clx.bg2,
                          getTooltipItems: (spots) {
                            return spots.map((s) {
                              final i = s.x.round().clamp(0, buckets.length - 1);
                              final b = buckets[i];
                              return LineTooltipItem(
                                'Saldo em ${b.label}\n${formatCurrency(b.saldo)}',
                                tt.labelMedium!.copyWith(
                                  color: clx.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < buckets.length; i++)
                              FlSpot(i.toDouble(), buckets[i].saldo * t),
                          ],
                          isCurved: false,
                          color: saldoColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, _, __, ___) =>
                                FlDotCirclePainter(
                              radius: 3.5,
                              color: clx.info,
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                    duration: ClxMotion.shortDuration,
                    curve: ClxMotion.standard,
                  ),
                ],
              );
            },
          ),
        ),
      ],
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
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: ClxMotion.emphasizedDuration,
            curve: ClxMotion.emphasized,
            builder: (context, t, _) {
              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  minY: minY,
                  groupsSpace: 14,
                  barTouchData: BarTouchData(
                    enabled: t > 0.9,
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
                          rod(groups[i].receitas * t, clx.finIncome),
                          rod(groups[i].despesas * t, clx.finExpense),
                          if (hasLucro)
                            rod((groups[i].lucro ?? 0) * t, clx.info),
                        ],
                      ),
                  ],
                ),
                duration: ClxMotion.emphasizedDuration,
                curve: ClxMotion.emphasized,
              );
            },
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
