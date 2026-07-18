/// fin_fechar_ciclo.dart — Fechar ciclo de pagamento da equipe (admin).
///
/// Lista o que cada profissional tem **pendente** de repasse, com data do
/// próximo pagamento e ciclo configurado. Permite pagar em lote (1 prof ou
/// todos), reutilizando o mesmo hook que a mãozinha 👍 (gera despesa).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import '../../profissional/financeiro/prof_pagamento.dart';
import '../data/painel_providers.dart';

/// Linha de um profissional no fechamento do ciclo.
class FecharCicloLinha {
  const FecharCicloLinha({
    required this.prof,
    required this.pendentes,
    required this.total,
    this.proximoPagamento,
    this.cicloLabel = '',
  });

  final User prof;
  final List<ProfComissao> pendentes;
  final double total;
  final DateTime? proximoPagamento;
  final String cicloLabel;

  int get qtd => pendentes.length;
  List<String> get ids => [for (final c in pendentes) c.id];
}

/// Agrupa comissões pendentes por profissional (só quem tem saldo).
List<FecharCicloLinha> buildFecharCicloLinhas({
  required List<User> profs,
  required List<ProfComissao> comissoes,
  DateTime? now,
}) {
  final byId = {for (final u in profs) u.id: u};
  final map = <String, List<ProfComissao>>{};
  for (final c in comissoes) {
    if (c.status != ComissaoStatus.pendente) continue;
    if (c.valorComissao <= 0) continue;
    map.putIfAbsent(c.profissional, () => []).add(c);
  }

  final out = <FecharCicloLinha>[];
  for (final e in map.entries) {
    final u = byId[e.key] ??
        User(
          id: e.key,
          name: e.key.length > 8 ? e.key.substring(0, 8) : e.key,
          role: Role.profissional,
        );
    final total = e.value.fold<int>(
          0,
          (s, c) => s + (c.valorComissao * 100).round(),
        ) /
        100.0;
    out.add(
      FecharCicloLinha(
        prof: u,
        pendentes: e.value,
        total: total,
        proximoPagamento: proximaDataPagamento(u, now: now),
        cicloLabel: cicloPagamentoLabel(u),
      ),
    );
  }
  out.sort((a, b) => b.total.compareTo(a.total));
  return out;
}

/// Abre o sheet de fechamento de ciclo.
Future<void> openFecharCicloSheet(
  BuildContext context, {
  required List<User> profs,
  required List<ProfComissao> comissoes,
  required VoidCallback onPaid,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.clx.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _FecharCicloSheet(
      profs: profs,
      comissoes: comissoes,
      onPaid: onPaid,
    ),
  );
}

class _FecharCicloSheet extends ConsumerStatefulWidget {
  const _FecharCicloSheet({
    required this.profs,
    required this.comissoes,
    required this.onPaid,
  });

  final List<User> profs;
  final List<ProfComissao> comissoes;
  final VoidCallback onPaid;

  @override
  ConsumerState<_FecharCicloSheet> createState() => _FecharCicloSheetState();
}

class _FecharCicloSheetState extends ConsumerState<_FecharCicloSheet> {
  late List<FecharCicloLinha> _linhas;
  final Set<String> _selectedProf = {};
  bool _paying = false;
  String? _busyProfId;

  @override
  void initState() {
    super.initState();
    _linhas = buildFecharCicloLinhas(
      profs: widget.profs,
      comissoes: widget.comissoes,
    );
    // Pré-seleciona todos com saldo.
    _selectedProf.addAll(_linhas.map((l) => l.prof.id));
  }

  double get _totalSelected {
    var cents = 0;
    for (final l in _linhas) {
      if (!_selectedProf.contains(l.prof.id)) continue;
      cents += (l.total * 100).round();
    }
    return cents / 100.0;
  }

  int get _qtdSelected {
    var n = 0;
    for (final l in _linhas) {
      if (!_selectedProf.contains(l.prof.id)) continue;
      n += l.qtd;
    }
    return n;
  }

  Future<void> _pagarProf(FecharCicloLinha l) async {
    if (_paying || l.ids.isEmpty) return;
    final ok = await _confirm(
      title: 'Pagar ${l.prof.displayName}?',
      body:
          'Marcar ${l.qtd} comissão${l.qtd == 1 ? '' : 'ões'} '
          '(${formatCurrency(l.total)}) como paga?\n'
          'Isso gera despesa no financeiro.',
    );
    if (ok != true || !mounted) return;
    setState(() {
      _paying = true;
      _busyProfId = l.prof.id;
    });
    try {
      await ref.read(comissaoRepositoryProvider).marcarLotePagas(l.ids);
      if (!mounted) return;
      showClxToast(
        context,
        'Pago ${l.prof.displayName}: ${formatCurrency(l.total)}',
        type: ToastType.success,
      );
      widget.onPaid();
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Falha ao pagar ${l.prof.displayName}.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _paying = false;
          _busyProfId = null;
        });
      }
    }
  }

  Future<void> _pagarSelecionados() async {
    if (_paying || _selectedProf.isEmpty) return;
    final ids = <String>[
      for (final l in _linhas)
        if (_selectedProf.contains(l.prof.id)) ...l.ids,
    ];
    if (ids.isEmpty) return;
    final ok = await _confirm(
      title: 'Pagar selecionados?',
      body:
          'Marcar $_qtdSelected comissão${_qtdSelected == 1 ? '' : 'ões'} '
          '(${formatCurrency(_totalSelected)}) como paga?\n'
          'Isso gera despesa no financeiro para cada uma.',
    );
    if (ok != true || !mounted) return;
    setState(() => _paying = true);
    try {
      await ref.read(comissaoRepositoryProvider).marcarLotePagas(ids);
      if (!mounted) return;
      showClxToast(
        context,
        'Ciclo pago: ${formatCurrency(_totalSelected)}',
        type: ToastType.success,
      );
      widget.onPaid();
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Falha ao pagar o lote. Tente de novo.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<bool?> _confirm({required String title, required String body}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar pagamento'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final h = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: clx.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fechar ciclo de pagamento',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Marca comissões pendentes como pagas e gera despesa.',
                        style: tt.bodySmall?.copyWith(color: clx.ink2),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _paying
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_linhas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nada a pagar',
                  message: 'Não há comissões pendentes no momento.',
                ),
              )
            else ...[
              // Resumo
              Container(
                padding: const EdgeInsets.all(ClxSpace.x3),
                decoration: BoxDecoration(
                  color: clx.bg3,
                  borderRadius: ClxRadii.rMd,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedProf.length} profissional${_selectedProf.length == 1 ? '' : 'is'} · '
                        '$_qtdSelected comissão${_qtdSelected == 1 ? '' : 'ões'}',
                        style: tt.bodySmall?.copyWith(color: clx.ink2),
                      ),
                    ),
                    Text(
                      formatCurrency(_totalSelected),
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: clx.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: _paying
                        ? null
                        : () => setState(
                              () => _selectedProf
                                ..clear()
                                ..addAll(_linhas.map((l) => l.prof.id)),
                            ),
                    child: const Text('Todos'),
                  ),
                  TextButton(
                    onPressed: _paying
                        ? null
                        : () => setState(() => _selectedProf.clear()),
                    child: const Text('Nenhum'),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: h * 0.45),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _linhas.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: ClxSpace.x2),
                  itemBuilder: (_, i) {
                    final l = _linhas[i];
                    final sel = _selectedProf.contains(l.prof.id);
                    final busy = _busyProfId == l.prof.id;
                    final data = l.proximoPagamento != null
                        ? formatProximoPagamento(l.proximoPagamento!)
                        : '—';
                    return Material(
                      color: clx.bg2,
                      borderRadius: ClxRadii.rMd,
                      child: InkWell(
                        borderRadius: ClxRadii.rMd,
                        onTap: _paying
                            ? null
                            : () => setState(() {
                                  if (sel) {
                                    _selectedProf.remove(l.prof.id);
                                  } else {
                                    _selectedProf.add(l.prof.id);
                                  }
                                }),
                        child: Padding(
                          padding: const EdgeInsets.all(ClxSpace.x3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: sel,
                                    onChanged: _paying
                                        ? null
                                        : (v) => setState(() {
                                              if (v == true) {
                                                _selectedProf.add(l.prof.id);
                                              } else {
                                                _selectedProf
                                                    .remove(l.prof.id);
                                              }
                                            }),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.prof.displayName,
                                          style: tt.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${l.cicloLabel} · próximo $data',
                                          style: tt.bodySmall?.copyWith(
                                            color: clx.ink3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(l.total),
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: clx.warning,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${l.qtd} comissão${l.qtd == 1 ? '' : 'ões'} pendente${l.qtd == 1 ? '' : 's'}',
                                style: tt.labelSmall?.copyWith(color: clx.ink2),
                              ),
                              const SizedBox(height: 6),
                              // Preview OS
                              for (final c in l.pendentes.take(3))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '· ${c.descricao.isNotEmpty ? c.descricao : 'Serviço'} — ${formatCurrency(c.valorComissao)}',
                                    style: tt.bodySmall?.copyWith(
                                      color: clx.ink2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (l.pendentes.length > 3)
                                Text(
                                  '… e mais ${l.pendentes.length - 3}',
                                  style: tt.labelSmall?.copyWith(
                                    color: clx.ink3,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonal(
                                  onPressed:
                                      _paying ? null : () => _pagarProf(l),
                                  child: busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Pagar ${l.prof.displayName.split(' ').first}',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _paying || _selectedProf.isEmpty
                    ? null
                    : _pagarSelecionados,
                child: _paying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Pagar selecionados · ${formatCurrency(_totalSelected)}',
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
