/// dashboard_screen.dart — Home do Painel.
///
/// APK / web estreita: hub estilo Easypay (saudação, hero de faturamento,
/// atalhos circulares, KPIs, lista de próximos). Desktop web clássico: layout
/// anterior (grade de KPIs + botões).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_surface_provider.dart';
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
    final easypay =
        ref.watch(isFintechCleanProvider) || ref.watch(isNarrowWebProvider);

    return async.when(
      loading: () => const _DashboardLoading(),
      error: (err, _) =>
          _DashboardError(onRetry: () => ref.invalidate(dashboardDataProvider)),
      data: (data) => easypay
          ? _EasypayDashboard(data: data)
          : _DashboardBody(data: data),
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

/* ─────────────────── Easypay hub (APK / narrow web) ─────────────────── */

class _EasypayDashboard extends ConsumerWidget {
  const _EasypayDashboard({required this.data});

  final DashboardData data;

  void _go(BuildContext context, PainelSection section) =>
      context.go(painelPath(section));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final kpis = data.kpis;
    final upcoming = data.upcoming;

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(dashboardDataProvider.future),
      color: clx.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Hero faturamento (saudação + avatar ficam no top bar fixo do shell)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x4,
              ClxSpace.x2,
              ClxSpace.x4,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: ClxFadeSlide(
                delay: const Duration(milliseconds: 60),
                child: _FaturamentoHero(
                  value: kpis.faturamentoDia,
                  concluidas: kpis.concluida,
                ),
              ),
            ),
          ),

          // Atalhos circulares
          SliverToBoxAdapter(
            child: ClxFadeSlide(
              delay: const Duration(milliseconds: 120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ClxSpace.x3,
                  ClxSpace.x4,
                  ClxSpace.x3,
                  0,
                ),
                child: Row(
                  children: [
                    _CircleAction(
                      label: 'Nova OS',
                      icon: Icons.add_rounded,
                      bg: clx.successBg,
                      fg: clx.success,
                      onTap: () => _go(context, PainelSection.ordens),
                    ),
                    _CircleAction(
                      label: 'Cliente',
                      icon: Icons.person_add_alt_1_rounded,
                      bg: clx.infoBg,
                      fg: clx.info,
                      onTap: () => _go(context, PainelSection.clientes),
                    ),
                    _CircleAction(
                      label: 'Agenda',
                      icon: Icons.calendar_month_rounded,
                      bg: clx.statusAtribuidaBg,
                      fg: clx.statusAtribuida,
                      onTap: () => _go(context, PainelSection.agenda),
                    ),
                    _CircleAction(
                      label: 'Carteira',
                      icon: Icons.account_balance_wallet_rounded,
                      bg: clx.warningBg,
                      fg: clx.warning,
                      onTap: () => _go(context, PainelSection.financeiro),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // KPIs do dia
          SliverToBoxAdapter(
            child: ClxFadeSlide(
              delay: const Duration(milliseconds: 180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ClxSpace.x4,
                  ClxSpace.x5,
                  ClxSpace.x4,
                  ClxSpace.x2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoje na operação',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: clx.ink,
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x3),
                    Row(
                      children: [
                        _MiniKpi(
                          value: kpis.agendada,
                          label: 'Agend.',
                          color: clx.info,
                        ),
                        const SizedBox(width: ClxSpace.x2),
                        _MiniKpi(
                          value: kpis.atribuida,
                          label: 'Atrib.',
                          color: clx.statusAtribuida,
                        ),
                        const SizedBox(width: ClxSpace.x2),
                        _MiniKpi(
                          value: kpis.emAndamento,
                          label: 'Andam.',
                          color: clx.warning,
                        ),
                        const SizedBox(width: ClxSpace.x2),
                        _MiniKpi(
                          value: kpis.concluida,
                          label: 'Concl.',
                          color: clx.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Próximos
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ClxSpace.x4,
              ClxSpace.x4,
              ClxSpace.x4,
              ClxSpace.x2,
            ),
            sliver: SliverToBoxAdapter(
              child: ClxFadeSlide(
                delay: const Duration(milliseconds: 220),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Próximos',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: clx.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _go(context, PainelSection.ordens),
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (upcoming.isEmpty)
            SliverToBoxAdapter(
              child: ClxFadeSlide(
                delay: const Duration(milliseconds: 260),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x4),
                  child: EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Nenhum atendimento pendente',
                    message:
                        'Todas as ordens estão concluídas ou canceladas. '
                        'Toque no + para criar uma OS.',
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ClxSpace.x4,
                0,
                ClxSpace.x4,
                ClxSpace.x12,
              ),
              sliver: SliverList.builder(
                itemCount: upcoming.length.clamp(0, 8),
                itemBuilder: (context, i) {
                  return ClxFadeSlide(
                    delay: Duration(milliseconds: 260 + i * 40),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: ClxSpace.x2),
                      child: _TxCard(
                        os: upcoming[i],
                        onTap: () => _go(context, PainelSection.ordens),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Typo fix: SliverPadding not SliverPadding
// I'll fix by search_replace after write if needed - actually I used SliverPadding which is wrong!

class _FaturamentoHero extends StatelessWidget {
  const _FaturamentoHero({required this.value, required this.concluidas});

  final double value;
  final int concluidas;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
            color: clx.accent.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: clx.primary.withValues(alpha: 0.25),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FATURAMENTO HOJE',
                style: tt.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: ClxMotion.emphasizedDuration,
                curve: ClxMotion.emphasized,
                builder: (context, v, _) {
                  return Text(
                    formatCurrency(v),
                    style: tt.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  concluidas == 1
                      ? '↑ 1 OS concluída'
                      : '↑ $concluidas OS concluídas',
                  style: tt.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fill: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.color, required this.fill});

  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.65,
        size.width * 0.25,
        size.height * 0.45,
        size.width * 0.35,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.38,
        size.width * 0.55,
        size.height * 0.55,
        size.width * 0.68,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.8,
        size.height * 0.1,
        size.width * 0.9,
        size.height * 0.35,
        size.width,
        size.height * 0.18,
      );

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.color != color || old.fill != fill;
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Expanded(
      child: ClxPressScale(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: clx.ink.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: fg, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: clx.ink2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: clx.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: clx.line),
          boxShadow: [
            BoxShadow(
              color: clx.ink.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            ClxCountUp(
              value: value,
              builder: (context, v) => Text(
                '$v',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: clx.ink3,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  const _TxCard({required this.os, required this.onTap});

  final OrdemServico os;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final prof = os.expand?.profissional;
    final money = formatCurrency(os.valorTotal);

    return Material(
      color: clx.bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: clx.line),
            boxShadow: [
              BoxShadow(
                color: clx.ink.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      clx.primary.withValues(alpha: 0.18),
                      clx.accent.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatTime(os.dataHora),
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: clx.accent,
                      ),
                    ),
                    Text(
                      formatDate(os.dataHora).substring(0, 5),
                      style: tt.labelSmall?.copyWith(
                        color: clx.ink3,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${os.clienteNomeExibicao} — ${os.bairro}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: clx.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        os.tipoServicoNome ?? '—',
                        money,
                        if (prof != null) prof.displayName,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: clx.ink3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: os.status, dense: true),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────── Layout clássico (web ≥ 600dp) ─────────────────── */

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
                  ClxFadeSlide(
                    child: _SectionHeader(
                      title: 'Hoje',
                      trailing: Text(
                        _longDatePtBr(),
                        style: tt.bodyMedium?.copyWith(color: clx.ink3),
                      ),
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x3),
                  ClxFadeSlide(
                    delay: const Duration(milliseconds: 80),
                    child: _KpiGrid(kpis: data.kpis),
                  ),
                  const SizedBox(height: ClxSpace.x6),
                  ClxFadeSlide(
                    delay: const Duration(milliseconds: 140),
                    child: _SectionHeader(
                      title: 'Próximos atendimentos',
                      trailing: ClxButton(
                        label: 'Ver todos',
                        variant: ClxButtonVariant.ghost,
                        onPressed: () => _go(context, PainelSection.ordens),
                      ),
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x3),
                  ClxFadeSlide(
                    delay: const Duration(milliseconds: 180),
                    child: Text(
                      'Ordens abertas — ${upcoming.length} '
                      'registro${upcoming.length == 1 ? '' : 's'}',
                      style: tt.bodyMedium?.copyWith(
                        color: clx.ink3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x2),
                ],
              ),
            ),
          ),
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
                  child: ClxFadeSlide(
                    delay: Duration(milliseconds: 60 + i * 50),
                    child: _UpcomingCard(
                      os: upcoming[i],
                      onTap: () => _go(context, PainelSection.ordens),
                    ),
                  ),
                ),
              ),
            ),
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
                  const _SectionHeader(title: 'Acesso rápido'),
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
                        onPressed: () =>
                            _go(context, PainelSection.financeiro),
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
          Text(label, style: tt.labelMedium?.copyWith(color: clx.ink3)),
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
                  formatDate(os.dataHora).substring(0, 5),
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
                  '${os.clienteNomeExibicao} — ${os.bairro}',
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


