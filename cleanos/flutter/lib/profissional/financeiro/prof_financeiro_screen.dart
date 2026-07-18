/// prof_financeiro_screen.dart — Carteira do profissional.
///
/// Card unificado: A receber (pendente) + Perspectiva (OS abertas até o
/// próximo pagamento) + Meus pagamentos (histórico agrupado por data).
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

/// OS abertas do profissional no ciclo atual (até o próximo pagamento).
final _profOsCicloProvider =
    FutureProvider.autoDispose<List<OrdemServico>>((ref) async {
      final me = ref.watch(currentUserProvider);
      if (me == null) return const [];
      final range = cicloAbertoRange(me);
      if (range == null) {
        // Sem ciclo: lista abertas futuras (próximos 60 dias) como fallback.
        final bounds = getBrtDayBounds();
        return ref.watch(ordensRepositoryProvider).listDoProfissional(
          me.id,
          janela: DateRange(
            bounds.todayStart,
            _pbPlusDays(bounds.todayStart, 60),
          ),
        );
      }
      return ref
          .watch(ordensRepositoryProvider)
          .listDoProfissional(me.id, janela: range);
    });

String _pbPlusDays(String startPb, int days) {
  final dt = parsePbUtc(startPb);
  if (dt == null) return startPb;
  final n = dt.add(Duration(days: days));
  String p(int x) => x.toString().padLeft(2, '0');
  return '${n.year.toString().padLeft(4, '0')}-${p(n.month)}-${p(n.day)} '
      '${p(n.hour)}:${p(n.minute)}:${p(n.second)}';
}

final _pagamentoSnapshotProvider =
    FutureProvider.autoDispose<ProfPagamentoSnapshot>((ref) async {
      final me = ref.watch(currentUserProvider);
      if (me == null) {
        return const ProfPagamentoSnapshot(
          aReceber: 0,
          qtdPendentes: 0,
          perspectiva: 0,
          qtdAbertasCiclo: 0,
          pendentes: [],
          historico: [],
        );
      }
      final comissoes = await ref.watch(_profComissoesProvider.future);
      final abertas = await ref.watch(_profOsCicloProvider.future);
      return buildPagamentoSnapshot(
        me: me,
        comissoes: comissoes,
        ordensAbertasCiclo: abertas,
      );
    });

Future<void> _refreshCarteira(WidgetRef ref) async {
  await ref.read(authServiceProvider).refresh();
  ref.invalidate(_profComissoesProvider);
  ref.invalidate(_profOsCicloProvider);
  await ref.read(_pagamentoSnapshotProvider.future);
}

class ProfFinanceiroScreen extends ConsumerWidget {
  const ProfFinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final me = ref.watch(currentUserProvider);
    final async = ref.watch(_pagamentoSnapshotProvider);

    return Scaffold(
      backgroundColor: clx.bg2,
      body: me == null || !me.hasComissaoAtiva
          ? const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Sem comissão configurada',
              message:
                  'Quando o admin definir sua comissão e o ciclo de pagamento, '
                  'a carteira aparece aqui.',
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
                    child: async.when(
                      loading: () => const ClxCard(
                        child: Padding(
                          padding: EdgeInsets.all(ClxSpace.x8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (_, __) => ErrorBanner(
                        message: 'Não foi possível carregar a carteira.',
                        onRetry: () => _refreshCarteira(ref),
                      ),
                      data: (snap) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClxFadeSlide(
                            delay: const Duration(milliseconds: 40),
                            child: _CarteiraCicloCard(me: me, snap: snap),
                          ),
                          const SizedBox(height: ClxSpace.x5),
                          ClxFadeSlide(
                            delay: const Duration(milliseconds: 80),
                            child: _MeusPagamentosSection(snap: snap),
                          ),
                          const SizedBox(height: ClxSpace.x8),
                        ],
                      ),
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
                    cicloPagamentoLabel(me),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
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

/// Card unificado: A receber (clicável → detalhe) + Perspectiva.
class _CarteiraCicloCard extends StatelessWidget {
  const _CarteiraCicloCard({required this.me, required this.snap});

  final User me;
  final ProfPagamentoSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final dataLabel = snap.proximoPagamento != null
        ? formatProximoPagamento(snap.proximoPagamento!)
        : '—';

    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Só o resumo — toque abre o menu flutuante com detalhes por data.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: ClxRadii.rMd,
              onTap: snap.pendentes.isEmpty
                  ? null
                  : () => _openAReceberDetalhe(context, snap),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                          Text(
                            snap.qtdPendentes == 0
                                ? 'Nenhuma comissão pendente'
                                : '${snap.qtdPendentes} serviço${snap.qtdPendentes == 1 ? '' : 's'} '
                                    'concluído${snap.qtdPendentes == 1 ? '' : 's'} aguardando repasse'
                                    ' · toque para ver',
                            style: tt.bodySmall?.copyWith(color: clx.ink2),
                          ),
                        ],
                      ),
                    ),
                    if (snap.pendentes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: clx.ink3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          // Perspectiva no mesmo card (só resumo)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ClxSpace.x3),
            decoration: BoxDecoration(
              color: clx.bg3,
              borderRadius: ClxRadii.rMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERSPECTIVA ATÉ O PRÓXIMO PAGAMENTO',
                  style: tt.labelSmall?.copyWith(
                    color: clx.ink3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(snap.perspectiva),
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: clx.warning,
                  ),
                ),
                Text(
                  snap.qtdAbertasCiclo == 0
                      ? 'Sem serviços em aberto no ciclo'
                      : '${snap.qtdAbertasCiclo} em aberto até $dataLabel · estimativa',
                  style: tt.bodySmall?.copyWith(color: clx.ink2),
                ),
                const SizedBox(height: ClxSpace.x2),
                Row(
                  children: [
                    Icon(Icons.event_available_rounded, size: 18, color: clx.ink2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        snap.temCiclo
                            ? 'Próximo pagamento · $dataLabel'
                            : 'Configure o ciclo no painel (admin)',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: clx.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${snap.cicloLabel} · ${me.comissaoResumo}',
                  style: tt.bodySmall?.copyWith(color: clx.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Agrupa pendentes por data de execução (campo `data` da comissão = dia BRT da OS).
List<({String dayKey, String label, List<ProfComissao> itens, double total})>
    groupPendentesPorData(List<ProfComissao> pendentes) {
  final byDay = <String, List<ProfComissao>>{};
  for (final c in pendentes) {
    final raw = (c.data ?? '').trim();
    final key = raw.length >= 10 ? raw.substring(0, 10) : (raw.isEmpty ? '—' : raw);
    byDay.putIfAbsent(key, () => []).add(c);
  }
  final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a)); // mais recente primeiro
  return [
    for (final k in keys)
      (
        dayKey: k,
        label: _labelDataExecucao(k),
        itens: byDay[k]!,
        total: byDay[k]!
                .fold<int>(0, (s, c) => s + (c.valorComissao * 100).round()) /
            100.0,
      ),
  ];
}

String _labelDataExecucao(String ymd) {
  if (ymd.length < 10 || ymd == '—') return 'Sem data';
  // YYYY-MM-DD → dd/MM/yyyy
  return '${ymd.substring(8, 10)}/${ymd.substring(5, 7)}/${ymd.substring(0, 4)}';
}

void _openAReceberDetalhe(BuildContext context, ProfPagamentoSnapshot snap) {
  final clx = context.clx;
  final groups = groupPendentesPorData(snap.pendentes);

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, _) {
      final size = MediaQuery.sizeOf(ctx);
      final maxW = size.width < 640 ? size.width - 32 : 420.0;
      final maxH = size.height * 0.78;
      return SafeArea(
        child: Center(
          child: Material(
            color: clx.bg,
            elevation: 12,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'A receber',
                                style: Theme.of(ctx).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${formatCurrency(snap.aReceber)} · '
                                '${snap.qtdPendentes} serviço${snap.qtdPendentes == 1 ? '' : 's'}',
                                style: Theme.of(ctx).textTheme.bodySmall
                                    ?.copyWith(color: clx.ink2),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.of(ctx).maybePop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: clx.line),
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (_, i) {
                        final g = groups[i];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i == groups.length - 1 ? 0 : ClxSpace.x4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_rounded,
                                    size: 16,
                                    color: clx.ink3,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      g.label,
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: clx.ink2,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(g.total),
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: clx.primary,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (final c in g.itens)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c.descricao.isNotEmpty
                                              ? c.descricao
                                              : 'Serviço',
                                          style: Theme.of(ctx)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        formatCurrency(c.valorComissao),
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: clx.primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _MeusPagamentosSection extends StatelessWidget {
  const _MeusPagamentosSection({required this.snap});
  final ProfPagamentoSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Meus pagamentos',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: ClxSpace.x1),
        Text(
          'Toque para ver quais serviços entraram em cada repasse.',
          style: tt.bodySmall?.copyWith(color: clx.ink2),
        ),
        const SizedBox(height: ClxSpace.x3),
        if (snap.historico.isEmpty)
          ClxCard(
            child: Text(
              'Nenhum pagamento registrado ainda. Quando o admin marcar '
              'suas comissões como pagas, elas aparecem aqui.',
              style: tt.bodyMedium?.copyWith(color: clx.ink2),
            ),
          )
        else
          for (final h in snap.historico) ...[
            _PagamentoTile(item: h),
            const SizedBox(height: ClxSpace.x2),
          ],
      ],
    );
  }
}

class _PagamentoTile extends StatelessWidget {
  const _PagamentoTile({required this.item});
  final PagamentoHistorico item;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    // data pode ser YYYY-MM-DD
    final label = item.data.length >= 10
        ? '${item.data.substring(8, 10)}/${item.data.substring(5, 7)}/${item.data.substring(0, 4)}'
        : item.data;

    return Material(
      color: clx.bg,
      borderRadius: ClxRadii.rLg,
      child: InkWell(
        borderRadius: ClxRadii.rLg,
        onTap: () => _openDetail(context),
        child: Container(
          padding: const EdgeInsets.all(ClxSpace.x3),
          decoration: BoxDecoration(
            borderRadius: ClxRadii.rLg,
            border: Border.all(color: clx.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: clx.successBg,
                  borderRadius: ClxRadii.rMd,
                ),
                child: Icon(Icons.payments_rounded, color: clx.success),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${item.qtdOs} serviço${item.qtdOs == 1 ? '' : 's'} pago${item.qtdOs == 1 ? '' : 's'}',
                      style: tt.bodySmall?.copyWith(color: clx.ink2),
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrency(item.total),
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: clx.success,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: clx.ink3),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    final clx = context.clx;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: clx.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final label = item.data.length >= 10
            ? '${item.data.substring(8, 10)}/${item.data.substring(5, 7)}/${item.data.substring(0, 4)}'
            : item.data;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                Text(
                  'Pagamento · $label',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${item.qtdOs} OS · total ${formatCurrency(item.total)}',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: clx.ink2,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: item.itens.length,
                    separatorBuilder: (_, __) => Divider(color: clx.line),
                    itemBuilder: (_, i) {
                      final c = item.itens[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          c.descricao.isNotEmpty ? c.descricao : 'Serviço',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Comissão ${c.tipoAplicado.label}',
                          style: TextStyle(color: clx.ink3, fontSize: 12),
                        ),
                        trailing: Text(
                          formatCurrency(c.valorComissao),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: clx.success,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


