/// fin_categoria_picker.dart — Categoria + subcategoria num único dropdown.
///
/// Estilo hierárquico (raiz com filhos indentados + busca), no lugar dos dois
/// campos separados "Categoria" / "Subcategoria". Ao escolher uma raiz grava
/// `categoria_id` e limpa sub; ao escolher um filho grava o pai em
/// `categoria_id` e o filho em `subcategoria_id`.
library;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/models/financeiro.dart';
import 'fin_chips.dart';

/// Valor selecionado: sempre o id da **opção** (raiz ou sub) e a resolução
/// canônica em (categoriaId, subcategoriaId) para o PB.
class FinCatPick {
  const FinCatPick({
    required this.categoriaId,
    this.subcategoriaId,
  });

  final String categoriaId;
  final String? subcategoriaId;

  bool get isSub => subcategoriaId != null && subcategoriaId!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is FinCatPick &&
      other.categoriaId == categoriaId &&
      other.subcategoriaId == subcategoriaId;

  @override
  int get hashCode => Object.hash(categoriaId, subcategoriaId);
}

/// Dropdown único com árvore de categorias (busca + indentação de sub).
class FinCategoriaTreePicker extends StatelessWidget {
  const FinCategoriaTreePicker({
    super.key,
    required this.categorias,
    required this.categoriaId,
    required this.subcategoriaId,
    required this.onChanged,
    this.required = false,
    this.error,
    this.enabled = true,
    this.label = 'Categoria',
  });

  /// Todas as categorias do **tipo** atual (raiz + sub). Filtrar por tipo no caller.
  final List<FinCategoria> categorias;
  final String? categoriaId;
  final String? subcategoriaId;
  final void Function(String? categoriaId, String? subcategoriaId) onChanged;
  final bool required;
  final String? error;
  final bool enabled;
  final String label;

  FinCatPick? get _selection {
    final sub = subcategoriaId;
    final cat = categoriaId;
    if (sub != null && sub.isNotEmpty) {
      // Resolve o pai se possível (edição com sub).
      final subCat = categorias.where((c) => c.id == sub).firstOrNull;
      final parent = subCat?.parentId ?? cat;
      if (parent == null || parent.isEmpty) return null;
      return FinCatPick(categoriaId: parent, subcategoriaId: sub);
    }
    if (cat != null && cat.isNotEmpty) {
      return FinCatPick(categoriaId: cat);
    }
    return null;
  }

  String _labelOf(FinCatPick? s) {
    if (s == null) return '';
    final byId = {for (final c in categorias) c.id: c};
    if (s.isSub) {
      final sub = byId[s.subcategoriaId];
      final root = byId[s.categoriaId];
      final subNome = sub?.nome ?? s.subcategoriaId!;
      final rootNome = root?.nome;
      if (rootNome == null || rootNome.isEmpty) return subNome;
      return '$rootNome · $subNome';
    }
    return byId[s.categoriaId]?.nome ?? s.categoriaId;
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    final picked = await showDialog<FinCatPick>(
      context: context,
      builder: (ctx) => _CategoriaTreeDialog(
        categorias: categorias,
        initial: _selection,
      ),
    );
    if (picked == null) return;
    onChanged(picked.categoriaId, picked.subcategoriaId);
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final sel = _selection;
    final display = _labelOf(sel);
    final byId = {for (final c in categorias) c.id: c};
    final avatarCat = sel == null
        ? null
        : byId[sel.isSub ? sel.subcategoriaId! : sel.categoriaId];

    return Padding(
      padding: const EdgeInsets.only(bottom: ClxSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clx.ink2,
                fontWeight: FontWeight.w600,
              ),
              children: [
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: clx.error),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ClxSpace.x1),
          InkWell(
            key: const ValueKey('fin-categoria-tree-picker'),
            onTap: enabled ? () => _open(context) : null,
            borderRadius: ClxRadii.rMd,
            child: InputDecorator(
              decoration: InputDecoration(
                isDense: true,
                errorText: error,
                suffixIcon: Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: enabled ? clx.ink2 : clx.ink3,
                ),
              ),
              child: Row(
                children: [
                  if (avatarCat != null) ...[
                    FinCategoriaAvatar(categoria: avatarCat, size: 22),
                    const SizedBox(width: ClxSpace.x2),
                  ],
                  Expanded(
                    child: Text(
                      display.isEmpty ? 'Selecione…' : display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: display.isEmpty ? clx.ink3 : clx.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── diálogo com busca ─────────────────────── */

class _CategoriaTreeDialog extends StatefulWidget {
  const _CategoriaTreeDialog({
    required this.categorias,
    this.initial,
  });

  final List<FinCategoria> categorias;
  final FinCatPick? initial;

  @override
  State<_CategoriaTreeDialog> createState() => _CategoriaTreeDialogState();
}

class _CategoriaTreeDialogState extends State<_CategoriaTreeDialog> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FinCategoria> get _roots {
    final list =
        widget.categorias
            .where((c) => c.parentId == null && !c.arquivada)
            .toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
    return list;
  }

  List<FinCategoria> _subsOf(String rootId) {
    final list =
        widget.categorias
            .where((c) => c.parentId == rootId && !c.arquivada)
            .toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
    return list;
  }

  bool _match(String nome) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    return nome.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final roots = _roots;
    // Filtra: raiz entra se ela ou algum filho bate na busca.
    final visible = <Widget>[];
    for (final root in roots) {
      final subs = _subsOf(root.id);
      final rootOk = _match(root.nome);
      final matchedSubs = subs.where((s) => _match(s.nome)).toList();
      if (!rootOk && matchedSubs.isEmpty) continue;

      // Com busca ativa e só filhos batem: mostra a raiz como cabeçalho fraco
      // e os filhos; se a raiz bate, mostra todos os filhos (ou os matched).
      final showSubs = _q.trim().isEmpty ? subs : matchedSubs;
      final showRootAsOption = rootOk || _q.trim().isEmpty;

      if (showRootAsOption) {
        visible.add(
          _CatTile(
            cat: root,
            indent: false,
            selected: widget.initial != null &&
                widget.initial!.categoriaId == root.id &&
                !widget.initial!.isSub,
            onTap: () => Navigator.of(context).pop(
              FinCatPick(categoriaId: root.id),
            ),
          ),
        );
      } else {
        // Cabeçalho não-selecionável quando só os filhos bateram na busca.
        visible.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x4,
              ClxSpace.x2,
              ClxSpace.x4,
              ClxSpace.x1,
            ),
            child: Text(
              root.nome,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: clx.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }

      for (final sub in showSubs) {
        visible.add(
          _CatTile(
            cat: sub,
            indent: true,
            selected: widget.initial?.subcategoriaId == sub.id,
            onTap: () => Navigator.of(context).pop(
              FinCatPick(categoriaId: root.id, subcategoriaId: sub.id),
            ),
          ),
        );
      }
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ClxSpace.x4,
                ClxSpace.x4,
                ClxSpace.x2,
                ClxSpace.x2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Categoria',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x4),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Buscar a categoria…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            const SizedBox(height: ClxSpace.x2),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        roots.isEmpty
                            ? 'Nenhuma categoria neste tipo'
                            : 'Nenhum resultado',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: clx.ink3,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: ClxSpace.x3),
                      children: visible,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatTile extends StatelessWidget {
  const _CatTile({
    required this.cat,
    required this.indent,
    required this.selected,
    required this.onTap,
  });

  final FinCategoria cat;
  final bool indent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Material(
      color: selected ? clx.primary.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            indent ? ClxSpace.x8 : ClxSpace.x4,
            ClxSpace.x2,
            ClxSpace.x4,
            ClxSpace.x2,
          ),
          child: Row(
            children: [
              FinCategoriaAvatar(categoria: cat, size: indent ? 26 : 30),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Text(
                  cat.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: clx.ink,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 18, color: clx.primary),
            ],
          ),
        ),
      ),
    );
  }
}
