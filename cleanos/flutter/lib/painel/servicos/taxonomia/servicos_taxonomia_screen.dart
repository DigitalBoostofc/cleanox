/// Editor da taxonomia Categoria → Grupo → Serviço (engrenagem em Serviços).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/models/servico.dart';
import '../servico_editor.dart';
import '../servicos_labels.dart';
import 'taxonomia_models.dart';
import 'taxonomia_providers.dart';
import 'taxonomia_repository.dart';

class ServicosTaxonomiaScreen extends ConsumerStatefulWidget {
  const ServicosTaxonomiaScreen({super.key});

  @override
  ConsumerState<ServicosTaxonomiaScreen> createState() =>
      _ServicosTaxonomiaScreenState();
}

class _ServicosTaxonomiaScreenState
    extends ConsumerState<ServicosTaxonomiaScreen> {
  String? _catId;
  String? _grupoId;
  bool _busy = false;

  Future<void> _reload() async {
    ref.invalidate(taxonomiaArvoreProvider);
    await ref.read(taxonomiaArvoreProvider.future);
  }

  TaxonomiaRepository get _repo => ref.read(taxonomiaRepositoryProvider);

  Future<void> _add({
    required TaxonomiaTipo tipo,
    required String parent,
    required String titulo,
  }) async {
    final r = await showDialog<_NomeSlug?>(
      context: context,
      builder: (_) => _NomeSlugDialog(titulo: titulo),
    );
    if (r == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final arvore = await ref.read(taxonomiaArvoreProvider.future);
      final siblings = switch (tipo) {
        TaxonomiaTipo.categoria => arvore.categorias,
        TaxonomiaTipo.grupo => arvore.gruposDe(parent),
        TaxonomiaTipo.subgrupo => const <TaxonomiaNo>[],
      };
      final ordem =
          siblings.isEmpty ? 10 : (siblings.map((e) => e.ordem).reduce(
                    (a, b) => a > b ? a : b,
                  ) +
              10);
      final created = await _repo.create(
        tipo: tipo,
        slug: r.slug,
        nome: r.nome,
        parent: parent,
        ordem: ordem,
      );
      await _reload();
      if (!mounted) return;
      setState(() {
        if (tipo == TaxonomiaTipo.categoria) _catId = created.id;
        if (tipo == TaxonomiaTipo.grupo) _grupoId = created.id;
      });
      showClxToast(context, 'Adicionado.', type: ToastType.success);
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível adicionar.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(TaxonomiaNo no) async {
    final r = await showDialog<_NomeSlug?>(
      context: context,
      builder: (_) => _NomeSlugDialog(
        titulo: 'Editar ${no.tipo.name}',
        initialNome: no.nome,
        initialSlug: no.slug,
      ),
    );
    if (r == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.update(no.id, nome: r.nome, slug: r.slug);
      await _reload();
      if (mounted) {
        showClxToast(context, 'Atualizado.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível salvar.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(TaxonomiaNo no) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir?'),
        content: Text(
          'Excluir "${no.nome}" também remove os grupos filhos. '
          'Serviços já cadastrados mantêm o slug antigo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.delete(no.id);
      await _reload();
      if (!mounted) return;
      setState(() {
        if (_catId == no.id) {
          _catId = null;
          _grupoId = null;
        }
        if (_grupoId == no.id) _grupoId = null;
      });
      showClxToast(context, 'Excluído.', type: ToastType.success);
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível excluir.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taxonomiaArvoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias e grupos'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: Spinner(size: 28)),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(ClxSpace.x6),
            child: ErrorBanner(
              message: 'Não foi possível carregar a taxonomia.',
              onRetry: _reload,
            ),
          ),
        ),
        data: (arvore) {
          final cats = arvore.categorias;
          final catId = _catId ?? (cats.isEmpty ? null : cats.first.id);
          final grupos = catId == null ? <TaxonomiaNo>[] : arvore.gruposDe(catId);
          final grupoId = _grupoId != null &&
                  grupos.any((g) => g.id == _grupoId)
              ? _grupoId
              : (grupos.isEmpty ? null : grupos.first.id);
          String catSlug = '';
          for (final c in cats) {
            if (c.id == catId) {
              catSlug = c.slug;
              break;
            }
          }
          String grupoSlug = '';
          for (final g in grupos) {
            if (g.id == grupoId) {
              grupoSlug = g.slug;
              break;
            }
          }

          return Stack(
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 900;
                  final cols = wide
                      ? [
                          _coluna(
                            key: const Key('taxonomia-col-categorias'),
                            titulo: 'Categorias',
                            items: cats,
                            selectedId: catId,
                            onSelect: (id) => setState(() {
                              _catId = id;
                              _grupoId = null;
                            }),
                            onAdd: () => _add(
                              tipo: TaxonomiaTipo.categoria,
                              parent: '',
                              titulo: 'Nova categoria',
                            ),
                          ),
                          _coluna(
                            key: const Key('taxonomia-col-grupos'),
                            titulo: 'Grupos',
                            items: grupos,
                            selectedId: grupoId,
                            enabled: catId != null,
                            onSelect: (id) => setState(() => _grupoId = id),
                            onAdd: catId == null
                                ? null
                                : () => _add(
                                      tipo: TaxonomiaTipo.grupo,
                                      parent: catId,
                                      titulo: 'Novo grupo',
                                    ),
                          ),
                          _servicosColuna(
                            key: const Key('taxonomia-col-servicos'),
                            enabled: grupoId != null,
                            categoriaSlug: catSlug,
                            grupoSlug: grupoSlug,
                          ),
                        ]
                      : null;

                  if (wide) {
                    return Padding(
                      padding: const EdgeInsets.all(ClxSpace.x4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < cols!.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: cols[i]),
                          ],
                        ],
                      ),
                    );
                  }

                  // Mobile: 3 seções empilhadas
                  return ListView(
                    padding: const EdgeInsets.all(ClxSpace.x4),
                    children: [
                      _coluna(
                        key: const Key('taxonomia-col-categorias'),
                        titulo: 'Categorias',
                        items: cats,
                        selectedId: catId,
                        onSelect: (id) => setState(() {
                          _catId = id;
                          _grupoId = null;
                        }),
                        onAdd: () => _add(
                          tipo: TaxonomiaTipo.categoria,
                          parent: '',
                          titulo: 'Nova categoria',
                        ),
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                      _coluna(
                        key: const Key('taxonomia-col-grupos'),
                        titulo: 'Grupos',
                        items: grupos,
                        selectedId: grupoId,
                        enabled: catId != null,
                        onSelect: (id) => setState(() => _grupoId = id),
                        onAdd: catId == null
                            ? null
                            : () => _add(
                                  tipo: TaxonomiaTipo.grupo,
                                  parent: catId,
                                  titulo: 'Novo grupo',
                                ),
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                      _servicosColuna(
                        key: const Key('taxonomia-col-servicos'),
                        enabled: grupoId != null,
                        categoriaSlug: catSlug,
                        grupoSlug: grupoSlug,
                        compact: true,
                      ),
                    ],
                  );
                },
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x33FFFFFF),
                    child: Center(child: Spinner(size: 28)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editServico(
    ServicoPB s, {
    required String categoriaSlug,
    required String grupoSlug,
  }) async {
    final bool? saved;
    if (GoRouter.maybeOf(context) != null) {
      saved = await context.push<bool>('/painel/servicos/${s.id}');
    } else {
      saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ServicoEditorScreen(servicoId: s.id),
        ),
      );
    }
    if (!mounted) return;
    ref.invalidate(
      servicosDoGrupoProvider((
        categoria: categoriaSlug,
        grupo: grupoSlug,
      )),
    );
    if (saved == true) {
      showClxToast(context, 'Serviço atualizado.', type: ToastType.success);
    }
  }

  Widget _coluna({
    Key? key,
    required String titulo,
    required List<TaxonomiaNo> items,
    required String? selectedId,
    required ValueChanged<String> onSelect,
    required VoidCallback? onAdd,
    bool enabled = true,
    bool compact = false,
  }) {
    final clx = context.clx;
    return Card(
      key: key,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: clx.ink,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Adicionar',
                  onPressed: enabled ? onAdd : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Selecione o nível anterior.',
                style: TextStyle(color: clx.ink3),
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nenhum item. Toque em + para adicionar.',
                style: TextStyle(color: clx.ink3),
              ),
            )
          else if (compact)
            ...[
              for (final n in items)
                _tile(n, selected: n.id == selectedId, onSelect: onSelect),
            ]
          else
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final n = items[i];
                  return _tile(
                    n,
                    selected: n.id == selectedId,
                    onSelect: onSelect,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(
    TaxonomiaNo n, {
    required bool selected,
    required ValueChanged<String> onSelect,
  }) {
    final clx = context.clx;
    return ListTile(
      selected: selected,
      selectedTileColor: clx.primary.withValues(alpha: 0.08),
      title: Text(
        n.nome,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        n.slug,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: clx.ink3, fontSize: 12),
      ),
      onTap: () => onSelect(n.id),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') _edit(n);
          if (v == 'del') _delete(n);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(value: 'del', child: Text('Excluir')),
        ],
      ),
    );
  }

  Widget _servicosColuna({
    Key? key,
    required bool enabled,
    required String categoriaSlug,
    required String grupoSlug,
    bool compact = false,
  }) {
    final clx = context.clx;
    final async = !enabled || categoriaSlug.isEmpty || grupoSlug.isEmpty
        ? null
        : ref.watch(
            servicosDoGrupoProvider((
              categoria: categoriaSlug,
              grupo: grupoSlug,
            )),
          );

    Widget body;
    if (!enabled) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Selecione o grupo.',
          style: TextStyle(color: clx.ink3),
        ),
      );
    } else if (async == null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Selecione o grupo.',
          style: TextStyle(color: clx.ink3),
        ),
      );
    } else {
      body = async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Spinner(size: 22)),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            message: 'Não foi possível carregar os serviços.',
            onRetry: () => ref.invalidate(
              servicosDoGrupoProvider((
                categoria: categoriaSlug,
                grupo: grupoSlug,
              )),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nenhum serviço neste grupo.',
                style: TextStyle(color: clx.ink3),
              ),
            );
          }
          final tiles = [
            for (final s in items)
              _servicoTile(
                s,
                categoriaSlug: categoriaSlug,
                grupoSlug: grupoSlug,
              ),
          ];
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tiles,
            );
          }
          return ListView(children: tiles);
        },
      );
    }

    return Card(
      key: key,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Text(
              'Serviços',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: clx.ink,
                  ),
            ),
          ),
          const Divider(height: 1),
          if (compact) body else Expanded(child: body),
        ],
      ),
    );
  }

  Widget _servicoTile(
    ServicoPB s, {
    required String categoriaSlug,
    required String grupoSlug,
  }) {
    final clx = context.clx;
    return Padding(
      key: Key('taxonomia-servico-${s.id}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.nome.isEmpty ? '—' : s.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            formatValorServico(s),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: clx.ink3, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('taxonomia-servico-editar-${s.id}'),
              onPressed: () => _editServico(
                s,
                categoriaSlug: categoriaSlug,
                grupoSlug: grupoSlug,
              ),
              child: const Text('Editar serviço'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NomeSlug {
  const _NomeSlug(this.nome, this.slug);
  final String nome;
  final String slug;
}

class _NomeSlugDialog extends StatefulWidget {
  const _NomeSlugDialog({
    required this.titulo,
    this.initialNome = '',
    this.initialSlug = '',
  });

  final String titulo;
  final String initialNome;
  final String initialSlug;

  @override
  State<_NomeSlugDialog> createState() => _NomeSlugDialogState();
}

class _NomeSlugDialogState extends State<_NomeSlugDialog> {
  late final TextEditingController _nome;
  late final TextEditingController _slug;
  bool _slugTouched = false;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.initialNome);
    _slug = TextEditingController(text: widget.initialSlug);
    _slugTouched = widget.initialSlug.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _nome.dispose();
    _slug.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nome,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex.: Residencial premium',
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) {
                if (_slugTouched) return;
                _slug.text = TaxonomiaRepository.slugify(v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _slug,
              decoration: const InputDecoration(
                labelText: 'Identificador (slug)',
                hintText: 'ex.: residencial_premium',
                helperText: 'Usado nos serviços. Evite mudar depois de usar.',
              ),
              onChanged: (_) => _slugTouched = true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final nome = _nome.text.trim();
            if (nome.isEmpty) return;
            Navigator.pop(
              context,
              _NomeSlug(nome, _slug.text.trim()),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
