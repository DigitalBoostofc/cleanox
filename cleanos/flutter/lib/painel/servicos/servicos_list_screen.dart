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
import '../../vitrine/admin/vitrine_midia_repository.dart';
import 'servicos_controller.dart';
import 'servicos_labels.dart';
import 'servicos_midia_index.dart';
import 'taxonomia/servicos_taxonomia_screen.dart';
import 'taxonomia/taxonomia_models.dart';
import 'taxonomia/taxonomia_providers.dart';

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
      ref.invalidate(servicosMidiaIndexProvider);
      if (mounted) {
        showClxToast(context, 'Serviço criado.', type: ToastType.success);
      }
    }
  }

  Future<void> _editar(ServicoPB s) async {
    // Rota deep-linkável `/painel/servicos/:id` (tela cheia no navigator raiz).
    final saved = await context.push<bool>('/painel/servicos/${s.id}');
    // Sempre revalida fotos: upload no editor não depende de "salvar" o serviço.
    ref.invalidate(servicosMidiaIndexProvider);
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
    final midiaAsync = ref.watch(servicosMidiaIndexProvider);
    final midiaIndex =
        midiaAsync.valueOrNull ?? const <String, List<VitrineMidiaItem>>{};
    return Column(
      children: [
        _Toolbar(onNovo: _novo),
        Expanded(child: _body(state, midiaIndex)),
      ],
    );
  }

  Widget _body(
    ServicosState state,
    Map<String, List<VitrineMidiaItem>> midiaIndex,
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
          onRefresh: () async {
            await ref.read(servicosControllerProvider.notifier).refresh();
            ref.invalidate(servicosMidiaIndexProvider);
          },
          color: context.clx.primary,
          child: table
              ? _tableView(state, midiaIndex)
              : _cardsView(state, midiaIndex),
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

  Widget _tableView(
    ServicosState state,
    Map<String, List<VitrineMidiaItem>> midiaIndex,
  ) {
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
              _HeaderCell('Categoria / Grupo', flex: 3),
              _HeaderCell('Valor', flex: 2),
              _HeaderCell('Fotos', flex: 2),
              _HeaderCell('Tipo de valor', flex: 2),
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
              final fotos = midiaIndex[s.id] ?? const <VitrineMidiaItem>[];
              return _ServicoRow(
                servico: s,
                fotos: fotos,
                onTap: () => _editar(s),
                onFotos: () => _showFotos(s, fotos),
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

  Widget _cardsView(
    ServicosState state,
    Map<String, List<VitrineMidiaItem>> midiaIndex,
  ) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(ClxSpace.x4),
      itemCount: state.items.length + _extra(state),
      itemBuilder: (context, i) {
        if (i >= state.items.length) return _footer(state, i);
        final s = state.items[i];
        final fotos = midiaIndex[s.id] ?? const <VitrineMidiaItem>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: ClxSpace.x3),
          child: _ServicoCard(
            servico: s,
            fotos: fotos,
            onTap: () => _editar(s),
            onFotos: () => _showFotos(s, fotos),
            onToggle: () =>
                ref.read(servicosControllerProvider.notifier).toggleStatus(s),
            onDuplicar: () => _duplicar(s),
            onExcluir: () => _excluir(s),
          ),
        );
      },
    );
  }

  Future<void> _showFotos(ServicoPB s, List<VitrineMidiaItem> fotos) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ServicoFotosDialog(
        nome: s.nome,
        fotos: fotos,
        onEditar: () {
          Navigator.of(context).pop();
          _editar(s);
        },
      ),
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
    final arvore = ref.watch(taxonomiaArvoreProvider).asData?.value;
    final categorias = (arvore?.categorias.isNotEmpty ?? false)
        ? [for (final c in arvore!.categorias) (slug: c.slug, nome: c.nome)]
        : [
            for (final c in Categoria.values)
              (slug: c.wire, nome: categoriaLabel(c)),
          ];
    final grupos = gruposDoFiltroServicos(
      categoriaSlug: state.categoria,
      arvore: arvore,
    );
    final grupoSel = grupos.contains(state.grupo) ? state.grupo : null;
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
            child: DropdownButtonFormField<String?>(
              key: const ValueKey('servicos-filtro-categoria'),
              initialValue: state.categoria,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('Todas as categorias'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todas as categorias'),
                ),
                for (final c in categorias)
                  DropdownMenuItem(value: c.slug, child: Text(c.nome)),
              ],
              onChanged: notifier.setCategoria,
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('servicos-filtro-grupo-${state.categoria ?? 'all'}'),
              initialValue: grupoSel,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('Todos os grupos'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos os grupos'),
                ),
                for (final g in grupos)
                  DropdownMenuItem(
                    value: g,
                    child: Text(grupoLabelSlug(g)),
                  ),
              ],
              onChanged: notifier.setGrupo,
            ),
          ),
          IconButton(
            key: const Key('servicos-taxonomia-gear'),
            tooltip: 'Categorias, grupos e serviços',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ServicosTaxonomiaScreen(),
                ),
              );
              ref.invalidate(taxonomiaArvoreProvider);
            },
            icon: const Icon(Icons.settings_rounded),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: clx.ink3,
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
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
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
    final grupo = servico.grupo.isEmpty ? 'outros' : servico.grupo;
    return ClxChip(
      label: grupoLabelSlug(grupo),
      color: clx.groupColor(grupo),
      dense: true,
    );
  }
}

/// "Categoria / `chip grupo`" — espelha o componente CategoriaGrupo do React.
class _CategoriaGrupo extends StatelessWidget {
  const _CategoriaGrupo({required this.servico});
  final ServicoPB servico;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            '${categoriaLabelSlug(servico.categoria.isEmpty ? 'veicular' : servico.categoria)} /',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: clx.ink3),
          ),
        ),
        const SizedBox(width: ClxSpace.x1),
        _GrupoChip(servico: servico),
      ],
    );
  }
}

/// Chip neutro do "Tipo de valor" (Fixo/Faixa/Variável) — espelha o React.
class _TipoValorChip extends StatelessWidget {
  const _TipoValorChip({required this.servico});
  final ServicoPB servico;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxChip(
      label: tipoValorLabel(servico.tipoValor ?? TipoValor.fixo),
      color: clx.ink2,
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
    required this.fotos,
    required this.onTap,
    required this.onFotos,
    required this.onToggle,
    required this.onDuplicar,
    required this.onExcluir,
  });

  final ServicoPB servico;
  final List<VitrineMidiaItem> fotos;
  final VoidCallback onTap;
  final VoidCallback onFotos;
  final VoidCallback onToggle;
  final VoidCallback onDuplicar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
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
              flex: 4,
              child: Row(
                children: [
                  Icon(
                    servico.categoria == 'residencial'
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
                      style: tt.titleSmall?.copyWith(
                        color: clx.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _CategoriaGrupo(servico: servico),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatValorServico(servico),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _FotosThumb(
                  fotos: fotos,
                  onTap: onFotos,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TipoValorChip(servico: servico),
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
                style: tt.bodyMedium?.copyWith(color: clx.ink2),
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
    required this.fotos,
    required this.onTap,
    required this.onFotos,
    required this.onToggle,
    required this.onDuplicar,
    required this.onExcluir,
  });

  final ServicoPB servico;
  final List<VitrineMidiaItem> fotos;
  final VoidCallback onTap;
  final VoidCallback onFotos;
  final VoidCallback onToggle;
  final VoidCallback onDuplicar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return ClxCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                servico.categoria == 'residencial'
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
                  style: tt.titleSmall?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusToggle(servico: servico, onToggle: onToggle),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          _CategoriaGrupo(servico: servico),
          const SizedBox(height: ClxSpace.x2),
          Row(
            children: [
              _TipoValorChip(servico: servico),
              const SizedBox(width: ClxSpace.x2),
              Expanded(
                child: Text(
                  formatTempoMedio(
                    servico.tempoMedioMin,
                    servico.tempoMedioLabel,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ),
              _FotosThumb(fotos: fotos, onTap: onFotos),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatValorServico(servico),
                  style: tt.bodyLarge?.copyWith(
                    color: clx.ink,
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

/// Miniatura + contagem: mostra se tem foto e abre o visualizador.
class _FotosThumb extends StatelessWidget {
  const _FotosThumb({required this.fotos, required this.onTap});

  final List<VitrineMidiaItem> fotos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final n = fotos.length;
    final url = n == 0 ? null : fotos.first.displayUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClxRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(ClxRadii.sm),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: n == 0
                      ? ColoredBox(
                          color: clx.bg3,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 18,
                            color: clx.ink3,
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: clx.bg3),
                            if (url != null && url.isNotEmpty)
                              Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  size: 18,
                                  color: clx.ink3,
                                ),
                              )
                            else
                              Icon(
                                Icons.image_outlined,
                                size: 18,
                                color: clx.ink3,
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                n == 0 ? 'Sem foto' : (n == 1 ? '1 foto' : '$n fotos'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: n == 0 ? clx.ink3 : clx.ink2,
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

class _ServicoFotosDialog extends StatelessWidget {
  const _ServicoFotosDialog({
    required this.nome,
    required this.fotos,
    required this.onEditar,
  });

  final String nome;
  final List<VitrineMidiaItem> fotos;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return AlertDialog(
      backgroundColor: clx.bg,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      title: Text(nome.isEmpty ? 'Fotos do serviço' : nome),
      content: SizedBox(
        width: 520,
        child: fotos.isEmpty
            ? Text(
                'Este serviço ainda não tem foto na Vitrine. '
                'Abra o editor e use “Fotos na Vitrine”.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: clx.ink2,
                      height: 1.45,
                    ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 4 / 3,
                  ),
                  itemCount: fotos.length,
                  itemBuilder: (context, i) {
                    final f = fotos[i];
                    final url = f.displayUrl;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(ClxRadii.md),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: clx.bg3),
                          if (url != null && url.isNotEmpty)
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: clx.ink3,
                                ),
                              ),
                            ),
                          if (f.papel == 'capa')
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: clx.ink.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Capa',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      actions: [
        ClxButton(
          label: 'Fechar',
          variant: ClxButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ClxButton(
          label: fotos.isEmpty ? 'Adicionar fotos' : 'Gerenciar fotos',
          icon: Icons.photo_library_outlined,
          onPressed: onEditar,
        ),
      ],
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
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: clx.ink2, height: 1.5),
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
