/// servicos_list_screen.dart — Catálogo RICO de Serviços do Painel.
///
/// Espelha `ServicosListPage.tsx`: busca por nome + filtros de categoria/grupo (NO
/// SERVIDOR), toggle de status inline, ações (editar/duplicar/excluir), tabela densa
/// no desktop / cards no mobile, scroll infinito virtualizado. Todos os estados.
/// Abre o [ServicoEditorScreen] (rota empilhada) para criar/editar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/models/servico.dart';
import 'servicos_controller.dart';
import 'servicos_labels.dart';

const double _kTableBreakpoint = 820;

class ServicosListScreen extends ConsumerStatefulWidget {
  const ServicosListScreen({super.key});

  @override
  ConsumerState<ServicosListScreen> createState() => _ServicosListScreenState();
}

class _ServicosListScreenState extends ConsumerState<ServicosListScreen> {
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
      ref.read(servicosControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _novo() async {
    // Rota deep-linkável `/painel/servicos/novo` (tela cheia no navigator raiz).
    final saved = await context.push<bool>('/painel/servicos/novo');
    if (saved == true) {
      await ref.read(servicosControllerProvider.notifier).refresh();
      if (mounted) {
        showClxToast(context, 'Serviço criado.', type: ToastType.success);
      }
    }
  }

  Future<void> _editar(ServicoPB s) async {
    // Rota deep-linkável `/painel/servicos/:id` (tela cheia no navigator raiz).
    final saved = await context.push<bool>('/painel/servicos/${s.id}');
    if (saved == true) {
      await ref.read(servicosControllerProvider.notifier).refresh();
      if (mounted) {
        showClxToast(context, 'Serviço atualizado.', type: ToastType.success);
      }
    }
  }

  Future<void> _duplicar(ServicoPB s) async {
    try {
      await ref.read(servicosControllerProvider.notifier).duplicate(s);
      if (mounted) {
        showClxToast(context, 'Serviço duplicado.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível duplicar o serviço.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _excluir(ServicoPB s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(nome: s.nome),
    );
    if (confirm != true) return;
    try {
      await ref.read(servicosControllerProvider.notifier).delete(s.id);
      if (mounted) {
        showClxToast(context, 'Serviço excluído.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível excluir o serviço.',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(servicosControllerProvider);
    return Column(
      children: [
        _Toolbar(onNovo: _novo),
        Expanded(child: _body(state)),
      ],
    );
  }

  Widget _body(ServicosState state) {
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
                  ref.read(servicosControllerProvider.notifier).refresh(),
            ),
          ),
        ),
      );
    }
    if (state.isEmpty) {
      return EmptyState(
        icon: state.hasFilters
            ? Icons.search_off_rounded
            : Icons.cleaning_services_outlined,
        title: state.hasFilters
            ? 'Nenhum serviço encontrado'
            : 'Nenhum serviço cadastrado',
        message: state.hasFilters
            ? 'Tente ajustar a busca ou os filtros.'
            : 'Clique em "Novo serviço" para começar.',
        action: state.hasFilters
            ? null
            : ClxButton(
                label: 'Novo serviço',
                icon: Icons.add_rounded,
                onPressed: _novo,
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final table = c.maxWidth >= _kTableBreakpoint;
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(servicosControllerProvider.notifier).refresh(),
          color: context.clx.primary,
          child: table ? _tableView(state) : _cardsView(state),
        );
      },
    );
  }

  int _extra(ServicosState s) => s.hasMore ? 1 : 0;

  Widget _footer(ServicosState state, int i) {
    if (i < state.items.length) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.all(ClxSpace.x4),
      child: Center(child: Spinner(size: 20)),
    );
  }

  Widget _tableView(ServicosState state) {
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
              _HeaderCell('Serviço', flex: 4),
              _HeaderCell('Grupo', flex: 2),
              _HeaderCell('Valor', flex: 3),
              _HeaderCell('Tempo médio', flex: 2),
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
              final s = state.items[i];
              return _ServicoRow(
                servico: s,
                onTap: () => _editar(s),
                onToggle: () => ref
                    .read(servicosControllerProvider.notifier)
                    .toggleStatus(s),
                onDuplicar: () => _duplicar(s),
                onExcluir: () => _excluir(s),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cardsView(ServicosState state) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(ClxSpace.x4),
      itemCount: state.items.length + _extra(state),
      itemBuilder: (context, i) {
        if (i >= state.items.length) return _footer(state, i);
        final s = state.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: ClxSpace.x3),
          child: _ServicoCard(
            servico: s,
            onTap: () => _editar(s),
            onToggle: () =>
                ref.read(servicosControllerProvider.notifier).toggleStatus(s),
            onDuplicar: () => _duplicar(s),
            onExcluir: () => _excluir(s),
          ),
        );
      },
    );
  }
}

class _Toolbar extends ConsumerStatefulWidget {
  const _Toolbar({required this.onNovo});
  final VoidCallback onNovo;

  @override
  ConsumerState<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends ConsumerState<_Toolbar> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final state = ref.watch(servicosControllerProvider);
    final notifier = ref.read(servicosControllerProvider.notifier);
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
      child: Wrap(
        spacing: ClxSpace.x3,
        runSpacing: ClxSpace.x2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _search,
              onChanged: notifier.setSearch,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Buscar por nome do serviço…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<Categoria?>(
              initialValue: state.categoria,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('Todas as categorias'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todas as categorias'),
                ),
                for (final c in Categoria.values)
                  DropdownMenuItem(value: c, child: Text(categoriaLabel(c))),
              ],
              onChanged: notifier.setCategoria,
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<Grupo?>(
              initialValue: state.grupo,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('Todos os grupos'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos os grupos'),
                ),
                for (final g in Grupo.values)
                  DropdownMenuItem(value: g, child: Text(grupoLabel(g))),
              ],
              onChanged: notifier.setGrupo,
            ),
          ),
          ClxButton(
            label: 'Novo serviço',
            icon: Icons.add_rounded,
            onPressed: widget.onNovo,
          ),
        ],
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

/// Pílula de status clicável (ativa/inativa) — otimista.
class _StatusToggle extends StatelessWidget {
  const _StatusToggle({required this.servico, required this.onToggle});
  final ServicoPB servico;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final ativo = servico.status == ServicoStatus.ativo;
    final color = ativo ? clx.success : clx.ink3;
    return Tooltip(
      message: ativo ? 'Clique para inativar' : 'Clique para ativar',
      child: Material(
        color: color.withValues(alpha: 0.14),
        borderRadius: ClxRadii.rPill,
        child: InkWell(
          onTap: onToggle,
          borderRadius: ClxRadii.rPill,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ClxSpace.x3,
              vertical: ClxSpace.x1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ativo ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  servicoStatusLabel(servico.status ?? ServicoStatus.inativo),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GrupoChip extends StatelessWidget {
  const _GrupoChip({required this.servico});
  final ServicoPB servico;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final grupo = servico.grupo ?? Grupo.outros;
    return ClxChip(
      label: grupoLabel(grupo),
      color: clx.groupColor(grupo),
      dense: true,
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.onDuplicar, required this.onExcluir});
  final VoidCallback onDuplicar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return PopupMenuButton<String>(
      tooltip: 'Mais ações',
      icon: Icon(Icons.more_vert_rounded, size: 18, color: clx.ink3),
      onSelected: (v) {
        if (v == 'dup') onDuplicar();
        if (v == 'del') onExcluir();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'dup',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 18),
              SizedBox(width: ClxSpace.x2),
              Text('Duplicar'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'del',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: clx.error),
              const SizedBox(width: ClxSpace.x2),
              Text('Excluir', style: TextStyle(color: clx.error)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServicoRow extends StatelessWidget {
  const _ServicoRow({
    required this.servico,
    required this.onTap,
    required this.onToggle,
    required this.onDuplicar,
    required this.onExcluir,
  });

  final ServicoPB servico;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDuplicar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
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
              flex: 4,
              child: Row(
                children: [
                  Icon(
                    servico.categoria == Categoria.residencial
                        ? Icons.home_outlined
                        : Icons.directions_car_outlined,
                    size: 16,
                    color: clx.ink3,
                  ),
                  const SizedBox(width: ClxSpace.x2),
                  Expanded(
                    child: Text(
                      servico.nome.isEmpty ? '—' : servico.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: clx.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _GrupoChip(servico: servico),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                formatValorServico(servico),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: clx.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatTempoMedio(
                  servico.tempoMedioMin,
                  servico.tempoMedioLabel,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: clx.ink2, fontSize: 13),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusToggle(servico: servico, onToggle: onToggle),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onTap,
                  ),
                  _RowMenu(onDuplicar: onDuplicar, onExcluir: onExcluir),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicoCard extends StatelessWidget {
  const _ServicoCard({
    required this.servico,
    required this.onTap,
    required this.onToggle,
    required this.onDuplicar,
    required this.onExcluir,
  });

  final ServicoPB servico;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDuplicar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                servico.categoria == Categoria.residencial
                    ? Icons.home_outlined
                    : Icons.directions_car_outlined,
                size: 18,
                color: clx.ink3,
              ),
              const SizedBox(width: ClxSpace.x2),
              Expanded(
                child: Text(
                  servico.nome.isEmpty ? '—' : servico.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusToggle(servico: servico, onToggle: onToggle),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          Row(
            children: [
              _GrupoChip(servico: servico),
              const SizedBox(width: ClxSpace.x2),
              Expanded(
                child: Text(
                  formatTempoMedio(
                    servico.tempoMedioMin,
                    servico.tempoMedioLabel,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: clx.ink3, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatValorServico(servico),
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onTap,
              ),
              _RowMenu(onDuplicar: onDuplicar, onExcluir: onExcluir),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.nome});
  final String nome;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return AlertDialog(
      backgroundColor: clx.bg,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      title: const Text('Excluir serviço'),
      content: Text(
        'Tem certeza que deseja excluir o serviço "$nome"? Esta ação não pode '
        'ser desfeita. Considere INATIVAR o serviço caso ele ainda seja usado '
        'em orçamentos ou OS.',
        style: TextStyle(color: clx.ink2, fontSize: 14, height: 1.5),
      ),
      actions: [
        ClxButton(
          label: 'Cancelar',
          variant: ClxButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        ClxButton(
          label: 'Excluir',
          variant: ClxButtonVariant.danger,
          icon: Icons.delete_outline_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
