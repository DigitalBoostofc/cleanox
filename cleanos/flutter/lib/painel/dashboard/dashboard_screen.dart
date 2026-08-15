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
import '../financeiro/charts/fin_charts.dart';
import '../ordens/ordens_controller.dart';
import '../ordens/ordens_periodo_calendario.dart';
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
    // Próximos (teto 8) agrupados por dia BRT: cada troca de dia insere um
    // separador. A lista já vem ordenada por data_hora, então basta detectar a
    // mudança de dia (pedido do dono, 16/07).
    final upcomingRows = <({String? header, OrdemServico? os})>[];
    String? lastDay;
    for (final os in upcoming.take(8)) {
      final day = formatDate(os.dataHora); // dd/MM/yyyy BRT = chave do dia
      if (day != lastDay) {
        upcomingRows.add((header: formatDayHeaderBrt(os.dataHora), os: null));
        lastDay = day;
      }
      upcomingRows.add((header: null, os: os));
    }

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
                      dashboardTitulo(ref.watch(dashboardPeriodoProvider)),
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: clx.ink,
                      ),
                    ),
                    const SizedBox(height: ClxSpace.x2),
                    const _DashboardPeriodoMenu(compact: true),
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

          SliverToBoxAdapter(
            child: ClxFadeSlide(
              delay: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ClxSpace.x4,
                  ClxSpace.x4,
                  ClxSpace.x4,
                  0,
                ),
                child: _AnaliseDoDia(
                  ranking: data.ranking,
                  local: data.local,
                  titulo: dashboardAnaliseTitulo(
                    ref.watch(dashboardPeriodoProvider),
                  ),
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
                itemCount: upcomingRows.length,
                itemBuilder: (context, i) {
                  final row = upcomingRows[i];
                  if (row.header != null) {
                    return _DaySeparator(label: row.header!, first: i == 0);
                  }
                  return ClxFadeSlide(
                    delay: Duration(milliseconds: 260 + i * 40),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: ClxSpace.x2),
                      child: _TxCard(
                        os: row.os!,
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

/// Separador de dia entre os cards de "Próximos" (ex.: "Hoje · 16/07").
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label, required this.first});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 0 : ClxSpace.x3,
        bottom: ClxSpace.x2,
      ),
      child: Row(
        children: [
          Icon(Icons.event_rounded, size: 14, color: clx.ink3),
          const SizedBox(width: 6),
          Text(
            label,
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: clx.ink2,
            ),
          ),
          const SizedBox(width: ClxSpace.x3),
          Expanded(child: Divider(color: clx.line, height: 1)),
        ],
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
                child: Text(
                  formatTime(os.dataHora),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: clx.accent,
                  ),
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
                      '${os.tipoServicoNome ?? '—'} · $money',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: clx.ink3),
                    ),
                    const SizedBox(height: 4),
                    // Profissional em linha própria — antes ficava no fim da
                    // linha do serviço e o ellipsis cortava (feedback do dono).
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 13,
                          color: prof != null ? clx.primary : clx.ink3,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            prof?.displayName ?? 'Sem profissional',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: prof != null ? clx.ink2 : clx.ink3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: os.status, dense: true, refazer: os.refazer, vitrine: os.isVitrine),
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
    final periodo = ref.watch(dashboardPeriodoProvider);

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
                      title: dashboardTitulo(periodo),
                      trailing: const _DashboardPeriodoMenu(),
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x3),
                  ClxFadeSlide(
                    delay: const Duration(milliseconds: 40),
                    child: _AcessoRapido(onGo: (s) => _go(context, s)),
                  ),
                  const SizedBox(height: ClxSpace.x6),
                  ClxFadeSlide(
                    delay: const Duration(milliseconds: 80),
                    child: _KpiGrid(
                      kpis: data.kpis,
                      faturamentoLabel: dashboardFaturamentoLabel(periodo),
                    ),
                  ),
                  const SizedBox(height: ClxSpace.x6),
                  ClxFadeSlide(
                    delay: const Duration(milliseconds: 110),
                    child: _AnaliseDoDia(
                      ranking: data.ranking,
                      local: data.local,
                      titulo: dashboardAnaliseTitulo(periodo),
                    ),
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
              padding: const EdgeInsets.fromLTRB(
                ClxSpace.x6,
                0,
                ClxSpace.x6,
                ClxSpace.x10,
              ),
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
        ],
      ),
    );
  }
}

class _DashboardPeriodoMenu extends ConsumerStatefulWidget {
  const _DashboardPeriodoMenu({this.compact = false});

  final bool compact;

  @override
  ConsumerState<_DashboardPeriodoMenu> createState() =>
      _DashboardPeriodoMenuState();
}

class _DashboardPeriodoMenuState extends ConsumerState<_DashboardPeriodoMenu> {
  var _tick = 0;

  Future<void> _escolherPersonalizado(DashboardPeriodo atual) async {
    final now = DateTime.now();
    final atualInicio = atual.personalizadoInicio ?? now;
    final atualFim = atual.personalizadoFim ?? atualInicio;
    var start = DateTime(atualInicio.year, atualInicio.month, atualInicio.day);
    var end = DateTime(atualFim.year, atualFim.month, atualFim.day);
    final first = DateTime(2020);
    final last = DateTime(now.year + 2);
    if (start.isBefore(first)) start = first;
    if (end.isAfter(last)) end = last;
    if (end.isBefore(start)) end = start;
    final picked = await showOrdensPeriodoCalendario(
      context,
      inicio: start,
      fim: end,
    );
    if (picked == null || !mounted) {
      setState(() => _tick++);
      return;
    }
    ref.read(dashboardPeriodoProvider.notifier).state = DashboardPeriodo(
      periodo: OrdensPeriodo.personalizado,
      personalizadoInicio: picked.start,
      personalizadoFim: picked.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final atual = ref.watch(dashboardPeriodoProvider);
    return SizedBox(
      key: const Key('dashboard-periodo'),
      width: widget.compact ? 200 : 180,
      child: DropdownButtonFormField<OrdensPeriodo>(
        key: ValueKey(
          'dashboard-periodo-${atual.periodo.name}-$_tick-'
          '${atual.personalizadoInicio?.millisecondsSinceEpoch ?? 0}',
        ),
        initialValue: atual.periodo,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: clx.bg2,
          prefixIcon: const Icon(Icons.event_outlined, size: 18),
          border: const OutlineInputBorder(
            borderRadius: ClxRadii.rMd,
            borderSide: BorderSide.none,
          ),
        ),
        items: [
          for (final p in OrdensPeriodo.values)
            DropdownMenuItem(
              value: p,
              child: Text(p.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        selectedItemBuilder: (context) => [
          for (final p in OrdensPeriodo.values)
            Text(
              p == atual.periodo ? dashboardTitulo(atual) : p.label,
              overflow: TextOverflow.ellipsis,
            ),
        ],
        onChanged: (p) {
          if (p == null) return;
          if (p == OrdensPeriodo.personalizado) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _escolherPersonalizado(atual);
            });
            return;
          }
          ref.read(dashboardPeriodoProvider.notifier).state = DashboardPeriodo(
            periodo: p,
          );
        },
      ),
    );
  }
}

class _AcessoRapido extends StatelessWidget {
  const _AcessoRapido({required this.onGo});

  final void Function(PainelSection section) onGo;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('dashboard-acesso-rapido'),
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
              onPressed: () => onGo(PainelSection.ordens),
            ),
            ClxButton(
              label: 'Novo Cliente',
              icon: Icons.add_rounded,
              variant: ClxButtonVariant.ghost,
              onPressed: () => onGo(PainelSection.clientes),
            ),
            ClxButton(
              label: 'Ver Agenda',
              variant: ClxButtonVariant.ghost,
              onPressed: () => onGo(PainelSection.agenda),
            ),
            ClxButton(
              label: 'Financeiro',
              variant: ClxButtonVariant.ghost,
              onPressed: () => onGo(PainelSection.financeiro),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnaliseDoDia extends StatelessWidget {
  const _AnaliseDoDia({
    required this.ranking,
    required this.local,
    required this.titulo,
  });

  final List<DashboardProfRanking> ranking;
  final DashboardLocalSplit local;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Column(
      key: const Key('dashboard-analise'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: titulo),
        const SizedBox(height: ClxSpace.x3),
        LayoutBuilder(
          builder: (context, c) {
            final sideBySide = c.maxWidth >= 720;
            final quem = _AnaliseCard(
              title: 'Quem atendeu',
              child: ranking.isEmpty
                  ? Text(
                      'Nenhuma OS atribuída neste período.',
                      style: tt.bodyMedium?.copyWith(color: clx.ink3),
                    )
                  : Column(
                      children: [
                        FinBarChart(
                          slices: [
                            for (final p in ranking.take(6))
                              FinSlice(
                                label: p.nome,
                                value: p.osCount.toDouble(),
                                color: dashboardCorProfissional(p),
                              ),
                          ],
                          height: 180,
                        ),
                        const SizedBox(height: ClxSpace.x2),
                        for (final p in ranking.take(6))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: dashboardCorProfissional(p),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    p.nome,
                                    style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: clx.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  p.osCount == 1 ? '1 OS' : '${p.osCount} OS',
                                  style: tt.bodyMedium?.copyWith(
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
            final onde = _AnaliseCard(
              title: 'Onde foi o atendimento',
              child: local.total == 0
                  ? Text(
                      'Nenhum atendimento neste período.',
                      style: tt.bodyMedium?.copyWith(color: clx.ink3),
                    )
                  : Column(
                      children: [
                        FinDonutChart(
                          slices: [
                            if (local.domicilio > 0)
                              FinSlice(
                                label: 'Domicílio',
                                value: local.domicilio.toDouble(),
                                color: clx.info,
                              ),
                            if (local.pontoFisico > 0)
                              FinSlice(
                                label: 'Ponto físico',
                                value: local.pontoFisico.toDouble(),
                                color: clx.primary,
                              ),
                          ],
                          centerLabel: 'Local',
                          size: 140,
                        ),
                      ],
                    ),
            );
            if (sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: quem),
                  const SizedBox(width: ClxSpace.x3),
                  Expanded(child: onde),
                ],
              );
            }
            return Column(
              children: [
                quem,
                const SizedBox(height: ClxSpace.x3),
                onde,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AnaliseCard extends StatelessWidget {
  const _AnaliseCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return ClxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.labelLarge?.copyWith(
              color: clx.ink3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ClxSpace.x3),
          child,
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
  const _KpiGrid({required this.kpis, required this.faturamentoLabel});

  final DashboardKpis kpis;
  final String faturamentoLabel;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cards = <Widget>[
      _KpiCard(
        label: 'Em agendamento',
        value: '${kpis.agendada}',
        color: clx.info,
      ),
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
        label: faturamentoLabel,
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
          StatusBadge(status: os.status, dense: true, refazer: os.refazer, vitrine: os.isVitrine),
        ],
      ),
    );
  }
}


