/// prof_financeiro_screen.dart — Financeiro do profissional (comissões).
///
/// 1) Estimativa de ganho no período (dia / semana / 15 dias / mês) a partir
///    das OS já geradas para o profissional.
/// 2) Extrato de comissões geradas ao concluir OS (pendente / paga).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import '../../painel/data/painel_providers.dart';
import 'prof_estimativa.dart';

final _profComissoesProvider = FutureProvider.autoDispose<List<ProfComissao>>((
  ref,
) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return const [];
  return ref
      .watch(comissaoRepositoryProvider)
      .listComissoes(profissionalId: me.id);
});

final _estimativaPeriodoProvider = StateProvider.autoDispose<EstimativaPeriodo>(
  (ref) => EstimativaPeriodo.semana,
);

final _profOsPeriodoProvider =
    FutureProvider.autoDispose<List<OrdemServico>>((ref) async {
      final me = ref.watch(currentUserProvider);
      if (me == null) return const [];
      final periodo = ref.watch(_estimativaPeriodoProvider);
      final range = periodo.toRange();
      return ref
          .watch(ordensRepositoryProvider)
          .listDoProfissional(me.id, janela: range);
    });

class ProfFinanceiroScreen extends ConsumerWidget {
  const ProfFinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final me = ref.watch(currentUserProvider);
    final asyncCom = ref.watch(_profComissoesProvider);
    final asyncOs = ref.watch(_profOsPeriodoProvider);
    final periodo = ref.watch(_estimativaPeriodoProvider);

    return Scaffold(
      backgroundColor: clx.bg2,
      body: me == null || !me.hasComissaoAtiva
          ? const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Sem comissão configurada',
              message:
                  'Quando o admin definir sua comissão, o extrato e a estimativa aparecem aqui.',
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_profComissoesProvider);
                ref.invalidate(_profOsPeriodoProvider);
              },
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ClxFadeSlide(
                    child: _ComissaoHero(
                      me: me,
                      onRefresh: () {
                        ref.invalidate(_profComissoesProvider);
                        ref.invalidate(_profOsPeriodoProvider);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(ClxSpace.x4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClxFadeSlide(
                          delay: const Duration(milliseconds: 60),
                          child: _EstimativaSection(
                            me: me,
                            periodo: periodo,
                            asyncOs: asyncOs,
                            onPeriodo: (p) => ref
                                .read(_estimativaPeriodoProvider.notifier)
                                .state = p,
                          ),
                        ),
                        const SizedBox(height: ClxSpace.x5),
                        Text(
                          'Extrato de comissões',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: ClxSpace.x1),
                        Text(
                          'Valores gerados ao concluir o serviço.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: clx.ink2),
                        ),
                        const SizedBox(height: ClxSpace.x3),
                        asyncCom.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(ClxSpace.x6),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => ErrorBanner(
                            message: 'Não foi possível carregar o extrato.',
                            onRetry: () =>
                                ref.invalidate(_profComissoesProvider),
                          ),
                          data: (items) =>
                              _ExtratoSection(items: items, clx: clx),
                        ),
                        const SizedBox(height: ClxSpace.x8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ComissaoHero extends StatelessWidget {
  const _ComissaoHero({required this.me, required this.onRefresh});
  final User me;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            clx.accent,
            Color.lerp(clx.accent, clx.primary, 0.55)!,
            clx.primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: clx.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MINHA CARTEIRA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    me.comissaoResumo,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Estimativa + extrato das suas comissões',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Atualizar',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimativaSection extends StatelessWidget {
  const _EstimativaSection({
    required this.me,
    required this.periodo,
    required this.asyncOs,
    required this.onPeriodo,
  });

  final User me;
  final EstimativaPeriodo periodo;
  final AsyncValue<List<OrdemServico>> asyncOs;
  final ValueChanged<EstimativaPeriodo> onPeriodo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Estimativa de ganho',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: ClxSpace.x1),
        Text(
          'Com base nas OS já geradas para você no período (sem canceladas).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: clx.ink2),
        ),
        const SizedBox(height: ClxSpace.x3),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in EstimativaPeriodo.values) ...[
                Padding(
                  padding: const EdgeInsets.only(right: ClxSpace.x2),
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: periodo == p,
                    onSelected: (_) => onPeriodo(p),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ClxSpace.x3),
        asyncOs.when(
          loading: () => const ClxCard(
            child: Padding(
              padding: EdgeInsets.all(ClxSpace.x4),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => ErrorBanner(
            message: 'Não foi possível carregar as OS do período.',
          ),
          data: (ordens) {
            final est = buildEstimativa(
              me: me,
              ordens: ordens,
              periodo: periodo,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClxCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perspectiva · ${periodo.label.toLowerCase()}',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: clx.ink2),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: est.totalEstimado),
                        duration: ClxMotion.emphasizedDuration,
                        curve: ClxMotion.emphasized,
                        builder: (context, v, _) => Text(
                          formatCurrency(v),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: clx.primary,
                              ),
                        ),
                      ),
                      const SizedBox(height: ClxSpace.x2),
                      Text(
                        '${est.qtdOs} OS · '
                        '${est.qtdAbertas} abertas · '
                        '${est.qtdConcluidas} concluídas',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: clx.ink2),
                      ),
                      const SizedBox(height: ClxSpace.x3),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStat(
                              label: 'Em aberto',
                              value: formatCurrency(est.totalAberto),
                              color: clx.warning,
                            ),
                          ),
                          const SizedBox(width: ClxSpace.x2),
                          Expanded(
                            child: _MiniStat(
                              label: 'Já concluído',
                              value: formatCurrency(est.totalConcluido),
                              color: clx.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (est.linhas.isEmpty) ...[
                  const SizedBox(height: ClxSpace.x3),
                  ClxCard(
                    child: Text(
                      'Nenhuma OS neste período. Quando o admin gerar serviços para você, a estimativa aparece aqui.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: ClxSpace.x3),
                  Text(
                    'OS no período',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x2),
                  for (final l in est.linhas) ...[
                    _OsEstimativaTile(linha: l),
                    const SizedBox(height: ClxSpace.x2),
                  ],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.all(ClxSpace.x3),
      decoration: BoxDecoration(
        color: clx.bg3,
        borderRadius: ClxRadii.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: clx.ink2),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OsEstimativaTile extends StatelessWidget {
  const _OsEstimativaTile({required this.linha});
  final EstimativaOsLinha linha;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final os = linha.os;
    final quando = os.dataHora.isNotEmpty
        ? formatDateTime(os.dataHora)
        : '—';
    final titulo = [
      if ((os.tipoServicoNome ?? '').isNotEmpty) os.tipoServicoNome!,
      if (os.nomeCurto.isNotEmpty) os.nomeCurto,
    ].join(' · ');
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo.isNotEmpty ? titulo : 'OS',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              ClxChip(
                label: os.status.label,
                color: linha.isConcluida ? clx.success : clx.primary,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quando + (os.bairro.isNotEmpty ? ' · ${os.bairro}' : ''),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: clx.ink2),
          ),
          const SizedBox(height: ClxSpace.x2),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Serviço ${formatCurrency(linha.base)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: clx.ink2),
                ),
              ),
              Text(
                formatCurrency(linha.comissaoEstimada),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: clx.primary,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              linha.isConcluida ? 'comissao (realizada)' : 'estimativa',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: clx.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtratoSection extends StatelessWidget {
  const _ExtratoSection({required this.items, required this.clx});

  final List<ProfComissao> items;
  final CleanoxColors clx;

  @override
  Widget build(BuildContext context) {
    final pendente = items
        .where((c) => c.status == ComissaoStatus.pendente)
        .fold<double>(0, (s, c) => s + c.valorComissao);
    final paga = items
        .where((c) => c.status == ComissaoStatus.paga)
        .fold<double>(0, (s, c) => s + c.valorComissao);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ClxCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A receber',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: clx.ink2),
                    ),
                    Text(
                      formatCurrency(pendente),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: clx.ink2),
                    ),
                    Text(
                      formatCurrency(paga),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
        const SizedBox(height: ClxSpace.x3),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: clx.ink2),
                  ),
                  const SizedBox(height: ClxSpace.x2),
                  Text(
                    formatCurrency(c.valorComissao),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: clx.primary,
                    ),
                  ),
                  Text(
                    'Serviço ${formatCurrency(c.valorOs)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: clx.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ClxSpace.x2),
          ],
      ],
    );
  }
}
