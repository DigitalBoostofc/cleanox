/// fin_transacoes_screen.dart — Transações v2 (lista mobile + tabela desktop).
///
/// UX refs Mobills: header Saldo atual | Balanço mensal, seletor de mês,
/// lista agrupada por data com pin favorito; desktop com colunas e
/// “Saldo previsto final do dia”. Reusa [finLancControllerProvider].
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
import '../fin_export.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';
import '../ui/fin_ui.dart';
import 'fin_lancamentos_controller.dart';
import 'lancamento_detail_panel.dart';
import 'lancamento_form.dart';

T? _firstOrNull<T>(Iterable<T> it, bool Function(T) test) {
  for (final e in it) {
    if (test(e)) return e;
  }
  return null;
}

class FinTransacoesScreen extends ConsumerStatefulWidget {
  const FinTransacoesScreen({super.key});

  @override
  ConsumerState<FinTransacoesScreen> createState() =>
      _FinTransacoesScreenState();
}

class _FinTransacoesScreenState extends ConsumerState<FinTransacoesScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

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

  Future<void> _refreshAfterMutation() async {
    await ref.read(finLancControllerProvider.notifier).refresh();
    ref.invalidate(finContasProvider);
    ref.invalidate(finPeriodLancamentosProvider);
    ref.invalidate(finPendentesProvider);
  }

  Future<void> _openForm({FinLancamento? editing}) async {
    final f = ref.read(finLancControllerProvider).filters;
    final saved = await showLancamentoForm(
      context,
      editing: editing,
      initialTipo: editing == null ? f.tipo : null,
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
      case 'duplicate':
      case 'repeat':
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
              'Não foi possível duplicar.',
              type: ToastType.error,
            );
          }
        }
      case 'delete':
        await _delete(l);
    }
  }

  Future<void> _togglePago(FinLancamento l) async {
    final novo = l.status == LancamentoStatus.pago
        ? LancamentoStatus.pendente
        : LancamentoStatus.pago;
    try {
      await ref.read(financeiroRepositoryProvider).updateLancamento(l.id, {
        'status': novo.wire,
      });
      ref
          .read(finLancControllerProvider.notifier)
          .applyStatusLocally(l.id, novo);
      ref.invalidate(finContasProvider);
      ref.invalidate(finPeriodLancamentosProvider);
      ref.invalidate(finPendentesProvider);
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

  Future<void> _toggleFavorito(FinLancamento l) async {
    final novo = !l.favorito;
    // Otimista
    ref
        .read(finLancControllerProvider.notifier)
        .applyFavoritoLocally(l.id, novo);
    try {
      await ref.read(financeiroRepositoryProvider).updateLancamento(l.id, {
        'favorito': novo,
      });
    } catch (_) {
      ref
          .read(finLancControllerProvider.notifier)
          .applyFavoritoLocally(l.id, !novo);
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível atualizar o favorito. '
          'Confira se a migration favorito está aplicada no servidor.',
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
        content: Text('Excluir "${l.descricao}"? Isso ajusta o saldo da conta.'),
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

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final f = ref.read(finLancControllerProvider).filters;
      ref
          .read(finLancControllerProvider.notifier)
          .setFilters(f.copyWith(search: value));
    });
  }

  String _weekdayLabel(String iso) {
    final d = dateOnly(iso);
    if (d.length != 10) return formatDateOnlyBr(iso);
    final dt = DateTime.tryParse(d);
    if (dt == null) return formatDateOnlyBr(iso);
    const nomes = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    final hoje = todayLocalDate();
    final amanha = DateTime.parse(hoje).add(const Duration(days: 1));
    final amanhaS =
        '${amanha.year}-${amanha.month.toString().padLeft(2, '0')}-${amanha.day.toString().padLeft(2, '0')}';
    if (d == hoje) return 'Hoje, ${d.substring(8, 10)}';
    if (d == amanhaS) return 'Amanhã';
    return '${nomes[dt.weekday - 1]}, ${d.substring(8, 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final mobile = finIsMobile(context);
    final state = ref.watch(finLancControllerProvider);
    final period = ref.watch(finPeriodProvider);
    final contas =
        ref.watch(finContasProvider).valueOrNull ?? const <FinConta>[];
    final categorias =
        ref.watch(finCategoriasProvider).valueOrNull ?? const <FinCategoria>[];
    final periodLancs =
        ref.watch(finPeriodLancamentosProvider).valueOrNull ?? state.items;

    final saldo = saldoGeral(contas.where((c) => c.ativo).toList());
    final resumo = resumoPeriodo(periodLancs);
    final prevPorDia = saldoPrevistoPorDia(
      saldoAtual: saldo,
      lancs: periodLancs.isNotEmpty ? periodLancs : state.items,
    );

    final catById = {for (final c in categorias) c.id: c};
    final contaById = {for (final c in contas) c.id: c};

    return ColoredBox(
      color: clx.bg2,
      child: Column(
        children: [
          _HeaderKpis(
            periodLabel: period.label,
            onPrev: () =>
                ref.read(finPeriodProvider.notifier).state = period.shift(-1),
            onNext: () =>
                ref.read(finPeriodProvider.notifier).state = period.shift(1),
            saldo: saldo,
            balanco: resumo.saldoMes,
            searchCtrl: _searchCtrl,
            onSearch: _onSearch,
            onNovo: () => _openForm(),
            onExport: () => finExportLancamentosCsv(
              context,
              lancs: periodLancs.isNotEmpty ? periodLancs : state.items,
              catById: catById,
              contaById: contaById,
              filename:
                  'cleanox-transacoes-${period.year}-${period.month.toString().padLeft(2, '0')}.csv',
            ),
            filters: state.filters,
            onTipo: (t) => ref
                .read(finLancControllerProvider.notifier)
                .setFilters(state.filters.copyWith(tipo: t)),
          ),
          Expanded(
            child: state.loading
                ? const Center(child: Spinner(size: 28))
                : state.error != null && state.isEmpty
                    ? Center(
                        child: ErrorBanner(
                          message: state.error!,
                          onRetry: () => ref
                              .read(finLancControllerProvider.notifier)
                              .refresh(),
                        ),
                      )
                    : state.isEmpty
                        ? EmptyState(
                            icon: Icons.swap_horiz_rounded,
                            title: 'Nenhuma transação neste mês',
                            message: 'Toque em + para lançar a primeira.',
                            action: ClxButton(
                              label: 'Novo lançamento',
                              icon: Icons.add_rounded,
                              onPressed: () => _openForm(),
                            ),
                          )
                        : mobile
                            ? _MobileList(
                                scroll: _scroll,
                                state: state,
                                catById: catById,
                                contaById: contaById,
                                weekdayLabel: _weekdayLabel,
                                onOpen: _openDetail,
                                onTogglePago: _togglePago,
                                onToggleFav: _toggleFavorito,
                                onLoadMore: () => ref
                                    .read(finLancControllerProvider.notifier)
                                    .loadMore(),
                              )
                            : _DesktopTable(
                                scroll: _scroll,
                                state: state,
                                catById: catById,
                                contaById: contaById,
                                prevPorDia: prevPorDia,
                                onOpen: _openDetail,
                                onTogglePago: _togglePago,
                                onToggleFav: _toggleFavorito,
                                onEdit: (l) => _openForm(editing: l),
                                onDelete: _delete,
                              ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── header ─────────────────────── */

class _HeaderKpis extends StatelessWidget {
  const _HeaderKpis({
    required this.periodLabel,
    required this.onPrev,
    required this.onNext,
    required this.saldo,
    required this.balanco,
    required this.searchCtrl,
    required this.onSearch,
    required this.onNovo,
    required this.onExport,
    required this.filters,
    required this.onTipo,
  });

  final String periodLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final double saldo;
  final double balanco;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onNovo;
  final VoidCallback onExport;
  final FinLancFilters filters;
  final ValueChanged<TipoLancamento?> onTipo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      color: clx.bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          FinMonthBar(label: periodLabel, onPrev: onPrev, onNext: onNext),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiMini(
                  icon: Icons.lock_outline_rounded,
                  label: 'Saldo atual',
                  value: saldo,
                ),
              ),
              Container(width: 1, height: 40, color: clx.line),
              Expanded(
                child: _KpiMini(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Balanço mensal',
                  value: balanco,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(
                label: 'Todos',
                selected: filters.tipo == null,
                onTap: () => onTipo(null),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Receitas',
                selected: filters.tipo == TipoLancamento.receita,
                onTap: () => onTipo(TipoLancamento.receita),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Despesas',
                selected: filters.tipo == TipoLancamento.despesa,
                onTap: () => onTipo(TipoLancamento.despesa),
              ),
              const Spacer(),
              if (!finIsMobile(context))
                SizedBox(
                  width: 220,
                  height: 40,
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      hintText: 'Buscar…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: ClxRadii.rMd,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Exportar CSV',
                onPressed: onExport,
                icon: Icon(Icons.download_outlined, color: clx.ink2),
              ),
              if (!finIsMobile(context)) ...[
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: onNovo,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Novo'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiMini extends StatelessWidget {
  const _KpiMini({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: clx.ink3),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: clx.ink3, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        FinMoneyText(value),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Material(
      color: selected ? clx.primary : clx.bg3,
      borderRadius: ClxRadii.rPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: ClxRadii.rPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? clx.onPrimary : clx.ink2,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────── mobile list ─────────────────────── */

class _MobileList extends StatelessWidget {
  const _MobileList({
    required this.scroll,
    required this.state,
    required this.catById,
    required this.contaById,
    required this.weekdayLabel,
    required this.onOpen,
    required this.onTogglePago,
    required this.onToggleFav,
    required this.onLoadMore,
  });

  final ScrollController scroll;
  final FinLancState state;
  final Map<String, FinCategoria> catById;
  final Map<String, FinConta> contaById;
  final String Function(String) weekdayLabel;
  final ValueChanged<FinLancamento> onOpen;
  final ValueChanged<FinLancamento> onTogglePago;
  final ValueChanged<FinLancamento> onToggleFav;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final grupos = agruparPorData(state.items);
    final clx = context.clx;

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: grupos.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= grupos.length) {
          onLoadMore();
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Spinner(size: 22)),
          );
        }
        final g = grupos[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                weekdayLabel(g.data),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: clx.ink2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            FinCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var j = 0; j < g.itens.length; j++) ...[
                    if (j > 0) Divider(height: 1, color: clx.line),
                    _TxTile(
                      l: g.itens[j],
                      cat: catById[g.itens[j].categoriaId],
                      conta: contaById[g.itens[j].contaId],
                      onOpen: () => onOpen(g.itens[j]),
                      onTogglePago: () => onTogglePago(g.itens[j]),
                      onToggleFav: () => onToggleFav(g.itens[j]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.l,
    required this.cat,
    required this.conta,
    required this.onOpen,
    required this.onTogglePago,
    required this.onToggleFav,
  });

  final FinLancamento l;
  final FinCategoria? cat;
  final FinConta? conta;
  final VoidCallback onOpen;
  final VoidCallback onTogglePago;
  final VoidCallback onToggleFav;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final meta = [
      if (cat != null) cat!.nome,
      if (conta != null) conta!.nome,
      if (l.recorrencia == RecorrenciaTipo.fixa) 'Fixa',
      if (l.recorrencia == RecorrenciaTipo.parcelada && l.parcelasTotal != null)
        '${l.parcelaAtual ?? 1}/${l.parcelasTotal}',
    ].join(' | ');

    return ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          FinCategoriaAvatar(categoria: cat, size: 40),
          if (l.status != LancamentoStatus.pago)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: clx.finExpense,
                  shape: BoxShape.circle,
                  border: Border.all(color: clx.bg, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        l.descricao.isEmpty ? '(sem descrição)' : l.descricao,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        meta,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: clx.ink3, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(l.valor),
                style: TextStyle(
                  color: tipoColor(clx, l.tipo),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: l.favorito ? 'Remover favorito' : 'Favoritar',
            onPressed: onToggleFav,
            icon: Icon(
              l.favorito ? Icons.push_pin : Icons.push_pin_outlined,
              size: 18,
              color: l.favorito ? clx.primary : clx.ink3,
            ),
          ),
          IconButton(
            tooltip: l.status == LancamentoStatus.pago
                ? 'Marcar pendente'
                : 'Marcar pago',
            onPressed: onTogglePago,
            icon: Icon(
              l.status == LancamentoStatus.pago
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 20,
              color: l.status == LancamentoStatus.pago
                  ? clx.finIncome
                  : clx.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── desktop table ─────────────────────── */

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.scroll,
    required this.state,
    required this.catById,
    required this.contaById,
    required this.prevPorDia,
    required this.onOpen,
    required this.onTogglePago,
    required this.onToggleFav,
    required this.onEdit,
    required this.onDelete,
  });

  final ScrollController scroll;
  final FinLancState state;
  final Map<String, FinCategoria> catById;
  final Map<String, FinConta> contaById;
  final Map<String, double> prevPorDia;
  final ValueChanged<FinLancamento> onOpen;
  final ValueChanged<FinLancamento> onTogglePago;
  final ValueChanged<FinLancamento> onToggleFav;
  final ValueChanged<FinLancamento> onEdit;
  final ValueChanged<FinLancamento> onDelete;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final grupos = agruparPorData(state.items);

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        FinCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: clx.line)),
                ),
                child: Row(
                  children: [
                    _H('Situação', 72),
                    _H('Data', 100),
                    const Expanded(flex: 3, child: _H('Descrição', null)),
                    const Expanded(flex: 2, child: _H('Categoria', null)),
                    const Expanded(child: _H('Conta', null)),
                    SizedBox(width: 110, child: _H('Valor', null, end: true)),
                    const SizedBox(width: 96, child: _H('Ações', null, end: true)),
                  ],
                ),
              ),
              for (final g in grupos) ...[
                for (final l in g.itens)
                  _TableRow(
                    l: l,
                    cat: catById[l.categoriaId],
                    conta: contaById[l.contaId],
                    onOpen: () => onOpen(l),
                    onTogglePago: () => onTogglePago(l),
                    onToggleFav: () => onToggleFav(l),
                    onEdit: () => onEdit(l),
                    onDelete: () => onDelete(l),
                  ),
                // chip saldo previsto do dia
                if (prevPorDia[g.data] != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: clx.bg3,
                        borderRadius: ClxRadii.rPill,
                        border: Border.all(color: clx.line),
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 12, color: clx.ink2),
                          children: [
                            const TextSpan(text: 'Saldo previsto final do dia  '),
                            TextSpan(
                              text: formatCurrency(prevPorDia[g.data]!),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: (prevPorDia[g.data]! < 0)
                                    ? clx.finExpense
                                    : clx.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              if (state.hasMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Spinner(size: 22)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.label, this.width, {this.end = false});
  final String label;
  final double? width;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final t = Text(
      label,
      textAlign: end ? TextAlign.right : TextAlign.left,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.clx.ink3,
            fontWeight: FontWeight.w700,
          ),
    );
    if (width == null) return t;
    return SizedBox(width: width, child: t);
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.l,
    required this.cat,
    required this.conta,
    required this.onOpen,
    required this.onTogglePago,
    required this.onToggleFav,
    required this.onEdit,
    required this.onDelete,
  });

  final FinLancamento l;
  final FinCategoria? cat;
  final FinConta? conta;
  final VoidCallback onOpen;
  final VoidCallback onTogglePago;
  final VoidCallback onToggleFav;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final pago = l.status == LancamentoStatus.pago;
    return Material(
      color: pago ? Colors.transparent : clx.warning.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: clx.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Icon(
                  pago ? Icons.check_circle : Icons.error_outline,
                  size: 20,
                  color: pago ? clx.finIncome : clx.finExpense,
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  formatDateOnlyBr(l.data),
                  style: TextStyle(color: clx.ink2, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        l.descricao.isEmpty ? '(sem descrição)' : l.descricao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (l.favorito) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.push_pin, size: 14, color: clx.primary),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    FinCategoriaAvatar(categoria: cat, size: 28),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        cat?.nome ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  conta?.nome ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  formatCurrency(l.valor),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: tipoColor(clx, l.tipo),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l.favorito ? 'Desfavoritar' : 'Favoritar',
                      onPressed: onToggleFav,
                      icon: Icon(
                        l.favorito
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        size: 18,
                        color: l.favorito ? clx.primary : clx.ink3,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        switch (v) {
                          case 'pago':
                            onTogglePago();
                          case 'edit':
                            onEdit();
                          case 'delete':
                            onDelete();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'pago',
                          child: Text(
                            pago ? 'Marcar pendente' : 'Marcar pago',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Excluir'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
