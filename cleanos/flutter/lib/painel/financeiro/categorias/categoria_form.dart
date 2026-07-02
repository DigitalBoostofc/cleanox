/// categoria_form.dart — Modal de criar/editar Categoria ou Subcategoria.
///
/// Espelha `CategoriaModal.tsx`. Uma SUBcategoria é uma categoria com `parentId`
/// apontando para a mãe. Ao criar subcategoria, o [parent] é fixo e o `tipo` é
/// herdado (não editável). Ícone/cor são escolhidos de conjuntos do tema.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/models/financeiro.dart';
import '../fin_form_kit.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';

/// Abre o form. [editing] = editar; [parent] = criar subcategoria de [parent].
Future<bool?> showCategoriaForm(
  BuildContext context, {
  FinCategoria? editing,
  FinCategoria? parent,
}) => showFinModal<bool>(
  context,
  CategoriaForm(editing: editing, parent: parent),
);

class CategoriaForm extends ConsumerStatefulWidget {
  const CategoriaForm({super.key, this.editing, this.parent});

  final FinCategoria? editing;
  final FinCategoria? parent;

  @override
  ConsumerState<CategoriaForm> createState() => _CategoriaFormState();
}

class _CategoriaFormState extends ConsumerState<CategoriaForm> {
  late final TextEditingController _nome;
  late TipoLancamento _tipo;
  late String _icone;
  String? _cor;

  bool _saving = false;
  String? _saveError;
  String? _nomeErr;

  bool get _isEdit => widget.editing != null;
  bool get _isSub =>
      widget.parent != null || (widget.editing?.parentId != null);

  @override
  void initState() {
    super.initState();
    final c = widget.editing;
    _nome = TextEditingController(text: c?.nome ?? '');
    _tipo = c?.tipo ?? widget.parent?.tipo ?? TipoLancamento.despesa;
    _icone = c?.icone ?? widget.parent?.icone ?? 'tag';
    _cor = c?.cor ?? widget.parent?.cor;
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _nomeErr = 'Nome é obrigatório');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _nomeErr = null;
    });
    final repo = ref.read(financeiroRepositoryProvider);
    // tipo herdado da mãe quando é subcategoria.
    final tipo = _isSub
        ? (widget.parent?.tipo ?? widget.editing?.tipo ?? _tipo)
        : _tipo;
    final data = <String, dynamic>{
      'nome': _nome.text.trim(),
      'tipo': tipo.wire,
      'icone': _icone,
      'cor': _cor,
      'arquivada': widget.editing?.arquivada ?? false,
      if (widget.parent != null) 'parent_id': widget.parent!.id,
      if (widget.editing?.parentId != null)
        'parent_id': widget.editing!.parentId,
    };
    try {
      if (_isEdit) {
        await repo.updateCategoria(widget.editing!.id, data);
      } else {
        await repo.createCategoria(data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Não foi possível salvar a categoria.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final titulo = _isEdit
        ? 'Editar ${_isSub ? 'subcategoria' : 'categoria'}'
        : 'Nova ${_isSub ? 'subcategoria' : 'categoria'}';
    return FinModalScaffold(
      title: titulo,
      saving: _saving,
      error: _saveError,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.parent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: ClxSpace.x4),
              child: Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 16,
                    color: clx.ink3,
                  ),
                  const SizedBox(width: ClxSpace.x2),
                  Text(
                    'Subcategoria de "${widget.parent!.nome}"',
                    style: TextStyle(color: clx.ink3, fontSize: 13),
                  ),
                ],
              ),
            ),
          FinField(
            label: 'Nome',
            controller: _nome,
            required: true,
            enabled: !_saving,
            hint: 'Ex.: Marketing, Salários, Vendas',
            error: _nomeErr,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_nomeErr != null) setState(() => _nomeErr = null);
            },
          ),
          if (!_isSub)
            FinDropdown<TipoLancamento>(
              label: 'Natureza',
              value: _tipo,
              enabled: !_saving,
              items: TipoLancamento.values,
              itemLabel: tipoLancamentoLabel,
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
          _iconePicker(clx),
          const SizedBox(height: ClxSpace.x4),
          _corPicker(clx),
        ],
      ),
    );
  }

  Widget _iconePicker(CleanoxColors clx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ícone',
          style: TextStyle(
            color: clx.ink2,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ClxSpace.x2),
        Wrap(
          spacing: ClxSpace.x2,
          runSpacing: ClxSpace.x2,
          children: [
            for (final entry in kFinCategoriaIcons.entries)
              InkWell(
                onTap: _saving
                    ? null
                    : () => setState(() => _icone = entry.key),
                borderRadius: ClxRadii.rMd,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _icone == entry.key
                        ? clx.primary.withValues(alpha: 0.14)
                        : clx.bg2,
                    borderRadius: ClxRadii.rMd,
                    border: Border.all(
                      color: _icone == entry.key ? clx.primary : clx.line,
                      width: _icone == entry.key ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    entry.value,
                    size: 20,
                    color: _icone == entry.key ? clx.primary : clx.ink2,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _corPicker(CleanoxColors clx) {
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cor',
          style: TextStyle(
            color: clx.ink2,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ClxSpace.x2),
        Wrap(
          spacing: ClxSpace.x2,
          runSpacing: ClxSpace.x2,
          children: [
            for (final c in clx.finSeries)
              InkWell(
                onTap: _saving ? null : () => setState(() => _cor = hex(c)),
                borderRadius: ClxRadii.rPill,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _cor == hex(c) ? clx.ink : clx.line2,
                      width: _cor == hex(c) ? 2.5 : 1,
                    ),
                  ),
                  child: _cor == hex(c)
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
