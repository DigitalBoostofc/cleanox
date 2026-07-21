/// fin_planejamento_screen.dart — Planejamento mensal v2.
///
/// Casca Cleanox sobre os limites por categoria ([FinLimitesScreen] logic
/// embutida + empty CTA no estilo das refs).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'fin_derivations.dart';
import 'fin_limites_screen.dart';
import 'fin_providers.dart';
import 'ui/fin_ui.dart';

class FinPlanejamentoScreen extends ConsumerWidget {
  const FinPlanejamentoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final period = ref.watch(finPeriodProvider);
    final anoMes =
        '${period.year.toString().padLeft(4, '0')}-${period.month.toString().padLeft(2, '0')}';
    final limitesAsync = ref.watch(finLimitesProvider);
    final lancs =
        ref.watch(finPeriodLancamentosProvider).valueOrNull ??
            const <FinLancamento>[];

    return ColoredBox(
      color: clx.bg2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Planejamento mensal',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                FinMonthBar(
                  label: period.label,
                  onPrev: () => ref.read(finPeriodProvider.notifier).state =
                      period.shift(-1),
                  onNext: () => ref.read(finPeriodProvider.notifier).state =
                      period.shift(1),
                ),
                const SizedBox(height: 12),
                limitesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (all) {
                    final doMes =
                        all.where((l) => l.anoMes == anoMes).toList();
                    if (doMes.isEmpty) return const SizedBox.shrink();
                    var gastoTotal = 0.0;
                    var limiteTotal = 0.0;
                    for (final lim in doMes) {
                      final p = progressoLimite(lim, lancs);
                      gastoTotal += p.gasto;
                      limiteTotal += lim.limite;
                    }
                    final pct = limiteTotal > 0
                        ? (gastoTotal / limiteTotal).clamp(0.0, 1.5)
                        : 0.0;
                    return FinCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Orçamento do mês',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}% usado',
                                style: TextStyle(
                                  color: pct > 1
                                      ? clx.finExpense
                                      : clx.ink2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: ClxRadii.rPill,
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 10,
                              backgroundColor: clx.line2,
                              color: pct > 1
                                  ? clx.finExpense
                                  : clx.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${formatCurrency(gastoTotal)} de ${formatCurrency(limiteTotal)}',
                            style: TextStyle(color: clx.ink3, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Reusa a tela de limites (árvore + definir/copiar) — já completa.
          const Expanded(child: FinLimitesScreen()),
        ],
      ),
    );
  }
}
