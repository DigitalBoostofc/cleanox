/// resumo_screen.dart — Dashboard do profissional: atendimentos + deslocamento.
///
/// Filtros: Hoje / Semana (atual) / Mês (atual). Cards (R4). Fintech Clean, BRT.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/pb/pb_filters.dart';
import 'resumo_metrics.dart';

/// Período selecionado no dashboard.
final resumoPeriodoProvider = StateProvider.autoDispose<ResumoPeriodo>(
  (ref) => ResumoPeriodo.hoje,
);

/// Indicadores do período. OS via listDoProfissional(janela) + km da coleção
/// `prof_deslocamento_dia` (soma de `km_planejado` nos dias do filtro).
final _resumoProvider = FutureProvider.autoDispose<ProfResumo>((ref) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return const ProfResumo.vazio();

  final periodo = ref.watch(resumoPeriodoProvider);
  final janela = periodo.bounds();
  final keys = periodo.diaKeys();

  final ordens = await ref
      .watch(ordensRepositoryProvider)
      .listDoProfissional(me.id, janela: janela);

  var km = 0.0;
  try {
    final pb = ref.watch(pocketBaseProvider);
    final filter =
        'profissional = ${pbStringLiteral(me.id)} '
        '&& dia >= ${pbStringLiteral(keys.startDia)} '
        '&& dia < ${pbStringLiteral(keys.endDiaExcl)}';
    final res = await pb
        .collection('prof_deslocamento_dia')
        .getList(page: 1, perPage: 50, filter: filter);
    for (final rec in res.items) {
      final v = rec.get<dynamic>('km_planejado');
      if (v is num) {
        km += v.toDouble();
      } else if (v is String) {
        km += double.tryParse(v) ?? 0;
      }
    }
  } catch (_) {
    /* sem km — coleção vazia ou sem permissão */
  }

  return buildResumo(
    ordens: ordens,
    kmDeslocamento: km,
    periodo: periodo,
  );
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
    final periodo = ref.watch(resumoPeriodoProvider);
    final asyncResumo = ref.watch(_resumoProvider);

    return Scaffold(
      backgroundColor: clx.bg2,
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(ClxSpace.x4),
          children: [
            Text(
              'Dashboard',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: clx.ink,
              ),
            ),
            const SizedBox(height: ClxSpace.x1),
            Text(
              'Números do período selecionado (horário de Brasília).',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: clx.ink3),
            ),
            const SizedBox(height: ClxSpace.x3),
            _PeriodoChips(
              value: periodo,
              onChanged: (p) {
                ref.read(resumoPeriodoProvider.notifier).state = p;
              },
            ),
            const SizedBox(height: ClxSpace.x4),
            asyncResumo.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(ClxSpace.x8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorBanner(
                message: e is ClientException
                    ? 'Não foi possível carregar o dashboard.'
                    : 'Não foi possível carregar o dashboard.',
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

class _PeriodoChips extends StatelessWidget {
  const _PeriodoChips({required this.value, required this.onChanged});
  final ResumoPeriodo value;
  final ValueChanged<ResumoPeriodo> onChanged;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: clx.bg,
        borderRadius: ClxRadii.rLg,
        border: Border.all(color: clx.line),
      ),
      child: Row(
        children: [
          for (final p in ResumoPeriodo.values) ...[
            if (p != ResumoPeriodo.values.first) const SizedBox(width: 4),
            Expanded(
              child: Material(
                color: value == p ? clx.primary : Colors.transparent,
                borderRadius: ClxRadii.rMd,
                child: InkWell(
                  onTap: () => onChanged(p),
                  borderRadius: ClxRadii.rMd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      p.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: value == p ? Colors.white : clx.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
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
    final kmStr = resumo.kmDeslocamento <= 0
        ? '—'
        : '${resumo.kmDeslocamento.toStringAsFixed(1).replaceAll('.', ',')} km';

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
                  icon: Icons.cancel_outlined,
                  label: 'Canceladas',
                  value: '${resumo.canceladas}',
                  color: clx.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClxSpace.x3),
          _MetricCard(
            icon: Icons.check_circle_rounded,
            label: 'Realizados',
            value: '${resumo.realizados}',
            color: clx.statusConcluida,
            expand: true,
          ),
          const SizedBox(height: ClxSpace.x5),
          Text(
            'Deslocamento',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ClxSpace.x3),
          ClxCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: clx.primary.withValues(alpha: 0.14),
                    borderRadius: ClxRadii.rMd,
                  ),
                  child: Icon(Icons.route_rounded, color: clx.primary, size: 22),
                ),
                const SizedBox(width: ClxSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kmStr,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: clx.ink,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resumo.kmDeslocamento <= 0
                            ? 'Sem km no período. Toque Em deslocamento '
                                  'nas OS para registrar a partida do dia.'
                            : 'Total planejado no período '
                                  '(partida → serviços → volta).',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: clx.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool expand;

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
