/// fin_fechar_ciclo.dart — Fechar ciclo de pagamento da equipe (admin).
///
/// Fluxo: 1) escolher profissional → 2) escolher semana com status **não paga**
/// → 3) ver OS da semana e pagar (gera despesa via hook).
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
import 'fin_providers.dart';

/// Linha de um profissional no fechamento do ciclo.
class FecharCicloLinha {
  const FecharCicloLinha({
    required this.prof,
    required this.pendentes,
    required this.total,
    this.proximoPagamento,
    this.cicloLabel = '',
    this.periodoLabel = '',
  });

  final User prof;
  final List<ProfComissao> pendentes;
  final double total;
  final DateTime? proximoPagamento;
  final String cicloLabel;

  /// Ex.: "20/07 a 26/07/2026" (janela de OS do ciclo).
  final String periodoLabel;

  int get qtd => pendentes.length;
  List<String> get ids => [for (final c in pendentes) c.id];
}

/// Agrupa comissões **pendentes** por profissional.
///
/// [janela]: se informada, só OS com data nessa semana/ciclo.
/// Se null, usa o ciclo **corrente** de cada profissional.
List<FecharCicloLinha> buildFecharCicloLinhas({
  required List<User> profs,
  required List<ProfComissao> comissoes,
  CicloPagamentoWindow? janela,
  DateTime? now,
  String? onlyProfId,
}) {
  final byId = {for (final u in profs) u.id: u};
  final map = <String, List<ProfComissao>>{};

  final allPend = <String, List<ProfComissao>>{};
  for (final c in comissoes) {
    // Bonificação é avulsa e não pode ser paga pelo fechamento do ciclo de OS.
    if (c.tipoAplicado == ProfComissaoTipo.bonificacao ||
        c.tipoAplicado == ProfComissaoTipo.salario) {
      continue;
    }
    if (c.status != ComissaoStatus.pendente) continue;
    if (c.valorComissao <= 0) continue;
    if (onlyProfId != null && c.profissional != onlyProfId) continue;
    allPend.putIfAbsent(c.profissional, () => []).add(c);
  }

  for (final e in allPend.entries) {
    final u = byId[e.key];
    List<ProfComissao> filtradas;
    if (u == null) {
      filtradas = janela == null
          ? e.value
          : [
              for (final c in e.value)
                if (comissaoYmd(c).isEmpty || janela.contemYmd(comissaoYmd(c)))
                  c,
            ];
    } else if (janela != null) {
      filtradas = comissoesPendentesNaJanela(e.value, janela);
    } else {
      filtradas = comissoesPendentesDoCiclo(u, e.value, now: now);
    }
    if (filtradas.isEmpty) continue;
    map[e.key] = filtradas;
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
    final win = janela ?? cicloCorrente(u, now: now);
    out.add(
      FecharCicloLinha(
        prof: u,
        pendentes: e.value,
        total: total,
        proximoPagamento: proximaDataPagamento(u, now: now),
        cicloLabel: cicloPagamentoLabel(u),
        periodoLabel: win?.labelBr ?? '',
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
  /// Profissionais que têm pelo menos 1 comissão pendente.
  late List<User> _profsComPendente;
  User? _profSel;
  List<CicloPagamentoWindow> _semanas = const [];
  CicloPagamentoWindow? _semanaSel;
  List<ProfComissao> _osSemana = const [];
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _profsComPendente = _profsComComissaoPendente();
    // Não pré-seleciona: admin escolhe o profissional primeiro.
  }

  List<User> _profsComComissaoPendente() {
    final ids = <String>{};
    for (final c in widget.comissoes) {
      if (c.status == ComissaoStatus.pendente && c.valorComissao > 0) {
        ids.add(c.profissional);
      }
    }
    final list = [
      for (final u in widget.profs)
        if (ids.contains(u.id)) u,
    ]..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
      );
    // Prof sem cadastro na lista mas com comissão.
    for (final id in ids) {
      if (list.any((u) => u.id == id)) continue;
      list.add(
        User(
          id: id,
          name: id.length > 8 ? id.substring(0, 8) : id,
          role: Role.profissional,
        ),
      );
    }
    return list;
  }

  void _onProfChanged(String? profId) {
    if (profId == null) return;
    User? u;
    for (final p in _profsComPendente) {
      if (p.id == profId) {
        u = p;
        break;
      }
    }
    if (u == null) return;
    setState(() {
      _profSel = u;
      _semanas = listarSemanasComPendentes([u!], widget.comissoes);
      _semanaSel = _semanas.isNotEmpty ? _semanas.first : null;
      _osSemana = _pendentesDaSemana();
    });
  }

  void _onSemanaChanged(CicloPagamentoWindow w) {
    setState(() {
      _semanaSel = w;
      _osSemana = _pendentesDaSemana();
    });
  }

  List<ProfComissao> _pendentesDaSemana() {
    final u = _profSel;
    final w = _semanaSel;
    if (u == null || w == null) return const [];
    final doProf = [
      for (final c in widget.comissoes)
        if (c.profissional == u.id) c,
    ];
    final list = comissoesPendentesNaJanela(doProf, w);
    list.sort((a, b) {
      final da = comissaoYmd(a);
      final db = comissaoYmd(b);
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
      return b.valorComissao.compareTo(a.valorComissao);
    });
    return list;
  }

  double get _totalSemana {
    return _osSemana.fold<int>(
          0,
          (s, c) => s + (c.valorComissao * 100).round(),
        ) /
        100.0;
  }

  String _semanaKey(CicloPagamentoWindow w) =>
      '${w.inicioYmd}_${w.fimYmd}';

  double _totalSemanaDe(User u, CicloPagamentoWindow w) {
    final doProf = [
      for (final c in widget.comissoes)
        if (c.profissional == u.id) c,
    ];
    final list = comissoesPendentesNaJanela(doProf, w);
    return list.fold<int>(0, (s, c) => s + (c.valorComissao * 100).round()) /
        100.0;
  }

  Future<void> _pagar() async {
    final u = _profSel;
    final w = _semanaSel;
    if (_paying || u == null || w == null || _osSemana.isEmpty) return;
    final ids = [for (final c in _osSemana) c.id];
    final total = _totalSemana;
    final ok = await _confirm(
      title: 'Pagar ${u.displayName}?',
      body:
          'Semana ${w.labelBr}\n'
          'Marcar ${_osSemana.length} comissão${_osSemana.length == 1 ? '' : 'ões'} '
          '(${formatCurrency(total)}) como paga?\n'
          'Isso gera despesa no financeiro.',
    );
    if (ok != true || !mounted) return;
    setState(() => _paying = true);
    try {
      // Preferência: 1 PATCH na despesa do ciclo (espelha todas as OS no hook).
      // Evita N updates sequenciais que reentravam e travavam a UI.
      final pagoViaCiclo = await _pagarViaLancamentoCiclo(u.id, w);
      if (!pagoViaCiclo) {
        await ref.read(comissaoRepositoryProvider).marcarLotePagas(ids);
      }
      if (!mounted) return;
      showClxToast(
        context,
        'Pago ${u.displayName}: ${formatCurrency(total)} · ${w.labelBr}',
        type: ToastType.success,
      );
      widget.onPaid();
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        showClxToast(
          context,
          'Falha ao pagar ${u.displayName}.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Marca a linha `repasse_ciclo:inicio:fim` como paga (1 request).
  /// Retorna false se não achar o lançamento (fallback para lote de OS).
  Future<bool> _pagarViaLancamentoCiclo(
    String profId,
    CicloPagamentoWindow w,
  ) async {
    final obs = 'repasse_ciclo:${w.inicioYmd}:${w.fimYmd}';
    // Escapa aspas no filter PB.
    final pid = profId.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final obsEsc = obs.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final filter =
        'origem = "via_comissao" && status = "pendente" && '
        'profissional_id = "$pid" && observacao = "$obsEsc"';
    final page = await ref.read(financeiroRepositoryProvider).listLancamentos(
          page: 1,
          perPage: 5,
          filter: filter,
          sort: '-updated',
        );
    if (page.items.isEmpty) return false;
    final id = page.items.first.id;
    await ref.read(financeiroRepositoryProvider).updateLancamento(id, {
      'status': 'pago',
    });
    return true;
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
    final u = _profSel;

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
                        '1º profissional · 2º semana não paga · 3º pagar',
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
            const SizedBox(height: 12),

            if (_profsComPendente.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nada a pagar',
                  message: 'Não há comissões pendentes no momento.',
                ),
              )
            else ...[
              // 1) Profissional
              Text(
                'Profissional',
                style: tt.labelMedium?.copyWith(
                  color: clx.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _profSel?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                hint: const Text('Selecione o profissional'),
                items: [
                  for (final p in _profsComPendente)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _paying ? null : _onProfChanged,
              ),
              const SizedBox(height: 12),

              // 2) Semana (só depois do prof)
              if (u != null) ...[
                Text(
                  'Semana não paga',
                  style: tt.labelMedium?.copyWith(
                    color: clx.ink2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                if (_semanas.isEmpty)
                  Text(
                    'Nenhuma semana com comissão em aberto para este profissional.',
                    style: tt.bodySmall?.copyWith(color: clx.ink3),
                  )
                else
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value:
                        _semanaSel == null ? null : _semanaKey(_semanaSel!),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.date_range_rounded),
                    ),
                    hint: const Text('Selecione a semana'),
                    items: [
                      for (final w in _semanas)
                        DropdownMenuItem(
                          value: _semanaKey(w),
                          child: Text(
                            '${w.labelBr} · ${formatCurrency(_totalSemanaDe(u, w))}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _paying
                        ? null
                        : (key) {
                            if (key == null) return;
                            for (final w in _semanas) {
                              if (_semanaKey(w) == key) {
                                _onSemanaChanged(w);
                                break;
                              }
                            }
                          },
                  ),
                const SizedBox(height: 12),
              ],

              // 3) Resumo + OS da semana
              if (u != null && _semanaSel != null) ...[
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
                          '${u.displayName}\n'
                          'Semana ${_semanaSel!.labelBr} · '
                          '${_osSemana.length} OS',
                          style: tt.bodySmall?.copyWith(color: clx.ink2),
                        ),
                      ),
                      Text(
                        formatCurrency(_totalSemana),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: clx.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_osSemana.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nenhuma OS pendente nesta semana.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: clx.ink3),
                    ),
                  )
                else ...[
                  Text(
                    'OS da semana',
                    style: tt.labelMedium?.copyWith(
                      color: clx.ink2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: h * 0.35),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _osSemana.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: ClxSpace.x2),
                      itemBuilder: (_, i) {
                        final c = _osSemana[i];
                        final data = comissaoYmd(c);
                        final dataBr = data.length >= 10
                            ? '${data.substring(8, 10)}/${data.substring(5, 7)}/${data.substring(0, 4)}'
                            : '—';
                        return Container(
                          padding: const EdgeInsets.all(ClxSpace.x3),
                          decoration: BoxDecoration(
                            color: clx.bg2,
                            borderRadius: ClxRadii.rMd,
                            border: Border.all(color: clx.line),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.descricao.isNotEmpty
                                          ? c.descricao
                                          : 'Comissão OS',
                                      style: tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: clx.ink,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      dataBr,
                                      style: tt.bodySmall?.copyWith(
                                        color: clx.ink3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatCurrency(c.valorComissao),
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: clx.warning,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _paying || _osSemana.isEmpty ? null : _pagar,
                    child: _paying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Pagar semana · ${formatCurrency(_totalSemana)}',
                          ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
