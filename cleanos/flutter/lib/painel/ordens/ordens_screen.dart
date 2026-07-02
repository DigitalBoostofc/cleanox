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

  Future<void> _novaOS() async {
    final saved = await showOSForm(context);
    if (saved == true) {
      await ref.read(ordensControllerProvider.notifier).refresh();
      if (mounted) {
        showClxToast(context, 'OS criada.', type: ToastType.success);
      }
    }
  }

  Future<void> _editar(OrdemServico os) async {
    final saved = await showOSForm(context, editing: os);
    if (saved == true) {
      await ref.read(ordensControllerProvider.notifier).refresh();
      if (mounted) {
        showClxToast(context, 'OS atualizada.', type: ToastType.success);
      }
    }
  }

  void _execucao(OrdemServico os) {
    // Rota deep-linkável `/painel/ordens/:osId/execucao` (tela cheia no raiz).
    context.push('/painel/ordens/${os.id}/execucao');
  }

  Future<void> _abrirDetalhe(OrdemServico os) async {
    final result = await showOSDetail(context, os);
    if (result == null) return;
    if (result.changed) {
      await ref.read(ordensControllerProvider.notifier).refresh();
    }
    if (!mounted) return;
    switch (result.intent) {
      case OSDetailIntent.editar:
        await _editar(os);
      case OSDetailIntent.execucao:
        _execucao(os);
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
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: filtrando
            ? 'Nenhuma OS com status "${state.filter.status!.label}"'
            : 'Nenhuma ordem de serviço',
        message: 'Clique em "Nova OS" para criar a primeira.',
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cardsView(OrdensState state) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(ClxSpace.x4),
      itemCount: state.items.length + _extra(state),
      itemBuilder: (context, i) {
        if (i >= state.items.length) return _footer(state, i);
        final os = state.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: ClxSpace.x3),
          child: _OrdemCard(
            os: os,
            onTap: () => _abrirDetalhe(os),
            onExecucao: () => _execucao(os),
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
        ],
      ),
    );
  }
}

/// Abas de status (Todas + cada OSStatus) — roláveis horizontalmente.
class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.active, required this.onSelect});

  final OSStatus? active;
  final ValueChanged<OSStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
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
            _Tab(
              label: 'Todas',
              selected: active == null,
              onTap: () => onSelect(null),
            ),
            for (final s in OSStatus.all)
              _Tab(
                label: s.label,
                selected: active == s,
                onTap: () => onSelect(s),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
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
            child: Text(
              label,
              style: TextStyle(
                color: selected ? clx.primary : clx.ink2,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
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
        style: TextStyle(
          color: clx.ink3,
          fontSize: 11,
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
  });

  final OrdemServico os;
  final VoidCallback onTap;
  final VoidCallback onExecucao;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final prof = os.expand?.profissional;
    final aberta =
        os.status != OSStatus.concluida && os.status != OSStatus.cancelada;
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
                    os.nomeCurto.isEmpty ? '—' : os.nomeCurto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: clx.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    os.bairro,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: clx.ink3, fontSize: 12),
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
                style: TextStyle(color: clx.ink2, fontSize: 13.5),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatDateTime(os.dataHora),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: clx.ink2, fontSize: 13),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                prof?.displayName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: clx.ink2, fontSize: 13.5),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatCurrency(os.valorServico ?? 0),
                style: TextStyle(
                  color: clx.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(status: os.status, dense: true),
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
  });

  final OrdemServico os;
  final VoidCallback onTap;
  final VoidCallback onExecucao;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final prof = os.expand?.profissional;
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
                      style: TextStyle(
                        color: clx.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${os.nomeCurto} · ${os.bairro}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: clx.ink3, fontSize: 12.5),
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
                style: TextStyle(color: clx.ink2, fontSize: 13),
              ),
              const Spacer(),
              Text(
                formatCurrency(os.valorServico ?? 0),
                style: TextStyle(
                  color: clx.ink,
                  fontSize: 14,
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
                    style: TextStyle(color: clx.ink2, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: ClxSpace.x2),
          Align(
            alignment: Alignment.centerRight,
            child: ClxButton(
              label: 'Execução',
              variant: ClxButtonVariant.ghost,
              icon: Icons.arrow_forward_rounded,
              onPressed: onExecucao,
            ),
          ),
        ],
      ),
    );
  }
}
