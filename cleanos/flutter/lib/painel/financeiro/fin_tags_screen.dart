/// fin_tags_screen.dart — Tags usadas nos lançamentos do período.
///
/// Campo `tags` (JSON) em `fin_lancamentos` — sem coleção extra.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';
import 'fin_derivations.dart';
import 'fin_labels.dart';
import 'fin_providers.dart';
import 'ui/fin_ui.dart';

class FinTagsScreen extends ConsumerWidget {
  const FinTagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final period = ref.watch(finPeriodProvider);
    final async = ref.watch(finPeriodLancamentosProvider);

    return ColoredBox(
      color: clx.bg2,
      child: async.when(
        loading: () => const Center(child: Spinner(size: 28)),
        error: (_, __) => Center(
          child: ErrorBanner(
            message: 'Não foi possível carregar as tags.',
            onRetry: () => ref.invalidate(finPeriodLancamentosProvider),
          ),
        ),
        data: (lancs) {
          final counts = <String, int>{};
          final byTag = <String, List<FinLancamento>>{};
          for (final l in lancs) {
            for (final t in l.tags) {
              final key = t.trim();
              if (key.isEmpty) continue;
              counts[key] = (counts[key] ?? 0) + 1;
              (byTag[key] ??= []).add(l);
            }
          }
          final tags = counts.keys.toList()
            ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            children: [
              Text(
                'Tags',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tags do mês ${period.label} (campo nos lançamentos)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: clx.ink3,
                    ),
              ),
              const SizedBox(height: ClxSpace.x4),
              FinMonthBar(
                label: period.label,
                onPrev: () => ref.read(finPeriodProvider.notifier).state =
                    period.shift(-1),
                onNext: () => ref.read(finPeriodProvider.notifier).state =
                    period.shift(1),
              ),
              const SizedBox(height: ClxSpace.x5),
              if (tags.isEmpty)
                FinEmptyCta(
                  icon: Icons.sell_outlined,
                  message: 'Nenhuma tag neste mês.',
                  hint:
                      'Ao criar/editar um lançamento, abra "Tags" e separe por vírgula (ex.: fixo, marketing).',
                  ctaLabel: 'Ir às transações',
                  onCta: () => context.go('/painel/financeiro/transacoes'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags)
                      ActionChip(
                        avatar: CircleAvatar(
                          backgroundColor: clx.primary.withValues(alpha: 0.15),
                          child: Text(
                            '${counts[t]}',
                            style: TextStyle(
                              fontSize: 11,
                              color: clx.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        label: Text(t),
                        onPressed: () => _showTagDetail(
                          context,
                          tag: t,
                          items: byTag[t] ?? const [],
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  void _showTagDetail(
    BuildContext context, {
    required String tag,
    required List<FinLancamento> items,
  }) {
    final clx = context.clx;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: clx.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (_, scroll) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: clx.line2,
                    borderRadius: ClxRadii.rPill,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.sell_outlined, color: clx.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tag,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      Text(
                        '${items.length} lanç.',
                        style: TextStyle(color: clx.ink3),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(color: clx.line),
                    itemBuilder: (_, i) {
                      final l = items[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.descricao),
                        subtitle: Text(
                          '${formatDateOnlyBr(l.data)} · ${statusLancamentoLabel(l.status)}',
                          style: TextStyle(color: clx.ink3, fontSize: 12),
                        ),
                        trailing: Text(
                          formatCurrency(l.valor),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: tipoColor(clx, l.tipo),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
