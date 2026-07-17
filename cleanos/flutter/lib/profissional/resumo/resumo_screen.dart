/// resumo_screen.dart — Aba "Resumo" do profissional: painel de indicadores.
///
/// Cinco números num relance: atendimentos agendados / realizados, valores a
/// receber / recebidos e a avaliação média. Todos derivados das OS do próprio
/// profissional (`listDoProfissional`) e das comissões congeladas — cálculo puro
/// em [buildResumo]. Sem tabela: cards (R4). Fintech Clean, PT-BR, BRT.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../painel/data/painel_providers.dart';
import 'resumo_metrics.dart';

/// Indicadores do profissional logado. Revalida a sessão no refresh (F-227):
/// sem `authRefresh` o app segue com a comissão que valia no login.
final _resumoProvider = FutureProvider.autoDispose<ProfResumo>((ref) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return const ProfResumo.vazio();

  final ordens = await ref
      .watch(ordensRepositoryProvider)
      .listDoProfissional(me.id);
  final comissoes = await ref
      .watch(comissaoRepositoryProvider)
      .listComissoes(profissionalId: me.id);

  return buildResumo(ordens: ordens, comissoes: comissoes);
});

Future<void> _refresh(WidgetRef ref) async {
  await ref.read(authServiceProvider).refresh();
  ref.invalidate(_resumoProvider);
  await ref.read(_resumoProvider.future);
}

class ProfResumoScreen extends ConsumerWidget {
  const ProfResumoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final asyncResumo = ref.watch(_resumoProvider);

    return Scaffold(
      backgroundColor: clx.bg2,
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(ClxSpace.x4),
          children: [
            asyncResumo.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(ClxSpace.x8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorBanner(
                message: 'Não foi possível carregar seus indicadores.',
                onRetry: () => ref.invalidate(_resumoProvider),
              ),
              data: (r) => _ResumoBody(resumo: r),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumoBody extends StatelessWidget {
  const _ResumoBody({required this.resumo});
  final ProfResumo resumo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxFadeSlide(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Atendimentos',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ClxSpace.x3),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.event_note_rounded,
                  label: 'Agendados',
                  value: '${resumo.agendados}',
                  color: clx.statusAgendada,
                ),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: _MetricCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Realizados',
                  value: '${resumo.realizados}',
                  color: clx.statusConcluida,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x5),
          Text(
            'Comissões',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ClxSpace.x3),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.schedule_rounded,
                  label: 'A receber',
                  value: formatCurrency(resumo.aReceber),
                  color: clx.warning,
                ),
              ),
              const SizedBox(width: ClxSpace.x3),
              Expanded(
                child: _MetricCard(
                  icon: Icons.payments_rounded,
                  label: 'Recebidos',
                  value: formatCurrency(resumo.recebidos),
                  color: clx.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x5),
          Text(
            'Avaliação',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ClxSpace.x3),
          _AvaliacaoCard(
            media: resumo.avaliacaoMedia,
            total: resumo.totalAvaliacoes,
          ),
          const SizedBox(height: ClxSpace.x8),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: ClxRadii.rMd,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: ClxSpace.x3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: clx.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: clx.ink2),
          ),
        ],
      ),
    );
  }
}

class _AvaliacaoCard extends StatelessWidget {
  const _AvaliacaoCard({required this.media, required this.total});
  final double? media;
  final int total;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    if (media == null) {
      return ClxCard(
        child: Row(
          children: [
            Icon(Icons.star_outline_rounded, color: clx.ink3, size: 28),
            const SizedBox(width: ClxSpace.x3),
            Expanded(
              child: Text(
                'Sem avaliações ainda. Elas aparecem aqui quando o cliente avalia um serviço concluído.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
              ),
            ),
          ],
        ),
      );
    }

    final mediaStr = media!.toStringAsFixed(1).replaceAll('.', ',');
    return ClxCard(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mediaStr,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: clx.ink,
                ),
              ),
              StarRating(value: media!, size: 18),
            ],
          ),
          const SizedBox(width: ClxSpace.x4),
          Expanded(
            child: Text(
              total == 1
                  ? 'Média de 1 avaliação'
                  : 'Média de $total avaliações',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: clx.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
