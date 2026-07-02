/// fin_visao_geral_screen.dart — Visão geral do Financeiro (KPIs + gráficos).
///
/// Espelha `VisaoGeral.tsx`: seletor de mês (BRT), KPIs (entradas/saídas/saldo do
/// mês/saldo geral), donut de "maiores gastos por categoria" e barras
/// entradas×saídas — tudo em `fl_chart`. Agrega os lançamentos do período
/// (carregados PAGINADOS pelo provider). Estados carregando/erro/vazio/sucesso.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'charts/fin_charts.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_providers.dart';

class FinVisaoGeralScreen extends ConsumerWidget {
  const FinVisaoGeralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lancAsync = ref.watch(finPeriodLancamentosProvider);
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];

    return Column(
      children: [
        _Header(),
        Expanded(
          child: FinAsync<List<FinLancamento>>(
            value: lancAsync,
            onRetry: () => ref.invalidate(finPeriodLancamentosProvider),
            data: (lancs) =>
                _Body(lancs: lancs, contas: contas, categorias: categorias),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x6,
        ClxSpace.x4,
        ClxSpace.x6,
        ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Visão geral',
              style: TextStyle(
                color: clx.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const FinPeriodSelector(),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.lancs,
    required this.contas,
    required this.categorias,
  });

  final List<FinLancamento> lancs;
  final List<FinConta> contas;
  final List<FinCategoria> categorias;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final resumo = resumoPeriodo(lancs);
    final saldoTotal = saldoGeral(contas);
    final gastos = gastoPorCategoria(lancs);

    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x6),
      children: [
        FinKpiGrid(
          cards: [
            FinKpiCard(
              label: 'Entradas',
              value: formatCurrency(resumo.entradas),
              color: clx.finIncome,
              icon: Icons.north_east_rounded,
            ),
            FinKpiCard(
              label: 'Saídas',
              value: formatCurrency(resumo.saidas),
              color: clx.finExpense,
              icon: Icons.south_west_rounded,
            ),
            FinKpiCard(
              label: 'Saldo do mês',
              value: formatCurrency(resumo.saldoMes),
              color: resumo.saldoMes < 0 ? clx.finExpense : clx.primary,
              icon: Icons.equalizer_rounded,
            ),
            FinKpiCard(
              label: 'Saldo geral',
              value: formatCurrency(saldoTotal),
              color: saldoTotal < 0 ? clx.finExpense : clx.ink,
              icon: Icons.account_balance_outlined,
            ),
          ],
        ),
        const SizedBox(height: ClxSpace.x6),
        if (lancs.isEmpty)
          const ClxCard(
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: 'Sem movimentações neste mês',
              message:
                  'Lançamentos pagos aparecerão aqui com gráficos de entradas, '
                  'saídas e gastos por categoria.',
            ),
          )
        else ...[
          // Gastos por categoria (donut).
          ClxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FinSectionHeader(title: 'Maiores gastos por categoria'),
                const SizedBox(height: ClxSpace.x4),
                _donutOrEmpty(context, gastos),
              ],
            ),
          ),
          const SizedBox(height: ClxSpace.x4),
          // Entradas × saídas (barras).
          ClxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FinSectionHeader(title: 'Entradas × saídas'),
                const SizedBox(height: ClxSpace.x4),
                FinBarChart(
                  slices: [
                    FinSlice(
                      label: 'Entradas',
                      value: resumo.entradas,
                      color: clx.finIncome,
                    ),
                    FinSlice(
                      label: 'Saídas',
                      value: resumo.saidas,
                      color: clx.finExpense,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _donutOrEmpty(BuildContext context, Map<String, double> gastos) {
    final clx = context.clx;
    if (gastos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ClxSpace.x6),
        child: Center(
          child: Text(
            'Nenhuma despesa paga no período.',
            style: TextStyle(color: clx.ink3, fontSize: 13),
          ),
        ),
      );
    }
    // Ordena desc, pega top 6, agrupa o resto em "Outros".
    final entries = gastos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final restoTotal = entries.skip(6).fold<double>(0, (a, e) => a + e.value);
    final cores = finSeriesColors(context, top.length + 1);
    String nome(String id) => categorias
        .firstWhere(
          (c) => c.id == id,
          orElse: () => FinCategoria(id: id, nome: '—'),
        )
        .nome;

    final slices = <FinSlice>[
      for (var i = 0; i < top.length; i++)
        FinSlice(label: nome(top[i].key), value: top[i].value, color: cores[i]),
      if (restoTotal > 0)
        FinSlice(label: 'Outros', value: restoTotal, color: cores.last),
    ];
    return FinDonutChart(slices: slices, centerLabel: 'Gastos');
  }
}
