/// fin_lancamentos_screen.dart — Lista de Lançamentos (CRUD, estilo Organizze).
///
/// Espelha `Lancamentos.tsx`: 4 KPIs do período (com variação vs. mês anterior),
/// lista agrupada por DIA (BRT) com total do dia, filtros (mês/busca/tipo/status/
/// categoria/conta) e CRUD por modal. Cada linha traz origem/conta/recorrência/
/// status; clicar abre o painel de detalhes; o kebab tem Ver detalhes, Editar,
/// Repetir, Copiar e Excluir. Lista VIRTUALIZADA (`ListView.builder`) com
/// PAGINAÇÃO no servidor + scroll infinito. Estados carregando/erro/vazio/sucesso.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/formatters/formatters.dart';
import '../../../core/models/financeiro.dart';
import '../fin_chips.dart';
import '../fin_common.dart';
import '../fin_derivations.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';
import 'fin_lancamentos_controller.dart';
import 'lancamento_detail_panel.dart';
import 'lancamento_form.dart';

/// Primeiro elemento que casa [test], ou `null` (sem depender de package:collection).
T? _firstOrNull<T>(Iterable<T> it, bool Function(T) test) {
  for (final e in it) {
    if (test(e)) return e;
  }
  return null;
}

class FinLancamentosScreen extends ConsumerStatefulWidget {
  const FinLancamentosScreen({super.key});

  @override
  ConsumerState<FinLancamentosScreen> createState() =>
      _FinLancamentosScreenState();
}

class _FinLancamentosScreenState extends ConsumerState<FinLancamentosScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  /// Mobile: filtro (busca + chips) colapsado por padrão para priorizar a lista.
  /// No desktop os filtros ficam sempre visíveis (este flag é ignorado).
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(finLancControllerProvider.notifier).loadMore();
    }
  }

  FinLancFilters get _filters => ref.read(finLancControllerProvider).filters;

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(finLancControllerProvider.notifier)
          .setFilters(_filters.copyWith(search: value));
    });
  }

  Future<void> _refreshAfterMutation() async {
    await ref.read(finLancControllerProvider.notifier).refresh();
    ref.invalidate(finContasProvider);
    ref.invalidate(finPeriodLancamentosProvider);
    ref.invalidate(finPrevPeriodResumoProvider);
    ref.invalidate(finPendentesProvider);
  }

  Future<void> _openForm({FinLancamento? editing}) async {
    final saved = await showLancamentoForm(
      context,
      editing: editing,
      // Criação herda o tipo do filtro ativo (Receitas/Despesas); com filtro
      // em "Todos" ou na edição, mantém o default do form.
      initialTipo: editing == null ? _filters.tipo : null,
    );
    if (saved == true) {
      await _refreshAfterMutation();
      if (mounted) {
        showClxToast(
          context,
          editing == null ? 'Lançamento criado.' : 'Lançamento atualizado.',
          type: ToastType.success,
        );
      }
    }
  }

  Future<void> _repeat(FinLancamento l) async {
    try {
      await ref.read(financeiroRepositoryProvider).repeatLancamento(l);
      await _refreshAfterMutation();
      if (mounted) {
        showClxToast(
          context,
          'Próxima ocorrência criada (prevista).',
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível repetir o lançamento.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _duplicate(FinLancamento l) async {
    try {
      await ref.read(financeiroRepositoryProvider).duplicateLancamento(l);
      await _refreshAfterMutation();
      if (mounted) {
        showClxToast(context, 'Lançamento copiado.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível copiar o lançamento.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _openDetail(FinLancamento l) async {
    final categorias =
        ref.read(finCategoriasProvider).valueOrNull ?? const <FinCategoria>[];
    final contas =
        ref.read(finContasProvider).valueOrNull ?? const <FinConta>[];
    FinCategoria? byId(String? id) =>
        id == null ? null : _firstOrNull(categorias, (c) => c.id == id);
    final conta = _firstOrNull(contas, (c) => c.id == l.contaId);
    final action = await showLancamentoDetail(
      context,
      lancamento: l,
      categoria: byId(l.categoriaId),
      subcategoria: byId(l.subcategoriaId),
      conta: conta,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _openForm(editing: l);
      case 'repeat':
        await _repeat(l);
      case 'duplicate':
        await _duplicate(l);
      case 'delete':
        await _delete(l);
    }
  }

  Future<void> _delete(FinLancamento l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento'),
        content: Text(
          'Excluir "${l.descricao}"? Isso ajusta o saldo da conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.clx.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(financeiroRepositoryProvider).deleteLancamento(l.id);
      await _refreshAfterMutation();
      if (mounted) {
        showClxToast(context, 'Lançamento excluído.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível excluir.',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(finLancControllerProvider);
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    final mobile = finIsMobile(context);

    final toolbar = _Toolbar(
      search: _searchCtrl,
      onSearch: _onSearch,
      filters: state.filters,
      categorias: categorias,
      contas: contas,
      mobile: mobile,
      showFilters: _showFilters,
      onToggleFilters: () => setState(() => _showFilters = !_showFilters),
      onTipo: (t) => ref
          .read(finLancControllerProvider.notifier)
          .setFilters(state.filters.copyWith(tipo: t)),
      onStatus: (s) => ref
          .read(finLancControllerProvider.notifier)
          .setFilters(state.filters.copyWith(status: s)),
      onCategoria: (id) => ref
          .read(finLancControllerProvider.notifier)
          .setFilters(state.filters.copyWith(categoriaId: id)),
      onConta: (id) => ref
          .read(finLancControllerProvider.notifier)
          .setFilters(state.filters.copyWith(contaId: id)),
      onNovo: () => _openForm(),
    );

    // Mobile (F-741): toolbar + KPIs rolam JUNTO com a lista (não são irmãos
    // fixos acima de um Expanded), liberando viewport para os lançamentos.
    if (mobile) return _mobileBody(state, categorias, contas, toolbar);

    // Desktop/tablet: layout original preservado (faixa fixa + lista).
    return Column(
      children: [
        toolbar,
        const _Kpis(),
        Expanded(child: _body(state, categorias, contas)),
      ],
    );
  }

  /// Layout de celular: um único `CustomScrollView` onde o cabeçalho (toolbar +
  /// KPIs) é o primeiro sliver rolável e a lista/estados vêm logo abaixo.
  Widget _mobileBody(
    FinLancState state,
    List<FinCategoria> categorias,
    List<FinConta> contas,
    Widget toolbar,
  ) {
    return RefreshIndicator(
      color: context.clx.primary,
      onRefresh: () => ref.read(finLancControllerProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ClxSpace.x4,
                ClxSpace.x4,
                ClxSpace.x4,
                ClxSpace.x2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  toolbar,
                  const SizedBox(height: ClxSpace.x4),
                  const _Kpis(mobile: true),
                ],
              ),
            ),
          ),
          ..._bodySlivers(state, categorias, contas),
        ],
      ),
    );
  }

  /// Slivers do corpo (lista/estado) usados no layout mobile.
  List<Widget> _bodySlivers(
    FinLancState state,
    List<FinCategoria> categorias,
    List<FinConta> contas,
  ) {
    if (state.loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(top: ClxSpace.x10),
            child: Center(child: Spinner(size: 26)),
          ),
        ),
      ];
    }
    if (state.error != null && state.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(ClxSpace.x6),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ErrorBanner(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(finLancControllerProvider.notifier).refresh(),
                ),
              ),
            ),
          ),
        ),
      ];
    }
    if (state.isEmpty) {
      return [
        SliverFillRemaining(hasScrollBody: false, child: _emptyState()),
      ];
    }

    final catById = {for (final c in categorias) c.id: c};
    final contaById = {for (final c in contas) c.id: c};
    final rows = _flatten(state);
    final extra = state.hasMore ? 1 : 0;
    return [
      SliverPadding(
        padding: const EdgeInsets.only(bottom: ClxSpace.x4),
        sliver: SliverList.builder(
          itemCount: rows.length + extra,
          itemBuilder: (context, i) =>
              _rowItem(context, rows, catById, contaById, i),
        ),
      ),
    ];
  }

  Widget _body(
    FinLancState state,
    List<FinCategoria> categorias,
    List<FinConta> contas,
  ) {
    if (state.loading) return const Center(child: Spinner(size: 26));
    if (state.error != null && state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(
              message: state.error!,
              onRetry: () =>
                  ref.read(finLancControllerProvider.notifier).refresh(),
            ),
          ),
        ),
      );
    }
    if (state.isEmpty) return _emptyState();

    final catById = {for (final c in categorias) c.id: c};
    final contaById = {for (final c in contas) c.id: c};

    final rows = _flatten(state);
    final extra = state.hasMore ? 1 : 0;

    return RefreshIndicator(
      color: context.clx.primary,
      onRefresh: () => ref.read(finLancControllerProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
        itemCount: rows.length + extra,
        itemBuilder: (context, i) =>
            _rowItem(context, rows, catById, contaById, i),
      ),
    );
  }

  /// Estado vazio (com/sem filtros) — compartilhado entre mobile e desktop.
  Widget _emptyState() {
    final filtered = _filters.hasAny;
    return EmptyState(
      icon: filtered ? Icons.search_off_rounded : Icons.receipt_long_outlined,
      title: filtered
          ? 'Nenhum lançamento encontrado'
          : 'Nenhum lançamento neste mês',
      message: filtered
          ? 'Ajuste os filtros ou o mês.'
          : 'Clique em "Novo lançamento" para começar.',
      action: filtered
          ? null
          : ClxButton(
              label: 'Novo lançamento',
              icon: Icons.add_rounded,
              onPressed: () => _openForm(),
            ),
    );
  }

  /// Achata os grupos por DIA (cabeçalho + itens) numa lista virtualizável.
  List<_Row> _flatten(FinLancState state) {
    final grupos = agruparPorData(state.items);
    final rows = <_Row>[];
    for (final g in grupos) {
      rows.add(_Row.header(g));
      for (final l in g.itens) {
        rows.add(_Row.item(l));
      }
    }
    return rows;
  }

  /// Constrói a i-ésima linha (cabeçalho de dia, lançamento ou spinner de
  /// "carregar mais"). Compartilhado pelo `ListView.builder` (desktop) e pelo
  /// `SliverList.builder` (mobile).
  Widget _rowItem(
    BuildContext context,
    List<_Row> rows,
    Map<String, FinCategoria> catById,
    Map<String, FinConta> contaById,
    int i,
  ) {
    if (i >= rows.length) {
      return const Padding(
        padding: EdgeInsets.all(ClxSpace.x4),
        child: Center(child: Spinner(size: 20)),
      );
    }
    final row = rows[i];
    return row.header != null
        ? _DayHeader(grupo: row.header!)
        : _LancamentoRow(
            lancamento: row.item!,
            categoria: catById[row.item!.categoriaId],
            subcategoria: row.item!.subcategoriaId == null
                ? null
                : catById[row.item!.subcategoriaId],
            conta: contaById[row.item!.contaId],
            onTap: () => _openDetail(row.item!),
            onDetail: () => _openDetail(row.item!),
            onEdit: () => _openForm(editing: row.item!),
            onRepeat: () => _repeat(row.item!),
            onDuplicate: () => _duplicate(row.item!),
            onDelete: () => _delete(row.item!),
          );
  }
}

/// Linha achatada: cabeçalho de dia OU um lançamento.
class _Row {
  const _Row.header(this.header) : item = null;
  const _Row.item(this.item) : header = null;
  final GrupoPorData? header;
  final FinLancamento? item;
}

/* ─────────────────────── KPIs do período ─────────────────────── */

/// 4 KPIs derivados do período (realizadas com variação vs. mês anterior,
/// previstas e saldo). Base = [finPeriodLancamentosProvider] +
/// [finPrevPeriodResumoProvider]. Espelha os KPIs de `Lancamentos.tsx`.
class _Kpis extends ConsumerWidget {
  const _Kpis({this.mobile = false});

  /// No mobile a grade entra DENTRO do scroll (o padding externo já vem do
  /// cabeçalho rolável), então dispensa o padding horizontal próprio.
  final bool mobile;

  static ({bool up, String text})? _trend(
    double cur,
    double prev,
    String prevLabel,
  ) {
    if (!prev.isFinite || prev <= 0) return null;
    final pct = (cur - prev) / prev * 100;
    return (
      up: pct >= 0,
      text: '${pct.abs().toStringAsFixed(1).replaceAll('.', ',')}% vs. $prevLabel',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final lancs =
        ref.watch(finPeriodLancamentosProvider).valueOrNull ?? const [];
    final prev = ref
        .watch(finPrevPeriodResumoProvider)
        .valueOrNull;
    final prevLabel = ref
        .watch(finPeriodProvider)
        .shift(-1)
        .label
        .split(' ')
        .first;

    final resumo = resumoPeriodo(lancs);
    final previstas = lancs
        .where((l) => l.status != LancamentoStatus.pago)
        .toList();
    final previstasTotal = previstas.fold<double>(0, (s, l) => s + l.valor);
    final saldoNeg = resumo.saldoMes < 0;

    return Padding(
      padding: mobile
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(ClxSpace.x6, ClxSpace.x4, ClxSpace.x6, 0),
      child: FinKpiGrid(
        cards: [
          FinKpiCard(
            label: 'Receitas realizadas',
            value: formatCurrency(resumo.entradas),
            color: clx.finIncome,
            icon: Icons.north_east_rounded,
            trend: prev == null
                ? null
                : _trend(resumo.entradas, prev.entradas, prevLabel),
          ),
          FinKpiCard(
            label: 'Despesas realizadas',
            value: formatCurrency(resumo.saidas),
            color: clx.finExpense,
            icon: Icons.south_west_rounded,
            trend: prev == null
                ? null
                : _trend(resumo.saidas, prev.saidas, prevLabel),
          ),
          FinKpiCard(
            label: 'Previstas',
            value: formatCurrency(previstasTotal),
            color: clx.info,
            icon: Icons.schedule_rounded,
            hint:
                '${previstas.length} lançamento${previstas.length == 1 ? '' : 's'}',
          ),
          FinKpiCard(
            label: 'Saldo do período',
            value: formatCurrency(resumo.saldoMes),
            color: saldoNeg ? clx.finExpense : clx.primary,
            icon: Icons.equalizer_rounded,
            hint: saldoNeg
                ? 'Despesas maiores que receitas'
                : resumo.saldoMes > 0
                ? 'Receitas maiores que despesas'
                : 'Equilíbrio no período',
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.onSearch,
    required this.filters,
    required this.categorias,
    required this.contas,
    required this.mobile,
    required this.showFilters,
    required this.onToggleFilters,
    required this.onTipo,
    required this.onStatus,
    required this.onCategoria,
    required this.onConta,
    required this.onNovo,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final FinLancFilters filters;
  final List<FinCategoria> categorias;
  final List<FinConta> contas;

  /// Layout de celular: filtro colapsável atrás de um botão "Filtros".
  final bool mobile;
  final bool showFilters;
  final VoidCallback onToggleFilters;

  final ValueChanged<TipoLancamento?> onTipo;
  final ValueChanged<LancamentoStatus?> onStatus;
  final ValueChanged<String?> onCategoria;
  final ValueChanged<String?> onConta;
  final VoidCallback onNovo;

  @override
  Widget build(BuildContext context) {
    // Categorias-mãe (todas as naturezas) para o filtro.
    final roots =
        categorias.where((c) => c.parentId == null).toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));

    if (mobile) return _mobile(context, roots);
    return _desktop(context, roots);
  }

  /// Desktop/tablet: layout original (faixa fixa com filtro sempre visível).
  Widget _desktop(BuildContext context, List<FinCategoria> roots) {
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
              const FinPeriodSelector(),
              const Spacer(),
              ClxButton(
                label: 'Novo lançamento',
                icon: Icons.add_rounded,
                onPressed: onNovo,
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: _searchField(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          _filterChips(context, roots),
        ],
      ),
    );
  }

  /// Mobile: período em largura total (sem truncar o mês) + linha com "Novo
  /// lançamento" e o botão "Filtros" (colapsa busca/chips). Tudo rola com o
  /// conteúdo (sem faixa fixa).
  Widget _mobile(BuildContext context, List<FinCategoria> roots) {
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
            Expanded(
              child: ClxButton(
                label: 'Novo lançamento',
                icon: Icons.add_rounded,
                onPressed: onNovo,
                expand: true,
              ),
            ),
            const SizedBox(width: ClxSpace.x2),
            FinFiltrosToggle(
              active: showFilters,
              hasActiveFilters: filters.hasAny,
              onTap: onToggleFilters,
            ),
          ],
        ),
        if (showFilters) ...[
          const SizedBox(height: ClxSpace.x3),
          _searchField(context),
          const SizedBox(height: ClxSpace.x3),
          _filterChips(context, roots),
        ],
      ],
    );
  }

  Widget _searchField(BuildContext context) {
    final clx = context.clx;
    return TextField(
      controller: search,
      onChanged: onSearch,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar descrição, cliente ou nº da OS…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: clx.bg2,
        border: const OutlineInputBorder(
          borderRadius: ClxRadii.rMd,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _filterChips(BuildContext context, List<FinCategoria> roots) {
    final clx = context.clx;
    return Wrap(
      spacing: ClxSpace.x2,
      runSpacing: ClxSpace.x2,
      children: [
        _FilterChip(
          label: 'Todos',
          selected: filters.tipo == null,
          onTap: () => onTipo(null),
        ),
        _FilterChip(
          label: 'Receitas',
          selected: filters.tipo == TipoLancamento.receita,
          color: clx.finIncome,
          onTap: () => onTipo(TipoLancamento.receita),
        ),
        _FilterChip(
          label: 'Despesas',
          selected: filters.tipo == TipoLancamento.despesa,
          color: clx.finExpense,
          onTap: () => onTipo(TipoLancamento.despesa),
        ),
        const SizedBox(width: ClxSpace.x2),
        _StatusMenu(value: filters.status, onChanged: onStatus),
        _IdFilterMenu(
          icon: Icons.category_outlined,
          allLabel: 'Categoria',
          value: filters.categoriaId,
          items: [for (final c in roots) (id: c.id, nome: c.nome)],
          onChanged: onCategoria,
        ),
        _IdFilterMenu(
          icon: Icons.account_balance_wallet_outlined,
          allLabel: 'Conta',
          value: filters.contaId,
          items: [for (final c in contas) (id: c.id, nome: c.nome)],
          onChanged: onConta,
        ),
      ],
    );
  }
}


class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final c = color ?? clx.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: ClxRadii.rPill,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x3,
          vertical: ClxSpace.x2,
        ),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.14) : clx.bg2,
          borderRadius: ClxRadii.rPill,
          border: Border.all(color: selected ? c : clx.line),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? c : clx.ink2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.value, required this.onChanged});

  final LancamentoStatus? value;
  final ValueChanged<LancamentoStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LancamentoStatus?>(
      tooltip: 'Filtrar por status',
      onSelected: onChanged,
      itemBuilder: (_) => [
        const PopupMenuItem<LancamentoStatus?>(
          value: null,
          child: Text('Todos os status'),
        ),
        for (final s in LancamentoStatus.values)
          PopupMenuItem<LancamentoStatus?>(
            value: s,
            child: Text(statusLancamentoLabel(s)),
          ),
      ],
      child: _MenuPill(
        icon: Icons.filter_list_rounded,
        active: value != null,
        label: value == null ? 'Status' : statusLancamentoLabel(value!),
      ),
    );
  }
}

/// Filtro por id (categoria/conta): `null` = todos. Mostra o nome resolvido.
class _IdFilterMenu extends StatelessWidget {
  const _IdFilterMenu({
    required this.icon,
    required this.allLabel,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String allLabel;
  final String? value;
  final List<({String id, String nome})> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = (value != null && value!.isNotEmpty)
        ? _firstOrNull(items, (e) => e.id == value)?.nome
        : null;
    return PopupMenuButton<String?>(
      tooltip: 'Filtrar por $allLabel',
      onSelected: (v) => onChanged((v == null || v.isEmpty) ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(value: '', child: Text('Todas as ${allLabel.toLowerCase()}s')),
        for (final e in items)
          PopupMenuItem<String?>(value: e.id, child: Text(e.nome)),
      ],
      child: _MenuPill(
        icon: icon,
        active: selected != null,
        label: selected ?? allLabel,
      ),
    );
  }
}

class _MenuPill extends StatelessWidget {
  const _MenuPill({
    required this.icon,
    required this.active,
    required this.label,
  });

  final IconData icon;
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x3,
        vertical: ClxSpace.x2,
      ),
      decoration: BoxDecoration(
        color: active ? clx.primary.withValues(alpha: 0.14) : clx.bg2,
        borderRadius: ClxRadii.rPill,
        border: Border.all(color: active ? clx.primary : clx.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: active ? clx.primary : clx.ink2),
          const SizedBox(width: ClxSpace.x1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: active ? clx.primary : clx.ink2,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.grupo});
  final GrupoPorData grupo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x6,
        ClxSpace.x3,
        ClxSpace.x6,
        ClxSpace.x1,
      ),
      child: Row(
        children: [
          Text(
            formatDateOnlyBr(grupo.data),
            style: tt.labelMedium?.copyWith(
              color: clx.ink2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: ClxSpace.x2),
          // Expanded (no lugar de Text + Spacer): ocupa o vão empurrando o total
          // pra direita como antes, mas a contagem elipsa/encolhe primeiro em
          // vez de estourar a Row em telas estreitas.
          Expanded(
            child: Text(
              '${grupo.itens.length} lançamento${grupo.itens.length == 1 ? '' : 's'}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: clx.ink3),
            ),
          ),
          const SizedBox(width: ClxSpace.x2),
          // Flexible p/ totais longos (ex.: R$ 1.234.567,89) não estourarem.
          Flexible(
            child: Text(
              formatSignedValue(grupo.totalDia),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: tt.labelMedium?.copyWith(
                color: grupo.totalDia < 0 ? clx.finExpense : clx.finIncome,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LancamentoRow extends StatelessWidget {
  const _LancamentoRow({
    required this.lancamento,
    required this.categoria,
    required this.subcategoria,
    required this.conta,
    required this.onTap,
    required this.onDetail,
    required this.onEdit,
    required this.onRepeat,
    required this.onDuplicate,
    required this.onDelete,
  });

  final FinLancamento lancamento;
  final FinCategoria? categoria;
  final FinCategoria? subcategoria;
  final FinConta? conta;
  final VoidCallback onTap;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onRepeat;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  /// Sub-linha: observação → serviço → subcategoria → categoria, + parcela.
  String _sub() {
    final l = lancamento;
    final parts = <String>[];
    if (l.observacao?.trim().isNotEmpty ?? false) {
      parts.add(l.observacao!.trim());
    } else if (l.servicoNome?.isNotEmpty ?? false) {
      parts.add(l.servicoNome!);
    } else if (subcategoria != null) {
      parts.add(subcategoria!.nome);
    } else if (categoria != null) {
      parts.add(categoria!.nome);
    }
    if (l.recorrencia == RecorrenciaTipo.parcelada && l.parcelasTotal != null) {
      parts.add('Parcela ${l.parcelaAtual ?? 1}/${l.parcelasTotal}');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final l = lancamento;
    final sub = _sub();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x6,
        vertical: ClxSpace.x1,
      ),
      child: ClxCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x4,
          vertical: ClxSpace.x3,
        ),
        child: Row(
          children: [
            FinCategoriaAvatar(categoria: categoria, size: 36),
            const SizedBox(width: ClxSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.descricao.isEmpty ? '(sem descrição)' : l.descricao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(color: clx.ink),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: clx.ink3),
                    ),
                  const SizedBox(height: ClxSpace.x1),
                  Wrap(
                    spacing: ClxSpace.x1,
                    runSpacing: ClxSpace.x1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OrigemChip(origem: l.origem),
                      if (conta != null) ContaBadge(conta: conta!),
                      if (l.recorrencia != RecorrenciaTipo.unica)
                        RecorrenciaChip(recorrencia: l.recorrencia),
                      StatusLancamentoChip(status: l.status, dense: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: ClxSpace.x3),
            // Sem Flexible/Expanded (QA-F3): o valor precisa da sua largura
            // intrínseca inteira — nunca trunca. É a descrição no Expanded
            // acima que cede espaço (ellipsis) quando o valor for longo.
            Text(
              formatSigned(l),
              maxLines: 1,
              softWrap: false,
              style: tt.bodyLarge?.copyWith(
                color: tipoColor(clx, l.tipo),
                fontWeight: FontWeight.w800,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Ações',
              icon: Icon(Icons.more_vert_rounded, size: 18, color: clx.ink3),
              onSelected: (v) {
                switch (v) {
                  case 'detail':
                    onDetail();
                  case 'edit':
                    onEdit();
                  case 'repeat':
                    onRepeat();
                  case 'duplicate':
                    onDuplicate();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'detail', child: Text('Ver detalhes')),
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'repeat', child: Text('Repetir')),
                PopupMenuItem(value: 'duplicate', child: Text('Copiar')),
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Builders expostos só para teste de layout (F-742): exercitam o `_DayHeader`
/// e o valor do `_LancamentoRow` isoladamente, sem a toolbar do Financeiro
/// (cujo layout mobile é escopo de F-741, fora desta correção).
@visibleForTesting
Widget debugDayHeader(GrupoPorData grupo) => _DayHeader(grupo: grupo);

@visibleForTesting
Widget debugLancamentoRow(FinLancamento lancamento) => _LancamentoRow(
  lancamento: lancamento,
  categoria: null,
  subcategoria: null,
  conta: null,
  onTap: () {},
  onDetail: () {},
  onEdit: () {},
  onRepeat: () {},
  onDuplicate: () {},
  onDelete: () {},
);
