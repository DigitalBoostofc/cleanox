/// fin_contas_pagar_receber_screen.dart — Contas a pagar / a receber.
///
/// Espelha `ContasPagarReceber.tsx`: alterna A pagar (despesas em aberto) / A
/// receber (receitas em aberto), com derivações de vencimento/atraso ([contasAPagar]
/// /[contasAReceber]) vs. HOJE em BRT, e a ação "marcar pago" (que ajusta o saldo
/// no repo). Total pendente no topo. Estados carregando/erro/vazio/sucesso.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'fin_common.dart';
import 'fin_derivations.dart';
import 'fin_labels.dart';
import 'fin_providers.dart';

final _cprTipoProvider = StateProvider.autoDispose<TipoLancamento>(
  (ref) => TipoLancamento.despesa,
);

class FinContasPagarReceberScreen extends ConsumerWidget {
  const FinContasPagarReceberScreen({super.key});

  Future<void> _marcarPago(
    BuildContext context,
    WidgetRef ref,
    FinLancamento l,
  ) async {
    try {
      await ref.read(financeiroRepositoryProvider).updateLancamento(l.id, {
        'status': LancamentoStatus.pago.wire,
      });
      ref.invalidate(finPendentesProvider);
      ref.invalidate(finContasProvider);
      ref.invalidate(finPeriodLancamentosProvider);
      if (context.mounted) {
        showClxToast(context, 'Marcado como pago.', type: ToastType.success);
      }
    } catch (_) {
      if (context.mounted) {
        showClxToast(
          context,
          'Não foi possível atualizar.',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = ref.watch(_cprTipoProvider);
    final async = ref.watch(finPendentesProvider);
    final hoje = todayLocalDate();

    return Column(
      children: [
        _Toolbar(
          tipo: tipo,
          onTipo: (t) => ref.read(_cprTipoProvider.notifier).state = t,
        ),
        Expanded(
          child: FinAsync<List<FinLancamento>>(
            value: async,
            onRetry: () => ref.invalidate(finPendentesProvider),
            data: (todos) {
              final pendentes = tipo == TipoLancamento.despesa
                  ? contasAPagar(todos, hoje)
                  : contasAReceber(todos, hoje);
              if (pendentes.isEmpty) {
                return EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: tipo == TipoLancamento.despesa
                      ? 'Nada a pagar em aberto'
                      : 'Nada a receber em aberto',
                  message: 'Tudo em dia por aqui. 🎉',
                );
              }
              final total = pendentes.fold<double>(
                0,
                (s, p) => s + p.lancamento.valor,
              );
              final emAtraso = pendentes.where((p) => p.emAtraso).length;
              return Column(
                children: [
                  _Summary(
                    tipo: tipo,
                    total: total,
                    qtd: pendentes.length,
                    emAtraso: emAtraso,
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        ClxSpace.x6,
                        0,
                        ClxSpace.x6,
                        ClxSpace.x6,
                      ),
                      itemCount: pendentes.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: ClxSpace.x2),
                      itemBuilder: (context, i) => _PendenteRow(
                        pendente: pendentes[i],
                        onPagar: () =>
                            _marcarPago(context, ref, pendentes[i].lancamento),
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

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.tipo, required this.onTipo});

  final TipoLancamento tipo;
  final ValueChanged<TipoLancamento> onTipo;

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
      child: SegmentedButton<TipoLancamento>(
        segments: const [
          ButtonSegment(
            value: TipoLancamento.despesa,
            label: Text('A pagar'),
            icon: Icon(Icons.south_west_rounded, size: 16),
          ),
          ButtonSegment(
            value: TipoLancamento.receita,
            label: Text('A receber'),
            icon: Icon(Icons.north_east_rounded, size: 16),
          ),
        ],
        selected: {tipo},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onTipo(s.first),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.tipo,
    required this.total,
    required this.qtd,
    required this.emAtraso,
  });

  final TipoLancamento tipo;
  final double total;
  final int qtd;
  final int emAtraso;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cor = tipo == TipoLancamento.despesa ? clx.finExpense : clx.finIncome;
    return Padding(
      padding: const EdgeInsets.all(ClxSpace.x6),
      child: ClxCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipo == TipoLancamento.despesa
                        ? 'Total a pagar'
                        : 'Total a receber',
                    style: TextStyle(color: clx.ink3, fontSize: 12.5),
                  ),
                  Text(
                    formatCurrency(total),
                    style: TextStyle(
                      color: cor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$qtd em aberto',
                  style: TextStyle(color: clx.ink2, fontSize: 13),
                ),
                if (emAtraso > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: ClxSpace.x1),
                    child: ClxChip(
                      label: '$emAtraso em atraso',
                      color: clx.error,
                      dense: true,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendenteRow extends StatelessWidget {
  const _PendenteRow({required this.pendente, required this.onPagar});

  final ContaPendente pendente;
  final VoidCallback onPagar;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final l = pendente.lancamento;
    final venc = (l.vencimento?.isNotEmpty ?? false) ? l.vencimento! : l.data;

    return ClxCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.descricao.isEmpty ? '(sem descrição)' : l.descricao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clx.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 13,
                      color: pendente.emAtraso ? clx.error : clx.ink3,
                    ),
                    const SizedBox(width: ClxSpace.x1),
                    Text(
                      'Vence ${formatDateOnlyBr(venc)}',
                      style: TextStyle(
                        color: pendente.emAtraso ? clx.error : clx.ink3,
                        fontSize: 12.5,
                        fontWeight: pendente.emAtraso
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    if (pendente.vencendoHoje) ...[
                      const SizedBox(width: ClxSpace.x2),
                      ClxChip(label: 'Hoje', color: clx.warning, dense: true),
                    ] else if (pendente.emAtraso) ...[
                      const SizedBox(width: ClxSpace.x2),
                      ClxChip(label: 'Atrasado', color: clx.error, dense: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: ClxSpace.x3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(l.valor),
                style: TextStyle(
                  color: tipoColor(clx, l.tipo),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              StatusLancamentoChip(status: l.status, dense: true),
            ],
          ),
          const SizedBox(width: ClxSpace.x3),
          IconButton(
            tooltip: 'Marcar como pago',
            icon: Icon(Icons.check_circle_outline_rounded, color: clx.success),
            onPressed: onPagar,
          ),
        ],
      ),
    );
  }
}
