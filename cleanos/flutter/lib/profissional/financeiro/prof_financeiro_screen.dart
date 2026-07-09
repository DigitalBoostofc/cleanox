/// prof_financeiro_screen.dart — Financeiro do profissional (comissões).
///
/// Só faz sentido quando o admin configurou comissão (% ou fixo). Lista o
/// extrato gerado ao concluir OS e totais pendente/pago.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/prof_comissao.dart';
import '../../painel/data/painel_providers.dart';

final _profComissoesProvider =
    FutureProvider.autoDispose<List<ProfComissao>>((ref) async {
      final me = ref.watch(currentUserProvider);
      if (me == null) return const [];
      return ref
          .watch(comissaoRepositoryProvider)
          .listComissoes(profissionalId: me.id);
    });

class ProfFinanceiroScreen extends ConsumerWidget {
  const ProfFinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final me = ref.watch(currentUserProvider);
    final async = ref.watch(_profComissoesProvider);

    return Scaffold(
      backgroundColor: clx.bg2,
      appBar: AppBar(
        title: const Text('Meu financeiro'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(_profComissoesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorBanner(
          message: 'Não foi possível carregar seu financeiro.',
          onRetry: () => ref.invalidate(_profComissoesProvider),
        ),
        data: (items) {
          if (me == null || !me.hasComissaoAtiva) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Sem comissão configurada',
              message:
                  'Quando o admin definir sua comissão, o extrato aparece aqui.',
            );
          }

          final pendente = items
              .where((c) => c.status == ComissaoStatus.pendente)
              .fold<double>(0, (s, c) => s + c.valorComissao);
          final paga = items
              .where((c) => c.status == ComissaoStatus.paga)
              .fold<double>(0, (s, c) => s + c.valorComissao);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_profComissoesProvider),
            child: ListView(
              padding: const EdgeInsets.all(ClxSpace.x4),
              children: [
                ClxCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sua comissão',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: clx.ink2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        me.comissaoResumo,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ClxSpace.x3),
                Row(
                  children: [
                    Expanded(
                      child: ClxCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'A receber',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: clx.ink2),
                            ),
                            Text(
                              formatCurrency(pendente),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: clx.warning,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: ClxSpace.x3),
                    Expanded(
                      child: ClxCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Já pago',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: clx.ink2),
                            ),
                            Text(
                              formatCurrency(paga),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: clx.success,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ClxSpace.x4),
                Text(
                  'Extrato',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ClxSpace.x2),
                if (items.isEmpty)
                  ClxCard(
                    child: Text(
                      'Nenhuma comissão ainda. Ao concluir um serviço, o valor aparece aqui.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
                    ),
                  )
                else
                  for (final c in items) ...[
                    ClxCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.descricao.isNotEmpty
                                      ? c.descricao
                                      : 'Comissão de OS',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              ClxChip(
                                label: c.status.label,
                                color: c.status == ComissaoStatus.paga
                                    ? clx.success
                                    : clx.warning,
                                dense: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.data != null && c.data!.isNotEmpty
                                ? formatDate(c.data!)
                                : '—',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: clx.ink2),
                          ),
                          const SizedBox(height: ClxSpace.x2),
                          Text(
                            formatCurrency(c.valorComissao),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: clx.primary,
                                ),
                          ),
                          Text(
                            'Serviço ${formatCurrency(c.valorOs)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: clx.ink2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x2),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}
