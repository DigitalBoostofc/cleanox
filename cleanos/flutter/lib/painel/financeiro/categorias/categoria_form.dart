/// categoria_form.dart — Modal de criar/editar Categoria ou Subcategoria.
///
/// Espelha `CategoriaModal.tsx`. Uma SUBcategoria é uma categoria com `parentId`
/// apontando para a mãe. O seletor de mãe é sempre visível (criar E editar),
/// permitindo reparent e promoção a raiz. Ícone é texto livre com picker de
/// atalho; cor é hex + 12 presets do React.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/models/financeiro.dart';
import '../fin_form_kit.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';

/// 12 cores preset (espelha PRESET_CORES do React).
const List<String> kPresetCores = [
  '#0E9F9C',
  '#14B8A6',
  '#10B981',
  '#22C55E',
  '#3B82F6',
  '#6366F1',
  '#8B5CF6',
  '#EC4899',
  '#F59E0B',
  '#F97316',
  '#EF4444',
  '#64748B',
];

/// Abre o form. [editing] = editar; [parent] = criar subcategoria de [parent].
/// [parents] = lista completa de categorias (para o seletor de mãe).
Future<bool?> showCategoriaForm(
  BuildContext context, {
  FinCategoria? editing,
  FinCategoria? parent,
  List<FinCategoria> parents = const [],
  TipoLancamento? defaultTipo,
}) => showFinModal<bool>(
  context,
  CategoriaForm(
    editing: editing,
    parent: parent,
    parents: parents,
    defaultTipo: defaultTipo,
  ),
);

class CategoriaForm extends ConsumerStatefulWidget {
  const CategoriaForm({
    super.key,
    this.editing,
    this.parent,
    this.parents = const [],
    this.defaultTipo,
  });

  final FinCategoria? editing;
  final FinCategoria? parent;

  /// Lista completa de categorias disponíveis como possíveis mães.
  final List<FinCategoria> parents;

  /// Natureza (Despesas/Receitas) da aba corrente da tela — usada como default
  /// ao criar uma categoria RAIZ nova (sem [editing]/[parent], que já carregam
  /// seu próprio tipo). Sem isso o form sempre nascia em Despesas, então criar
  /// na aba Receitas gerava uma categoria invisível na aba corrente.
  final TipoLancamento? defaultTipo;

  @override
  ConsumerState<CategoriaForm> createState() => _CategoriaFormState();
}

class _CategoriaFormState extends ConsumerState<CategoriaForm> {
  late final TextEditingController _nome;
  late final TextEditingController _iconeCtrl;
  late final TextEditingController _corCtrl;
  late TipoLancamento _tipo;
  late String _icone;
  String? _cor;
  String? _parentId;

  bool _saving = false;
  String? _saveError;
  String? _nomeErr;

  bool get _isEdit => widget.editing != null;
  bool get _isSub => _parentId != null;

  /// Categorias raiz não arquivadas do mesmo tipo, excluindo a própria.
  List<FinCategoria> get _maesElegiveis =>
      widget.parents
          .where(
            (p) =>
                p.parentId == null &&
                !p.arquivada &&
                p.tipo == _tipo &&
                p.id != widget.editing?.id,
          )
          .toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));

  @override
  void initState() {
    super.initState();
    final c = widget.editing;
    _parentId = c?.parentId ?? widget.parent?.id;
    _tipo =
        c?.tipo ??
        widget.parent?.tipo ??
        widget.defaultTipo ??
        TipoLancamento.despesa;
    _icone = c?.icone ?? widget.parent?.icone ?? 'tag';
    _cor = c?.cor ?? widget.parent?.cor ?? kPresetCores[0];
    _nome = TextEditingController(text: c?.nome ?? '');
    _iconeCtrl = TextEditingController(text: _icone);
    _corCtrl = TextEditingController(text: _cor ?? kPresetCores[0]);
  }

  @override
  void dispose() {
    _nome.dispose();
    _iconeCtrl.dispose();
    _corCtrl.dispose();
    super.dispose();
  }

  void _handleParent(String? id) {
    if (id == null || id.isEmpty) {
      setState(() => _parentId = null);
      return;
    }
    final mae = widget.parents.firstWhere(
      (c) => c.id == id,
      orElse: () => FinCategoria(id: id, nome: id),
    );
    setState(() {
      _parentId = id;
      _tipo = mae.tipo;
    });
  }

  void _onCorHexChanged(String v) {
    final m = RegExp(r'^#?([0-9A-Fa-f]{6})$').firstMatch(v.trim());
    if (m != null) {
      setState(() => _cor = '#${m.group(1)!.toUpperCase()}');
    }
  }

  void _selecionarCor(String hex) {
    setState(() => _cor = hex);
    _corCtrl.text = hex;
  }

  Color? _hexToColor(String? hex) {
    if (hex == null) return null;
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
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
    final icone =
        _iconeCtrl.text.trim().isEmpty ? 'tag' : _iconeCtrl.text.trim();
    final cor =
        (_cor == null || _cor!.isEmpty) ? kPresetCores[0] : _cor;
    final data = <String, dynamic>{
      'nome': _nome.text.trim(),
      'tipo': _tipo.wire,
      'icone': icone,
      'cor': cor,
      'arquivada': widget.editing?.arquivada ?? false,
      'parent_id': _parentId,
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
          // Seletor de categoria-mãe — sempre visível (criar E editar).
          FinDropdown<String>(
            label: 'Categoria-mãe (opcional)',
            value: _parentId ?? '',
            enabled: !_saving,
            items: ['', ..._maesElegiveis.map((c) => c.id)],
            itemLabel: (id) => id.isEmpty
                ? 'Nenhuma (categoria principal)'
                : _maesElegiveis
                    .firstWhere(
                      (c) => c.id == id,
                      orElse: () => FinCategoria(id: id, nome: id),
                    )
                    .nome,
            onChanged: _handleParent,
          ),
          FinDropdown<TipoLancamento>(
            label: 'Natureza',
            value: _tipo,
            enabled: !_saving && !_isSub,
            items: TipoLancamento.values,
            itemLabel: tipoLancamentoLabel,
            onChanged: (v) => setState(() => _tipo = v ?? _tipo),
          ),
          if (_isSub)
            Padding(
              padding: const EdgeInsets.only(bottom: ClxSpace.x4),
              child: Text(
                'A subcategoria herda o tipo da categoria-mãe.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: clx.ink3),
              ),
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
        FinField(
          label: 'Ícone',
          controller: _iconeCtrl,
          enabled: !_saving,
          hint: 'Ex.: spray-can, truck, home',
          onChanged: (v) => setState(() => _icone = v),
        ),
        Wrap(
          spacing: ClxSpace.x2,
          runSpacing: ClxSpace.x2,
          children: [
            for (final entry in kFinCategoriaIcons.entries)
              InkWell(
                onTap: _saving
                    ? null
                    : () {
                        setState(() => _icone = entry.key);
                        _iconeCtrl.text = entry.key;
                      },
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
    final corAtual = _hexToColor(_cor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 40,
              height: 36,
              margin: const EdgeInsets.only(right: ClxSpace.x2, bottom: ClxSpace.x4),
              decoration: BoxDecoration(
                color: corAtual ?? clx.bg3,
                borderRadius: ClxRadii.rMd,
                border: Border.all(color: clx.line),
              ),
            ),
            Expanded(
              child: FinField(
                label: 'Cor',
                controller: _corCtrl,
                enabled: !_saving,
                hint: '#0E9F9C',
                onChanged: _onCorHexChanged,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: ClxSpace.x2,
          runSpacing: ClxSpace.x2,
          children: [
            for (final hex in kPresetCores)
              InkWell(
                onTap: _saving ? null : () => _selecionarCor(hex),
                borderRadius: ClxRadii.rPill,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _hexToColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          (_cor?.toUpperCase() == hex.toUpperCase())
                              ? clx.ink
                              : clx.line2,
                      width:
                          (_cor?.toUpperCase() == hex.toUpperCase())
                              ? 2.5
                              : 1,
                    ),
                  ),
                  child: (_cor?.toUpperCase() == hex.toUpperCase())
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
