/// fin_serie_actions.dart — Diálogos compartilhados de série (pausar/encerrar/excluir).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/models/financeiro.dart';
import 'fin_providers.dart';
import 'fin_recorrencia.dart';
import 'lancamentos/fin_lancamentos_controller.dart';

/// Resultado do diálogo de exclusão de lançamento de série.
enum DeleteLancamentoChoice {
  cancel,
  onlyThis,
  thisAndFuture,
  stopSeries,
}

/// Pergunta o que fazer ao excluir um lançamento fixo/recorrente.
Future<DeleteLancamentoChoice> showDeleteSerieDialog(
  BuildContext context, {
  required FinLancamento lancamento,
}) async {
  final isSerie = lancamento.isDaSerie;
  if (!isSerie) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento'),
        content: Text(
          'Excluir "${lancamento.descricao}"? Isso ajusta o saldo da conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.clx.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return ok == true
        ? DeleteLancamentoChoice.onlyThis
        : DeleteLancamentoChoice.cancel;
  }

  final choice = await showDialog<DeleteLancamentoChoice>(
    context: context,
    builder: (ctx) {
      final clx = context.clx;
      return AlertDialog(
        title: const Text('Excluir lançamento recorrente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '"${lancamento.descricao}" faz parte de uma cobrança fixa. '
              'O que você quer fazer?',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _ChoiceTile(
              icon: Icons.looks_one_outlined,
              title: 'Só este',
              subtitle: 'Apaga apenas este mês/data. A regra continua ativa.',
              onTap: () =>
                  Navigator.pop(ctx, DeleteLancamentoChoice.onlyThis),
            ),
            _ChoiceTile(
              icon: Icons.date_range_outlined,
              title: 'Este e os futuros',
              subtitle:
                  'Remove este e os próximos em aberto; outros já pagos ficam. '
                  'A cobrança é pausada (não gera de novo).',
              onTap: () =>
                  Navigator.pop(ctx, DeleteLancamentoChoice.thisAndFuture),
            ),
            _ChoiceTile(
              icon: Icons.block_outlined,
              title: 'Encerrar a cobrança',
              subtitle:
                  'Para de gerar para sempre. Remove previstos futuros; '
                  'pagos ficam no extrato.',
              danger: true,
              onTap: () =>
                  Navigator.pop(ctx, DeleteLancamentoChoice.stopSeries),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, DeleteLancamentoChoice.cancel),
              child: Text('Cancelar', style: TextStyle(color: clx.ink3)),
            ),
          ],
        ),
      );
    },
  );
  return choice ?? DeleteLancamentoChoice.cancel;
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final color = danger ? clx.error : clx.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: clx.bg2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: clx.ink3,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: clx.ink3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aplica a escolha de exclusão (com ensure de série se legado).
Future<String?> applyDeleteLancamentoChoice(
  WidgetRef ref, {
  required FinLancamento l,
  required DeleteLancamentoChoice choice,
}) async {
  if (choice == DeleteLancamentoChoice.cancel) return null;
  final repo = ref.read(financeiroRepositoryProvider);

  if (choice == DeleteLancamentoChoice.onlyThis || !l.isDaSerie) {
    await repo.deleteLancamento(l.id);
    return 'Lançamento excluído.';
  }

  // Garante série (legado sem serie_id).
  FinSerie serie;
  try {
    serie = await repo.ensureSerieForLancamento(l);
  } catch (e) {
    // Fallback: só apaga este se não der para criar série.
    await repo.deleteLancamento(l.id);
    return 'Lançamento excluído (série legada não vinculada).';
  }

  switch (choice) {
    case DeleteLancamentoChoice.onlyThis:
      await repo.deleteLancamento(l.id);
      return 'Lançamento excluído.';
    case DeleteLancamentoChoice.thisAndFuture:
      // Remove este + futuros não pagos e pausa a regra (senão o ensure recria).
      final n = await repo.excluirOcorrenciasSerie(
        serieId: serie.id,
        escopo: SerieExclusaoEscopo.esteEFuturos,
        referencia: l,
      );
      // pausarSerie também limpa não-pagos a partir da data; idempotente.
      // Usa o dia seguinte ao "este" se "este" era pago e ficou (não apagamos
      // outros pagos). Na prática pausar com a data do item basta.
      final fromYmd = l.data.length >= 10 ? l.data.substring(0, 10) : l.data;
      await repo.pausarSerie(serie.id, aPartirDeYmd: fromYmd);
      return n <= 1
          ? 'Lançamento e recorrência parados.'
          : '$n lançamentos removidos e cobrança pausada.';
    case DeleteLancamentoChoice.stopSeries:
      await repo.excluirOcorrenciasSerie(
        serieId: serie.id,
        escopo: SerieExclusaoEscopo.encerrarMantendoPagos,
        referencia: l,
      );
      return 'Cobrança encerrada. Histórico pago mantido.';
    case DeleteLancamentoChoice.cancel:
      return null;
  }
}

Future<void> refreshAfterSerieMutation(WidgetRef ref) async {
  ref.invalidate(finContasProvider);
  ref.invalidate(finPeriodLancamentosProvider);
  ref.invalidate(finPendentesProvider);
  ref.invalidate(finSeriesProvider);
  if (ref.exists(finLancControllerProvider)) {
    await ref.read(finLancControllerProvider.notifier).refresh();
  }
}

/// Ações rápidas sobre uma [FinSerie] (tela de fixas / detalhe).
Future<void> _runSerieAction(
  BuildContext context,
  WidgetRef ref, {
  required FinSerie serie,
  required _SerieAction action,
}) async {
  final repo = ref.read(financeiroRepositoryProvider);
  try {
    switch (action) {
      case _SerieAction.pausar:
        await repo.pausarSerie(serie.id);
        if (context.mounted) {
          showClxToast(context, 'Cobrança pausada.', type: ToastType.success);
        }
      case _SerieAction.retomar:
        await repo.retomarSerie(serie.id);
        if (context.mounted) {
          showClxToast(context, 'Cobrança reativada.', type: ToastType.success);
        }
      case _SerieAction.encerrar:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Encerrar cobrança'),
            content: Text(
              'Encerrar "${serie.descricao}"?\n\n'
              'Remove os próximos lançamentos em aberto. '
              'O que já foi pago fica no extrato.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: context.clx.error),
                child: const Text('Encerrar'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await repo.encerrarSerie(serie.id);
        if (context.mounted) {
          showClxToast(context, 'Cobrança encerrada.', type: ToastType.success);
        }
    }
    await refreshAfterSerieMutation(ref);
  } catch (_) {
    if (context.mounted) {
      showClxToast(
        context,
        'Não foi possível atualizar a cobrança.',
        type: ToastType.error,
      );
    }
  }
}

enum _SerieAction { pausar, retomar, encerrar }

Future<void> pausarSerieUi(
  BuildContext context,
  WidgetRef ref,
  FinSerie s,
) =>
    _runSerieAction(context, ref, serie: s, action: _SerieAction.pausar);

Future<void> retomarSerieUi(
  BuildContext context,
  WidgetRef ref,
  FinSerie s,
) =>
    _runSerieAction(context, ref, serie: s, action: _SerieAction.retomar);

Future<void> encerrarSerieUi(
  BuildContext context,
  WidgetRef ref,
  FinSerie s,
) =>
    _runSerieAction(context, ref, serie: s, action: _SerieAction.encerrar);
