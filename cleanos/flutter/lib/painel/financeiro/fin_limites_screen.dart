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
              return ListView.builder(
                padding: const EdgeInsets.all(ClxSpace.x6),
                itemCount: limites.length,
                itemBuilder: (context, i) {
                  final limite = limites[i];
                  final prog = progressoLimite(limite, periodLancs);
                  final cat = categorias.firstWhere(
                    (c) => c.id == limite.categoriaId,
                    orElse: () =>
                        FinCategoria(id: limite.categoriaId, nome: 'Categoria'),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: ClxSpace.x3),
                    child: _LimiteCard(
                      categoria: cat,
                      progresso: prog,
                      onEdit: () => _form(
                        context,
                        ref,
                        editing: limite,
                        categorias: categorias,
                        existentes: limites,
                      ),
                      onDelete: () => _delete(context, ref, limite),
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
      child: Row(
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

class _LimiteCard extends StatelessWidget {
  const _LimiteCard({
    required this.categoria,
    required this.progresso,
    required this.onEdit,
    required this.onDelete,
  });

  final FinCategoria categoria;
  final ProgressoLimite progresso;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final pct = progresso.pct;
    final estourou = progresso.gasto > progresso.limite && progresso.limite > 0;
    final atencao = pct >= 0.8 && !estourou;
    final barColor = estourou
        ? clx.error
        : atencao
        ? clx.warning
        : clx.success;

    return ClxCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                finCategoriaIcon(categoria.icone),
                size: 18,
                color: clx.ink2,
              ),
              const SizedBox(width: ClxSpace.x2),
              Expanded(
                child: Text(
                  categoria.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (estourou)
                ClxChip(label: 'Estourou', color: clx.error, dense: true)
              else if (atencao)
                ClxChip(label: 'Atenção', color: clx.warning, dense: true),
              IconButton(
                tooltip: 'Remover limite',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: clx.ink3,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x2),
          // Barra de progresso.
          ClipRRect(
            borderRadius: ClxRadii.rPill,
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: clx.bg3,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          Row(
            children: [
              Text(
                '${formatCurrency(progresso.gasto)} de '
                '${formatCurrency(progresso.limite)}',
                style: TextStyle(color: clx.ink2, fontSize: 12.5),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(
                  color: barColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
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
      _valorErr = (valor == null || valor <= 0)
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
