/// fin_lancamentos_screen.dart — Lista de Lançamentos (CRUD, estilo Organizze).
///
/// Espelha `Lancamentos.tsx`: agrupado por DIA (BRT) com total do dia, filtros
/// (mês/busca/tipo/status) e CRUD por modal. Lista VIRTUALIZADA (`ListView.builder`)
/// com PAGINAÇÃO no servidor + scroll infinito — nunca `getFullList`. Estados
/// carregando/erro/vazio/sucesso.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/models/financeiro.dart';
import '../fin_common.dart';
import '../fin_derivations.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';
import 'fin_lancamentos_controller.dart';
import 'lancamento_form.dart';

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

  Future<void> _openForm({FinLancamento? editing}) async {
    final saved = await showLancamentoForm(context, editing: editing);
    if (saved == true) {
      await ref.read(finLancControllerProvider.notifier).refresh();
      ref.invalidate(finContasProvider);
      ref.invalidate(finPeriodLancamentosProvider);
      if (mounted) {
        showClxToast(
          context,
          editing == null ? 'Lançamento criado.' : 'Lançamento atualizado.',
          type: ToastType.success,
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
      await ref.read(finLancControllerProvider.notifier).refresh();
      ref.invalidate(finContasProvider);
      ref.invalidate(finPeriodLancamentosProvider);
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
    return Column(
      children: [
        _Toolbar(
          search: _searchCtrl,
          onSearch: _onSearch,
          filters: state.filters,
          onTipo: (t) => ref
              .read(finLancControllerProvider.notifier)
              .setFilters(state.filters.copyWith(tipo: t)),
          onStatus: (s) => ref
              .read(finLancControllerProvider.notifier)
              .setFilters(state.filters.copyWith(status: s)),
          onNovo: () => _openForm(),
        ),
        Expanded(child: _body(state)),
      ],
    );
  }

  Widget _body(FinLancState state) {
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
    if (state.isEmpty) {
      final filtered = state.filters.hasAny;
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

    // Achata grupos (cabeçalho por dia) + itens num só ListView virtualizado.
    final grupos = agruparPorData(state.items);
    final rows = <_Row>[];
    for (final g in grupos) {
      rows.add(_Row.header(g));
      for (final l in g.itens) {
        rows.add(_Row.item(l));
      }
    }
    final extra = state.hasMore ? 1 : 0;

    return RefreshIndicator(
      color: context.clx.primary,
      onRefresh: () => ref.read(finLancControllerProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
        itemCount: rows.length + extra,
        itemBuilder: (context, i) {
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
                  onTap: () => _openForm(editing: row.item!),
                  onDelete: () => _delete(row.item!),
                );
        },
      ),
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

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.onSearch,
    required this.filters,
    required this.onTipo,
    required this.onStatus,
    required this.onNovo,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final FinLancFilters filters;
  final ValueChanged<TipoLancamento?> onTipo;
  final ValueChanged<LancamentoStatus?> onStatus;
  final VoidCallback onNovo;

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
                  child: TextField(
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
            ],
          ),
        ],
      ),
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
          style: TextStyle(
            color: selected ? c : clx.ink2,
            fontSize: 12.5,
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
    final clx = context.clx;
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
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x3,
          vertical: ClxSpace.x2,
        ),
        decoration: BoxDecoration(
          color: value != null ? clx.primary.withValues(alpha: 0.14) : clx.bg2,
          borderRadius: ClxRadii.rPill,
          border: Border.all(color: value != null ? clx.primary : clx.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, size: 15, color: clx.ink2),
            const SizedBox(width: ClxSpace.x1),
            Text(
              value == null ? 'Status' : statusLancamentoLabel(value!),
              style: TextStyle(
                color: value != null ? clx.primary : clx.ink2,
                fontSize: 12.5,
                fontWeight: value != null ? FontWeight.w700 : FontWeight.w500,
              ),
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

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
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
            style: TextStyle(
              color: clx.ink2,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            formatSignedValue(grupo.totalDia),
            style: TextStyle(
              color: grupo.totalDia < 0 ? clx.finExpense : clx.finIncome,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
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
    required this.onTap,
    required this.onDelete,
  });

  final FinLancamento lancamento;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final l = lancamento;
    final isReceita = l.tipo == TipoLancamento.receita;
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
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tipoColor(clx, l.tipo).withValues(alpha: 0.14),
                borderRadius: ClxRadii.rMd,
              ),
              child: Icon(
                isReceita ? Icons.north_east_rounded : Icons.south_west_rounded,
                size: 17,
                color: tipoColor(clx, l.tipo),
              ),
            ),
            const SizedBox(width: ClxSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          l.descricao.isEmpty ? '(sem descrição)' : l.descricao,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: clx.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (l.origem == OrigemLancamento.viaOs) ...[
                        const SizedBox(width: ClxSpace.x2),
                        ClxChip(
                          label: 'Via OS',
                          color: clx.info,
                          icon: Icons.link_rounded,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      StatusLancamentoChip(status: l.status, dense: true),
                      if (l.recorrencia != RecorrenciaTipo.unica) ...[
                        const SizedBox(width: ClxSpace.x2),
                        Text(
                          recorrenciaLabel(l.recorrencia),
                          style: TextStyle(color: clx.ink3, fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: ClxSpace.x3),
            Text(
              formatSigned(l),
              style: TextStyle(
                color: tipoColor(clx, l.tipo),
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Ações',
              icon: Icon(Icons.more_vert_rounded, size: 18, color: clx.ink3),
              onSelected: (v) {
                if (v == 'edit') onTap();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
