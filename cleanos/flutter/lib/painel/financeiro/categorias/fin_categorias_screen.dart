/// fin_categorias_screen.dart — Árvore de Categorias/Subcategorias.
///
/// Espelha `Categorias.tsx`: alterna Despesas/Receitas, lista as categorias-mãe
/// com suas subcategorias (via `parentId`), ícone/cor, e CRUD (nova categoria,
/// nova subcategoria, editar, excluir). Conjunto pequeno → `getFullList` no repo.
/// Estados carregando/erro/vazio/sucesso.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/models/financeiro.dart';
import '../fin_common.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';
import 'categoria_form.dart';

/// Filtro de natureza exibido (segmented).
final _tipoFilterProvider = StateProvider.autoDispose<TipoLancamento>(
  (ref) => TipoLancamento.despesa,
);

class FinCategoriasScreen extends ConsumerWidget {
  const FinCategoriasScreen({super.key});

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    FinCategoria? editing,
    FinCategoria? parent,
  }) async {
    final saved = await showCategoriaForm(
      context,
      editing: editing,
      parent: parent,
    );
    if (saved == true) {
      ref.invalidate(finCategoriasProvider);
      if (context.mounted) {
        showClxToast(context, 'Categoria salva.', type: ToastType.success);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FinCategoria cat,
    bool hasChildren,
  ) async {
    if (hasChildren) {
      showClxToast(
        context,
        'Exclua ou mova as subcategorias antes.',
        type: ToastType.warning,
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir categoria'),
        content: Text('Excluir "${cat.nome}"?'),
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
      await ref.read(financeiroRepositoryProvider).deleteCategoria(cat.id);
      ref.invalidate(finCategoriasProvider);
      if (context.mounted) {
        showClxToast(context, 'Categoria excluída.', type: ToastType.success);
      }
    } catch (_) {
      if (context.mounted) {
        showClxToast(
          context,
          'Não foi possível excluir.',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(finCategoriasProvider);
    final tipo = ref.watch(_tipoFilterProvider);
    return Column(
      children: [
        _Toolbar(
          tipo: tipo,
          onTipo: (t) => ref.read(_tipoFilterProvider.notifier).state = t,
          onNova: () => _form(context, ref),
        ),
        Expanded(
          child: FinAsync<List<FinCategoria>>(
            value: async,
            onRetry: () => ref.invalidate(finCategoriasProvider),
            data: (todas) {
              final roots =
                  todas
                      .where((c) => c.parentId == null && c.tipo == tipo)
                      .toList()
                    ..sort((a, b) => a.nome.compareTo(b.nome));
              if (roots.isEmpty) {
                return EmptyState(
                  icon: Icons.category_outlined,
                  title: tipo == TipoLancamento.despesa
                      ? 'Nenhuma categoria de despesa'
                      : 'Nenhuma categoria de receita',
                  message: 'Crie categorias para classificar os lançamentos.',
                  action: ClxButton(
                    label: 'Nova categoria',
                    icon: Icons.add_rounded,
                    onPressed: () => _form(context, ref),
                  ),
                );
              }
              List<FinCategoria> childrenOf(String id) =>
                  todas.where((c) => c.parentId == id).toList()
                    ..sort((a, b) => a.nome.compareTo(b.nome));
              return ListView.builder(
                padding: const EdgeInsets.all(ClxSpace.x6),
                itemCount: roots.length,
                itemBuilder: (context, i) {
                  final root = roots[i];
                  final filhos = childrenOf(root.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: ClxSpace.x3),
                    child: _CategoriaTile(
                      categoria: root,
                      filhos: filhos,
                      onEdit: () => _form(context, ref, editing: root),
                      onAddSub: () => _form(context, ref, parent: root),
                      onDelete: () =>
                          _delete(context, ref, root, filhos.isNotEmpty),
                      onEditFilho: (f) => _form(context, ref, editing: f),
                      onDeleteFilho: (f) => _delete(context, ref, f, false),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.tipo,
    required this.onTipo,
    required this.onNova,
  });

  final TipoLancamento tipo;
  final ValueChanged<TipoLancamento> onTipo;
  final VoidCallback onNova;

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
      child: Row(
        children: [
          SegmentedButton<TipoLancamento>(
            segments: const [
              ButtonSegment(
                value: TipoLancamento.despesa,
                label: Text('Despesas'),
                icon: Icon(Icons.south_west_rounded, size: 16),
              ),
              ButtonSegment(
                value: TipoLancamento.receita,
                label: Text('Receitas'),
                icon: Icon(Icons.north_east_rounded, size: 16),
              ),
            ],
            selected: {tipo},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onTipo(s.first),
          ),
          const Spacer(),
          ClxButton(
            label: 'Nova categoria',
            icon: Icons.add_rounded,
            onPressed: onNova,
          ),
        ],
      ),
    );
  }
}

class _CategoriaTile extends StatelessWidget {
  const _CategoriaTile({
    required this.categoria,
    required this.filhos,
    required this.onEdit,
    required this.onAddSub,
    required this.onDelete,
    required this.onEditFilho,
    required this.onDeleteFilho,
  });

  final FinCategoria categoria;
  final List<FinCategoria> filhos;
  final VoidCallback onEdit;
  final VoidCallback onAddSub;
  final VoidCallback onDelete;
  final ValueChanged<FinCategoria> onEditFilho;
  final ValueChanged<FinCategoria> onDeleteFilho;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final accent = _parseHex(categoria.cor) ?? clx.primary;
    return ClxCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x2,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(
            left: ClxSpace.x2,
            bottom: ClxSpace.x2,
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: ClxRadii.rMd,
            ),
            child: Icon(
              finCategoriaIcon(categoria.icone),
              size: 18,
              color: accent,
            ),
          ),
          title: Text(
            categoria.nome,
            style: TextStyle(
              color: clx.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            filhos.isEmpty
                ? 'Sem subcategorias'
                : '${filhos.length} subcategoria${filhos.length == 1 ? '' : 's'}',
            style: TextStyle(color: clx.ink3, fontSize: 12),
          ),
          trailing: _menu(context),
          children: [
            for (final f in filhos)
              _SubRow(
                categoria: f,
                onEdit: () => onEditFilho(f),
                onDelete: () => onDeleteFilho(f),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddSub,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nova subcategoria'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Ações',
    icon: Icon(Icons.more_vert_rounded, size: 20, color: context.clx.ink3),
    onSelected: (v) {
      if (v == 'edit') onEdit();
      if (v == 'sub') onAddSub();
      if (v == 'delete') onDelete();
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Editar')),
      PopupMenuItem(value: 'sub', child: Text('Nova subcategoria')),
      PopupMenuItem(value: 'delete', child: Text('Excluir')),
    ],
  );

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.categoria,
    required this.onEdit,
    required this.onDelete,
  });

  final FinCategoria categoria;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return InkWell(
      onTap: onEdit,
      borderRadius: ClxRadii.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x2,
          vertical: ClxSpace.x2,
        ),
        child: Row(
          children: [
            Icon(
              Icons.subdirectory_arrow_right_rounded,
              size: 16,
              color: clx.ink3,
            ),
            const SizedBox(width: ClxSpace.x2),
            Icon(finCategoriaIcon(categoria.icone), size: 16, color: clx.ink2),
            const SizedBox(width: ClxSpace.x2),
            Expanded(
              child: Text(
                categoria.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: clx.ink2, fontSize: 13.5),
              ),
            ),
            IconButton(
              tooltip: 'Excluir',
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: clx.ink3,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
