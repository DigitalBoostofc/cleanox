/// fin_contas_pagar_receber_screen.dart — Contas a pagar / a receber.
///
/// Espelha `ContasPagarReceber.tsx`: seletor de mês (BRT) + Filtros + abas
/// A pagar / A receber / Todas + 4 KPIs GLOBAIS (total a pagar/receber, vencendo
/// hoje, em atraso) derivados de [contasAPagar]/[contasAReceber] vs. HOJE. As
/// listas respeitam o mês + filtros (tipo/origem/categoria/conta/vencimento) e
/// têm a ação "marcar pago". Rodapé informativo sobre recebimentos via OS.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'fin_chips.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_labels.dart';
import 'fin_providers.dart';

/// Aba ativa (a pagar / a receber / todas).
enum _Aba { pagar, receber, todas }

/// Preset de vencimento do filtro.
enum _Venc { todos, vencidas, hoje, d7, d30 }

/// Filtros combinados (AND) das listas. `null` = sem filtro daquele campo.
class _CprFilters {
  const _CprFilters({
    this.tipo,
    this.origem,
    this.categoriaId,
    this.contaId,
    this.venc = _Venc.todos,
  });

  final TipoLancamento? tipo;
  final OrigemLancamento? origem;
  final String? categoriaId;
  final String? contaId;
  final _Venc venc;

  bool get ativos =>
      tipo != null ||
      origem != null ||
      categoriaId != null ||
      contaId != null ||
      venc != _Venc.todos;

  _CprFilters copyWith({
    Object? tipo = _s,
    Object? origem = _s,
    Object? categoriaId = _s,
    Object? contaId = _s,
    _Venc? venc,
  }) => _CprFilters(
    tipo: tipo == _s ? this.tipo : tipo as TipoLancamento?,
    origem: origem == _s ? this.origem : origem as OrigemLancamento?,
    categoriaId: categoriaId == _s ? this.categoriaId : categoriaId as String?,
    contaId: contaId == _s ? this.contaId : contaId as String?,
    venc: venc ?? this.venc,
  );

  static const Object _s = Object();
}

class FinContasPagarReceberScreen extends ConsumerStatefulWidget {
  const FinContasPagarReceberScreen({super.key});

  @override
  ConsumerState<FinContasPagarReceberScreen> createState() =>
      _FinContasPagarReceberScreenState();
}

class _FinContasPagarReceberScreenState
    extends ConsumerState<FinContasPagarReceberScreen> {
  _Aba _aba = _Aba.pagar;

  /// `null` = ainda não alternado pelo usuário: usa o padrão por viewport
  /// (aberto no desktop, colapsado no mobile). Depois do 1º toque no botão
  /// "Filtros", o valor explícito prevalece.
  bool? _showFilters;
  _CprFilters _filters = const _CprFilters();
  String? _savingId;

  String _vencYmd(ContaPendente p) {
    final l = p.lancamento;
    return dateOnly(
      (l.vencimento?.isNotEmpty ?? false) ? l.vencimento! : l.data,
    );
  }

  String _ymdPlus(String ymd, int days) => DateTime.parse(
    '${ymd}T00:00:00Z',
  ).add(Duration(days: days)).toIso8601String().substring(0, 10);

  bool _passaVenc(ContaPendente p, String hoje) {
    switch (_filters.venc) {
      case _Venc.todos:
        return true;
      case _Venc.vencidas:
        return p.emAtraso;
      case _Venc.hoje:
        return p.vencendoHoje;
      case _Venc.d7:
        final v = _vencYmd(p);
        return v.compareTo(hoje) >= 0 && v.compareTo(_ymdPlus(hoje, 7)) <= 0;
      case _Venc.d30:
        final v = _vencYmd(p);
        return v.compareTo(hoje) >= 0 && v.compareTo(_ymdPlus(hoje, 30)) <= 0;
    }
  }

  List<ContaPendente> _aplicar(
    List<ContaPendente> items,
    String mesPrefix,
    String hoje,
  ) {
    return items.where((p) {
      final l = p.lancamento;
      if (!_vencYmd(p).startsWith(mesPrefix)) return false;
      if (_filters.origem != null && l.origem != _filters.origem) return false;
      if (_filters.categoriaId != null &&
          l.categoriaId != _filters.categoriaId &&
          l.subcategoriaId != _filters.categoriaId) {
        return false;
      }
      if (_filters.contaId != null && l.contaId != _filters.contaId) {
        return false;
      }
      if (!_passaVenc(p, hoje)) return false;
      return true;
    }).toList();
  }

  Future<void> _marcarPago(FinLancamento l) async {
    setState(() => _savingId = l.id);
    try {
      await ref.read(financeiroRepositoryProvider).updateLancamento(l.id, {
        'status': LancamentoStatus.pago.wire,
      });
      ref
        ..invalidate(finPendentesProvider)
        ..invalidate(finContasProvider)
        ..invalidate(finPeriodLancamentosProvider);
      if (mounted) {
        showClxToast(context, 'Marcado como pago.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível atualizar.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(finPendentesProvider);
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    final period = ref.watch(finPeriodProvider);
    final hoje = todayLocalDate();
    final mesPrefix =
        '${period.year}-${period.month.toString().padLeft(2, '0')}';

    final catById = {for (final c in categorias) c.id: c};
    final contaById = {for (final c in contas) c.id: c};
    final showFilters = _showFilters ?? !finIsMobile(context);

    return Column(
      children: [
        _Toolbar(
          aba: _aba,
          showFilters: showFilters,
          hasActiveFilters: _filters.ativos,
          onAba: (a) => setState(() => _aba = a),
          onToggleFilters: () => setState(() => _showFilters = !showFilters),
        ),
        Expanded(
          child: FinAsync<List<FinLancamento>>(
            value: async,
            onRetry: () => ref.invalidate(finPendentesProvider),
            data: (pendentes) {
              final aPagarAll = contasAPagar(pendentes, hoje);
              final aReceberAll = contasAReceber(pendentes, hoje);
              double sum(List<ContaPendente> xs) =>
                  xs.fold<double>(0, (s, p) => s + p.lancamento.valor);
              final todos = [...aPagarAll, ...aReceberAll];
              final vencendoHoje = todos.where((p) => p.vencendoHoje).toList();
              final emAtraso = todos.where((p) => p.emAtraso).toList();

              final mostrarPagar = _aba != _Aba.receber;
              final mostrarReceber = _aba != _Aba.pagar;
              final aPagar = _filters.tipo == TipoLancamento.receita
                  ? <ContaPendente>[]
                  : _aplicar(aPagarAll, mesPrefix, hoje);
              final aReceber = _filters.tipo == TipoLancamento.despesa
                  ? <ContaPendente>[]
                  : _aplicar(aReceberAll, mesPrefix, hoje);

              return ListView(
                padding: const EdgeInsets.all(ClxSpace.x6),
                children: [
                  FinKpiGrid(
                    cards: [
                      FinKpiCard(
                        label: 'Total a pagar',
                        value: formatCurrency(sum(aPagarAll)),
                        color: context.clx.finExpense,
                        icon: Icons.south_west_rounded,
                        hint:
                            '${aPagarAll.length} ${aPagarAll.length == 1 ? 'item' : 'itens'}',
                      ),
                      FinKpiCard(
                        label: 'Total a receber',
                        value: formatCurrency(sum(aReceberAll)),
                        color: context.clx.finIncome,
                        icon: Icons.north_east_rounded,
                        hint:
                            '${aReceberAll.length} ${aReceberAll.length == 1 ? 'item' : 'itens'}',
                      ),
                      FinKpiCard(
                        label: 'Vencendo hoje',
                        value: formatCurrency(sum(vencendoHoje)),
                        color: context.clx.info,
                        icon: Icons.event_rounded,
                        hint:
                            '${vencendoHoje.length} ${vencendoHoje.length == 1 ? 'item' : 'itens'}',
                      ),
                      FinKpiCard(
                        label: 'Em atraso',
                        value: formatCurrency(sum(emAtraso)),
                        color: context.clx.error,
                        icon: Icons.warning_amber_rounded,
                        hint:
                            '${emAtraso.length} ${emAtraso.length == 1 ? 'item' : 'itens'}',
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: ClxSpace.x2),
                    child: Text(
                      'Os totais consideram todas as contas em aberto. As listas '
                      'abaixo respeitam o período e os filtros selecionados.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: context.clx.ink3),
                    ),
                  ),
                  if (showFilters) ...[
                    const SizedBox(height: ClxSpace.x4),
                    _FiltrosBar(
                      filters: _filters,
                      categorias: categorias,
                      contas: contas,
                      onChange: (f) => setState(() => _filters = f),
                      onClear: () =>
                          setState(() => _filters = const _CprFilters()),
                    ),
                  ],
                  const SizedBox(height: ClxSpace.x5),
                  _Colunas(
                    mostrarPagar: mostrarPagar,
                    mostrarReceber: mostrarReceber,
                    aPagar: aPagar,
                    aReceber: aReceber,
                    catById: catById,
                    contaById: contaById,
                    savingId: _savingId,
                    onPagar: _marcarPago,
                  ),
                  const SizedBox(height: ClxSpace.x5),
                  const _RodapeOs(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ─────────────────────── toolbar (período + filtros + abas) ─────────────────────── */

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.aba,
    required this.showFilters,
    required this.hasActiveFilters,
    required this.onAba,
    required this.onToggleFilters,
  });

  final _Aba aba;
  final bool showFilters;

  /// Há ao menos um filtro aplicado — mantém o botão "Filtros" preenchido
  /// mesmo com o painel fechado, sinalizando que o filtro ainda está ativo.
  final bool hasActiveFilters;
  final ValueChanged<_Aba> onAba;
  final VoidCallback onToggleFilters;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final filtrosButton = _FiltrosButton(
      active: showFilters || hasActiveFilters,
      onPressed: onToggleFilters,
    );
    // Mobile: período em largura total + botão "Filtros" na linha de baixo
    // (Row original estourava — período + botão não cabiam lado a lado em
    // ~360px).
    final periodoEFiltros = finIsMobile(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: double.infinity,
                child: FinPeriodSelector(expand: true),
              ),
              const SizedBox(height: ClxSpace.x3),
              filtrosButton,
            ],
          )
        : Row(
            children: [
              const FinPeriodSelector(),
              const SizedBox(width: ClxSpace.x3),
              filtrosButton,
            ],
          );

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
          periodoEFiltros,
          const SizedBox(height: ClxSpace.x3),
          SegmentedButton<_Aba>(
            segments: const [
              ButtonSegment(
                value: _Aba.pagar,
                label: Text('A pagar'),
                icon: Icon(Icons.south_west_rounded, size: 16),
              ),
              ButtonSegment(
                value: _Aba.receber,
                label: Text('A receber'),
                icon: Icon(Icons.north_east_rounded, size: 16),
              ),
              ButtonSegment(value: _Aba.todas, label: Text('Todas')),
            ],
            selected: {aba},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onAba(s.first),
            // Mobile: mesma inconsistência de largura da toolbar de
            // Categorias (review, feedback do dono) — o grupo fica encolhido
            // com a própria largura intrínseca enquanto o resto do header
            // mobile é full-width. `expandedInsets` estica os 3 segmentos
            // pra dividir a largura total igualmente.
            expandedInsets: finIsMobile(context) ? EdgeInsets.zero : null,
          ),
        ],
      ),
    );
  }
}

/// Botão "Filtros" da toolbar. Quando ativo (painel aberto ou filtro
/// aplicado), fica preenchido com a MESMA cor do chip "A pagar" selecionado
/// (secondaryContainer/onSecondaryContainer do tema — teal escuro/texto
/// branco), para reforçar visualmente que o filtro está em uso.
class _FiltrosButton extends StatelessWidget {
  const _FiltrosButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final scheme = Theme.of(context).colorScheme;
    final fg = active ? scheme.onSecondaryContainer : clx.ink2;
    return Material(
      color: active ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: ClxRadii.rPill,
      child: InkWell(
        onTap: onPressed,
        borderRadius: ClxRadii.rPill,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: ClxLayout.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x5),
          decoration: BoxDecoration(
            borderRadius: ClxRadii.rPill,
            border: active ? null : Border.all(color: clx.line2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list_rounded, size: 18, color: fg),
              const SizedBox(width: ClxSpace.x2),
              Text(
                'Filtros',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────── barra de filtros ─────────────────────── */

class _FiltrosBar extends StatelessWidget {
  const _FiltrosBar({
    required this.filters,
    required this.categorias,
    required this.contas,
    required this.onChange,
    required this.onClear,
  });

  final _CprFilters filters;
  final List<FinCategoria> categorias;
  final List<FinConta> contas;
  final ValueChanged<_CprFilters> onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final roots =
        categorias.where((c) => c.parentId == null && !c.arquivada).toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));

    return ClxCard(
      child: Wrap(
        spacing: ClxSpace.x4,
        runSpacing: ClxSpace.x3,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          _Filter<TipoLancamento?>(
            label: 'Tipo',
            value: filters.tipo,
            entries: [
              (value: null, text: 'Todos os tipos'),
              (value: TipoLancamento.despesa, text: 'Despesas (a pagar)'),
              (value: TipoLancamento.receita, text: 'Receitas (a receber)'),
            ],
            onChanged: (v) => onChange(filters.copyWith(tipo: v)),
          ),
          _Filter<OrigemLancamento?>(
            label: 'Origem',
            value: filters.origem,
            entries: [
              (value: null, text: 'Todas as origens'),
              (value: OrigemLancamento.manual, text: 'Manual'),
              (value: OrigemLancamento.viaOs, text: 'Via OS'),
            ],
            onChanged: (v) => onChange(filters.copyWith(origem: v)),
          ),
          _Filter<String?>(
            label: 'Categoria',
            value: filters.categoriaId,
            entries: [
              (value: null, text: 'Todas as categorias'),
              for (final c in roots) (value: c.id, text: c.nome),
            ],
            onChanged: (v) => onChange(filters.copyWith(categoriaId: v)),
          ),
          _Filter<String?>(
            label: 'Conta',
            value: filters.contaId,
            entries: [
              (value: null, text: 'Todas as contas'),
              for (final c in contas) (value: c.id, text: c.nome),
            ],
            onChanged: (v) => onChange(filters.copyWith(contaId: v)),
          ),
          _Filter<_Venc>(
            label: 'Vencimento',
            value: filters.venc,
            entries: const [
              (value: _Venc.todos, text: 'Todos os vencimentos'),
              (value: _Venc.vencidas, text: 'Vencidas'),
              (value: _Venc.hoje, text: 'Vence hoje'),
              (value: _Venc.d7, text: 'Próximos 7 dias'),
              (value: _Venc.d30, text: 'Próximos 30 dias'),
            ],
            onChanged: (v) => onChange(filters.copyWith(venc: v)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: TextButton.icon(
              onPressed: filters.ativos ? onClear : null,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Limpar filtros'),
              style: TextButton.styleFrom(foregroundColor: clx.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de filtro compacto (rótulo + dropdown), genérico no valor.
class _Filter<T> extends StatelessWidget {
  const _Filter({
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
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: tt.labelMedium?.copyWith(color: clx.ink3)),
        const SizedBox(height: ClxSpace.x1),
        Container(
          constraints: const BoxConstraints(minWidth: 150),
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
              style: tt.bodyLarge?.copyWith(color: clx.ink),
              dropdownColor: clx.bg,
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

/* ─────────────────────── colunas de contas ─────────────────────── */

class _Colunas extends StatelessWidget {
  const _Colunas({
    required this.mostrarPagar,
    required this.mostrarReceber,
    required this.aPagar,
    required this.aReceber,
    required this.catById,
    required this.contaById,
    required this.savingId,
    required this.onPagar,
  });

  final bool mostrarPagar;
  final bool mostrarReceber;
  final List<ContaPendente> aPagar;
  final List<ContaPendente> aReceber;
  final Map<String, FinCategoria> catById;
  final Map<String, FinConta> contaById;
  final String? savingId;
  final ValueChanged<FinLancamento> onPagar;

  @override
  Widget build(BuildContext context) {
    final pagar = _Coluna(
      titulo: 'Contas a pagar',
      itens: aPagar,
      tipo: TipoLancamento.despesa,
      catById: catById,
      contaById: contaById,
      savingId: savingId,
      onPagar: onPagar,
      vazio: 'Nenhuma conta a pagar no período.',
    );
    final receber = _Coluna(
      titulo: 'Contas a receber',
      itens: aReceber,
      tipo: TipoLancamento.receita,
      catById: catById,
      contaById: contaById,
      savingId: savingId,
      onPagar: onPagar,
      vazio: 'Nenhuma conta a receber no período.',
    );

    if (mostrarPagar && mostrarReceber) {
      return LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 720) {
            return Column(
              children: [
                pagar,
                const SizedBox(height: ClxSpace.x4),
                receber,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: pagar),
              const SizedBox(width: ClxSpace.x4),
              Expanded(child: receber),
            ],
          );
        },
      );
    }
    return mostrarPagar ? pagar : receber;
  }
}

class _Coluna extends StatelessWidget {
  const _Coluna({
    required this.titulo,
    required this.itens,
    required this.tipo,
    required this.catById,
    required this.contaById,
    required this.savingId,
    required this.onPagar,
    required this.vazio,
  });

  final String titulo;
  final List<ContaPendente> itens;
  final TipoLancamento tipo;
  final Map<String, FinCategoria> catById;
  final Map<String, FinConta> contaById;
  final String? savingId;
  final ValueChanged<FinLancamento> onPagar;
  final String vazio;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinSectionHeader(
            title: titulo,
            trailing: Text(
              '${itens.length} ${itens.length == 1 ? 'item' : 'itens'}',
              style: tt.bodyMedium?.copyWith(color: clx.ink3),
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          if (itens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ClxSpace.x5),
              child: Center(
                child: Text(
                  vazio,
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ),
            )
          else
            for (final p in itens)
              Padding(
                padding: const EdgeInsets.only(bottom: ClxSpace.x2),
                child: _PendenteRow(
                  pendente: p,
                  tipo: tipo,
                  categoria: catById[p.lancamento.categoriaId],
                  conta: contaById[p.lancamento.contaId],
                  saving: savingId == p.lancamento.id,
                  onPagar: () => onPagar(p.lancamento),
                ),
              ),
        ],
      ),
    );
  }
}

class _PendenteRow extends StatelessWidget {
  const _PendenteRow({
    required this.pendente,
    required this.tipo,
    required this.categoria,
    required this.conta,
    required this.saving,
    required this.onPagar,
  });

  final ContaPendente pendente;
  final TipoLancamento tipo;
  final FinCategoria? categoria;
  final FinConta? conta;
  final bool saving;
  final VoidCallback onPagar;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final l = pendente.lancamento;
    final venc = (l.vencimento?.isNotEmpty ?? false) ? l.vencimento! : l.data;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Row(
        children: [
          FinCategoriaAvatar(categoria: categoria, size: 32),
          const SizedBox(width: ClxSpace.x2),
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 12,
                      color: pendente.emAtraso ? clx.error : clx.ink3,
                    ),
                    const SizedBox(width: ClxSpace.x1),
                    Flexible(
                      child: Text(
                        'Vence ${formatDateOnlyBr(venc)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: pendente.emAtraso ? clx.error : clx.ink3,
                          fontWeight: pendente.emAtraso
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (pendente.vencendoHoje) ...[
                      const SizedBox(width: ClxSpace.x2),
                      ClxChip(label: 'Hoje', color: clx.warning, dense: true),
                    ] else if (pendente.emAtraso) ...[
                      const SizedBox(width: ClxSpace.x2),
                      ClxChip(label: 'Atrasado', color: clx.error, dense: true),
                    ],
                    if (conta != null) ...[
                      const SizedBox(width: ClxSpace.x2),
                      Flexible(child: ContaBadge(conta: conta!)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: ClxSpace.x2),
          Text(
            formatCurrency(l.valor),
            style: tt.bodyLarge?.copyWith(
              color: tipoColor(clx, tipo),
              fontWeight: FontWeight.w800,
            ),
          ),
          saving
              ? const Padding(
                  padding: EdgeInsets.all(ClxSpace.x2),
                  child: Spinner(size: 18),
                )
              : IconButton(
                  tooltip: 'Marcar como pago',
                  icon: Icon(
                    Icons.check_circle_outline_rounded,
                    color: clx.success,
                  ),
                  onPressed: onPagar,
                ),
        ],
      ),
    );
  }
}

/* ─────────────────────── rodapé informativo (recebimentos via OS) ─────────────────────── */

class _RodapeOs extends StatelessWidget {
  const _RodapeOs();

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: clx.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 18, color: clx.primary),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recebimentos via Ordens de Serviço',
                      style: tt.titleSmall?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quando uma OS é marcada como paga, o sistema pode gerar '
                      'automaticamente a conta a receber e registrar o pagamento, '
                      'mantendo suas finanças sempre atualizadas.',
                      style: tt.bodyMedium?.copyWith(
                        color: clx.ink3,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
