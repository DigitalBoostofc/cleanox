/// dashboard_screen.dart — Home do Painel (espelha `Dashboard.tsx`).
///
/// KPIs do dia + próximos atendimentos + acesso rápido. Estados vazio/carregando/
/// erro via `AsyncValue`. A lista de atendimentos é VIRTUALIZADA (`SliverList`)
/// para não renderizar tudo de uma vez (mitigação Flutter Web §4). Layout
/// desktop-first, largura já limitada pelo shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/ordem_servico.dart';
import '../shell/painel_nav.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardDataProvider);
    return async.when(
      loading: () => const _DashboardLoading(),
      error: (err, _) =>
          _DashboardError(onRetry: () => ref.invalidate(dashboardDataProvider)),
      data: (data) => _DashboardBody(data: data),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Spinner(size: 22),
          const SizedBox(width: ClxSpace.x3),
          Text('Carregando…', style: TextStyle(color: clx.ink2)),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ClxSpace.x6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ErrorBanner(
            message: 'Não foi possível carregar o dashboard. Tente novamente.',
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  void _go(BuildContext context, PainelSection section) =>
      context.go(painelPath(section));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final upcoming = data.upcoming;

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(dashboardDataProvider.future),
      color: clx.primary,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x6,
              ClxSpace.x6,
              ClxSpace.x6,
              ClxSpace.x2,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'Hoje',
                    trailing: Text(
                      _longDatePtBr(),
                      style: tt.bodyMedium?.copyWith(color: clx.ink3),
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x3),
                  _KpiGrid(kpis: data.kpis),
                  const SizedBox(height: ClxSpace.x6),
                  _SectionHeader(
                    title: 'Próximos atendimentos',
                    trailing: ClxButton(
                      label: 'Ver todos',
                      variant: ClxButtonVariant.ghost,
                      onPressed: () => _go(context, PainelSection.ordens),
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x3),
                  Text(
                    'Ordens abertas — ${upcoming.length} '
                    'registro${upcoming.length == 1 ? '' : 's'}',
                    style: tt.bodyMedium?.copyWith(
                      color: clx.ink3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x2),
                ],
              ),
            ),
          ),

          // Lista VIRTUALIZADA de atendimentos (ou estado vazio inline).
          if (upcoming.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ClxSpace.x6),
                child: EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nenhum atendimento pendente',
                  message:
                      'Todas as ordens de serviço estão concluídas ou canceladas.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x6),
              sliver: SliverList.builder(
                itemCount: upcoming.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: ClxSpace.x2),
                  child: _UpcomingCard(
                    os: upcoming[i],
                    onTap: () => _go(context, PainelSection.ordens),
                  ),
                ),
              ),
            ),

          // Acesso rápido.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x6,
              ClxSpace.x6,
              ClxSpace.x6,
              ClxSpace.x10,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Acesso rápido'),
                  const SizedBox(height: ClxSpace.x3),
                  Wrap(
                    spacing: ClxSpace.x3,
                    runSpacing: ClxSpace.x3,
                    children: [
                      ClxButton(
                        label: 'Nova OS',
                        icon: Icons.add_rounded,
                        onPressed: () => _go(context, PainelSection.ordens),
                      ),
                      ClxButton(
                        label: 'Novo Cliente',
                        icon: Icons.add_rounded,
                        variant: ClxButtonVariant.ghost,
                        onPressed: () => _go(context, PainelSection.clientes),
                      ),
                      ClxButton(
                        label: 'Ver Agenda',
                        variant: ClxButtonVariant.ghost,
                        onPressed: () => _go(context, PainelSection.agenda),
                      ),
                      ClxButton(
                        label: 'Financeiro',
                        variant: ClxButtonVariant.ghost,
                        onPressed: () => _go(context, PainelSection.financeiro),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabeçalho de seção: título forte + trailing opcional (data/botão).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Grade de KPIs responsiva (2 → 3 → 5 colunas conforme largura).
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final DashboardKpis kpis;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cards = <Widget>[
      _KpiCard(label: 'Agendadas', value: '${kpis.agendada}', color: clx.info),
      _KpiCard(
        label: 'Atribuídas',
        value: '${kpis.atribuida}',
        color: clx.statusAtribuida,
      ),
      _KpiCard(
        label: 'Em andamento',
        value: '${kpis.emAndamento}',
        color: clx.warning,
      ),
      _KpiCard(
        label: 'Concluídas',
        value: '${kpis.concluida}',
        color: clx.success,
      ),
      _KpiCard(
        label: 'Faturamento hoje',
        value: formatCurrency(kpis.faturamentoDia),
        color: clx.primary,
        wide: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 900
            ? 5
            : w >= 620
            ? 3
            : 2;
        const gap = ClxSpace.x3;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(width: itemW.clamp(120.0, w), child: card),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.labelMedium?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: ClxSpace.x2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (wide ? tt.titleLarge : tt.headlineMedium)?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de um atendimento próximo (hora + descrição + status).
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.os, required this.onTap});

  final OrdemServico os;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final prof = os.expand?.profissional;
    final subtitle = [
      os.tipoServicoNome ?? '—',
      if (prof != null) prof.displayName,
    ].join(' · ');

    return ClxCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x3,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTime(os.dataHora),
                  style: tt.titleSmall?.copyWith(
                    color: clx.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  formatDate(os.dataHora).substring(0, 5), // dd/MM
                  style: tt.labelSmall?.copyWith(color: clx.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: ClxSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${os.nomeCurto} — ${os.bairro}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(color: clx.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: clx.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: ClxSpace.x3),
          StatusBadge(status: os.status, dense: true),
        ],
      ),
    );
  }
}

/// Data longa pt-BR de hoje em BRT (ex.: "quarta-feira, 01 de julho"), sem
/// depender de `initializeDateFormatting` (determinística e test-safe).
String _longDatePtBr() {
  final brt = DateTime.now().toUtc().subtract(kBrtOffset);
  const semana = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  const meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  final dia = brt.day.toString().padLeft(2, '0');
  return '${semana[brt.weekday - 1]}, $dia de ${meses[brt.month - 1]}';
}
