/// fin_relatorios_screen.dart — Relatórios densos do Financeiro.
///
/// Espelha `Relatorios.tsx`: sobre o período (BRT), mostra entradas×saídas
/// (barras), a distribuição de despesas e de receitas por categoria (donuts) e
/// um ranking tabular das categorias. Tudo em `fl_chart` (canvas). Os dados do
/// período já vêm PAGINADOS do provider (nunca `getFullList`). Estados
/// carregando/erro/vazio/sucesso.
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

class FinRelatoriosScreen extends ConsumerWidget {
  const FinRelatoriosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lancAsync = ref.watch(finPeriodLancamentosProvider);
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];

    return Column(
      children: [
        _Header(),
        Expanded(
          child: FinAsync<List<FinLancamento>>(
            value: lancAsync,
            onRetry: () => ref.invalidate(finPeriodLancamentosProvider),
            data: (lancs) {
              if (lancs.isEmpty) {
                return const EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'Sem dados no período',
                  message:
                      'Selecione outro mês ou registre lançamentos para ver os '
                      'relatórios.',
                );
              }
              return _Body(lancs: lancs, categorias: categorias);
            },
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
              'Relatórios',
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
  const _Body({required this.lancs, required this.categorias});

  final List<FinLancamento> lancs;
  final List<FinCategoria> categorias;

  String _nome(String id) => categorias
      .firstWhere(
        (c) => c.id == id,
        orElse: () => FinCategoria(id: id, nome: '—'),
      )
      .nome;

  List<FinSlice> _slices(BuildContext context, Map<String, double> porCat) {
    final entries = porCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final resto = entries.skip(6).fold<double>(0, (a, e) => a + e.value);
    final cores = finSeriesColors(context, top.length + 1);
    return [
      for (var i = 0; i < top.length; i++)
        FinSlice(
          label: _nome(top[i].key),
          value: top[i].value,
          color: cores[i],
        ),
      if (resto > 0) FinSlice(label: 'Outros', value: resto, color: cores.last),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final resumo = resumoPeriodo(lancs);
    final despesas = totalPagoPorCategoria(lancs, TipoLancamento.despesa);
    final receitas = totalPagoPorCategoria(lancs, TipoLancamento.receita);

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
              label: 'Resultado',
              value: formatCurrency(resumo.saldoMes),
              color: resumo.saldoMes < 0 ? clx.finExpense : clx.primary,
              icon: Icons.equalizer_rounded,
            ),
          ],
        ),
        const SizedBox(height: ClxSpace.x6),
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
        const SizedBox(height: ClxSpace.x4),
        _CategoriaBreakdown(
          title: 'Despesas por categoria',
          slices: despesas.isEmpty ? const [] : _slices(context, despesas),
          emptyMsg: 'Nenhuma despesa paga no período.',
        ),
        const SizedBox(height: ClxSpace.x4),
        _CategoriaBreakdown(
          title: 'Receitas por categoria',
          slices: receitas.isEmpty ? const [] : _slices(context, receitas),
          emptyMsg: 'Nenhuma receita paga no período.',
        ),
      ],
    );
  }
}

/// Card com donut + ranking tabular de uma distribuição por categoria.
class _CategoriaBreakdown extends StatelessWidget {
  const _CategoriaBreakdown({
    required this.title,
    required this.slices,
    required this.emptyMsg,
  });

  final String title;
  final List<FinSlice> slices;
  final String emptyMsg;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinSectionHeader(title: title),
          const SizedBox(height: ClxSpace.x4),
          if (slices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Center(
                child: Text(
                  emptyMsg,
                  style: TextStyle(color: clx.ink3, fontSize: 13),
                ),
              ),
            )
          else ...[
            FinDonutChart(slices: slices, centerLabel: 'Total'),
            const SizedBox(height: ClxSpace.x4),
            Divider(height: 1, color: clx.line),
            const SizedBox(height: ClxSpace.x2),
            for (final s in slices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: ClxSpace.x1),
                child: Row(
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
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: clx.ink2, fontSize: 13),
                      ),
                    ),
                    Text(
                      formatCurrency(s.value),
                      style: TextStyle(
                        color: clx.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: ClxSpace.x3),
                    SizedBox(
                      width: 42,
                      child: Text(
                        total > 0
                            ? '${(s.value / total * 100).round()}%'
                            : '0%',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: clx.ink3, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
