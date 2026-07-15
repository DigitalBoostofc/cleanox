/// fin_limites_screen.dart — Limites de gasto por categoria (`fin_limites`).
///
/// Espelha `LimiteGastos.tsx`: para cada limite, progresso do GASTO (despesas
/// pagas do período) vs. o TETO, com barra colorida (ok/atenção/estourado). O
/// seletor de mês (BRT) define o período do gasto. CRUD via modal (upsert por
/// categoria). Estados carregando/erro/vazio/sucesso.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'fin_chips.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_form_kit.dart';
import 'fin_labels.dart';
import 'fin_providers.dart';

class FinLimitesScreen extends ConsumerWidget {
  const FinLimitesScreen({super.key});

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    FinLimite? editing,
    required List<FinCategoria> categorias,
    required List<FinLimite> existentes,
  }) async {
    final saved = await showFinModal<bool>(
      context,
      _LimiteForm(
        editing: editing,
        categorias: categorias,
        existentes: existentes,
      ),
    );
    if (saved == true) {
      ref.invalidate(finLimitesProvider);
      if (context.mounted) {
        showClxToast(context, 'Limite salvo.', type: ToastType.success);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FinLimite limite,
  ) async {
    try {
      await ref.read(financeiroRepositoryProvider).deleteLimite(limite.id);
      ref.invalidate(finLimitesProvider);
      if (context.mounted) {
        showClxToast(context, 'Limite removido.', type: ToastType.success);
      }
    } catch (_) {
      if (context.mounted) {
        showClxToast(
          context,
          'Não foi possível remover.',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitesAsync = ref.watch(finLimitesProvider);
    final categorias = ref.watch(finCategoriasProvider).valueOrNull ?? const [];
    final periodLancs =
        ref.watch(finPeriodLancamentosProvider).valueOrNull ?? const [];

    return Column(
      children: [
        _Header(
          onNovo: () {
            final lims = limitesAsync.valueOrNull ?? const <FinLimite>[];
            _form(context, ref, categorias: categorias, existentes: lims);
          },
        ),
        Expanded(
          child: FinAsync<List<FinLimite>>(
            value: limitesAsync,
            onRetry: () => ref.invalidate(finLimitesProvider),
            data: (limites) {
              if (limites.isEmpty) {
                return EmptyState(
                  icon: Icons.speed_outlined,
                  title: 'Nenhum limite definido',
                  message:
                      'Defina tetos de gasto por categoria para acompanhar '
                      'o orçamento do mês.',
                  action: ClxButton(
                    label: 'Novo limite',
                    icon: Icons.add_rounded,
                    onPressed: () => _form(
                      context,
                      ref,
                      categorias: categorias,
                      existentes: limites,
                    ),
                  ),
                );
              }
              final tree = _buildLimiteTree(limites, categorias);
              // Totais do mês (estilo Organizze: "despesas X de Y").
              var gastoAll = 0.0;
              var metaAll = 0.0;
              for (final l in limites) {
                final p = progressoLimite(l, periodLancs);
                gastoAll += p.gasto;
                metaAll += p.limite;
              }
              return ListView(
                padding: const EdgeInsets.all(ClxSpace.x6),
                children: [
                  _TotaisBar(gasto: gastoAll, meta: metaAll),
                  const SizedBox(height: ClxSpace.x5),
                  for (final node in tree) ...[
                    _LimiteTreeRow(
                      node: node,
                      periodLancs: periodLancs,
                      indent: false,
                      onEdit: (lim) => _form(
                        context,
                        ref,
                        editing: lim,
                        categorias: categorias,
                        existentes: limites,
                      ),
                      onDelete: (lim) => _delete(context, ref, lim),
                      onAddChild: (parentCat) => _form(
                        context,
                        ref,
                        categorias: categorias,
                        existentes: limites,
                      ),
                    ),
                    for (final child in node.children)
                      _LimiteTreeRow(
                        node: child,
                        periodLancs: periodLancs,
                        indent: true,
                        onEdit: (lim) => _form(
                          context,
                          ref,
                          editing: lim,
                          categorias: categorias,
                          existentes: limites,
                        ),
                        onDelete: (lim) => _delete(context, ref, lim),
                        onAddChild: (_) {},
                      ),
                    const SizedBox(height: ClxSpace.x4),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNovo});
  final VoidCallback onNovo;

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
      // Mobile: período em largura total + botão embaixo (Row original
      // cortava "+ Novo limite" na borda direita da tela).
      child: finIsMobile(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: double.infinity,
                  child: FinPeriodSelector(expand: true),
                ),
                const SizedBox(height: ClxSpace.x3),
                ClxButton(
                  label: 'Novo limite',
                  icon: Icons.add_rounded,
                  onPressed: onNovo,
                  expand: true,
                ),
              ],
            )
          : Row(
              children: [
                const FinPeriodSelector(),
                const Spacer(),
                ClxButton(
                  label: 'Novo limite',
                  icon: Icons.add_rounded,
                  onPressed: onNovo,
                ),
              ],
            ),
    );
  }
}

/* ─────────────────────── árvore (pai → filhos) ─────────────────────── */

class _LimiteNode {
  _LimiteNode({
    required this.categoria,
    this.limite,
    List<_LimiteNode>? children,
  }) : children = children ?? [];

  final FinCategoria categoria;
  final FinLimite? limite;
  final List<_LimiteNode> children;
}

/// Agrupa limites em raízes + filhos (estilo Organizze).
List<_LimiteNode> _buildLimiteTree(
  List<FinLimite> limites,
  List<FinCategoria> categorias,
) {
  final catById = {for (final c in categorias) c.id: c};
  final limByCat = {for (final l in limites) l.categoriaId: l};
  final roots = <String, _LimiteNode>{};

  _LimiteNode ensureRoot(FinCategoria rootCat) {
    return roots.putIfAbsent(
      rootCat.id,
      () => _LimiteNode(
        categoria: rootCat,
        limite: limByCat[rootCat.id],
      ),
    );
  }

  for (final lim in limites) {
    final cat = catById[lim.categoriaId] ??
        FinCategoria(id: lim.categoriaId, nome: 'Categoria');
    if (cat.parentId == null) {
      // Limite na raiz.
      final node = ensureRoot(cat);
      roots[cat.id] = _LimiteNode(
        categoria: cat,
        limite: lim,
        children: node.children,
      );
    } else {
      final parent = catById[cat.parentId!] ??
          FinCategoria(id: cat.parentId!, nome: 'Grupo');
      final root = ensureRoot(parent);
      // Evita duplicar filho.
      if (!root.children.any((c) => c.categoria.id == cat.id)) {
        root.children.add(_LimiteNode(categoria: cat, limite: lim));
      }
    }
  }

  // Ordena filhos e raízes por nome.
  final list = roots.values.toList()
    ..sort((a, b) => a.categoria.nome.compareTo(b.categoria.nome));
  for (final r in list) {
    r.children.sort((a, b) => a.categoria.nome.compareTo(b.categoria.nome));
  }
  return list;
}

class _TotaisBar extends StatelessWidget {
  const _TotaisBar({required this.gasto, required this.meta});
  final double gasto;
  final double meta;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final pct = meta > 0 ? (gasto / meta).clamp(0.0, 1.0) : 0.0;
    final estourou = meta > 0 && gasto > meta;
    final barColor = estourou
        ? clx.error
        : pct >= 0.8
        ? clx.warning
        : clx.success;
    return Column(
      children: [
        Text(
          'despesas',
          style: tt.labelMedium?.copyWith(color: clx.finExpense),
        ),
        Text(
          '${formatCurrency(gasto)} de ${formatCurrency(meta)}',
          style: tt.titleMedium?.copyWith(
            color: estourou ? clx.error : clx.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ClxSpace.x2),
        ClipRRect(
          borderRadius: ClxRadii.rPill,
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 14,
            backgroundColor: clx.bg3,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

/// Linha de limite (raiz ou filha indentada).
class _LimiteTreeRow extends StatelessWidget {
  const _LimiteTreeRow({
    required this.node,
    required this.periodLancs,
    required this.indent,
    required this.onEdit,
    required this.onDelete,
    required this.onAddChild,
  });

  final _LimiteNode node;
  final List<FinLancamento> periodLancs;
  final bool indent;
  final void Function(FinLimite) onEdit;
  final void Function(FinLimite) onDelete;
  final void Function(FinCategoria) onAddChild;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final lim = node.limite;
    final prog = lim != null
        ? progressoLimite(lim, periodLancs)
        : const ProgressoLimite(gasto: 0, limite: 0, pct: 0);
    final temLimite = lim != null && lim.limite > 0;
    final estourou = temLimite && prog.gasto > prog.limite;
    final atencao = temLimite && prog.pct >= 0.8 && !estourou;
    final barColor = !temLimite
        ? clx.bg3
        : estourou
        ? clx.error
        : atencao
        ? clx.warning
        : clx.success;

    return Padding(
      padding: EdgeInsets.only(
        left: indent ? ClxSpace.x6 : 0,
        bottom: ClxSpace.x3,
      ),
      child: InkWell(
        onTap: lim != null ? () => onEdit(lim) : null,
        borderRadius: ClxRadii.rMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: indent ? 26 : 30,
                  height: indent ? 26 : 30,
                  decoration: BoxDecoration(
                    color: (finParseHex(node.categoria.cor) ?? clx.primary)
                        .withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    finCategoriaIcon(node.categoria.icone),
                    size: indent ? 14 : 16,
                    color: finParseHex(node.categoria.cor) ?? clx.primary,
                  ),
                ),
                const SizedBox(width: ClxSpace.x2),
                Expanded(
                  child: Text(
                    node.categoria.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(
                      color: clx.ink,
                      fontWeight: indent ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ),
                if (temLimite)
                  Text(
                    '${formatCurrency(prog.gasto)} de ${formatCurrency(prog.limite)}',
                    style: tt.labelMedium?.copyWith(
                      color: estourou ? clx.error : clx.ink2,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    'sem limite',
                    style: tt.labelSmall?.copyWith(color: clx.ink3),
                  ),
                if (lim != null)
                  IconButton(
                    tooltip: 'Editar / remover',
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: clx.ink3,
                    ),
                    onPressed: () => onEdit(lim),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  IconButton(
                    tooltip: 'Definir limite',
                    icon: Icon(Icons.add_rounded, size: 18, color: clx.ink3),
                    onPressed: () => onAddChild(node.categoria),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: ClxSpace.x1),
            ClipRRect(
              borderRadius: ClxRadii.rPill,
              child: LinearProgressIndicator(
                value: temLimite ? prog.pct : 0,
                minHeight: indent ? 8 : 10,
                backgroundColor: clx.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  temLimite ? barColor : clx.bg3,
                ),
              ),
            ),
            if (temLimite)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    if (estourou)
                      Text(
                        'Estourou',
                        style: tt.labelSmall?.copyWith(
                          color: clx.error,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (atencao)
                      Text(
                        'Atenção',
                        style: tt.labelSmall?.copyWith(
                          color: clx.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${(prog.pct * 100).round()}%',
                      style: tt.labelSmall?.copyWith(
                        color: barColor,
                        fontWeight: FontWeight.w800,
                      ),
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

/// Modal de definir/editar um limite (upsert por categoria).
class _LimiteForm extends ConsumerStatefulWidget {
  const _LimiteForm({
    this.editing,
    required this.categorias,
    required this.existentes,
  });

  final FinLimite? editing;
  final List<FinCategoria> categorias;
  final List<FinLimite> existentes;

  @override
  ConsumerState<_LimiteForm> createState() => _LimiteFormState();
}

class _LimiteFormState extends ConsumerState<_LimiteForm> {
  late final TextEditingController _valor;
  String? _categoriaId;
  bool _saving = false;
  String? _saveError;
  String? _catErr;
  String? _valorErr;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _valor = TextEditingController(
      text: widget.editing == null
          ? ''
          : formatMoedaInput(widget.editing!.limite),
    );
    _categoriaId = widget.editing?.categoriaId;
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  /// Categorias disponíveis: as de despesa que ainda não têm limite (na criação).
  List<FinCategoria> get _opcoes {
    final comLimite = widget.existentes
        .where((l) => l.id != widget.editing?.id)
        .map((l) => l.categoriaId)
        .toSet();
    return widget.categorias
        .where(
          (c) => c.tipo == TipoLancamento.despesa && !comLimite.contains(c.id),
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }

  Future<void> _save() async {
    final valor = parseMoedaBr(_valor.text);
    setState(() {
      _catErr = _categoriaId == null ? 'Escolha uma categoria' : null;
      _valorErr = (valor == null || valor < 0)
          ? 'Informe um teto válido'
          : null;
    });
    if (_catErr != null || _valorErr != null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref.read(financeiroRepositoryProvider).upsertLimite({
        if (_isEdit) 'id': widget.editing!.id,
        'categoria_id': _categoriaId,
        'limite': valor,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Não foi possível salvar o limite.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editingCat = _isEdit
        ? widget.categorias.firstWhere(
            (c) => c.id == widget.editing!.categoriaId,
            orElse: () => FinCategoria(
              id: widget.editing!.categoriaId,
              nome: 'Categoria',
            ),
          )
        : null;
    return FinModalScaffold(
      title: _isEdit ? 'Editar limite' : 'Novo limite',
      saving: _saving,
      error: _saveError,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEdit)
            FinField(
              label: 'Categoria',
              controller: TextEditingController(text: editingCat?.nome ?? ''),
              enabled: false,
            )
          else
            FinDropdown<String>(
              label: 'Categoria de despesa',
              required: true,
              value: _categoriaId,
              enabled: !_saving,
              error: _catErr,
              hint: 'Selecione…',
              items: _opcoes.map((c) => c.id).toList(),
              itemLabel: (id) => _opcoes
                  .firstWhere(
                    (c) => c.id == id,
                    orElse: () => FinCategoria(id: id, nome: id),
                  )
                  .nome,
              onChanged: (v) => setState(() {
                _categoriaId = v;
                _catErr = null;
              }),
            ),
          FinField(
            label: 'Teto de gasto (mês)',
            controller: _valor,
            required: true,
            enabled: !_saving,
            prefix: 'R\$ ',
            hint: '0,00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            error: _valorErr,
            onChanged: (_) {
              if (_valorErr != null) setState(() => _valorErr = null);
            },
          ),
        ],
      ),
    );
  }
}
