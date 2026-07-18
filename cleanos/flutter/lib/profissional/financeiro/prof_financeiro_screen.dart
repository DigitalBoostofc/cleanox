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
import '../../core/models/ordem_servico.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import '../../painel/data/painel_providers.dart';
import 'prof_estimativa.dart';
import 'prof_pagamento.dart';

final _profComissoesProvider = FutureProvider.autoDispose<List<ProfComissao>>((
  ref,
) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return const [];
  return ref
      .watch(comissaoRepositoryProvider)
      .listComissoes(profissionalId: me.id);
});

/// A receber + próximo pagamento (ciclo configurado no perfil).
final _pagamentoSnapshotProvider =
    FutureProvider.autoDispose<ProfPagamentoSnapshot>((ref) async {
      final me = ref.watch(currentUserProvider);
      if (me == null) {
        return const ProfPagamentoSnapshot(aReceber: 0, qtdPendentes: 0);
      }
      final list = await ref.watch(_profComissoesProvider.future);
      return buildPagamentoSnapshot(me: me, comissoes: list);
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

/// Carteira do período: OS + comissões CONGELADAS juntas.
///
/// As duas fontes são resolvidas ANTES de montar a tela de propósito (F-226):
/// se as OS chegassem sozinhas, uma OS já concluída seria pintada com a
/// estimativa da config atual até o extrato carregar — que é exatamente o
/// valor errado que o profissional não pode ver.
final _carteiraProvider = FutureProvider.autoDispose<EstimativaGanho>((
  ref,
) async {
  final me = ref.watch(currentUserProvider);
  final periodo = ref.watch(_estimativaPeriodoProvider);
  if (me == null) return EstimativaGanho.vazia(periodo);

  final ordens = await ref.watch(_profOsPeriodoProvider.future);
  final comissoes = await ref.watch(_profComissoesProvider.future);

  return buildEstimativa(
    me: me,
    ordens: ordens,
    comissoes: comissoes,
    periodo: periodo,
  );
});

/// Atualiza a tela. Revalida a SESSÃO antes das listas (F-227): sem
/// `authRefresh` o app segue com a comissão que valia no login, e o botão de
/// atualizar só recarregaria OS com a config velha.
Future<void> _refreshCarteira(WidgetRef ref) async {
  await ref.read(authServiceProvider).refresh();
  ref.invalidate(_profComissoesProvider);
  ref.invalidate(_profOsPeriodoProvider);
  ref.invalidate(_pagamentoSnapshotProvider);
  await Future.wait([
    ref.read(_carteiraProvider.future),
    ref.read(_pagamentoSnapshotProvider.future),
  ]);
}

class ProfFinanceiroScreen extends ConsumerWidget {
  const ProfFinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final me = ref.watch(currentUserProvider);
    final asyncCarteira = ref.watch(_carteiraProvider);
    final asyncPagamento = ref.watch(_pagamentoSnapshotProvider);
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
              onRefresh: () => _refreshCarteira(ref),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ClxFadeSlide(
                    child: _ComissaoHero(
                      me: me,
                      onRefresh: () => _refreshCarteira(ref),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(ClxSpace.x4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClxFadeSlide(
                          delay: const Duration(milliseconds: 40),
                          child: asyncPagamento.when(
                            loading: () => const ClxCard(
                              child: Padding(
                                padding: EdgeInsets.all(ClxSpace.x4),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (snap) => _ProximoPagamentoCard(
                              me: me,
                              snap: snap,
                            ),
                          ),
                        ),
                        const SizedBox(height: ClxSpace.x5),
                        ClxFadeSlide(
                          delay: const Duration(milliseconds: 80),
                          child: _EstimativaSection(
                            periodo: periodo,
                            asyncCarteira: asyncCarteira,
                            onPeriodo: (p) => ref
                                .read(_estimativaPeriodoProvider.notifier)
                                .state = p,
                          ),
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

/// Card principal: quanto tem a receber e quando é o próximo repasse.
class _ProximoPagamentoCard extends StatelessWidget {
  const _ProximoPagamentoCard({required this.me, required this.snap});

  final User me;
  final ProfPagamentoSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final dataLabel = snap.proximoPagamento != null
        ? formatProximoPagamento(snap.proximoPagamento!)
        : '—';
    final ciclo = snap.frequencia?.label ?? 'não configurado';

    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A RECEBER',
            style: tt.labelSmall?.copyWith(
              color: clx.ink3,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatCurrency(snap.aReceber),
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: clx.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            snap.qtdPendentes == 0
                ? 'Nenhuma comissão pendente'
                : '${snap.qtdPendentes} lançamento${snap.qtdPendentes == 1 ? '' : 's'} pendente${snap.qtdPendentes == 1 ? '' : 's'}',
            style: tt.bodySmall?.copyWith(color: clx.ink2),
          ),
          const SizedBox(height: ClxSpace.x3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ClxSpace.x3),
            decoration: BoxDecoration(
              color: clx.bg3,
              borderRadius: ClxRadii.rMd,
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, color: clx.ink2, size: 22),
                const SizedBox(width: ClxSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Próximo pagamento',
                        style: tt.labelMedium?.copyWith(
                          color: clx.ink2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        snap.temCiclo ? dataLabel : 'Defina o ciclo no painel',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: clx.ink,
                        ),
                      ),
                      Text(
                        'Ciclo: $ciclo · ${me.comissaoResumo}',
                        style: tt.bodySmall?.copyWith(color: clx.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
                    me.pagamentoFrequencia != null
                        ? 'Repasse ${me.pagamentoFrequencia!.label.toLowerCase()} · ${me.comissaoResumo}'
                        : 'Estimativa + extrato das suas comissões',
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
    required this.periodo,
    required this.asyncCarteira,
    required this.onPeriodo,
  });

  final EstimativaPeriodo periodo;
  final AsyncValue<EstimativaGanho> asyncCarteira;
  final ValueChanged<EstimativaPeriodo> onPeriodo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ganho no período',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: ClxSpace.x1),
        Text(
          'Serviço concluído entra pelo valor fechado na hora. '
          'Serviço em aberto é estimativa e ainda pode mudar.',
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
        asyncCarteira.when(
          loading: () => const ClxCard(
            child: Padding(
              padding: EdgeInsets.all(ClxSpace.x4),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => ErrorBanner(
            message: 'Não foi possível carregar as OS do período.',
          ),
          data: (est) {
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
                        tween: Tween(begin: 0, end: est.totalGeral),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MiniStat(
                              label: 'Estimativa',
                              value: formatCurrency(est.totalPrevisto),
                              color: clx.warning,
                            ),
                          ),
                          const SizedBox(width: ClxSpace.x2),
                          Expanded(
                            child: _MiniStat(
                              label: 'Já garantido',
                              value: formatCurrency(est.totalRealizado),
                              color: clx.success,
                            ),
                          ),
                          const SizedBox(width: ClxSpace.x2),
                          Expanded(
                            child: _MiniStat(
                              label: 'Pago',
                              value: formatCurrency(est.totalPago),
                              color: clx.primary,
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
                color: clx.statusColor(os.status),
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
                formatCurrency(linha.valorComissao),
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
              // F-226: só chama de valor final o que está CONGELADO no banco.
              linha.isCongelada
                  ? 'valor final (não muda mais)'
                  : linha.isConcluidaSemComissao
                  ? 'estimativa · comissão ainda não gerada'
                  : 'estimativa',
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
