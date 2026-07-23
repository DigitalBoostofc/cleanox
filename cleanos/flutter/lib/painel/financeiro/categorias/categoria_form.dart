/// categoria_form.dart — Modal de criar/editar Categoria ou Subcategoria.
///
/// - Categoria raiz: ícone alocado (ou preservado) + **cor editável** no pool.
/// - Subcategoria: herda símbolo e cor da mãe; na UI só muda o tamanho.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/models/financeiro.dart';
import '../fin_chips.dart';
import '../fin_form_kit.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';

/// Abre o form. [editing] = editar; [parent] = criar subcategoria de [parent].
/// [parents] = lista completa de categorias (para o seletor de mãe e alocação).
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

  /// Lista completa de categorias disponíveis como possíveis mães / alocação.
  final List<FinCategoria> parents;

  /// Natureza (Despesas/Receitas) da aba corrente — default ao criar raiz.
  final TipoLancamento? defaultTipo;

  @override
  ConsumerState<CategoriaForm> createState() => _CategoriaFormState();
}

class _CategoriaFormState extends ConsumerState<CategoriaForm> {
  late final TextEditingController _nome;
  late TipoLancamento _tipo;
  late String _icone;
  late String _cor;
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
    _nome = TextEditingController(text: c?.nome ?? '');

    if (_isEdit) {
      // Edição: preserva ícone/cor atuais.
      _icone = (c?.icone != null && c!.icone!.isNotEmpty) ? c.icone! : 'tag';
      _cor = _normCor(c?.cor) ?? kFinCategoriaCoresPool.first;
      // Se já é sub e a mãe tem ícone/cor, alinha (caso legado dessincronizado).
      if (_parentId != null) {
        _aplicarHerancaMae(_parentId!);
      }
    } else {
      // Criação: aloca automaticamente (cor ainda editável se for raiz).
      _alocarPara(_parentId);
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  static String? _normCor(String? cor) {
    if (cor == null || cor.isEmpty) return null;
    final u = cor.trim().toUpperCase();
    return u.startsWith('#') ? u : '#$u';
  }

  void _alocarPara(String? parentId) {
    final aloc = alocarIconeCorCategoria(
      existentes: widget.parents,
      parentId: parentId,
    );
    _icone = aloc.icone;
    _cor = aloc.cor;
  }

  void _aplicarHerancaMae(String parentId) {
    final mae = widget.parents.cast<FinCategoria?>().firstWhere(
      (c) => c?.id == parentId,
      orElse: () => null,
    );
    if (mae == null) return;
    if (mae.icone != null && mae.icone!.isNotEmpty) _icone = mae.icone!;
    final cor = _normCor(mae.cor);
    if (cor != null) _cor = cor;
  }

  void _handleParent(String? id) {
    if (id == null || id.isEmpty) {
      setState(() {
        _parentId = null;
        // Voltou a ser raiz: se está criando, realoca único; se editando e
        // era sub, realoca para não colidir com outras raízes.
        if (!_isEdit || widget.editing?.parentId != null) {
          _alocarPara(null);
        }
      });
      return;
    }
    final mae = widget.parents.firstWhere(
      (c) => c.id == id,
      orElse: () => FinCategoria(id: id, nome: id),
    );
    setState(() {
      _parentId = id;
      _tipo = mae.tipo;
      // Sub sempre herda símbolo + cor da mãe.
      _aplicarHerancaMae(id);
    });
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
    // Sub herda ícone/cor da mãe. Raiz: usa o que está no estado
    // (alocado na criação ou escolhido/editado pelo usuário).
    var icone = _icone;
    var cor = _normCor(_cor) ?? kFinCategoriaCoresPool.first;
    if (_parentId != null) {
      final aloc = alocarIconeCorCategoria(
        existentes: widget.parents,
        parentId: _parentId,
      );
      icone = aloc.icone;
      cor = aloc.cor;
    }
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
        // Propaga cor/ícone da raiz para as subcategorias (UI e gráficos).
        if (_parentId == null) {
          final rootId = widget.editing!.id;
          for (final f in widget.parents) {
            if (f.parentId != rootId) continue;
            await repo.updateCategoria(f.id, {
              'icone': icone,
              'cor': cor,
            });
          }
        }
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
                'A subcategoria herda o tipo, o símbolo e a cor da categoria-mãe.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: clx.ink3),
              ),
            ),
          _previewVisual(clx),
          if (!_isSub) ...[
            const SizedBox(height: ClxSpace.x4),
            _colorPicker(clx),
          ],
        ],
      ),
    );
  }

  Widget _colorPicker(CleanoxColors clx) {
    final selected = _normCor(_cor) ?? kFinCategoriaCoresPool.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cor do ícone',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: clx.ink2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: ClxSpace.x1),
        Text(
          'Usada no avatar da categoria e nos gráficos do Financeiro.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: clx.ink3,
                height: 1.3,
              ),
        ),
        const SizedBox(height: ClxSpace.x2),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in kFinCategoriaCoresPool)
              Tooltip(
                message: hex,
                child: InkWell(
                  onTap: _saving
                      ? null
                      : () => setState(() => _cor = hex.toUpperCase()),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _hexToColor(hex) ?? clx.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected == hex.toUpperCase()
                            ? clx.ink
                            : Colors.white.withValues(alpha: 0.55),
                        width: selected == hex.toUpperCase() ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _previewVisual(CleanoxColors clx) {
    final cor = _hexToColor(_cor) ?? clx.primary;
    final sizeRoot = 48.0;
    final sizeSub = 32.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ícone e cor',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: clx.ink2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: ClxSpace.x2),
        Container(
          padding: const EdgeInsets.all(ClxSpace.x4),
          decoration: BoxDecoration(
            color: clx.bg2,
            borderRadius: ClxRadii.rMd,
            border: Border.all(color: clx.line),
          ),
          child: Row(
            children: [
              Container(
                width: _isSub ? sizeSub : sizeRoot,
                height: _isSub ? sizeSub : sizeRoot,
                decoration: BoxDecoration(
                  color: cor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  finCategoriaIcon(_icone),
                  size: (_isSub ? sizeSub : sizeRoot) * 0.52,
                  color: finOnCategoriaColor(cor),
                ),
              ),
              const SizedBox(width: ClxSpace.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSub
                          ? 'Mesmo símbolo e cor da mãe'
                          : 'Pré-visualização',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: clx.ink,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isSub
                          ? 'Na lista, a subcategoria aparece menor — '
                              'mesmo ícone e cor da categoria principal.'
                          : 'Escolha a cor abaixo. O símbolo é único entre as '
                              'categorias principais.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: clx.ink3,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
