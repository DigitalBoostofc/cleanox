/// ordens_screen.dart — Lista + gestão de Ordens de Serviço do Painel.
///
/// Espelha `OrdensServico.tsx` com mitigações Flutter Web (§4): filtros NO SERVIDOR
/// (status/profissional) + paginação + scroll infinito virtualizado. Layout MD3
/// adaptativo (tabela densa ≥ 860px / cards). Ações: Nova OS, editar, reatribuir e
/// cancelar (via detalhe), e abrir a Execução (visão admin). Todos os estados.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_surface_provider.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import 'ordens_controller.dart';
import 'os_detail.dart';
import 'os_form.dart';

const double _kTableBreakpoint = 860;

class OrdensScreen extends ConsumerStatefulWidget {
  const OrdensScreen({super.key});

  @override
  ConsumerState<OrdensScreen> createState() => _OrdensScreenState();
}

class _OrdensScreenState extends ConsumerState<OrdensScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(ordensControllerProvider.notifier).loadMore();
    }
  }

  /// Recarrega a lista e, se a OS salva não pertence mais à aba ATIVA, leva a
  /// lista até a aba do status novo.
  ///
  /// F-232: salvar o form pode mudar o status na surdina (agendada +
  /// profissional → atribuída). Sem isto a OS deixa de casar com o filtro ativo
  /// e simplesmente SOME da tela — o admin fica olhando um empty-state achando
  /// que apagou a OS. Mesmo comportamento que o detalhe já tinha ao reatribuir.
  Future<void> _mostrarNaAbaCerta(OrdemServico os) async {
    final notifier = ref.read(ordensControllerProvider.notifier);
    final filtroAtivo = ref.read(ordensControllerProvider).filter.status;
    if (filtroAtivo != null && filtroAtivo != os.status) {
      await notifier.setStatus(os.status);
    } else {
      await notifier.refresh();
    }
  }

  Future<void> _novaOS() async {
    final salva = await showOSForm(context);
    if (salva == null || !mounted) return;
    ref.invalidate(ordensCountsProvider);
    await _mostrarNaAbaCerta(salva);
    if (mounted) {
      showClxToast(context, 'OS criada.', type: ToastType.success);
    }
  }

  Future<void> _editar(OrdemServico os) async {
    final salva = await showOSForm(context, editing: os);
    if (salva == null || !mounted) return;
    ref.invalidate(ordensCountsProvider);
    await _mostrarNaAbaCerta(salva);
    if (mounted) {
      showClxToast(context, 'OS atualizada.', type: ToastType.success);
    }
  }

  /// Cancela uma OS inline (confirmação + toast). Espelha `handleCancel` do React.
  Future<void> _cancelar(OrdemServico os) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.clx.bg,
        shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
        title: const Text('Cancelar OS'),
        content: const Text('Deseja cancelar esta ordem de serviço?'),
        actions: [
          ClxButton(
            label: 'Voltar',
            variant: ClxButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ClxButton(
            label: 'Cancelar OS',
            variant: ClxButtonVariant.danger,
            icon: Icons.cancel_outlined,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ordensControllerProvider.notifier).cancelar(os.id);
      ref.invalidate(ordensCountsProvider);
      if (mounted) {
        showClxToast(context, 'OS cancelada.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível cancelar a OS.',
          type: ToastType.error,
        );
      }
    }
  }

  /// Abre a Execução (visão admin) e ESPERA a volta: lá dentro dá para mudar
  /// valor, serviço e status, então a lista e os contadores desta tela ficam
  /// velhos se ninguém recarregar ao voltar (F-233).
  Future<void> _execucao(OrdemServico os) async {
    // Rota deep-linkável `/painel/ordens/:osId/execucao` (tela cheia no raiz).
    await context.push('/painel/ordens/${os.id}/execucao');
    if (!mounted) return;
    await ref.read(ordensControllerProvider.notifier).refresh();
    ref.invalidate(ordensCountsProvider);
  }

  Future<void> _abrirDetalhe(OrdemServico os) async {
    final result = await showOSDetail(context, os);
    if (result == null) return;
    if (result.changed) {
      await ref.read(ordensControllerProvider.notifier).refresh();
      ref.invalidate(ordensCountsProvider);
    }
    if (!mounted) return;
    // `result.os` é a OS ATUAL — o detalhe pode ter reatribuído enquanto estava
    // aberto. Abrir o form com o `os` do closure reabria o form com o registro
    // velho e gravava `status=atribuida` + `profissional=""` (F-234).
    final atual = result.os ?? os;
    switch (result.intent) {
      case OSDetailIntent.editar:
        await _editar(atual);
      case OSDetailIntent.execucao:
        await _execucao(atual);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordensControllerProvider);
    return Column(
      children: [
        _Toolbar(onNovaOS: _novaOS),
        _StatusTabs(
          active: state.filter.status,
          onSelect: (s) =>
              ref.read(ordensControllerProvider.notifier).setStatus(s),
        ),
        Expanded(child: _body(state)),
      ],
    );
  }

  Widget _body(OrdensState state) {
    if (state.loading) {
      return const Center(child: Spinner(size: 26));
    }
    if (state.error != null && state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(
              message: state.error!,
              onRetry: () =>
                  ref.read(ordensControllerProvider.notifier).refresh(),
            ),
          ),
        ),
      );
    }
    if (state.isEmpty) {
      final filtrando = state.filter.status != null;
      final periodo = state.filter.periodo;
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: filtrando
            ? 'Nenhuma OS com status "${state.filter.status!.label}"'
            : 'Nenhuma ordem de serviço',
        message: periodo != OrdensPeriodo.tudo
            ? 'Nada no período "${periodo.label}" — troque o período acima '
                  'ou crie uma Nova OS.'
            : 'Clique em "Nova OS" para criar a primeira.',
        action: ClxButton(
          label: 'Nova OS',
          icon: Icons.add_rounded,
          onPressed: _novaOS,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final table = c.maxWidth >= _kTableBreakpoint;
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(ordensControllerProvider.notifier).refresh(),
          color: context.clx.primary,
          child: table ? _tableView(state) : _cardsView(state),
        );
      },
    );
  }

  int _extra(OrdensState s) => s.hasMore ? 1 : 0;

  Widget _footer(OrdensState state, int i) {
    if (i < state.items.length) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.all(ClxSpace.x4),
      child: Center(child: Spinner(size: 20)),
    );
  }

  Widget _tableView(OrdensState state) {
    final clx = context.clx;
    return Column(
      children: [
        Container(
          color: clx.bg3,
          padding: const EdgeInsets.symmetric(
            horizontal: ClxSpace.x6,
            vertical: ClxSpace.x3,
          ),
          child: Row(
            children: const [
              _HeaderCell('Cliente', flex: 3),
              _HeaderCell('Serviço', flex: 3),
              _HeaderCell('Data / Hora', flex: 2),
              _HeaderCell('Profissional', flex: 2),
              _HeaderCell('Valor', flex: 2),
              _HeaderCell('Status', flex: 2),
              _HeaderCell('', flex: 2),
            ],
          ),
        ),
        Divider(height: 1, color: clx.line),
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            itemCount: state.items.length + _extra(state),
            separatorBuilder: (_, __) => Divider(height: 1, color: clx.line),
            itemBuilder: (context, i) {
              if (i >= state.items.length) return _footer(state, i);
              final os = state.items[i];
              return _OrdemRow(
                os: os,
                onTap: () => _abrirDetalhe(os),
                onExecucao: () => _execucao(os),
                onEditar: () => _editar(os),
                onCancelar: () => _cancelar(os),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cardsView(OrdensState state) {
    final easypay =
        ref.watch(isFintechCleanProvider) || ref.watch(isNarrowWebProvider);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(ClxSpace.x4),
      itemCount: state.items.length + _extra(state),
      itemBuilder: (context, i) {
        if (i >= state.items.length) return _footer(state, i);
        final os = state.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: ClxSpace.x3),
          child: ClxFadeSlide(
            delay: Duration(milliseconds: (i % 8) * 35),
            child: _OrdemCard(
              os: os,
              easypay: easypay,
              onTap: () => _abrirDetalhe(os),
              onExecucao: () => _execucao(os),
              onCancelar: () => _cancelar(os),
            ),
          ),
        );
      },
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.onNovaOS});

  final VoidCallback onNovaOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final filter = ref.watch(ordensControllerProvider.select((s) => s.filter));
    final lookups = ref.watch(ordensLookupsProvider);
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
          ClxButton(
            label: 'Nova OS',
            icon: Icons.add_rounded,
            onPressed: onNovaOS,
          ),
          const SizedBox(width: ClxSpace.x3),
          // Filtro por profissional (server-side).
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: lookups.maybeWhen(
                data: (lk) => DropdownButtonFormField<String>(
                  initialValue: filter.profissionalId ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: clx.bg2,
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                    border: const OutlineInputBorder(
                      borderRadius: ClxRadii.rMd,
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Todos os profissionais'),
                    ),
                    for (final p in lk.profissionais)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => ref
                      .read(ordensControllerProvider.notifier)
                      .setProfissional((v ?? '').isEmpty ? null : v),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(width: ClxSpace.x3),
          // Filtro de período (server-side): janela de data_hora na lista e nas
          // contagens. Era uma linha de chips; virou dropdown ao lado do
          // ordenador (pedido do dono, 16/07).
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: DropdownButtonFormField<OrdensPeriodo>(
              initialValue: filter.periodo,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: clx.bg2,
                prefixIcon: const Icon(Icons.event_outlined, size: 18),
                border: const OutlineInputBorder(
                  borderRadius: ClxRadii.rMd,
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                for (final p in OrdensPeriodo.values)
                  DropdownMenuItem(
                    value: p,
                    child: Text(p.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (p) {
                if (p != null) {
                  ref.read(ordensControllerProvider.notifier).setPeriodo(p);
                }
              },
            ),
          ),
          const SizedBox(width: ClxSpace.x3),
          // Ordenação por ABA de status (salva em prefs — cada status independente).
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: DropdownButtonFormField<OrdensSort>(
              // Key força rebuild ao trocar de aba (initialValue não reage sozinho).
              key: ValueKey(
                'ordens-sort-${filter.status?.wire ?? 'all'}-${filter.sort.name}',
              ),
              initialValue: filter.sort,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: clx.bg2,
                prefixIcon: const Icon(Icons.swap_vert_rounded, size: 18),
                border: const OutlineInputBorder(
                  borderRadius: ClxRadii.rMd,
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                for (final s in OrdensSort.values)
                  DropdownMenuItem(
                    value: s,
                    child: Text(s.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (s) {
                if (s != null) {
                  ref.read(ordensControllerProvider.notifier).setSort(s);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Abas de status (Todas + cada OSStatus) — roláveis horizontalmente, com badge
/// de contagem por status (espelha `countByStatus` do React).
class _StatusTabs extends ConsumerWidget {
  const _StatusTabs({required this.active, required this.onSelect});

  final OSStatus? active;
  final ValueChanged<OSStatus?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final data = ref
        .watch(ordensCountsProvider)
        .maybeWhen(data: (d) => d, orElse: () => null);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x6,
          vertical: ClxSpace.x2,
        ),
        child: Row(
          children: [
            // Status primeiro (Agendada é o default de entrada); "Todas" é a
            // rota de fuga e mora no FIM (pedido do dono, 16/07).
            for (final s in OSStatus.all)
              _Tab(
                label: s.label,
                count: data?.of(s),
                selected: active == s,
                onTap: () => onSelect(s),
              ),
            _Tab(
              label: 'Todas',
              count: data?.total,
              alwaysShowCount: true,
              selected: active == null,
              onTap: () => onSelect(null),
            ),
          ],
        ),
      ),
    );
  }
}


class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.alwaysShowCount = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Contagem exibida no badge (null enquanto carrega). Só aparece quando > 0,
  /// exceto na aba "Todas" ([alwaysShowCount]).
  final int? count;
  final bool alwaysShowCount;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final showBadge =
        count != null && (alwaysShowCount || count! > 0);
    return Padding(
      padding: const EdgeInsets.only(right: ClxSpace.x2),
      child: Material(
        color: selected
            ? clx.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: ClxRadii.rPill,
        child: InkWell(
          onTap: onTap,
          borderRadius: ClxRadii.rPill,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ClxSpace.x4,
              vertical: ClxSpace.x2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: tt.bodyLarge?.copyWith(
                    color: selected ? clx.primary : clx.ink2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (showBadge) ...[
                  const SizedBox(width: ClxSpace.x2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? clx.primary.withValues(alpha: 0.18)
                          : clx.bg3,
                      borderRadius: ClxRadii.rPill,
                    ),
                    child: Text(
                      '${count!}',
                      style: tt.labelSmall?.copyWith(
                        color: selected ? clx.primary : clx.ink3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.flex = 1});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: clx.ink3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _OrdemRow extends StatelessWidget {
  const _OrdemRow({
    required this.os,
    required this.onTap,
    required this.onExecucao,
    required this.onEditar,
    required this.onCancelar,
  });

  final OrdemServico os;
  final VoidCallback onTap;
  final VoidCallback onExecucao;
  final VoidCallback onEditar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final prof = os.expand?.profissional;
    final aberta =
        os.status != OSStatus.concluida && os.status != OSStatus.cancelada;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x6,
          vertical: ClxSpace.x3,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    os.clienteNomeExibicao.isEmpty ? '—' : os.clienteNomeExibicao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    os.bairro,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: clx.ink3),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                os.tipoServicoNome ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge?.copyWith(color: clx.ink2),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatDateTime(os.dataHora),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(color: clx.ink2),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                prof?.displayName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge?.copyWith(color: clx.ink2),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatCurrency(os.valorServico ?? 0),
                style: tt.bodyLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StatusBadge(status: os.status, dense: true),
                  if (os.avaliacaoNota != null) ...[
                    const SizedBox(height: 3),
                    StarRating(value: os.avaliacaoNota!, size: 12),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Execução',
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    onPressed: onExecucao,
                  ),
                  if (aberta)
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: onEditar,
                    ),
                  if (aberta)
                    IconButton(
                      tooltip: 'Cancelar OS',
                      icon: Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: context.clx.error,
                      ),
                      onPressed: onCancelar,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdemCard extends StatelessWidget {
  const _OrdemCard({
    required this.os,
    required this.onTap,
    required this.onExecucao,
    required this.onCancelar,
    this.easypay = false,
  });

  final OrdemServico os;
  final VoidCallback onTap;
  final VoidCallback onExecucao;
  final VoidCallback onCancelar;
  final bool easypay;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final prof = os.expand?.profissional;
    final aberta =
        os.status != OSStatus.concluida && os.status != OSStatus.cancelada;
    final tt = Theme.of(context).textTheme;
    final valor = formatCurrency(os.valorTotal);

    if (easypay) {
      return Material(
        color: clx.bg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: clx.line),
              boxShadow: [
                BoxShadow(
                  color: clx.ink.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        clx.statusColor(os.status),
                        clx.primary.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              os.tipoServicoNome ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: clx.ink,
                              ),
                            ),
                          ),
                          StatusBadge(status: os.status, dense: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${os.clienteNomeExibicao} · ${os.bairro}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(color: clx.ink3),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 15, color: clx.ink3),
                          const SizedBox(width: 4),
                          Text(
                            formatDateTime(os.dataHora),
                            style: tt.bodySmall?.copyWith(color: clx.ink2),
                          ),
                          const Spacer(),
                          Text(
                            valor,
                            style: tt.titleMedium?.copyWith(
                              color: clx.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      if (prof != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          prof.displayName,
                          style: tt.labelMedium?.copyWith(color: clx.ink3),
                        ),
                      ],
                      if (os.avaliacaoNota != null) ...[
                        const SizedBox(height: 6),
                        StarRating(value: os.avaliacaoNota!, size: 14),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (aberta)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onCancelar,
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Cancelar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: clx.error,
                                  side: BorderSide(
                                    color: clx.error.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ),
                          if (aberta) const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: onExecucao,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                              ),
                              label: const Text('Execução'),
                            ),
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

    return ClxCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      os.tipoServicoNome ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${os.clienteNomeExibicao} · ${os.bairro}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(color: clx.ink3),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: os.status, dense: true),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 15, color: clx.ink3),
              const SizedBox(width: ClxSpace.x1),
              Text(
                formatDateTime(os.dataHora),
                style: tt.bodyMedium?.copyWith(color: clx.ink2),
              ),
              const Spacer(),
              Text(
                formatCurrency(os.valorServico ?? 0),
                style: tt.bodyLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (prof != null) ...[
            const SizedBox(height: ClxSpace.x1),
            Row(
              children: [
                Icon(Icons.badge_outlined, size: 15, color: clx.ink3),
                const SizedBox(width: ClxSpace.x1),
                Expanded(
                  child: Text(
                    prof.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: clx.ink2),
                  ),
                ),
              ],
            ),
          ],
          if (os.avaliacaoNota != null) ...[
            const SizedBox(height: ClxSpace.x1),
            StarRating(value: os.avaliacaoNota!, size: 14),
          ],
          const SizedBox(height: ClxSpace.x2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (aberta)
                ClxButton(
                  label: 'Cancelar',
                  variant: ClxButtonVariant.danger,
                  icon: Icons.cancel_outlined,
                  onPressed: onCancelar,
                ),
              if (aberta) const SizedBox(width: ClxSpace.x2),
              ClxButton(
                label: 'Execução',
                variant: ClxButtonVariant.ghost,
                icon: Icons.arrow_forward_rounded,
                onPressed: onExecucao,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
