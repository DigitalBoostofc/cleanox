/// fin_relatorios_screen.dart — Relatórios densos do Financeiro (estilo Organizze).
///
/// Espelha `Relatorios.tsx`: filtros (categoria/conta/status; período = mês via
/// seletor BRT) + abas (Categorias / Entradas x Saídas / Contas / Tags), 5 KPIs
/// (com variação vs. mês anterior), 2 donuts por categoria, fluxo de caixa de 6
/// meses (barras agrupadas), "Resumo do período", donut "Receitas via OS" e
/// tabelas por conta e por tag. Os dados vêm do provider de 6 meses (paginado).
/// Exportar/Imprimir apenas sinaliza (o navegador/SO cuida da impressão).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'charts/fin_charts.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_labels.dart';
import 'fin_providers.dart';

const _mesesAbbr = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

enum _Tab { categorias, fluxo, contas, tags }

extension on _Tab {
  String get label => switch (this) {
    _Tab.categorias => 'Categorias',
    _Tab.fluxo => 'Entradas × Saídas',
    _Tab.contas => 'Contas',
    _Tab.tags => 'Tags',
  };
}

/* ─────────────────────── helpers de agregação ─────────────────────── */

({double receita, double despesa}) _totaisPorTipo(List<FinLancamento> lancs) {
  var receita = 0.0;
  var despesa = 0.0;
  for (final l in lancs) {
    if (l.tipo == TipoLancamento.receita) {
      receita += l.valor;
    } else {
      despesa += l.valor;
    }
  }
  return (receita: receita, despesa: despesa);
}

Map<String, double> _porCategoria(List<FinLancamento> lancs, TipoLancamento t) {
  final m = <String, double>{};
  for (final l in lancs) {
    if (l.tipo != t) continue;
    m[l.categoriaId] = (m[l.categoriaId] ?? 0) + l.valor;
  }
  return m;
}

class _Slice {
  const _Slice(this.label, this.value, this.color, this.pct);
  final String label;
  final double value;
  final Color color;
  final double pct;
}

List<_Slice> _buildSlices(
  Map<String, double> totais,
  FinCategoria? Function(String) cat,
  List<Color> palette, {
  int max = 8,
}) {
  final entries = totais.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = entries.fold<double>(0, (s, e) => s + e.value);
  if (total <= 0) return const [];
  final head = entries.take(max).toList();
  final tail = entries.skip(max).fold<double>(0, (s, e) => s + e.value);
  final out = <_Slice>[
    for (var i = 0; i < head.length; i++)
      _Slice(
        cat(head[i].key)?.nome ?? 'Sem categoria',
        head[i].value,
        palette[i % palette.length],
        head[i].value / total,
      ),
  ];
  if (tail > 0) {
    out.add(_Slice('Outras', tail, palette.last, tail / total));
  }
  return out;
}

String _pctLabel(double v) =>
    '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1).replaceAll('.', ',')}%';

class FinRelatoriosScreen extends ConsumerStatefulWidget {
  const FinRelatoriosScreen({super.key});

  @override
  ConsumerState<FinRelatoriosScreen> createState() =>
      _FinRelatoriosScreenState();
}

class _FinRelatoriosScreenState extends ConsumerState<FinRelatoriosScreen> {
  _Tab _tab = _Tab.categorias;
  String? _catFilter;
  String? _contaFilter;
  LancamentoStatus? _statusFilter;

  /// Mobile: filtros colapsados por padrão (F-741). Ignorado no desktop.
  bool _showFilters = false;

  bool get _hasFilters =>
      _catFilter != null || _contaFilter != null || _statusFilter != null;

  ({bool up, String text}) _trend(double atual, double anterior) {
    final pct = anterior == 0
        ? (atual == 0 ? 0.0 : 100.0)
        : (atual - anterior) / anterior.abs() * 100;
    return (up: pct >= 0, text: '${_pctLabel(pct)} vs. mês anterior');
  }

  void _export() => showClxToast(
    context,
    'Use a impressão do navegador/sistema para exportar em PDF.',
    type: ToastType.info,
  );

  @override
  Widget build(BuildContext context) {
    final lancAsync = ref.watch(finRelatorioLancamentosProvider);
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    final mobile = finIsMobile(context);

    // Mobile (F-741): sem cabeçalho fixo — período + filtro colapsável rolam
    // como primeiro item do relatório, junto com KPIs e gráficos.
    final leadingChildren = mobile
        ? <Widget>[
            _MobileHeader(
              categorias: categorias,
              contas: contas,
              catFilter: _catFilter,
              contaFilter: _contaFilter,
              statusFilter: _statusFilter,
              showFilters: _showFilters,
              hasFilters: _hasFilters,
              onToggleFilters: () =>
                  setState(() => _showFilters = !_showFilters),
              onCat: (v) => setState(() => _catFilter = v),
              onConta: (v) => setState(() => _contaFilter = v),
              onStatus: (v) => setState(() => _statusFilter = v),
              onExport: _export,
            ),
            const SizedBox(height: ClxSpace.x4),
          ]
        : const <Widget>[];

    final body = FinAsync<List<FinLancamento>>(
      value: lancAsync,
      onRetry: () => ref.invalidate(finRelatorioLancamentosProvider),
      data: (todos) => _Body(
        todos: todos,
        contas: contas,
        categorias: categorias,
        tab: _tab,
        onTab: (t) => setState(() => _tab = t),
        catFilter: _catFilter,
        contaFilter: _contaFilter,
        statusFilter: _statusFilter,
        trend: _trend,
        mobile: mobile,
        leadingChildren: leadingChildren,
      ),
    );

    if (mobile) return body;

    return Column(
      children: [
        _Header(
          categorias: categorias,
          contas: contas,
          catFilter: _catFilter,
          contaFilter: _contaFilter,
          statusFilter: _statusFilter,
          onCat: (v) => setState(() => _catFilter = v),
          onConta: (v) => setState(() => _contaFilter = v),
          onStatus: (v) => setState(() => _statusFilter = v),
          onExport: _export,
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.categorias,
    required this.contas,
    required this.catFilter,
    required this.contaFilter,
    required this.statusFilter,
    required this.onCat,
    required this.onConta,
    required this.onStatus,
    required this.onExport,
  });

  final List<FinCategoria> categorias;
  final List<FinConta> contas;
  final String? catFilter;
  final String? contaFilter;
  final LancamentoStatus? statusFilter;
  final ValueChanged<String?> onCat;
  final ValueChanged<String?> onConta;
  final ValueChanged<LancamentoStatus?> onStatus;
  final VoidCallback onExport;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Relatórios',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: clx.ink),
                ),
              ),
              ClxButton(
                label: 'Exportar PDF',
                icon: Icons.picture_as_pdf_outlined,
                variant: ClxButtonVariant.ghost,
                onPressed: onExport,
              ),
              const SizedBox(width: ClxSpace.x2),
              const FinPeriodSelector(),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          _RelFiltersWrap(
            categorias: categorias,
            contas: contas,
            catFilter: catFilter,
            contaFilter: contaFilter,
            statusFilter: statusFilter,
            onCat: onCat,
            onConta: onConta,
            onStatus: onStatus,
          ),
        ],
      ),
    );
  }
}

/// Wrap de filtros (categoria/conta/status) compartilhado entre o cabeçalho de
/// desktop e o cabeçalho colapsável de mobile.
class _RelFiltersWrap extends StatelessWidget {
  const _RelFiltersWrap({
    required this.categorias,
    required this.contas,
    required this.catFilter,
    required this.contaFilter,
    required this.statusFilter,
    required this.onCat,
    required this.onConta,
    required this.onStatus,
  });

  final List<FinCategoria> categorias;
  final List<FinConta> contas;
  final String? catFilter;
  final String? contaFilter;
  final LancamentoStatus? statusFilter;
  final ValueChanged<String?> onCat;
  final ValueChanged<String?> onConta;
  final ValueChanged<LancamentoStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final roots =
        categorias.where((c) => c.parentId == null && !c.arquivada).toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
    return Wrap(
      spacing: ClxSpace.x4,
      runSpacing: ClxSpace.x3,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        _RepFilter<String?>(
          label: 'Categorias',
          value: catFilter,
          entries: [
            (value: null, text: 'Todas as categorias'),
            for (final c in roots) (value: c.id, text: c.nome),
          ],
          onChanged: onCat,
        ),
        _RepFilter<String?>(
          label: 'Contas',
          value: contaFilter,
          entries: [
            (value: null, text: 'Todas as contas'),
            for (final c in contas) (value: c.id, text: c.nome),
          ],
          onChanged: onConta,
        ),
        _RepFilter<LancamentoStatus?>(
          label: 'Status',
          value: statusFilter,
          entries: [
            (value: null, text: 'Todos'),
            for (final s in LancamentoStatus.values)
              (value: s, text: statusLancamentoLabel(s)),
          ],
          onChanged: onStatus,
        ),
      ],
    );
  }
}

/// Cabeçalho ROLÁVEL do mobile: período + botão "Filtros" (colapsa os filtros e
/// o "Exportar"). Entra como primeiro item do relatório em vez de faixa fixa.
class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.categorias,
    required this.contas,
    required this.catFilter,
    required this.contaFilter,
    required this.statusFilter,
    required this.showFilters,
    required this.hasFilters,
    required this.onToggleFilters,
    required this.onCat,
    required this.onConta,
    required this.onStatus,
    required this.onExport,
  });

  final List<FinCategoria> categorias;
  final List<FinConta> contas;
  final String? catFilter;
  final String? contaFilter;
  final LancamentoStatus? statusFilter;
  final bool showFilters;
  final bool hasFilters;
  final VoidCallback onToggleFilters;
  final ValueChanged<String?> onCat;
  final ValueChanged<String?> onConta;
  final ValueChanged<LancamentoStatus?> onStatus;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: double.infinity,
          child: FinPeriodSelector(expand: true),
        ),
        const SizedBox(height: ClxSpace.x2),
        Align(
          alignment: Alignment.centerLeft,
          child: FinFiltrosToggle(
            active: showFilters,
            hasActiveFilters: hasFilters,
            onTap: onToggleFilters,
          ),
        ),
        if (showFilters) ...[
          const SizedBox(height: ClxSpace.x3),
          _RelFiltersWrap(
            categorias: categorias,
            contas: contas,
            catFilter: catFilter,
            contaFilter: contaFilter,
            statusFilter: statusFilter,
            onCat: onCat,
            onConta: onConta,
            onStatus: onStatus,
          ),
          const SizedBox(height: ClxSpace.x3),
          Align(
            alignment: Alignment.centerLeft,
            child: ClxButton(
              label: 'Exportar PDF',
              icon: Icons.picture_as_pdf_outlined,
              variant: ClxButtonVariant.ghost,
              onPressed: onExport,
            ),
          ),
        ],
      ],
    );
  }
}

class _RepFilter<T> extends StatelessWidget {
  const _RepFilter({
    required this.label,
    required this.value,
    required this.entries,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<({T value, String text})> entries;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: clx.ink3),
        ),
        const SizedBox(height: ClxSpace.x1),
        Container(
          constraints: const BoxConstraints(minWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x3),
          decoration: BoxDecoration(
            color: clx.bg2,
            borderRadius: ClxRadii.rMd,
            border: Border.all(color: clx.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              isExpanded: true,
              borderRadius: ClxRadii.rMd,
              dropdownColor: clx.bg,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: clx.ink),
              items: [
                for (final e in entries)
                  DropdownMenuItem<T>(
                    value: e.value,
                    child: Text(
                      e.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null || null is T) onChanged(v as T);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.todos,
    required this.contas,
    required this.categorias,
    required this.tab,
    required this.onTab,
    required this.catFilter,
    required this.contaFilter,
    required this.statusFilter,
    required this.trend,
    this.mobile = false,
    this.leadingChildren = const [],
  });

  final List<FinLancamento> todos;
  final List<FinConta> contas;
  final List<FinCategoria> categorias;
  final _Tab tab;
  final ValueChanged<_Tab> onTab;
  final String? catFilter;
  final String? contaFilter;
  final LancamentoStatus? statusFilter;
  final ({bool up, String text}) Function(double, double) trend;

  /// Layout de celular: reduz o padding e recebe o cabeçalho rolável.
  final bool mobile;

  /// Widgets inseridos ANTES das abas/KPIs (cabeçalho mobile). Vazio no desktop.
  final List<Widget> leadingChildren;

  FinCategoria? _cat(String id) {
    for (final c in categorias) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<FinLancamento> _status(List<FinLancamento> l) => statusFilter == null
      ? l
      : l.where((x) => x.status == statusFilter).toList();

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;

    // Filtro base (categoria/conta) sobre os 6 meses.
    final base = todos.where((l) {
      if (catFilter != null &&
          l.categoriaId != catFilter &&
          l.subcategoriaId != catFilter) {
        return false;
      }
      if (contaFilter != null && l.contaId != contaFilter) return false;
      return true;
    }).toList();

    return Consumer(
      builder: (context, ref, _) {
        final period = ref.watch(finPeriodProvider);
        final periodo = period.periodo;
        final periodoAnt = period.shift(-1).periodo;

        final viewLancs = _status(lancamentosDoPeriodo(base, periodo));
        final prevLancs = _status(lancamentosDoPeriodo(base, periodoAnt));
        final tot = _totaisPorTipo(viewLancs);
        final totPrev = _totaisPorTipo(prevLancs);
        final lucro = tot.receita - tot.despesa;
        final lucroPrev = totPrev.receita - totPrev.despesa;

        final viaOsLancs = viewLancs
            .where(
              (l) =>
                  l.tipo == TipoLancamento.receita &&
                  l.origem == OrigemLancamento.viaOs,
            )
            .toList();
        final receitaViaOs = viaOsLancs.fold<double>(0, (s, l) => s + l.valor);
        final ticketMedio = viaOsLancs.isEmpty
            ? 0.0
            : receitaViaOs / viaOsLancs.length;
        final pctViaOs = tot.receita > 0
            ? receitaViaOs / tot.receita * 100
            : 0.0;

        final palette = finSeriesColors(context, 9);
        final despesaSlices = _buildSlices(
          _porCategoria(viewLancs, TipoLancamento.despesa),
          _cat,
          palette,
        );
        final receitaSlices = _buildSlices(
          _porCategoria(viewLancs, TipoLancamento.receita),
          _cat,
          palette,
        );

        // Fluxo de caixa (6 meses até o selecionado).
        final fluxo = <FinBarGroup>[];
        for (var i = 5; i >= 0; i--) {
          final p = period.shift(-i);
          final mesLancs = _status(lancamentosDoPeriodo(base, p.periodo));
          final t = _totaisPorTipo(mesLancs);
          fluxo.add(
            FinBarGroup(
              label: _mesesAbbr[p.month - 1],
              receitas: t.receita,
              despesas: t.despesa,
              lucro: t.receita - t.despesa,
            ),
          );
        }
        final fluxoVazio = fluxo.every(
          (g) => g.receitas == 0 && g.despesas == 0,
        );

        final resumo = resumoPeriodo(lancamentosDoPeriodo(base, periodo));
        final saldoFinal = saldoGeral(contas);
        final saldoInicial = saldoFinal - resumo.saldoMes;
        final variacao = saldoInicial != 0
            ? resumo.saldoMes / saldoInicial.abs() * 100
            : 0.0;

        final periodoVazio = viewLancs.isEmpty;

        return ListView(
          padding: EdgeInsets.all(mobile ? ClxSpace.x4 : ClxSpace.x6),
          children: [
            ...leadingChildren,
            // Abas.
            _Tabs(active: tab, onTab: onTab),
            const SizedBox(height: ClxSpace.x4),
            // KPIs (sempre visíveis).
            FinKpiGrid(
              cards: [
                FinKpiCard(
                  label: 'Receita total',
                  value: formatCurrency(tot.receita),
                  color: clx.finIncome,
                  trend: trend(tot.receita, totPrev.receita),
                ),
                FinKpiCard(
                  label: 'Despesa total',
                  value: formatCurrency(tot.despesa),
                  color: clx.finExpense,
                  trend: trend(tot.despesa, totPrev.despesa),
                ),
                FinKpiCard(
                  label: 'Lucro / Prejuízo',
                  value: formatCurrency(lucro),
                  color: lucro >= 0 ? clx.info : clx.finExpense,
                  trend: trend(lucro, lucroPrev),
                ),
                FinKpiCard(
                  label: 'Ticket médio por serviço',
                  value: formatCurrency(ticketMedio),
                  color: clx.primary,
                  hint:
                      '${viaOsLancs.length} serviço${viaOsLancs.length == 1 ? '' : 's'} via OS',
                ),
                FinKpiCard(
                  label: 'Receitas via OS',
                  value: formatCurrency(receitaViaOs),
                  color: clx.primary,
                  hint:
                      '${pctViaOs.toStringAsFixed(1).replaceAll('.', ',')}% do total',
                ),
              ],
            ),
            const SizedBox(height: ClxSpace.x5),
            if (periodoVazio)
              const ClxCard(
                child: EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'Sem dados no período',
                  message:
                      'Não há lançamentos no período/filtros selecionados. '
                      'Ajuste os filtros ou o mês.',
                ),
              )
            else
              ..._tabContent(
                context,
                despesaSlices: despesaSlices,
                receitaSlices: receitaSlices,
                fluxo: fluxo,
                fluxoVazio: fluxoVazio,
                resumo: resumo,
                saldoInicial: saldoInicial,
                saldoFinal: saldoFinal,
                variacao: variacao,
                receitaViaOs: receitaViaOs,
                pctViaOs: pctViaOs,
                totReceita: tot.receita,
                totDespesa: tot.despesa,
                lucro: lucro,
                viewLancs: viewLancs,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _tabContent(
    BuildContext context, {
    required List<_Slice> despesaSlices,
    required List<_Slice> receitaSlices,
    required List<FinBarGroup> fluxo,
    required bool fluxoVazio,
    required ResumoPeriodo resumo,
    required double saldoInicial,
    required double saldoFinal,
    required double variacao,
    required double receitaViaOs,
    required double pctViaOs,
    required double totReceita,
    required double totDespesa,
    required double lucro,
    required List<FinLancamento> viewLancs,
  }) {
    switch (tab) {
      case _Tab.categorias:
        return [
          _ResponsivePair(
            a: _DonutCard(
              title: 'Despesas por categoria',
              slices: despesaSlices,
              emptyMsg: 'Sem despesas no período.',
            ),
            b: _DonutCard(
              title: 'Receitas por categoria',
              slices: receitaSlices,
              emptyMsg: 'Sem receitas no período.',
            ),
          ),
          const SizedBox(height: ClxSpace.x4),
          _ResponsivePair(
            a: _ResumoCard(
              saldoInicial: saldoInicial,
              entradas: resumo.entradas,
              saidas: resumo.saidas,
              saldoFinal: saldoFinal,
              variacao: variacao,
            ),
            b: _ViaOsCard(
              receitaViaOs: receitaViaOs,
              totReceita: totReceita,
              pctViaOs: pctViaOs,
            ),
          ),
          const SizedBox(height: ClxSpace.x4),
          _FluxoCard(fluxo: fluxo, vazio: fluxoVazio),
        ];
      case _Tab.fluxo:
        return [
          _FluxoCard(fluxo: fluxo, vazio: fluxoVazio),
          const SizedBox(height: ClxSpace.x4),
          _ResumoSimplesCard(
            receita: totReceita,
            despesa: totDespesa,
            lucro: lucro,
          ),
        ];
      case _Tab.contas:
        return [
          _ContasTable(
            contas: contas,
            viewLancs: viewLancs,
            saldoFinal: saldoFinal,
          ),
        ];
      case _Tab.tags:
        return [_TagsTable(viewLancs: viewLancs)];
    }
  }
}

/* ─────────────────────── abas ─────────────────────── */

class _Tabs extends StatelessWidget {
  const _Tabs({required this.active, required this.onTab});
  final _Tab active;
  final ValueChanged<_Tab> onTab;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in _Tab.values)
            Padding(
              padding: const EdgeInsets.only(right: ClxSpace.x2),
              child: InkWell(
                onTap: () => onTab(t),
                borderRadius: ClxRadii.rPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClxSpace.x4,
                    vertical: ClxSpace.x2,
                  ),
                  decoration: BoxDecoration(
                    color: t == active
                        ? clx.primary.withValues(alpha: 0.14)
                        : clx.bg2,
                    borderRadius: ClxRadii.rPill,
                    border: Border.all(
                      color: t == active ? clx.primary : clx.line,
                    ),
                  ),
                  child: Text(
                    t.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: t == active ? clx.primary : clx.ink2,
                      fontWeight: t == active
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dois cards lado a lado (empilham < 720px).
class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.a, required this.b});
  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 720) {
          return Column(children: [a, const SizedBox(height: ClxSpace.x4), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: ClxSpace.x4),
            Expanded(child: b),
          ],
        );
      },
    );
  }
}

/* ─────────────────────── donut por categoria ─────────────────────── */

class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.title,
    required this.slices,
    required this.emptyMsg,
  });

  final String title;
  final List<_Slice> slices;
  final String emptyMsg;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final total = slices.fold<double>(0, (s, x) => s + x.value);
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
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ),
            )
          else ...[
            FinDonutChart(
              centerLabel: 'Total',
              slices: [
                for (final s in slices)
                  FinSlice(label: s.label, value: s.value, color: s.color),
              ],
            ),
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
                        style: tt.bodyMedium?.copyWith(color: clx.ink2),
                      ),
                    ),
                    Text(
                      formatCurrency(s.value),
                      style: tt.bodyMedium?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: ClxSpace.x3),
                    SizedBox(
                      width: 46,
                      child: Text(
                        '${(total > 0 ? s.pct * 100 : 0).toStringAsFixed(1).replaceAll('.', ',')}%',
                        textAlign: TextAlign.right,
                        style: tt.bodyMedium?.copyWith(color: clx.ink3),
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

/* ─────────────────────── resumo do período ─────────────────────── */

class _ResumoCard extends StatelessWidget {
  const _ResumoCard({
    required this.saldoInicial,
    required this.entradas,
    required this.saidas,
    required this.saldoFinal,
    required this.variacao,
  });

  final double saldoInicial;
  final double entradas;
  final double saidas;
  final double saldoFinal;
  final double variacao;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinSectionHeader(title: 'Resumo do período'),
          const SizedBox(height: ClxSpace.x3),
          _row(context, 'Saldo inicial', formatCurrency(saldoInicial), clx.ink),
          _row(
            context,
            'Total de entradas',
            formatCurrency(entradas),
            clx.finIncome,
          ),
          _row(
            context,
            'Total de saídas',
            formatCurrency(saidas),
            clx.finExpense,
          ),
          _row(context, 'Saldo final', formatCurrency(saldoFinal), clx.primary),
          _row(
            context,
            'Variação no período',
            _pctLabel(variacao),
            variacao >= 0 ? clx.finIncome : clx.finExpense,
          ),
          const SizedBox(height: ClxSpace.x2),
          Text(
            'Movimentação realizada (lançamentos pagos) no período.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: clx.ink3),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Color color) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ClxSpace.x1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: clx.ink2),
            ),
          ),
          Text(
            value,
            style: tt.bodyLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoSimplesCard extends StatelessWidget {
  const _ResumoSimplesCard({
    required this.receita,
    required this.despesa,
    required this.lucro,
  });

  final double receita;
  final double despesa;
  final double lucro;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinSectionHeader(title: 'Resumo do período'),
          const SizedBox(height: ClxSpace.x3),
          _kv(context, 'Total de entradas', formatCurrency(receita), clx.finIncome),
          _kv(context, 'Total de saídas', formatCurrency(despesa), clx.finExpense),
          _kv(
            context,
            'Resultado',
            formatCurrency(lucro),
            lucro >= 0 ? clx.finIncome : clx.finExpense,
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value, Color color) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ClxSpace.x1),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: tt.bodyMedium?.copyWith(color: clx.ink2)),
          ),
          Text(
            value,
            style: tt.bodyLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── receitas via OS ─────────────────────── */

class _ViaOsCard extends StatelessWidget {
  const _ViaOsCard({
    required this.receitaViaOs,
    required this.totReceita,
    required this.pctViaOs,
  });

  final double receitaViaOs;
  final double totReceita;
  final double pctViaOs;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final outras = (totReceita - receitaViaOs).clamp(0, double.infinity);
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinSectionHeader(title: 'Receitas via OS'),
          const SizedBox(height: ClxSpace.x4),
          if (totReceita <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Center(
                child: Text(
                  'Sem receitas no período.',
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ),
            )
          else ...[
            FinDonutChart(
              centerLabel: 'Via OS',
              slices: [
                FinSlice(
                  label: 'Via OS',
                  value: receitaViaOs,
                  color: clx.primary,
                ),
                FinSlice(
                  label: 'Outras receitas',
                  value: outras.toDouble(),
                  color: clx.finMuted,
                ),
              ],
            ),
            const SizedBox(height: ClxSpace.x3),
            Center(
              child: Column(
                children: [
                  Text(
                    formatCurrency(receitaViaOs),
                    style: tt.titleLarge?.copyWith(
                      color: clx.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${pctViaOs.toStringAsFixed(1).replaceAll('.', ',')}% do total de receitas',
                    style: tt.bodyMedium?.copyWith(color: clx.ink3),
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

/* ─────────────────────── fluxo de caixa ─────────────────────── */

class _FluxoCard extends StatelessWidget {
  const _FluxoCard({required this.fluxo, required this.vazio});
  final List<FinBarGroup> fluxo;
  final bool vazio;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinSectionHeader(title: 'Fluxo de caixa mensal'),
          const SizedBox(height: ClxSpace.x4),
          if (vazio)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Center(
                child: Text(
                  'Sem movimentação nos últimos meses.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ),
            )
          else
            FinGroupedBarChart(groups: fluxo),
        ],
      ),
    );
  }
}

/* ─────────────────────── tabela por conta ─────────────────────── */

class _ContasTable extends StatelessWidget {
  const _ContasTable({
    required this.contas,
    required this.viewLancs,
    required this.saldoFinal,
  });

  final List<FinConta> contas;
  final List<FinLancamento> viewLancs;
  final double saldoFinal;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final linhas = contas.map((c) {
      final doConta = viewLancs.where((l) => l.contaId == c.id).toList();
      final t = _totaisPorTipo(doConta);
      return (conta: c, entradas: t.receita, saidas: t.despesa);
    }).toList();

    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinSectionHeader(
            title: 'Movimentação por conta',
            trailing: Text(
              'Saldo geral: ${formatCurrency(saldoFinal)}',
              style: tt.labelMedium?.copyWith(color: clx.ink3),
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          if (linhas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Center(
                child: Text(
                  'Nenhuma conta cadastrada.',
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ),
            )
          else ...[
            _headerRow(context, const ['Conta', 'Entradas', 'Saídas', 'Saldo atual']),
            Divider(height: 1, color: clx.line),
            for (final l in linhas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        l.conta.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: clx.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _cell(context, formatCurrency(l.entradas), clx.finIncome),
                    _cell(context, formatCurrency(l.saidas), clx.finExpense),
                    _cell(
                      context,
                      formatCurrency(l.conta.saldoAtual),
                      l.conta.saldoAtual < 0 ? clx.finExpense : clx.ink,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _headerRow(BuildContext context, List<String> cols) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x2),
      child: Row(
        children: [
          for (var i = 0; i < cols.length; i++)
            Expanded(
              flex: i == 0 ? 2 : 1,
              child: Text(
                cols[i],
                textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: clx.ink3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String value, Color color) {
    return Expanded(
      child: Text(
        value,
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/* ─────────────────────── tabela por tag ─────────────────────── */

class _TagsTable extends StatelessWidget {
  const _TagsTable({required this.viewLancs});
  final List<FinLancamento> viewLancs;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final m = <String, ({double receita, double despesa, int count})>{};
    for (final l in viewLancs) {
      for (final tag in l.tags) {
        final cur = m[tag] ?? (receita: 0.0, despesa: 0.0, count: 0);
        m[tag] = (
          receita: cur.receita + (l.tipo == TipoLancamento.receita ? l.valor : 0),
          despesa: cur.despesa + (l.tipo == TipoLancamento.despesa ? l.valor : 0),
          count: cur.count + 1,
        );
      }
    }
    final linhas = m.entries.toList()
      ..sort(
        (a, b) => (b.value.receita + b.value.despesa).compareTo(
          a.value.receita + a.value.despesa,
        ),
      );

    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinSectionHeader(title: 'Lançamentos por tag'),
          const SizedBox(height: ClxSpace.x3),
          if (linhas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: EmptyState(
                icon: Icons.sell_outlined,
                title: 'Nenhuma tag no período',
                message: 'Adicione tags aos lançamentos para vê-los aqui.',
              ),
            )
          else
            for (final e in linhas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ClxChip(
                          label: e.key,
                          color: clx.ink2,
                          dense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${e.value.count}',
                        textAlign: TextAlign.right,
                        style: tt.bodyMedium?.copyWith(color: clx.ink2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatCurrency(e.value.receita),
                        textAlign: TextAlign.right,
                        style: tt.bodyMedium?.copyWith(
                          color: clx.finIncome,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatCurrency(e.value.despesa),
                        textAlign: TextAlign.right,
                        style: tt.bodyMedium?.copyWith(
                          color: clx.finExpense,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
