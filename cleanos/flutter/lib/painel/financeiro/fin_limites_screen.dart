/// fin_limites_screen.dart — Limites de gasto por categoria × mês (Organizze).
///
/// • Seletor de mês no topo.
/// • Mês sem limites: "Definir limite de gastos" | "Copiar os últimos definidos".
/// • Após definir: árvore de todas as categorias/sub de despesa, barra de
///   progresso pelo gasto do mês, "+" no fim da linha abre popover R$ + Ok.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

String _anoMesOf(FinPeriod p) =>
    '${p.year.toString().padLeft(4, '0')}-${p.month.toString().padLeft(2, '0')}';

class FinLimitesScreen extends ConsumerStatefulWidget {
  const FinLimitesScreen({super.key});

  @override
  ConsumerState<FinLimitesScreen> createState() => _FinLimitesScreenState();
}

class _FinLimitesScreenState extends ConsumerState<FinLimitesScreen> {
  /// true após clicar "Definir limite de gastos" num mês vazio (mostra a árvore).
  bool _definindo = false;

  /// Popover de valor aberto nesta categoria.
  String? _editingCatId;
  final _valorCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  /// Melhor mês anterior (YYYY-MM lexicográfico) com algum limite.
  String? _ultimoMesComLimites(List<FinLimite> all, String anoMesAtual) {
    final meses = <String>{};
    for (final l in all) {
      final m = l.anoMes;
      if (m.isNotEmpty && m.compareTo(anoMesAtual) < 0) meses.add(m);
    }
    if (meses.isEmpty) return null;
    final list = meses.toList()..sort();
    return list.last;
  }

  Future<void> _copiarUltimos(
    List<FinLimite> all,
    String anoMesAtual,
  ) async {
    final origem = _ultimoMesComLimites(all, anoMesAtual);
    if (origem == null) {
      if (mounted) {
        showClxToast(
          context,
          'Não há limites em meses anteriores para copiar.',
          type: ToastType.warning,
        );
      }
      return;
    }
    final repo = ref.read(financeiroRepositoryProvider);
    final fontes = all.where((l) => l.anoMes == origem).toList();
    try {
      for (final l in fontes) {
        await repo.upsertLimite({
          'categoria_id': l.categoriaId,
          'limite': l.limite,
          'ano_mes': anoMesAtual,
        });
      }
      ref.invalidate(finLimitesProvider);
      if (mounted) {
        setState(() => _definindo = true);
        showClxToast(
          context,
          'Limites de $origem copiados para $anoMesAtual.',
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível copiar os limites.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _salvarLimite({
    required String categoriaId,
    required String anoMes,
    FinLimite? existente,
  }) async {
    final valor = parseMoedaBr(_valorCtrl.text);
    if (valor == null || valor < 0) {
      showClxToast(context, 'Informe um valor válido.', type: ToastType.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(financeiroRepositoryProvider).upsertLimite({
        if (existente != null) 'id': existente.id,
        'categoria_id': categoriaId,
        'limite': valor,
        'ano_mes': anoMes,
      });
      ref.invalidate(finLimitesProvider);
      if (mounted) {
        setState(() {
          _editingCatId = null;
          _saving = false;
          _valorCtrl.clear();
        });
        showClxToast(context, 'Limite salvo.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showClxToast(
          context,
          'Não foi possível salvar o limite.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _removerLimite(FinLimite lim) async {
    try {
      await ref.read(financeiroRepositoryProvider).deleteLimite(lim.id);
      ref.invalidate(finLimitesProvider);
      if (mounted) {
        showClxToast(context, 'Limite removido.', type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Não foi possível remover.',
          type: ToastType.error,
        );
      }
    }
  }

  void _abrirPopover(String catId, FinLimite? existente) {
    setState(() {
      _editingCatId = catId;
      _valorCtrl.text = existente == null || existente.limite <= 0
          ? ''
          : formatMoedaInput(existente.limite);
    });
  }

  @override
  Widget build(BuildContext context) {
    final limitesAsync = ref.watch(finLimitesProvider);
    final categorias =
        ref.watch(finCategoriasProvider).valueOrNull ?? const <FinCategoria>[];
    final period = ref.watch(finPeriodProvider);
    final periodLancs =
        ref.watch(finPeriodLancamentosProvider).valueOrNull ??
        const <FinLancamento>[];
    final anoMes = _anoMesOf(period);
    final mobile = finIsMobile(context);

    // Ao trocar de mês, sai do modo "definindo" se o novo mês já tem limites.
    ref.listen(finPeriodProvider, (prev, next) {
      if (prev != next) {
        setState(() {
          _definindo = false;
          _editingCatId = null;
        });
      }
    });

    return Column(
      children: [
        _Header(periodLabel: period.label, mobile: mobile),
        Expanded(
          child: FinAsync<List<FinLimite>>(
            value: limitesAsync,
            onRetry: () => ref.invalidate(finLimitesProvider),
            data: (allLimites) {
              final doMes = allLimites
                  .where((l) => l.anoMes == anoMes)
                  .toList();
              // Legado sem ano_mes: conta só no mês corrente se coincidir
              // com o backfill; senão ignora.
              final vazio = doMes.isEmpty;
              final mostrarArvore = !vazio || _definindo;

              if (!mostrarArvore) {
                return _EmptyMes(
                  labelMes: period.label,
                  temAnteriores:
                      _ultimoMesComLimites(allLimites, anoMes) != null,
                  onDefinir: () => setState(() => _definindo = true),
                  onCopiar: () => _copiarUltimos(allLimites, anoMes),
                );
              }

              final limByCat = {for (final l in doMes) l.categoriaId: l};
              final tree = _buildCatTree(categorias);

              // Totais: gasto do mês em despesas + soma dos tetos definidos.
              var gastoAll = 0.0;
              var metaAll = 0.0;
              for (final l in doMes) {
                final p = progressoLimite(l, periodLancs);
                gastoAll += p.gasto;
                metaAll += p.limite;
              }
              // Se nenhum teto, ainda mostra o gasto total de despesas do mês.
              if (doMes.isEmpty) {
                for (final l in periodLancs) {
                  if (l.tipo == TipoLancamento.despesa &&
                      l.status == LancamentoStatus.pago) {
                    gastoAll += l.valor;
                  }
                }
              }

              return ListView(
                padding: EdgeInsets.all(mobile ? ClxSpace.x4 : ClxSpace.x6),
                children: [
                  _TotaisBar(gasto: gastoAll, meta: metaAll),
                  const SizedBox(height: ClxSpace.x6),
                  for (final root in tree) ...[
                    _CatLimiteRow(
                      categoria: root.cat,
                      limite: limByCat[root.cat.id],
                      periodLancs: periodLancs,
                      indent: false,
                      editing: _editingCatId == root.cat.id,
                      valorCtrl: _valorCtrl,
                      saving: _saving,
                      onPlus: () =>
                          _abrirPopover(root.cat.id, limByCat[root.cat.id]),
                      onOk: () => _salvarLimite(
                        categoriaId: root.cat.id,
                        anoMes: anoMes,
                        existente: limByCat[root.cat.id],
                      ),
                      onCancel: () => setState(() {
                        _editingCatId = null;
                        _valorCtrl.clear();
                      }),
                      onLongRemove: limByCat[root.cat.id] != null
                          ? () => _removerLimite(limByCat[root.cat.id]!)
                          : null,
                    ),
                    for (final sub in root.subs)
                      _CatLimiteRow(
                        categoria: sub,
                        limite: limByCat[sub.id],
                        periodLancs: periodLancs,
                        indent: true,
                        editing: _editingCatId == sub.id,
                        valorCtrl: _valorCtrl,
                        saving: _saving,
                        onPlus: () =>
                            _abrirPopover(sub.id, limByCat[sub.id]),
                        onOk: () => _salvarLimite(
                          categoriaId: sub.id,
                          anoMes: anoMes,
                          existente: limByCat[sub.id],
                        ),
                        onCancel: () => setState(() {
                          _editingCatId = null;
                          _valorCtrl.clear();
                        }),
                        onLongRemove: limByCat[sub.id] != null
                            ? () => _removerLimite(limByCat[sub.id]!)
                            : null,
                      ),
                    const SizedBox(height: ClxSpace.x4),
                  ],
                  if (tree.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: ClxSpace.x8),
                      child: Center(
                        child: Text(
                          'Nenhuma categoria de despesa cadastrada.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.clx.ink3),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ─────────────────────── header ─────────────────────── */

class _Header extends StatelessWidget {
  const _Header({required this.periodLabel, required this.mobile});
  final String periodLabel;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
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
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Limite de gastos',
                  style: tt.titleSmall?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ClxSpace.x3),
                const FinPeriodSelector(expand: true),
              ],
            )
          : Row(
              children: [
                Text(
                  'Limite de gastos',
                  style: tt.titleSmall?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const FinPeriodSelector(),
              ],
            ),
    );
  }
}

/* ─────────────────────── empty do mês ─────────────────────── */

class _EmptyMes extends StatelessWidget {
  const _EmptyMes({
    required this.labelMes,
    required this.temAnteriores,
    required this.onDefinir,
    required this.onCopiar,
  });

  final String labelMes;
  final bool temAnteriores;
  final VoidCallback onDefinir;
  final VoidCallback onCopiar;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nenhum limite de gasto definido em $labelMes.',
                textAlign: TextAlign.center,
                style: tt.bodyLarge?.copyWith(color: clx.ink3),
              ),
              const SizedBox(height: ClxSpace.x5),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onDefinir,
                  style: FilledButton.styleFrom(
                    backgroundColor: clx.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: ClxRadii.rMd,
                    ),
                  ),
                  child: const Text(
                    'Definir limite de gastos',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: ClxSpace.x3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: temAnteriores ? onCopiar : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: clx.bg3,
                    foregroundColor: clx.ink2,
                    disabledBackgroundColor: clx.bg3,
                    disabledForegroundColor: clx.ink3,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: ClxRadii.rMd,
                    ),
                  ),
                  child: const Text(
                    'Copiar os últimos definidos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────── totais ─────────────────────── */

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
          style: tt.labelMedium?.copyWith(
            color: clx.finExpense,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${_fmtOrg(gasto)} de ${_fmtOrg(meta)}',
          style: tt.titleMedium?.copyWith(
            color: estourou ? clx.error : clx.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ClxSpace.x3),
        ClipRRect(
          borderRadius: ClxRadii.rPill,
          child: LinearProgressIndicator(
            value: meta > 0 ? pct : 0,
            minHeight: 18,
            backgroundColor: clx.bg3,
            valueColor: AlwaysStoppedAnimation<Color>(
              meta > 0 ? barColor : clx.bg3,
            ),
          ),
        ),
      ],
    );
  }
}

String _fmtOrg(num v) =>
    formatCurrency(v).replaceFirst(RegExp(r'^R\$\s*'), '');

/* ─────────────────────── árvore de categorias ─────────────────────── */

class _RootNode {
  _RootNode(this.cat, this.subs);
  final FinCategoria cat;
  final List<FinCategoria> subs;
}

List<_RootNode> _buildCatTree(List<FinCategoria> cats) {
  final despesas = cats
      .where((c) => c.tipo == TipoLancamento.despesa && !c.arquivada)
      .toList();
  final roots = despesas.where((c) => c.parentId == null).toList()
    ..sort((a, b) => a.nome.compareTo(b.nome));
  return [
    for (final r in roots)
      _RootNode(
        r,
        despesas.where((c) => c.parentId == r.id).toList()
          ..sort((a, b) => a.nome.compareTo(b.nome)),
      ),
  ];
}

/* ─────────────────────── linha de categoria ─────────────────────── */

class _CatLimiteRow extends StatelessWidget {
  const _CatLimiteRow({
    required this.categoria,
    required this.limite,
    required this.periodLancs,
    required this.indent,
    required this.editing,
    required this.valorCtrl,
    required this.saving,
    required this.onPlus,
    required this.onOk,
    required this.onCancel,
    this.onLongRemove,
  });

  final FinCategoria categoria;
  final FinLimite? limite;
  final List<FinLancamento> periodLancs;
  final bool indent;
  final bool editing;
  final TextEditingController valorCtrl;
  final bool saving;
  final VoidCallback onPlus;
  final VoidCallback onOk;
  final VoidCallback onCancel;
  final VoidCallback? onLongRemove;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final lim = limite;
    final prog = lim != null
        ? progressoLimite(lim, periodLancs)
        : ProgressoLimite(
            gasto: _gastoCat(categoria.id, periodLancs),
            limite: 0,
            pct: 0,
          );
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
    final cor = finParseHex(categoria.cor) ?? clx.primary;

    return Padding(
      padding: EdgeInsets.only(
        left: indent ? ClxSpace.x8 : 0,
        bottom: ClxSpace.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (indent)
                Padding(
                  padding: const EdgeInsets.only(right: ClxSpace.x2),
                  child: Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 14,
                    color: clx.ink3,
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: ClxSpace.x2),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    finCategoriaIcon(categoria.icone),
                    size: 16,
                    color: cor,
                  ),
                ),
              Expanded(
                child: Text(
                  categoria.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyLarge?.copyWith(
                    color: clx.ink,
                    fontWeight: indent ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
              if (temLimite)
                Padding(
                  padding: const EdgeInsets.only(right: ClxSpace.x2),
                  child: Text(
                    '${formatCurrency(prog.gasto)} de ${formatCurrency(prog.limite)}',
                    style: tt.labelMedium?.copyWith(
                      color: estourou ? clx.error : clx.ink2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ClxSpace.x1),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: ClxRadii.rPill,
                  child: LinearProgressIndicator(
                    value: temLimite ? prog.pct : 0,
                    minHeight: indent ? 10 : 12,
                    backgroundColor: clx.bg3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      temLimite ? barColor : clx.bg3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ClxSpace.x2),
              if (editing)
                _ValorPopover(
                  controller: valorCtrl,
                  saving: saving,
                  onOk: onOk,
                  onCancel: onCancel,
                )
              else
                InkWell(
                  onTap: onPlus,
                  onLongPress: onLongRemove,
                  borderRadius: ClxRadii.rPill,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.add,
                      size: 18,
                      color: clx.ink3,
                    ),
                  ),
                ),
            ],
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
    );
  }

  static double _gastoCat(String catId, List<FinLancamento> lancs) {
    var cents = 0;
    for (final l in lancs) {
      if (l.tipo != TipoLancamento.despesa ||
          l.status != LancamentoStatus.pago) {
        continue;
      }
      if (l.categoriaId == catId || l.subcategoriaId == catId) {
        cents += (l.valor * 100).round();
      }
    }
    return cents / 100.0;
  }
}

/// Mini formulário inline: R$ + Ok (estilo Organizze).
class _ValorPopover extends StatelessWidget {
  const _ValorPopover({
    required this.controller,
    required this.saving,
    required this.onOk,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onOk;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Material(
      elevation: 6,
      color: clx.bg,
      borderRadius: ClxRadii.rMd,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(ClxSpace.x2),
        decoration: BoxDecoration(
          borderRadius: ClxRadii.rMd,
          border: Border.all(color: clx.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              enabled: !saving,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w600,
                  ),
              decoration: InputDecoration(
                isDense: true,
                prefixText: 'R\$ ',
                hintText: '0,00',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: ClxRadii.rMd,
                  borderSide: BorderSide(color: clx.success, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: ClxRadii.rMd,
                  borderSide: BorderSide(color: clx.success, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: ClxRadii.rMd,
                  borderSide: BorderSide(color: clx.success, width: 2),
                ),
              ),
              onSubmitted: (_) => onOk(),
            ),
            const SizedBox(height: ClxSpace.x2),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : onOk,
                style: FilledButton.styleFrom(
                  backgroundColor: clx.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: ClxRadii.rMd,
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Ok',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
