/// fin_relatorios_screen.dart — Relatórios densos do Financeiro (estilo Organizze).
///
/// Filtros (categoria/conta/status; período = mês via seletor BRT) + abas
/// (Categorias / Entradas x Saídas / Contas / Tags), explorer Organizze por
/// categoria, fluxo de caixa de 6 meses, resumo e tabelas. Os dados vêm do
/// provider de 6 meses (paginado). Exportar/Imprimir sinaliza impressão do SO.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'charts/fin_charts.dart';
import 'fin_chips.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_export.dart';
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

enum _Tab { categorias, fluxo }

extension on _Tab {
  String get label => switch (this) {
    _Tab.categorias => 'Categorias',
    _Tab.fluxo => 'Entradas × Saídas',
  };
}

class FinRelatoriosScreen extends ConsumerStatefulWidget {
  const FinRelatoriosScreen({super.key});

  @override
  ConsumerState<FinRelatoriosScreen> createState() =>
      _FinRelatoriosScreenState();
}

class _FinRelatoriosScreenState extends ConsumerState<FinRelatoriosScreen> {
  _Tab _tab = _Tab.categorias;

  /// Multi-select Organizze: vazio = todas.
  final Set<String> _catIds = {};
  final Set<String> _contaIds = {};

  /// null = todos · true = só pagos · false = só não-pagos.
  bool? _onlyPago;

  /// Inclui lançamentos ainda não pagos (pendente/previsto/atraso) nos totais.
  /// Desligado = só realizados (status pago), padrão Organizze.
  bool _incluirNaoPagos = false;

  bool get _hasFilters =>
      _catIds.isNotEmpty ||
      _contaIds.isNotEmpty ||
      _onlyPago != null ||
      _incluirNaoPagos;

  Future<void> _export() async {
    final lancs =
        ref.read(finRelatorioLancamentosProvider).valueOrNull ??
            const <FinLancamento>[];
    final cats =
        ref.read(finCategoriasProvider).valueOrNull ?? const <FinCategoria>[];
    final contas =
        ref.read(finContasProvider).valueOrNull ?? const <FinConta>[];
    final period = ref.read(finPeriodProvider);
    await finExportLancamentosCsv(
      context,
      lancs: lancs,
      catById: {for (final c in cats) c.id: c},
      contaById: {for (final c in contas) c.id: c},
      filename:
          'cleanox-relatorio-${period.year}-${period.month.toString().padLeft(2, '0')}.csv',
    );
  }

  Future<void> _openFiltros(
    List<FinCategoria> categorias,
    List<FinConta> contas,
  ) async {
    final result = await showDialog<_FiltrosResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _OrganizzeFiltrosDialog(
        categorias: categorias,
        contas: contas.where((c) => c.ativo).toList(),
        initialCatIds: Set.of(_catIds),
        initialContaIds: Set.of(_contaIds),
        initialOnlyPago: _onlyPago,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _catIds
        ..clear()
        ..addAll(result.catIds);
      _contaIds
        ..clear()
        ..addAll(result.contaIds);
      _onlyPago = result.onlyPago;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lancAsync = ref.watch(finRelatorioLancamentosProvider);
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    final mobile = finIsMobile(context);

    final leadingChildren = mobile
        ? <Widget>[
            _MobileHeader(
              hasFilters: _hasFilters,
              incluirNaoPagos: _incluirNaoPagos,
              onToggleNaoPagos: () =>
                  setState(() => _incluirNaoPagos = !_incluirNaoPagos),
              onOpenFiltros: () => _openFiltros(categorias, contas),
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
        catIds: _catIds,
        contaIds: _contaIds,
        onlyPago: _onlyPago,
        incluirNaoPagos: _incluirNaoPagos,
        onToggleNaoPagos: () =>
            setState(() => _incluirNaoPagos = !_incluirNaoPagos),
        hasFilters: _hasFilters,
        onOpenFiltros: () => _openFiltros(categorias, contas),
        mobile: mobile,
        leadingChildren: leadingChildren,
      ),
    );

    if (mobile) return body;

    return Column(
      children: [
        _Header(
          hasFilters: _hasFilters,
          incluirNaoPagos: _incluirNaoPagos,
          onToggleNaoPagos: () =>
              setState(() => _incluirNaoPagos = !_incluirNaoPagos),
          onOpenFiltros: () => _openFiltros(categorias, contas),
          onExport: _export,
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.hasFilters,
    required this.incluirNaoPagos,
    required this.onToggleNaoPagos,
    required this.onOpenFiltros,
    required this.onExport,
  });

  final bool hasFilters;
  final bool incluirNaoPagos;
  final VoidCallback onToggleNaoPagos;
  final VoidCallback onOpenFiltros;
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Relatórios',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: clx.ink),
            ),
          ),
          _NaoPagasToggle(
            active: incluirNaoPagos,
            onTap: onToggleNaoPagos,
          ),
          const SizedBox(width: ClxSpace.x2),
          FinFiltrosToggle(
            active: false,
            hasActiveFilters: hasFilters,
            onTap: onOpenFiltros,
          ),
          const SizedBox(width: ClxSpace.x2),
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
    );
  }
}

/// Botão: incluir lançamentos ainda não pagos nos totais do relatório.
class _NaoPagasToggle extends StatelessWidget {
  const _NaoPagasToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: ClxRadii.rPill,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x3,
          vertical: ClxSpace.x2,
        ),
        decoration: BoxDecoration(
          color: active ? clx.warning.withValues(alpha: 0.16) : clx.bg2,
          borderRadius: ClxRadii.rPill,
          border: Border.all(color: active ? clx.warning : clx.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.pending_actions_rounded
                  : Icons.pending_outlined,
              size: 18,
              color: active ? clx.warning : clx.ink3,
            ),
            const SizedBox(width: ClxSpace.x2),
            Text(
              active ? 'Não pagas: on' : 'Incluir não pagas',
              style: tt.labelLarge?.copyWith(
                color: active ? clx.warning : clx.ink2,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.hasFilters,
    required this.incluirNaoPagos,
    required this.onToggleNaoPagos,
    required this.onOpenFiltros,
    required this.onExport,
  });

  final bool hasFilters;
  final bool incluirNaoPagos;
  final VoidCallback onToggleNaoPagos;
  final VoidCallback onOpenFiltros;
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
        Row(
          children: [
            Flexible(
              child: _NaoPagasToggle(
                active: incluirNaoPagos,
                onTap: onToggleNaoPagos,
              ),
            ),
            const SizedBox(width: ClxSpace.x2),
            FinFiltrosToggle(
              active: false,
              hasActiveFilters: hasFilters,
              onTap: onOpenFiltros,
            ),
            const Spacer(),
            ClxButton(
              label: 'Exportar PDF',
              icon: Icons.picture_as_pdf_outlined,
              variant: ClxButtonVariant.ghost,
              onPressed: onExport,
            ),
          ],
        ),
      ],
    );
  }
}

/* ─────────────────────── Modal Filtros Organizze ─────────────────────── */

class _FiltrosResult {
  const _FiltrosResult({
    required this.catIds,
    required this.contaIds,
    required this.onlyPago,
  });

  final Set<String> catIds;
  final Set<String> contaIds;
  final bool? onlyPago;
}

class _OrganizzeFiltrosDialog extends StatefulWidget {
  const _OrganizzeFiltrosDialog({
    required this.categorias,
    required this.contas,
    required this.initialCatIds,
    required this.initialContaIds,
    required this.initialOnlyPago,
  });

  final List<FinCategoria> categorias;
  final List<FinConta> contas;
  final Set<String> initialCatIds;
  final Set<String> initialContaIds;
  final bool? initialOnlyPago;

  @override
  State<_OrganizzeFiltrosDialog> createState() =>
      _OrganizzeFiltrosDialogState();
}

class _OrganizzeFiltrosDialogState extends State<_OrganizzeFiltrosDialog> {
  late Set<String> _cats;
  late Set<String> _contas;
  bool? _onlyPago;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _cats = Set.of(widget.initialCatIds);
    _contas = Set.of(widget.initialContaIds);
    _onlyPago = widget.initialOnlyPago;
  }

  List<FinCategoria> get _roots {
    final list = widget.categorias
        .where((c) => c.parentId == null && !c.arquivada)
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
    return list;
  }

  List<FinCategoria> _subsOf(String rootId) => widget.categorias
      .where((c) => c.parentId == rootId && !c.arquivada)
      .toList()
    ..sort((a, b) => a.nome.compareTo(b.nome));

  void _toggleCat(String id) {
    setState(() {
      if (_cats.contains(id)) {
        _cats.remove(id);
      } else {
        _cats.add(id);
      }
    });
  }

  void _selectAllCats() {
    setState(() {
      _cats
        ..clear()
        ..addAll(widget.categorias.where((c) => !c.arquivada).map((c) => c.id));
    });
  }

  void _clearCats() => setState(() => _cats.clear());

  void _toggleConta(String id) {
    setState(() {
      if (_contas.contains(id)) {
        _contas.remove(id);
      } else {
        _contas.add(id);
      }
    });
  }

  void _selectAllContas() {
    setState(() {
      _contas
        ..clear()
        ..addAll(widget.contas.map((c) => c.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final roots = _roots;
    final allCatsSelected = _cats.isEmpty ||
        _cats.length >= widget.categorias.where((c) => !c.arquivada).length;
    final allContasSelected =
        _contas.isEmpty || _contas.length >= widget.contas.length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: ClxRadii.rLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ClxSpace.x5,
                ClxSpace.x4,
                ClxSpace.x2,
                ClxSpace.x2,
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, color: clx.ink2, size: 22),
                  const SizedBox(width: ClxSpace.x2),
                  Text(
                    'Filtros',
                    style: tt.titleMedium?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: clx.ink2),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(ClxSpace.x5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Categorias ──
                    Row(
                      children: [
                        Text(
                          'Categorias',
                          style: tt.titleSmall?.copyWith(
                            color: clx.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: ClxSpace.x2),
                        TextButton(
                          onPressed: allCatsSelected
                              ? _clearCats
                              : _selectAllCats,
                          child: Text(
                            allCatsSelected
                                ? 'limpar seleção'
                                : 'selecionar todas',
                            style: tt.labelLarge?.copyWith(
                              color: clx.finIncome,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(
                            context,
                            _FiltrosResult(
                              catIds: Set.of(_cats),
                              contaIds: Set.of(_contas),
                              onlyPago: _onlyPago,
                            ),
                          ),
                          child: const Text('Aplicar seleção'),
                        ),
                      ],
                    ),
                    const SizedBox(height: ClxSpace.x3),
                    Wrap(
                      spacing: ClxSpace.x2,
                      runSpacing: ClxSpace.x2,
                      children: [
                        for (final root in roots) ...[
                          _FilterChipCat(
                            cat: root,
                            selected: _cats.isEmpty ||
                                _cats.contains(root.id) ||
                                _subsOf(root.id)
                                    .any((s) => _cats.contains(s.id)),
                            hasSubs: _subsOf(root.id).isNotEmpty,
                            expanded: _expanded.contains(root.id),
                            onTap: () => _toggleCat(root.id),
                            onExpand: _subsOf(root.id).isEmpty
                                ? null
                                : () => setState(() {
                                      if (_expanded.contains(root.id)) {
                                        _expanded.remove(root.id);
                                      } else {
                                        _expanded.add(root.id);
                                      }
                                    }),
                          ),
                          if (_expanded.contains(root.id))
                            for (final sub in _subsOf(root.id))
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _FilterChipCat(
                                  cat: sub,
                                  selected: _cats.isEmpty ||
                                      _cats.contains(sub.id) ||
                                      _cats.contains(root.id),
                                  hasSubs: false,
                                  expanded: false,
                                  onTap: () => _toggleCat(sub.id),
                                  small: true,
                                ),
                              ),
                        ],
                      ],
                    ),
                    const SizedBox(height: ClxSpace.x5),
                    // ── Contas ──
                    Row(
                      children: [
                        Text(
                          'Contas e Cartões',
                          style: tt.titleSmall?.copyWith(
                            color: clx.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: ClxSpace.x2),
                        TextButton(
                          onPressed: allContasSelected
                              ? () => setState(() => _contas.clear())
                              : _selectAllContas,
                          child: Text(
                            allContasSelected
                                ? 'limpar seleção'
                                : 'selecionar todas',
                            style: tt.labelLarge?.copyWith(
                              color: clx.finIncome,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ClxSpace.x3),
                    Wrap(
                      spacing: ClxSpace.x2,
                      runSpacing: ClxSpace.x2,
                      children: [
                        for (final c in widget.contas)
                          _FilterChipConta(
                            conta: c,
                            selected:
                                _contas.isEmpty || _contas.contains(c.id),
                            onTap: () => _toggleConta(c.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: ClxSpace.x5),
                    // ── Status ──
                    Text(
                      'Status do pagamento',
                      style: tt.titleSmall?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x3),
                    Wrap(
                      spacing: ClxSpace.x2,
                      children: [
                        _FilterChipStatus(
                          label: 'Pagos',
                          icon: Icons.thumb_up_alt_rounded,
                          color: clx.finIncome,
                          selected: _onlyPago == true || _onlyPago == null,
                          exclusive: _onlyPago == true,
                          onTap: () => setState(() {
                            if (_onlyPago == true) {
                              _onlyPago = null;
                            } else {
                              _onlyPago = true;
                            }
                          }),
                        ),
                        _FilterChipStatus(
                          label: 'Não-pagos',
                          icon: Icons.thumb_down_alt_rounded,
                          color: clx.finExpense,
                          selected: _onlyPago == false || _onlyPago == null,
                          exclusive: _onlyPago == false,
                          onTap: () => setState(() {
                            if (_onlyPago == false) {
                              _onlyPago = null;
                            } else {
                              _onlyPago = false;
                            }
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipCat extends StatelessWidget {
  const _FilterChipCat({
    required this.cat,
    required this.selected,
    required this.hasSubs,
    required this.expanded,
    required this.onTap,
    this.onExpand,
    this.small = false,
  });

  final FinCategoria cat;
  final bool selected;
  final bool hasSubs;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback? onExpand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cor = finParseHex(cat.cor) ?? clx.primary;
    final size = small ? 28.0 : 36.0;
    return Material(
      color: selected ? cor.withValues(alpha: 0.10) : clx.bg2,
      borderRadius: ClxRadii.rPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rPill,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            ClxSpace.x2,
            ClxSpace.x1,
            hasSubs ? ClxSpace.x1 : ClxSpace.x3,
            ClxSpace.x1,
          ),
          decoration: BoxDecoration(
            borderRadius: ClxRadii.rPill,
            border: Border.all(
              color: selected ? cor : clx.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FinCategoriaAvatar(categoria: cat, size: size),
              const SizedBox(width: ClxSpace.x2),
              Text(
                cat.nome,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasSubs && onExpand != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: clx.ink3,
                  ),
                  onPressed: onExpand,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipConta extends StatelessWidget {
  const _FilterChipConta({
    required this.conta,
    required this.selected,
    required this.onTap,
  });

  final FinConta conta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cor = finParseHex(conta.cor) ?? clx.primary;
    return Material(
      color: selected ? cor.withValues(alpha: 0.10) : clx.bg2,
      borderRadius: ClxRadii.rPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rPill,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ClxSpace.x3,
            vertical: ClxSpace.x2,
          ),
          decoration: BoxDecoration(
            borderRadius: ClxRadii.rPill,
            border: Border.all(color: selected ? cor : clx.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(contaTipoIcon(conta.tipo), size: 16, color: cor),
              ),
              const SizedBox(width: ClxSpace.x2),
              Text(
                conta.nome,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipStatus extends StatelessWidget {
  const _FilterChipStatus({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.exclusive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool exclusive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final on = exclusive;
    return Material(
      color: on ? color.withValues(alpha: 0.12) : clx.bg2,
      borderRadius: ClxRadii.rPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rPill,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ClxSpace.x3,
            vertical: ClxSpace.x2,
          ),
          decoration: BoxDecoration(
            borderRadius: ClxRadii.rPill,
            border: Border.all(color: on ? color : clx.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: ClxSpace.x2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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
    required this.catIds,
    required this.contaIds,
    required this.onlyPago,
    required this.incluirNaoPagos,
    required this.onToggleNaoPagos,
    required this.hasFilters,
    required this.onOpenFiltros,
    this.mobile = false,
    this.leadingChildren = const [],
  });

  final List<FinLancamento> todos;
  final List<FinConta> contas;
  final List<FinCategoria> categorias;
  final _Tab tab;
  final ValueChanged<_Tab> onTab;
  final Set<String> catIds;
  final Set<String> contaIds;
  final bool? onlyPago;
  final bool incluirNaoPagos;
  final VoidCallback onToggleNaoPagos;
  final bool hasFilters;
  final VoidCallback onOpenFiltros;

  /// Layout de celular: reduz o padding e recebe o cabeçalho rolável.
  final bool mobile;

  /// Widgets inseridos ANTES das abas (cabeçalho mobile). Vazio no desktop.
  final List<Widget> leadingChildren;

  /// Status: filtro do modal (onlyPago) tem prioridade; senão o botão
  /// "Incluir não pagas" (default = só pagos / realizados).
  List<FinLancamento> _applyStatus(List<FinLancamento> l) {
    if (onlyPago != null) {
      if (onlyPago!) {
        return l.where((x) => x.status == LancamentoStatus.pago).toList();
      }
      return l.where((x) => x.status != LancamentoStatus.pago).toList();
    }
    if (incluirNaoPagos) return l;
    return l.where((x) => x.status == LancamentoStatus.pago).toList();
  }

  bool _passaFiltrosCatConta(FinLancamento l) {
    if (catIds.isNotEmpty &&
        !catIds.contains(l.categoriaId) &&
        !(l.subcategoriaId != null && catIds.contains(l.subcategoriaId))) {
      return false;
    }
    if (contaIds.isNotEmpty && !contaIds.contains(l.contaId)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final period = ref.watch(finPeriodProvider);
        final periodo = period.periodo;

        // Comissões pendentes → despesas previstas em Equipe → Profissionais.
        // Entram na lista base; _applyStatus só as mantém com "Incluir não pagas"
        // (status previsto) ou filtro "só não pagas".
        final comissoes =
            ref.watch(finComissoesProvider).valueOrNull ?? const [];
        final profs =
            ref.watch(finProfissionaisProvider).valueOrNull ?? const [];
        final nomePorProf = {
          for (final u in profs)
            if (u.displayName.trim().isNotEmpty) u.id: u.displayName.trim(),
        };
        String contaPadrao = '';
        for (final c in contas) {
          if (c.ativo) {
            contaPadrao = c.id;
            break;
          }
        }
        final comissaoPrevistas = finComissoesPendentesComoLancamentos(
          comissoes: comissoes,
          categorias: categorias,
          profissionais: profs,
          nomePorProfId: nomePorProf,
          contaId: contaPadrao,
        );

        final idsTodos = {for (final l in todos) l.id};
        final unidos = [
          ...todos,
          ...comissaoPrevistas.where((l) => !idsTodos.contains(l.id)),
        ];

        // Filtro multi-select (vazio = todas) sobre os 6 meses + sintéticos.
        final base = unidos.where(_passaFiltrosCatConta).toList();

        final viewLancs = _applyStatus(lancamentosDoPeriodo(base, periodo));
        final periodoVazio = viewLancs.isEmpty;

        return ListView(
          padding: EdgeInsets.all(mobile ? ClxSpace.x4 : ClxSpace.x6),
          children: [
            ...leadingChildren,
            // Abas + Filtros (botão "Incluir não pagas" fica no header).
            Row(
              children: [
                Expanded(child: _Tabs(active: tab, onTab: onTab)),
                const SizedBox(width: ClxSpace.x2),
                FinFiltrosToggle(
                  active: false,
                  hasActiveFilters: hasFilters,
                  onTap: onOpenFiltros,
                ),
              ],
            ),
            const SizedBox(height: ClxSpace.x4),
            // Entradas×Saídas tem painel próprio (mesmo com mês atual vazio).
            if (periodoVazio && tab != _Tab.fluxo)
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
                viewLancs: viewLancs,
                allLancs: base,
                period: period,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _tabContent(
    BuildContext context, {
    required List<FinLancamento> viewLancs,
    required List<FinLancamento> allLancs,
    required FinPeriod period,
  }) {
    switch (tab) {
      case _Tab.categorias:
        return [
          _OrganizzeCatExplorer(
            lancs: viewLancs,
            categorias: categorias,
            mobile: mobile,
          ),
        ];
      case _Tab.fluxo:
        return [
          _EntradasSaidasOrganizze(
            // allLancs já sem filtro de status do mês; o toggle global
            // controla se entram não-pagos (via _applyStatus em viewLancs
            // não se aplica a allLancs — reaplicar aqui).
            lancs: _applyStatus(allLancs),
            period: period,
            mobile: mobile,
            incluirNaoPagos: incluirNaoPagos,
          ),
        ];
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

/* ─────────────────────── Categorias estilo Organizze ─────────────────────── */

/// Valor monetário sem "R$" (como o Organizze: 2.178,43).
String _valorOrg(num v) =>
    formatCurrency(v).replaceFirst(RegExp(r'^R\$\s*'), '');

String _pctOrg(double fraction) =>
    '${(fraction * 100).toStringAsFixed(2).replaceAll('.', ',')}%';

/// Despesas (cima) + Receitas (baixo), cada bloco com lista + donut.
class _OrganizzeCatExplorer extends StatelessWidget {
  const _OrganizzeCatExplorer({
    required this.lancs,
    required this.categorias,
    this.mobile = false,
  });

  final List<FinLancamento> lancs;
  final List<FinCategoria> categorias;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrganizzeTipoPanel(
          tipo: TipoLancamento.despesa,
          titulo: 'Despesas',
          lancs: lancs,
          categorias: categorias,
          mobile: mobile,
        ),
        const SizedBox(height: ClxSpace.x5),
        _OrganizzeTipoPanel(
          tipo: TipoLancamento.receita,
          titulo: 'Receitas',
          lancs: lancs,
          categorias: categorias,
          mobile: mobile,
        ),
      ],
    );
  }
}

/// Um bloco Organizze (Despesas ou Receitas): drill hierárquico + donut.
class _OrganizzeTipoPanel extends StatefulWidget {
  const _OrganizzeTipoPanel({
    required this.tipo,
    required this.titulo,
    required this.lancs,
    required this.categorias,
    this.mobile = false,
  });

  final TipoLancamento tipo;
  final String titulo;
  final List<FinLancamento> lancs;
  final List<FinCategoria> categorias;
  final bool mobile;

  @override
  State<_OrganizzeTipoPanel> createState() => _OrganizzeTipoPanelState();
}

class _OrganizzeTipoPanelState extends State<_OrganizzeTipoPanel> {
  /// Acordeão: no máximo UMA raiz aberta por vez (null = todas fechadas).
  String? _openRootId;
  final Set<String> _openSubs = {};

  /// Confia no filtro de status do pai (só pagos / incluir não pagas / modal).
  List<FinLancamento> get _typed =>
      widget.lancs.where((l) => l.tipo == widget.tipo).toList();

  List<FinCategoria> _childrenOf(String? parentId) {
    return widget.categorias
        .where(
          (c) =>
              !c.arquivada &&
              c.tipo == widget.tipo &&
              (parentId == null
                  ? c.parentId == null
                  : c.parentId == parentId),
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }

  double _totalDaCategoria(String catId) {
    var cents = 0;
    final children = {for (final c in _childrenOf(catId)) c.id};
    for (final l in _typed) {
      if (l.categoriaId == catId ||
          l.subcategoriaId == catId ||
          children.contains(l.categoriaId) ||
          children.contains(l.subcategoriaId)) {
        cents += (l.valor * 100).round();
      }
    }
    return cents / 100.0;
  }

  double _totalDaSub(String rootId, String subId) {
    var cents = 0;
    for (final l in _typed) {
      if (l.subcategoriaId == subId ||
          (l.categoriaId == subId &&
              (l.subcategoriaId == null || l.subcategoriaId!.isEmpty)) ||
          (l.categoriaId == rootId && l.subcategoriaId == subId)) {
        cents += (l.valor * 100).round();
      }
    }
    return cents / 100.0;
  }

  List<FinLancamento> _lancsDaSub(String rootId, String subId) {
    final out = _typed.where((l) {
      if (l.subcategoriaId == subId) return true;
      if (l.categoriaId == subId &&
          (l.subcategoriaId == null || l.subcategoriaId!.isEmpty)) {
        return true;
      }
      if (l.categoriaId == rootId && l.subcategoriaId == subId) return true;
      return false;
    }).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    return out;
  }

  List<FinLancamento> _lancsDaRaizDiretos(String rootId) {
    final childIds = {for (final c in _childrenOf(rootId)) c.id};
    return _typed.where((l) {
      if (l.categoriaId != rootId) return false;
      final sub = l.subcategoriaId;
      if (sub == null || sub.isEmpty) return true;
      return !childIds.contains(sub);
    }).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
  }

  void _toggleRoot(String id) {
    setState(() {
      if (_openRootId == id) {
        // Fecha a aberta.
        _openRootId = null;
        _openSubs.clear();
      } else {
        // Fecha a anterior e abre só a nova.
        _openRootId = id;
        _openSubs.clear();
      }
    });
  }

  /// Abre a categoria a partir do clique no donut (fecha as outras).
  void _openFromChart(FinSlice slice) {
    final id = slice.id;
    if (id == null || id.isEmpty) return;
    setState(() {
      _openRootId = id;
      _openSubs
        ..clear()
        ..addAll(
          _childrenOf(id)
              .where((s) => _totalDaSub(id, s.id) > 0)
              .map((s) => s.id),
        );
    });
  }

  void _toggleSub(String id) {
    setState(() {
      if (_openSubs.contains(id)) {
        _openSubs.remove(id);
      } else {
        _openSubs.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final typed = _typed;
    final totalGeral = typed.fold<double>(0, (s, l) => s + l.valor);

    final roots = _childrenOf(null)
        .map((r) => (cat: r, total: _totalDaCategoria(r.id)))
        .where((e) => e.total > 0)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final donutSlices = <FinSlice>[
      for (final e in roots)
        FinSlice(
          id: e.cat.id,
          label: e.cat.nome,
          value: e.total,
          color: finParseHex(e.cat.cor) ?? clx.primary,
        ),
    ];

    final listChildren = <Widget>[
      Text(
        widget.titulo,
        style: tt.titleMedium?.copyWith(
          color: clx.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: ClxSpace.x2),
    ];

    if (roots.isEmpty) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ClxSpace.x6),
          child: Center(
            child: Text(
              'Nenhum lançamento.',
              style: tt.bodyMedium?.copyWith(color: clx.ink3),
            ),
          ),
        ),
      );
    } else {
      for (final e in roots) {
        final root = e.cat;
        final rootOpen = _openRootId == root.id;
        final subs = _childrenOf(root.id)
            .map((s) => (cat: s, total: _totalDaSub(root.id, s.id)))
            .where((x) => x.total > 0)
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));
        final diretos = _lancsDaRaizDiretos(root.id);

        listChildren.add(
          _catRow(
            context,
            cat: root,
            total: e.total,
            pct: totalGeral > 0 ? e.total / totalGeral : 0,
            largeIcon: true,
            open: rootOpen,
            indent: 0,
            onTap: () => _toggleRoot(root.id),
          ),
        );

        if (rootOpen) {
          for (final se in subs) {
            final sub = se.cat;
            final subOpen = _openSubs.contains(sub.id);
            listChildren.add(
              _catRow(
                context,
                cat: sub,
                total: se.total,
                pct: e.total > 0 ? se.total / e.total : 0,
                largeIcon: false,
                open: subOpen,
                indent: 1,
                onTap: () => _toggleSub(sub.id),
              ),
            );
            if (subOpen) {
              for (final l in _lancsDaSub(root.id, sub.id)) {
                listChildren.add(_itemRow(context, l, indent: 2));
              }
            }
          }
          for (final l in diretos) {
            listChildren.add(_itemRow(context, l, indent: 1));
          }
        }
      }
    }

    listChildren.add(const Divider(height: ClxSpace.x5));
    listChildren.add(
      Row(
        children: [
          Text(
            'Total',
            style: tt.labelLarge?.copyWith(
              color: clx.ink2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _valorOrg(totalGeral),
            style: tt.titleSmall?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    final chartSize = widget.mobile ? 220.0 : 300.0;
    final chart = donutSlices.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: ClxSpace.x6),
            child: Center(
              child: Text(
                'Sem ${widget.titulo.toLowerCase()} no período.',
                style: tt.bodyMedium?.copyWith(color: clx.ink3),
              ),
            ),
          )
        : FinDonutChart(
            centerLabel: widget.titulo,
            size: chartSize,
            showLegend: false,
            interactive: true,
            slices: donutSlices,
            onSectionTap: _openFromChart,
          );

    // Um único card: lista + donut. No desktop o gráfico fica centralizado
    // verticalmente no card mesmo quando a lista cresce (categoria aberta).
    final body = widget.mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...listChildren,
              if (donutSlices.isNotEmpty) ...[
                const SizedBox(height: ClxSpace.x5),
                Center(child: chart),
              ],
            ],
          )
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: listChildren,
                  ),
                ),
                const SizedBox(width: ClxSpace.x5),
                Expanded(
                  flex: 4,
                  child: Center(child: chart),
                ),
              ],
            ),
          );

    // Entrada com motion ao abrir a página / trocar período.
    final delay = widget.tipo == TipoLancamento.despesa
        ? Duration.zero
        : const Duration(milliseconds: 90);
    return ClxFadeSlide(
      delay: delay,
      duration: ClxMotion.emphasizedDuration,
      offset: const Offset(0, 0.06),
      child: ClxScaleFade(
        delay: delay,
        beginScale: 0.97,
        child: ClxCard(child: body),
      ),
    );
  }

  Widget _catRow(
    BuildContext context, {
    required FinCategoria cat,
    required double total,
    required double pct,
    required bool largeIcon,
    required bool open,
    required int indent,
    required VoidCallback onTap,
  }) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final iconSize = largeIcon ? 40.0 : 28.0;
    return Material(
      color: open ? clx.bg2.withValues(alpha: 0.55) : Colors.transparent,
      borderRadius: ClxRadii.rMd,
      child: InkWell(
        borderRadius: ClxRadii.rMd,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ClxSpace.x2 + indent * ClxSpace.x4,
            ClxSpace.x2,
            ClxSpace.x1,
            ClxSpace.x2,
          ),
          child: Row(
            children: [
              FinCategoriaAvatar(categoria: cat, size: iconSize),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Text(
                  cat.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyLarge?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _valorOrg(total),
                    style: tt.bodyLarge?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _pctOrg(pct),
                    style: tt.labelMedium?.copyWith(
                      color: clx.ink3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Icon(
                open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 22,
                color: clx.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemRow(
    BuildContext context,
    FinLancamento l, {
    required int indent,
  }) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ClxSpace.x2 + indent * ClxSpace.x4 + 8,
        ClxSpace.x1,
        ClxSpace.x3,
        ClxSpace.x1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.descricao.isEmpty ? '(sem descrição)' : l.descricao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: clx.ink2),
                ),
                Text(
                  formatDateOnlyBr(l.data),
                  style: tt.labelSmall?.copyWith(color: clx.ink3),
                ),
              ],
            ),
          ),
          Text(
            _valorOrg(l.valor),
            style: tt.bodyMedium?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── Entradas × Saídas (Organizze) ─────────────────────── */

enum _FluxoGran { diario, semanal, mensal, acumulado }

/// Painel Entradas × Saídas: granulação (dia/semana/mês/acumulado), gráfico
/// barras+linha e tabela — espelha o Organizze.
class _EntradasSaidasOrganizze extends StatefulWidget {
  const _EntradasSaidasOrganizze({
    required this.lancs,
    required this.period,
    this.mobile = false,
    this.incluirNaoPagos = false,
  });

  final List<FinLancamento> lancs;
  final FinPeriod period;
  final bool mobile;

  /// Já aplicado no pai; usado só para o chip visual (estado do botão global).
  final bool incluirNaoPagos;

  @override
  State<_EntradasSaidasOrganizze> createState() =>
      _EntradasSaidasOrganizzeState();
}

class _EntradasSaidasOrganizzeState extends State<_EntradasSaidasOrganizze> {
  _FluxoGran _gran = _FluxoGran.semanal;

  /// Mensal só após existir pelo menos 1 mês civil completo no sistema.
  bool get _mensalDisponivel {
    if (widget.lancs.isEmpty) return false;
    var minD = '9999-99-99';
    for (final l in widget.lancs) {
      final d = dateOnly(l.data);
      if (d.isNotEmpty && d.compareTo(minD) < 0) minD = d;
    }
    if (minD.startsWith('9999')) return false;
    final hoje = todayLocalDate(); // BRT YYYY-MM-DD
    final mesAtualStart = '${hoje.substring(0, 7)}-01';
    // Há lançamento antes do mês corrente → já passou ao menos um mês civil.
    return minD.compareTo(mesAtualStart) < 0;
  }

  /// Status já filtrado pelo botão global / modal no pai.
  List<FinLancamento> get _filtrados => widget.lancs;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    if (!_mensalDisponivel && _gran == _FluxoGran.mensal) {
      // Se perdeu elegibilidade, volta para semanal.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _gran == _FluxoGran.mensal) {
          setState(() => _gran = _FluxoGran.semanal);
        }
      });
    }

    final buckets = _buildBuckets(_filtrados);
    final vazio = buckets.every((b) => b.entradas == 0 && b.saidas == 0);

    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Entradas × Saídas',
            style: tt.titleMedium?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ClxSpace.x4),
          // Filtros de granulação + checkbox.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: ClxSpace.x2,
            runSpacing: ClxSpace.x2,
            children: [
              for (final g in _FluxoGran.values)
                _granChip(
                  context,
                  g,
                  enabled: g != _FluxoGran.mensal || _mensalDisponivel,
                ),
              if (widget.incluirNaoPagos) ...[
                const SizedBox(width: ClxSpace.x3),
                Text(
                  'Incluindo não pagas',
                  style: tt.labelMedium?.copyWith(
                    color: clx.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (!_mensalDisponivel) ...[
            const SizedBox(height: ClxSpace.x2),
            Text(
              'O filtro mensal fica disponível após o sistema completar um mês inteiro de dados.',
              style: tt.bodySmall?.copyWith(color: clx.ink3),
            ),
          ],
          const SizedBox(height: ClxSpace.x5),
          if (vazio)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x8),
              child: Center(
                child: Text(
                  'Sem movimentação no período.',
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ),
            )
          else ...[
            FinEntradasSaidasChart(
              buckets: buckets,
              height: widget.mobile ? 240 : 300,
            ),
            const SizedBox(height: ClxSpace.x6),
            _fluxoTabela(context, buckets),
          ],
        ],
      ),
    );
  }

  Widget _granChip(BuildContext context, _FluxoGran g, {required bool enabled}) {
    final clx = context.clx;
    final selected = _gran == g;
    final label = switch (g) {
      _FluxoGran.diario => 'diário',
      _FluxoGran.semanal => 'semanal',
      _FluxoGran.mensal => 'mensal',
      _FluxoGran.acumulado => 'acumulado',
    };
    final color = !enabled
        ? clx.ink3.withValues(alpha: 0.45)
        : selected
            ? clx.primary
            : clx.ink2;
    return InkWell(
      onTap: !enabled
          ? null
          : () => setState(() => _gran = g),
      borderRadius: ClxRadii.rSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x2,
          vertical: ClxSpace.x1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: ClxMotion.shortDuration,
              height: 3,
              width: selected && enabled ? 28 : 0,
              decoration: BoxDecoration(
                color: clx.primary,
                borderRadius: ClxRadii.rPill,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fluxoTabela(BuildContext context, List<FinFluxoBucket> buckets) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;

    if (widget.mobile) {
      // R4: card por linha no APK / web estreita.
      return Column(
        children: [
          for (final b in buckets) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ClxSpace.x3),
              decoration: BoxDecoration(
                color: clx.bg2,
                borderRadius: ClxRadii.rMd,
                border: Border.all(color: clx.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.label,
                    style: tt.titleSmall?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x2),
                  _kv(context, 'Entradas', b.entradas, clx.finIncome),
                  _kv(context, 'Saídas', -b.saidas, clx.finExpense),
                  _kv(
                    context,
                    'Resultado',
                    b.resultado,
                    b.resultado >= 0 ? clx.finIncome : clx.finExpense,
                    signed: true,
                  ),
                  _kv(
                    context,
                    'Saldo',
                    b.saldo,
                    b.saldo >= 0 ? clx.finIncome : clx.finExpense,
                  ),
                ],
              ),
            ),
            const SizedBox(height: ClxSpace.x2),
          ],
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
          child: Row(
            children: [
              const Expanded(flex: 3, child: SizedBox.shrink()),
              Expanded(child: _th(context, 'Entradas')),
              Expanded(child: _th(context, 'Saídas')),
              Expanded(child: _th(context, 'Resultado')),
              Expanded(child: _th(context, 'Saldo')),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        for (final b in buckets) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: ClxSpace.x3),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    b.label,
                    style: tt.bodyMedium?.copyWith(color: clx.ink2),
                  ),
                ),
                Expanded(
                  child: _td(
                    context,
                    b.entradas,
                    clx.finIncome,
                  ),
                ),
                Expanded(
                  child: _td(
                    context,
                    -b.saidas,
                    clx.finExpense,
                  ),
                ),
                Expanded(
                  child: _td(
                    context,
                    b.resultado,
                    b.resultado >= 0 ? clx.finIncome : clx.finExpense,
                    signed: true,
                  ),
                ),
                Expanded(
                  child: _td(
                    context,
                    b.saldo,
                    b.saldo >= 0 ? clx.finIncome : clx.finExpense,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: clx.line.withValues(alpha: 0.6)),
        ],
      ],
    );
  }

  Widget _th(BuildContext context, String t) => Text(
        t,
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.clx.ink3,
              fontWeight: FontWeight.w600,
            ),
      );

  Widget _td(
    BuildContext context,
    double v,
    Color c, {
    bool signed = false,
  }) {
    // Organizze: saídas com sinal negativo; resultado com +/−.
    final text = signed
        ? '${v > 0 ? '+' : (v < 0 ? '-' : '')}${_valorOrg(v.abs())}'
        : v < 0
            ? '-${_valorOrg(v.abs())}'
            : _valorOrg(v);
    return Text(
      text,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: c,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _kv(
    BuildContext context,
    String label,
    double v,
    Color c, {
    bool signed = false,
  }) {
    final clx = context.clx;
    final text = signed
        ? '${v >= 0 ? '+' : (v < 0 ? '-' : '')}${_valorOrg(v.abs())}'
        : v < 0
            ? '-${_valorOrg(v.abs())}'
            : _valorOrg(v);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: clx.ink3,
                  ),
            ),
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  // ── buckets ──────────────────────────────────────────────────────────────

  List<FinFluxoBucket> _buildBuckets(List<FinLancamento> lancs) {
    return switch (_gran) {
      _FluxoGran.diario => _bucketsDiario(lancs),
      _FluxoGran.semanal => _bucketsSemanal(lancs),
      _FluxoGran.mensal => _bucketsMensal(lancs),
      _FluxoGran.acumulado => _bucketsAcumulado(lancs),
    };
  }

  List<FinFluxoBucket> _withSaldo(
    List<({String label, double ent, double sai})> raw,
  ) {
    var saldo = 0.0;
    final out = <FinFluxoBucket>[];
    for (final r in raw) {
      final res = r.ent - r.sai;
      saldo += res;
      out.add(
        FinFluxoBucket(
          label: r.label,
          entradas: r.ent,
          saidas: r.sai,
          resultado: res,
          saldo: saldo,
        ),
      );
    }
    return out;
  }

  ({double ent, double sai}) _totais(List<FinLancamento> list) {
    var ent = 0;
    var sai = 0;
    for (final l in list) {
      final c = (l.valor * 100).round();
      if (l.tipo == TipoLancamento.receita) {
        ent += c;
      } else {
        sai += c;
      }
    }
    return (ent: ent / 100.0, sai: sai / 100.0);
  }

  DateTime _parseDay(String ymd) {
    final d = dateOnly(ymd);
    return DateTime(
      int.parse(d.substring(0, 4)),
      int.parse(d.substring(5, 7)),
      int.parse(d.substring(8, 10)),
    );
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _labelDia(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_mesesAbbr[d.month - 1]}';

  String _labelFaixa(DateTime a, DateTime b) {
    // inclusivo no fim visual (b é exclusive no bucket)
    final fim = b.subtract(const Duration(days: 1));
    if (a.month == fim.month && a.year == fim.year) {
      return '${a.day.toString().padLeft(2, '0')} ${_mesesAbbr[a.month - 1]} '
          'à ${fim.day.toString().padLeft(2, '0')} ${_mesesAbbr[fim.month - 1]}';
    }
    return '${a.day.toString().padLeft(2, '0')} ${_mesesAbbr[a.month - 1]} '
        'à ${fim.day.toString().padLeft(2, '0')} ${_mesesAbbr[fim.month - 1]}';
  }

  List<FinFluxoBucket> _bucketsDiario(List<FinLancamento> lancs) {
    final p = widget.period.periodo;
    final start = _parseDay(p.start);
    var end = _parseDay(p.end); // exclusive
    final hoje = _parseDay(todayLocalDate());
    // No mês corrente, só até hoje.
    if (end.isAfter(hoje.add(const Duration(days: 1)))) {
      end = hoje.add(const Duration(days: 1));
    }
    if (!end.isAfter(start)) end = start.add(const Duration(days: 1));

    final raw = <({String label, double ent, double sai})>[];
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final day = _ymd(d);
      final next = _ymd(d.add(const Duration(days: 1)));
      final t = _totais(
        lancs.where((l) {
          final x = dateOnly(l.data);
          return x.compareTo(day) >= 0 && x.compareTo(next) < 0;
        }).toList(),
      );
      raw.add((label: _labelDia(d), ent: t.ent, sai: t.sai));
    }
    return _withSaldo(raw);
  }

  List<FinFluxoBucket> _bucketsSemanal(List<FinLancamento> lancs) {
    final p = widget.period.periodo;
    final monthStart = _parseDay(p.start);
    final monthEndEx = _parseDay(p.end);
    // Segunda-feira on or before month start.
    var weekStart = monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final raw = <({String label, double ent, double sai})>[];
    while (weekStart.isBefore(monthEndEx)) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final t = _totais(
        lancs.where((l) {
          final x = dateOnly(l.data);
          return x.compareTo(_ymd(weekStart)) >= 0 &&
              x.compareTo(_ymd(weekEnd)) < 0;
        }).toList(),
      );
      raw.add((
        label: _labelFaixa(weekStart, weekEnd),
        ent: t.ent,
        sai: t.sai,
      ));
      weekStart = weekEnd;
    }
    return _withSaldo(raw);
  }

  List<FinFluxoBucket> _bucketsMensal(List<FinLancamento> lancs) {
    // Últimos 6 meses até o selecionado.
    final raw = <({String label, double ent, double sai})>[];
    for (var i = 5; i >= 0; i--) {
      final fp = widget.period.shift(-i);
      final per = fp.periodo;
      final t = _totais(
        lancs.where((l) {
          final x = dateOnly(l.data);
          return x.compareTo(per.start) >= 0 && x.compareTo(per.end) < 0;
        }).toList(),
      );
      raw.add((
        label: '${_mesesAbbr[fp.month - 1]} ${fp.year}',
        ent: t.ent,
        sai: t.sai,
      ));
    }
    return _withSaldo(raw);
  }

  List<FinFluxoBucket> _bucketsAcumulado(List<FinLancamento> lancs) {
    // Total do mês (ainda incompleto) do seletor — um bucket só.
    final p = widget.period.periodo;
    final start = _parseDay(p.start);
    var endEx = _parseDay(p.end);
    final hoje = _parseDay(todayLocalDate());
    final cur = FinPeriod.currentBrt();
    if (widget.period.year == cur.year && widget.period.month == cur.month) {
      endEx = hoje.add(const Duration(days: 1));
    }
    final t = _totais(
      lancs.where((l) {
        final x = dateOnly(l.data);
        return x.compareTo(p.start) >= 0 && x.compareTo(_ymd(endEx)) < 0;
      }).toList(),
    );
    final label = _labelFaixa(start, endEx);
    return _withSaldo([(label: label, ent: t.ent, sai: t.sai)]);
  }
}

