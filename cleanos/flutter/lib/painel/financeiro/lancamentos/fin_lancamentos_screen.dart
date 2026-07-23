/// fin_lancamentos_screen.dart — Movimentações (estilo Organizze clean).
///
/// Layout: título + (+) | seletor de mês | barra laranja de filtros (Tipo /
/// Conta / Categoria + busca) | lista por dia | rodapé saldo / a receber /
/// prevista. Sem KPIs no topo. Lista VIRTUALIZADA com paginação no servidor.
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
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  /// Campo de busca expandido na barra laranja (ícone 🔍).
  bool _searchOpen = false;

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
    _searchFocus.dispose();
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

  /// Duplica criando outra movimentação **idêntica** (descrição, valor, status…).
  Future<void> _duplicate(FinLancamento l) async {
    try {
      await ref.read(financeiroRepositoryProvider).duplicateLancamento(l);
      await _refreshAfterMutation();
      if (mounted) {
        showClxToast(
          context,
          'Lançamento duplicado.',
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível duplicar o lançamento.',
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
    final dependente = isLancamentoDependenteExterno(l);
    final action = await showLancamentoDetail(
      context,
      lancamento: l,
      categoria: byId(l.categoriaId),
      subcategoria: byId(l.subcategoriaId),
      conta: conta,
      readOnly: dependente,
    );
    if (!mounted || action == null || dependente) return;
    switch (action) {
      case 'edit':
        await _openForm(editing: l);
      case 'duplicate':
      case 'repeat': // legado do botão antigo "Repetir" → agora é duplicar
        await _duplicate(l);
      case 'delete':
        await _delete(l);
    }
  }

  /// Mãozinha Organizze: pago ↔ pendente (atualiza saldo no server via hook).
  /// OS e comissão: status vem da OS / Equipe — não alterna aqui.
  Future<void> _togglePago(FinLancamento l) async {
    if (isLancamentoDependenteExterno(l)) {
      if (!mounted) return;
      showClxToast(
        context,
        isLancamentoComissao(l)
            ? 'Comissão segue o status em Equipe / comissões.'
            : 'Receita de OS segue o status da própria OS.',
        type: ToastType.info,
      );
      return;
    }
    final novo = l.status == LancamentoStatus.pago
        ? LancamentoStatus.pendente
        : LancamentoStatus.pago;
    try {
      await ref.read(financeiroRepositoryProvider).updateLancamento(l.id, {
        'status': novo.wire,
      });
      // Só atualiza o item no lugar + revalida os totais/rodapé/banner (que são
      // providers à parte). NÃO recarrega a lista — senão o scroll pula pro topo.
      ref.read(finLancControllerProvider.notifier).applyStatusLocally(l.id, novo);
      ref.invalidate(finContasProvider);
      ref.invalidate(finPeriodLancamentosProvider);
      ref.invalidate(finPrevPeriodResumoProvider);
      ref.invalidate(finPendentesProvider);
      if (mounted) {
        showClxToast(
          context,
          novo == LancamentoStatus.pago
              ? 'Marcado como pago.'
              : 'Marcado como pendente.',
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível atualizar o status.',
          type: ToastType.error,
        );
      }
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

    final toolbar = _OrganizzeToolbar(
      search: _searchCtrl,
      searchFocus: _searchFocus,
      searchOpen: _searchOpen,
      onToggleSearch: () {
        setState(() => _searchOpen = !_searchOpen);
        if (!_searchOpen) {
          _searchCtrl.clear();
          _onSearch('');
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searchFocus.requestFocus();
          });
        }
      },
      onSearch: _onSearch,
      onClearFilters: () {
        _searchCtrl.clear();
        ref.read(finLancControllerProvider.notifier).setFilters(
              const FinLancFilters(),
            );
        setState(() => _searchOpen = false);
      },
      filters: state.filters,
      categorias: categorias,
      contas: contas,
      mobile: mobile,
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

    // Mobile: header + lista no mesmo scroll; rodapé sticky de saldo.
    if (mobile) {
      return Column(
        children: [
          Expanded(
            child: _mobileBody(state, categorias, contas, toolbar),
          ),
          if (!state.isEmpty || state.loading) const _SaldoPrevistoFooter(),
        ],
      );
    }

    // Desktop: header fixo + lista + rodapé (Organizze).
    return Column(
      children: [
        toolbar,
        if (_unpaidPastBanner(state) != null) _unpaidPastBanner(state)!,
        Expanded(child: _body(state, categorias, contas)),
        const _SaldoPrevistoFooter(),
      ],
    );
  }

  /// Banner: quantos lançamentos em aberto com data/vencimento no passado.
  Widget? _unpaidPastBanner(FinLancState state) {
    final hoje = todayLocalDate();
    final n = state.items.where((l) => isLancamentoAtrasado(l, hoje)).length;
    if (n == 0) return null;
    return _UnpaidPastBanner(count: n);
  }

  /// Layout de celular: um único `CustomScrollView` onde o cabeçalho (toolbar)
  /// é o primeiro sliver rolável e a lista/estados vêm logo abaixo.
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
              child: toolbar,
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
      return [SliverFillRemaining(hasScrollBody: false, child: _emptyState())];
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
          : 'Toque no + para lançar a primeira movimentação.',
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
            onEdit: isLancamentoDependenteExterno(row.item!)
                ? () => _openDetail(row.item!)
                : () => _openForm(editing: row.item!),
            onDuplicate: isLancamentoDependenteExterno(row.item!)
                ? () {}
                : () => _duplicate(row.item!),
            onDelete: isLancamentoDependenteExterno(row.item!)
                ? () {}
                : () => _delete(row.item!),
            onTogglePago: isLancamentoDependenteExterno(row.item!)
                ? null
                : () => _togglePago(row.item!),
            dependente: isLancamentoDependenteExterno(row.item!),
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

/* ─────────────────────── Toolbar Organizze ─────────────────────── */

/// Cor da barra de filtros (referência visual Organizze).
const Color _kOrgFilterBar = Color(0xFFF5A623);
const Color _kOrgFilterOn = Color(0xFFFFFFFF);

/// Cabeçalho clean: título + (+) | seletor de mês | barra laranja sempre
/// visível (Tipo / Status / Conta / Categoria + busca). Sem KPIs no topo.
class _OrganizzeToolbar extends StatelessWidget {
  const _OrganizzeToolbar({
    required this.search,
    required this.searchFocus,
    required this.searchOpen,
    required this.onToggleSearch,
    required this.onSearch,
    required this.onClearFilters,
    required this.filters,
    required this.categorias,
    required this.contas,
    required this.mobile,
    required this.onTipo,
    required this.onStatus,
    required this.onCategoria,
    required this.onConta,
    required this.onNovo,
  });

  final TextEditingController search;
  final FocusNode searchFocus;
  final bool searchOpen;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearFilters;
  final FinLancFilters filters;
  final List<FinCategoria> categorias;
  final List<FinConta> contas;
  final bool mobile;
  final ValueChanged<TipoLancamento?> onTipo;
  final ValueChanged<LancamentoStatus?> onStatus;
  final ValueChanged<String?> onCategoria;
  final ValueChanged<String?> onConta;
  final VoidCallback onNovo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final roots = categorias.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));

    final addBtn = Tooltip(
      message: 'Novo lançamento',
      child: Material(
        color: clx.ink,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onNovo,
          child: const SizedBox(
            width: 28,
            height: 28,
            child: Icon(Icons.add_rounded, size: 18, color: Colors.white),
          ),
        ),
      ),
    );

    final titleRow = Row(
      children: [
        Flexible(
          child: Text(
            'Movimentações',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (mobile ? tt.titleLarge : tt.headlineSmall)?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: ClxSpace.x2),
        addBtn,
        if (!mobile) ...[
          const Spacer(),
          const FinPeriodSelector(),
          const Spacer(),
          // Espelho visual do (+): mantém o seletor de mês centrado.
          const SizedBox(width: 100),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 0 : ClxSpace.x6,
        mobile ? 0 : ClxSpace.x4,
        mobile ? 0 : ClxSpace.x6,
        ClxSpace.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleRow,
          if (mobile) ...[
            const SizedBox(height: ClxSpace.x2),
            const SizedBox(
              width: double.infinity,
              child: FinPeriodSelector(expand: true),
            ),
          ],
          const SizedBox(height: ClxSpace.x3),
          _orangeBar(context, roots),
        ],
      ),
    );
  }

  Widget _orangeBar(BuildContext context, List<FinCategoria> roots) {
    final hasFilters = filters.hasAny;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _kOrgFilterBar,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kOrgFilterBar.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: searchOpen
          ? _searchExpanded(context)
          : _filterMenus(context, roots, hasFilters),
    );
  }

  Widget _searchExpanded(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Fechar busca',
          onPressed: onToggleSearch,
          icon: const Icon(Icons.close_rounded, color: _kOrgFilterOn, size: 20),
        ),
        Expanded(
          child: TextField(
            controller: search,
            focusNode: searchFocus,
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: _kOrgFilterOn, fontSize: 15),
            cursorColor: _kOrgFilterOn,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Buscar descrição, cliente ou nº da OS…',
              hintStyle: TextStyle(color: Color(0xCCFFFFFF)),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterMenus(
    BuildContext context,
    List<FinCategoria> roots,
    bool hasFilters,
  ) {
    final tipoLabel = switch (filters.tipo) {
      TipoLancamento.receita => 'Receitas',
      TipoLancamento.despesa => 'Despesas',
      null => 'Tipo',
    };
    final statusLabel = filters.status == null
        ? 'Status'
        : statusLancamentoLabel(filters.status!);
    final catNome = (filters.categoriaId != null &&
            filters.categoriaId!.isNotEmpty)
        ? _firstOrNull(roots, (c) => c.id == filters.categoriaId)?.nome
        : null;
    final contaNome =
        (filters.contaId != null && filters.contaId!.isNotEmpty)
            ? _firstOrNull(contas, (c) => c.id == filters.contaId)?.nome
            : null;

    // Busca e (X) ficam fixos; só os menus rolam no meio (mobile estreito).
    return Row(
      children: [
        if (hasFilters)
          IconButton(
            tooltip: 'Limpar filtros',
            onPressed: onClearFilters,
            icon: const Icon(
              Icons.close_rounded,
              color: _kOrgFilterOn,
              size: 20,
            ),
          )
        else
          const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _OrgDropMenu<TipoLancamento?>(
                  label: tipoLabel,
                  active: filters.tipo != null,
                  tooltip: 'Filtrar por tipo',
                  onSelected: onTipo,
                  items: const [
                    (value: null, label: 'Todos os lançamentos'),
                    (value: TipoLancamento.receita, label: 'Receitas'),
                    (value: TipoLancamento.despesa, label: 'Despesas'),
                  ],
                ),
                _OrgDropMenu<LancamentoStatus?>(
                  label: statusLabel,
                  active: filters.status != null,
                  tooltip: 'Filtrar por status',
                  onSelected: onStatus,
                  items: [
                    (value: null, label: 'Todos os status'),
                    for (final s in LancamentoStatus.values)
                      (value: s, label: statusLancamentoLabel(s)),
                  ],
                ),
                _OrgDropMenu<String?>(
                  label: contaNome ?? 'Contas',
                  active: contaNome != null,
                  tooltip: 'Filtrar por conta',
                  onSelected: (v) =>
                      onConta((v == null || v.isEmpty) ? null : v),
                  items: [
                    (value: '', label: 'Todas as contas'),
                    for (final c in contas) (value: c.id, label: c.nome),
                  ],
                ),
                _OrgDropMenu<String?>(
                  label: catNome ?? 'Categorias',
                  active: catNome != null,
                  tooltip: 'Filtrar por categoria',
                  onSelected: (v) =>
                      onCategoria((v == null || v.isEmpty) ? null : v),
                  items: [
                    (value: '', label: 'Todas as categorias'),
                    for (final c in roots) (value: c.id, label: c.nome),
                  ],
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Buscar',
          onPressed: onToggleSearch,
          icon: const Icon(
            Icons.search_rounded,
            color: _kOrgFilterOn,
            size: 22,
          ),
        ),
      ],
    );
  }
}

/// Item de menu na barra laranja: rótulo + seta, popup com opções.
class _OrgDropMenu<T> extends StatelessWidget {
  const _OrgDropMenu({
    required this.label,
    required this.active,
    required this.tooltip,
    required this.onSelected,
    required this.items,
  });

  final String label;
  final bool active;
  final String tooltip;
  final ValueChanged<T> onSelected;
  final List<({T value, String label})> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      offset: const Offset(0, 40),
      itemBuilder: (_) => [
        for (final e in items)
          PopupMenuItem<T>(
            value: e.value,
            child: Text(e.label),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _kOrgFilterOn,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: _kOrgFilterOn,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.grupo});
  final GrupoPorData grupo;

  /// 'YYYY-MM-DD' → 'dd/MM/yy' (compacto, estilo Organizze).
  String get _dataCurta {
    final d = dateOnly(grupo.data);
    if (d.length != 10) return formatDateOnlyBr(grupo.data);
    return '${d.substring(8, 10)}/${d.substring(5, 7)}/${d.substring(2, 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: clx.bg2.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x5,
        ClxSpace.x3,
        ClxSpace.x5,
        ClxSpace.x2,
      ),
      child: Text(
        _dataCurta,
        style: tt.labelLarge?.copyWith(
          color: clx.ink2,
          fontWeight: FontWeight.w700,
        ),
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
    required this.onDuplicate,
    required this.onDelete,
    this.onTogglePago,
    this.dependente = false,
  });

  final FinLancamento lancamento;
  final FinCategoria? categoria;
  final FinCategoria? subcategoria;
  final FinConta? conta;
  final VoidCallback onTap;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePago;
  /// OS / comissão: sem 👍/👎 nem menu de editar.
  final bool dependente;

  /// Sub-linha: serviço / categoria / parcela (obs vai pro ícone de comentário).
  String _sub() {
    final l = lancamento;
    final parts = <String>[];
    if (l.servicoNome?.isNotEmpty ?? false) {
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

  bool get _emAberto => lancamento.status != LancamentoStatus.pago;

  bool get _temObs =>
      (lancamento.observacao?.trim().isNotEmpty ?? false);

  bool get _temRecorrencia =>
      lancamento.recorrencia != RecorrenciaTipo.unica;

  String get _tooltipRecorrencia => switch (lancamento.recorrencia) {
        RecorrenciaTipo.fixa => 'Este é um lançamento fixo',
        RecorrenciaTipo.recorrente => 'Este é um lançamento recorrente',
        RecorrenciaTipo.parcelada =>
          'Parcela ${lancamento.parcelaAtual ?? 1}'
              '${lancamento.parcelasTotal != null ? ' de ${lancamento.parcelasTotal}' : ''}',
        RecorrenciaTipo.unica => '',
      };

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final l = lancamento;
    final sub = _sub();
    final pago = !_emAberto;
    // Vermelho: não pago + data/vencimento no passado (ou status em_atraso).
    final atrasado = isLancamentoAtrasado(l, todayLocalDate());
    final bg = atrasado ? clx.error.withValues(alpha: 0.10) : clx.bg;
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ClxSpace.x4,
            vertical: ClxSpace.x3,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 520;
              return Row(
                children: [
                  // Bolinha status (vermelho = em aberto/atrasado; transparente se pago).
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: ClxSpace.x2),
                    decoration: BoxDecoration(
                      color: _emAberto ? clx.error : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  FinCategoriaAvatar(
                    categoria: subcategoria ?? categoria,
                    size: narrow ? 32 : 36,
                  ),
                  const SizedBox(width: ClxSpace.x3),
                  // Coluna esquerda: descrição.
                  Expanded(
                    flex: narrow ? 3 : 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.descricao.isEmpty
                              ? '(sem descrição)'
                              : l.descricao,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall?.copyWith(
                            color: atrasado ? clx.error : clx.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (sub.isNotEmpty)
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: atrasado
                                  ? clx.error.withValues(alpha: 0.75)
                                  : clx.ink3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Coluna central: recorrência · comentário · conta.
                  Expanded(
                    flex: narrow ? 3 : 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_temRecorrencia) ...[
                          Tooltip(
                            message: _tooltipRecorrencia,
                            waitDuration: const Duration(milliseconds: 250),
                            child: Icon(
                              Icons.sync_rounded,
                              size: 18,
                              color: clx.ink3,
                            ),
                          ),
                          const SizedBox(width: ClxSpace.x1),
                        ],
                        if (_temObs) ...[
                          Tooltip(
                            message: l.observacao!.trim(),
                            waitDuration: const Duration(milliseconds: 250),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 17,
                              color: clx.ink3,
                            ),
                          ),
                          const SizedBox(width: ClxSpace.x1),
                        ],
                        if (conta != null)
                          Flexible(child: ContaBadge(conta: conta!)),
                      ],
                    ),
                  ),
                  // Valor (nunca trunca — FittedBox se apertar).
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * (narrow ? 0.28 : 0.22),
                      minWidth: 72,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatSigned(l),
                          maxLines: 1,
                          softWrap: false,
                          style: tt.bodyLarge?.copyWith(
                            color: atrasado
                                ? clx.error
                                : tipoColor(clx, l.tipo),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Mãozinha: 👍/👎 — oculto em OS/comissão (status dependente).
                  if (dependente)
                    Tooltip(
                      message: isLancamentoComissao(l)
                          ? 'Comissão — status em Equipe'
                          : 'OS — status da ordem de serviço',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: clx.ink3,
                        ),
                      ),
                    )
                  else
                    Tooltip(
                      message: pago
                          ? 'Pago — toque para marcar pendente'
                          : atrasado
                              ? 'Em atraso — toque para marcar pago'
                              : 'Pendente — toque para marcar pago',
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: onTogglePago,
                        icon: Icon(
                          pago
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_down_alt_rounded,
                          size: 20,
                          color: pago
                              ? clx.success
                              : (atrasado ? clx.error : clx.ink3),
                        ),
                      ),
                    ),
                  if (!narrow)
                    PopupMenuButton<String>(
                      tooltip: 'Ações',
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: clx.ink3,
                      ),
                      onSelected: (v) {
                        switch (v) {
                          case 'detail':
                            onDetail();
                          case 'edit':
                            onEdit();
                          case 'duplicate':
                            onDuplicate();
                          case 'delete':
                            onDelete();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'detail',
                          child: Text('Ver detalhes'),
                        ),
                        if (!dependente) ...const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(
                            value: 'duplicate',
                            child: Text('Duplicar'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Excluir')),
                        ],
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────── banner + rodapé Organizze ─────────────────────── */

class _UnpaidPastBanner extends StatelessWidget {
  const _UnpaidPastBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        ClxSpace.x6,
        ClxSpace.x2,
        ClxSpace.x6,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        color: clx.warning.withValues(alpha: 0.12),
        borderRadius: ClxRadii.rMd,
        border: Border.all(color: clx.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: clx.warning),
          const SizedBox(width: ClxSpace.x2),
          Expanded(
            child: Text(
              count == 1
                  ? 'Há 1 lançamento passado que ainda não foi pago'
                  : 'Há $count lançamentos passados que ainda não foram pagos',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clx.ink2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rodapé sticky do período:
/// - **saldo** — realizado (só pagos: receitas − despesas)
/// - **a receber** — +Σ receitas/OS em aberto (não pagas)
/// - **prevista** — receita total − despesa total (todos status); verde/vermelho
class _SaldoPrevistoFooter extends ConsumerWidget {
  const _SaldoPrevistoFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    // Período completo (não só a página da lista) — totais fiéis do mês.
    final items =
        ref.watch(finPeriodLancamentosProvider).valueOrNull ?? const [];

    final resumo = resumoPeriodo(items);
    final aReceber = totalReceitasPrevistas(items);

    var recCents = 0;
    var despCents = 0;
    for (final l in items) {
      final c = (l.valor * 100).round();
      if (l.tipo == TipoLancamento.receita) {
        recCents += c;
      } else {
        despCents += c;
      }
    }
    final prevista = (recCents - despCents) / 100.0;
    final saldo = resumo.saldoMes;

    Widget metric(
      String label,
      String valueText,
      Color valueColor,
    ) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: tt.bodySmall?.copyWith(color: clx.ink3)),
          const SizedBox(width: ClxSpace.x2),
          Flexible(
            child: Text(
              valueText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleSmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }

    final saldoW = metric(
      'saldo',
      formatCurrency(saldo),
      saldo < 0 ? clx.finExpense : clx.primary,
    );
    // A receber: sempre positivo (+R$ …) — OS/receitas em aberto.
    final aReceberW = metric(
      'a receber',
      aReceber > 0
          ? '+${formatCurrency(aReceber)}'
          : formatCurrency(0),
      clx.finIncome,
    );
    // Prevista = receitas totais − despesas totais (verde se ≥ 0, vermelho se < 0).
    final previstaW = metric(
      'prevista',
      formatCurrency(prevista),
      prevista < 0 ? clx.finExpense : clx.finIncome,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        color: clx.bg,
        border: Border(top: BorderSide(color: clx.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 480;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                saldoW,
                const SizedBox(height: ClxSpace.x1),
                aReceberW,
                const SizedBox(height: ClxSpace.x1),
                previstaW,
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(child: saldoW),
              const SizedBox(width: ClxSpace.x4),
              Flexible(child: aReceberW),
              const SizedBox(width: ClxSpace.x4),
              Flexible(child: previstaW),
            ],
          );
        },
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
  onDuplicate: () {},
  onDelete: () {},
  onTogglePago: () {},
);
