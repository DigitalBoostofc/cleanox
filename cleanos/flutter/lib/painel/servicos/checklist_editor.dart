/// checklist_editor.dart — Editor do checklist PADRÃO do serviço.
///
/// Espelha `components/ChecklistEditor.tsx`: adicionar, remover, editar título,
/// marcar obrigatório e REORDENAR (arrastar pelo handle, com fallback de setas
/// ↑/↓ para teclado/acessibilidade). A `ordem` sai sempre normalizada (1-based).
///
/// Componente controlado: recebe [items] e emite [onChanged] a cada mutação. Mantém
/// `TextEditingController`s internos por item (id) para preservar cursor/foco.
library;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/models/servico.dart';

class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final List<ChecklistTemplateItem> items;
  final ValueChanged<List<ChecklistTemplateItem>> onChanged;
  final bool enabled;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  /// Ordem estável de trabalho (ids). Controllers vivem num mapa por id.
  late List<_ChkRow> _rows;
  final Map<String, TextEditingController> _controllers = {};
  int _tmpSeq = 0;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final it in _sorted(widget.items))
        _ChkRow(
          id: it.id.isEmpty ? _tmpId() : it.id,
          obrigatorio: it.obrigatorio,
        ),
    ];
    for (var i = 0; i < _rows.length; i++) {
      _controllers[_rows[i].id] = TextEditingController(
        text: _sorted(widget.items)[i].titulo,
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  static List<ChecklistTemplateItem> _sorted(List<ChecklistTemplateItem> src) {
    final copy = [...src];
    copy.sort((a, b) => a.ordem.compareTo(b.ordem));
    return copy;
  }

  String _tmpId() => 'chktmp_${_tmpSeq++}';

  TextEditingController _ctrl(String id) =>
      _controllers.putIfAbsent(id, () => TextEditingController());

  /// Reconstrói a lista de domínio (ordem 1-based) e emite ao pai.
  void _emit() {
    final out = <ChecklistTemplateItem>[
      for (var i = 0; i < _rows.length; i++)
        ChecklistTemplateItem(
          id: _rows[i].id,
          titulo: _ctrl(_rows[i].id).text.trim(),
          ordem: i + 1,
          obrigatorio: _rows[i].obrigatorio,
        ),
    ];
    widget.onChanged(out);
  }

  void _add() {
    final id = _tmpId();
    _controllers[id] = TextEditingController();
    setState(() => _rows.add(_ChkRow(id: id, obrigatorio: false)));
    _emit();
  }

  void _remove(int index) {
    final row = _rows[index];
    setState(() => _rows.removeAt(index));
    _controllers.remove(row.id)?.dispose();
    _emit();
  }

  void _move(int from, int to) {
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= _rows.length ||
        to >= _rows.length) {
      return;
    }
    setState(() {
      final r = _rows.removeAt(from);
      _rows.insert(to, r);
    });
    _emit();
  }

  void _onReorder(int oldIndex, int newIndex) {
    // ReorderableListView passa newIndex já deslocado quando move para baixo.
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    _move(oldIndex, target);
  }

  void _toggleObrigatorio(int index, bool value) {
    setState(() => _rows[index] = _rows[index].copyWith(obrigatorio: value));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    if (_rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(ClxSpace.x4),
            decoration: BoxDecoration(
              color: clx.bg2,
              borderRadius: ClxRadii.rMd,
              border: Border.all(color: clx.line),
            ),
            child: Text(
              'Nenhum item no checklist. Adicione itens que a equipe deverá '
              'marcar durante a execução.',
              style: TextStyle(color: clx.ink3, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          _addButton(clx),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _rows.length,
          onReorder: widget.enabled ? _onReorder : (_, __) {},
          itemBuilder: (context, i) => _rowTile(clx, i),
        ),
        const SizedBox(height: ClxSpace.x3),
        _addButton(clx),
      ],
    );
  }

  Widget _addButton(CleanoxColors clx) => Align(
    alignment: Alignment.centerLeft,
    child: ClxButton(
      label: 'Adicionar item',
      icon: Icons.add_rounded,
      variant: ClxButtonVariant.ghost,
      onPressed: widget.enabled ? _add : null,
    ),
  );

  Widget _rowTile(CleanoxColors clx, int i) {
    final row = _rows[i];
    return Padding(
      key: ValueKey(row.id),
      padding: const EdgeInsets.only(bottom: ClxSpace.x2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x2,
          vertical: ClxSpace.x1,
        ),
        decoration: BoxDecoration(
          color: clx.bg2,
          borderRadius: ClxRadii.rMd,
          border: Border.all(color: clx.line),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: i,
              enabled: widget.enabled,
              child: Padding(
                padding: const EdgeInsets.all(ClxSpace.x1),
                child: Tooltip(
                  message: 'Arraste para reordenar',
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: clx.ink3,
                  ),
                ),
              ),
            ),
            Text(
              '${i + 1}.',
              style: TextStyle(
                color: clx.ink3,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: ClxSpace.x2),
            Expanded(
              child: TextField(
                controller: _ctrl(row.id),
                enabled: widget.enabled,
                onChanged: (_) => _emit(),
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: clx.ink, fontSize: 14),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Descreva o item…',
                  border: InputBorder.none,
                ),
              ),
            ),
            // Obrigatório (bloqueia a conclusão da OS).
            Tooltip(
              message: 'Bloqueia a conclusão da OS enquanto não concluído',
              child: InkWell(
                borderRadius: ClxRadii.rSm,
                onTap: widget.enabled
                    ? () => _toggleObrigatorio(i, !row.obrigatorio)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClxSpace.x1,
                    vertical: ClxSpace.x1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        row.obrigatorio
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: row.obrigatorio ? clx.error : clx.ink3,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Obrigatório',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: row.obrigatorio ? clx.error : clx.ink3,
                          fontWeight: row.obrigatorio
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mover para cima',
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
              onPressed: widget.enabled && i > 0 ? () => _move(i, i - 1) : null,
            ),
            IconButton(
              tooltip: 'Mover para baixo',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              onPressed: widget.enabled && i < _rows.length - 1
                  ? () => _move(i, i + 1)
                  : null,
            ),
            IconButton(
              tooltip: 'Remover item',
              icon: Icon(Icons.close_rounded, size: 18, color: clx.error),
              onPressed: widget.enabled ? () => _remove(i) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChkRow {
  const _ChkRow({required this.id, required this.obrigatorio});
  final String id;
  final bool obrigatorio;

  _ChkRow copyWith({bool? obrigatorio}) =>
      _ChkRow(id: id, obrigatorio: obrigatorio ?? this.obrigatorio);
}
