/// agenda_screen.dart — Agenda do Painel: CALENDÁRIO de ordens de serviço.
///
/// Espelha `Agenda.tsx`: três visões — **dia**, **semana** e **mês** — com
/// navegação de período, filtro de profissional (em memória) e modal de
/// disponibilidade (admin/gerente). As OS aparecem como eventos posicionados por
/// dia/horário; tocar num evento abre o detalhe. Responsivo: grade densa no
/// desktop, listas/compacto no mobile (espelha as `Mobile*View` do React).
///
/// MD3: superfícies tonais + `outline-variant` (clx.line) nas divisórias, raios/
/// tokens do design system, `SegmentedButton` para as visões, cores de status nos
/// eventos, alvos de toque ≥ 48dp. PT-BR, BRT (UTC-3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';
import '../usuarios/disponibilidade_editor.dart';
import 'agenda_controller.dart';

/// Abaixo disto, usa as variantes mobile (listas/compacto).
const double _kMobileBreakpoint = 760;
const double _kTimeColW = 56;
const double _kHourRowH = 60;

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agendaControllerProvider);
    return Column(
      children: [
        const _Toolbar(),
        Expanded(child: _Body(state: state)),
      ],
    );
  }
}

/* ─────────────────────────── Toolbar ─────────────────────────── */

class _Toolbar extends ConsumerWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final state = ref.watch(agendaControllerProvider);
    final notifier = ref.read(agendaControllerProvider.notifier);
    final role = ref.watch(currentRoleProvider);
    final canManageDisp = role == Role.admin || role == Role.gerente;
    final profId = state.filterProfId;
    User? selectedProf;
    if (profId != null) {
      for (final p in state.profissionais) {
        if (p.id == profId) {
          selectedProf = p;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClxSpace.x6,
        ClxSpace.x4,
        ClxSpace.x6,
        ClxSpace.x3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Wrap(
        spacing: ClxSpace.x3,
        runSpacing: ClxSpace.x2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Navegação de período.
          Container(
            decoration: BoxDecoration(
              color: clx.bg2,
              borderRadius: ClxRadii.rMd,
              border: Border.all(color: clx.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Anterior',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: notifier.goPrev,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140),
                  child: Text(
                    agendaPeriodLabel(state.view, state.anchor),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: notifier.goNext,
                ),
              ],
            ),
          ),
          ClxButton(
            label: 'Hoje',
            variant: ClxButtonVariant.ghost,
            icon: Icons.today_rounded,
            onPressed: notifier.goToday,
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: notifier.load,
          ),
          // Filtro de profissional + engrenagem de disponibilidade.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: state.filterProfId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: clx.bg2,
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                    border: const OutlineInputBorder(
                      borderRadius: ClxRadii.rMd,
                      borderSide: BorderSide.none,
                    ),
                  ),
                  hint: const Text('Todos os profissionais'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos os profissionais'),
                    ),
                    for (final p in state.profissionais)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: notifier.setFilterProf,
                ),
              ),
              if (selectedProf != null && canManageDisp)
                Builder(
                  builder: (context) {
                    final prof = selectedProf!;
                    return IconButton(
                      tooltip: 'Configurar disponibilidade',
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      onPressed: () => showDisponibilidadeEditor(
                        context,
                        profissional: prof,
                      ),
                    );
                  },
                ),
            ],
          ),
          // Abas de visão.
          SegmentedButton<AgendaView>(
            segments: const [
              ButtonSegment(value: AgendaView.dia, label: Text('Dia')),
              ButtonSegment(value: AgendaView.semana, label: Text('Semana')),
              ButtonSegment(value: AgendaView.mes, label: Text('Mês')),
            ],
            selected: {state.view},
            showSelectedIcon: false,
            onSelectionChanged: (s) => notifier.setView(s.first),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────────── Corpo ─────────────────────────── */

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final AgendaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading) return const Center(child: Spinner(size: 26));
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ClxSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorBanner(
              message: state.error!,
              onRetry: () => ref.read(agendaControllerProvider.notifier).load(),
            ),
          ),
        ),
      );
    }

    void openOS(OrdemServico os) => showDialog<void>(
      context: context,
      builder: (_) => _OSDetailDialog(os: os),
    );

    final notifier = ref.read(agendaControllerProvider.notifier);
    final today = _todayDate();

    return LayoutBuilder(
      builder: (context, c) {
        final mobile = c.maxWidth < _kMobileBreakpoint;
        switch (state.view) {
          case AgendaView.semana:
            return mobile
                ? _MobileWeekView(state: state, today: today, onTap: openOS)
                : _WeekView(state: state, today: today, onTap: openOS);
          case AgendaView.mes:
            return mobile
                ? _MobileMonthView(
                    state: state,
                    today: today,
                    onTap: openOS,
                    onSelectDay: notifier.setSelectedDay,
                  )
                : _MonthView(
                    state: state,
                    today: today,
                    onTap: openOS,
                    onDayClick: notifier.openDay,
                  );
          case AgendaView.dia:
            return mobile
                ? _MobileDayView(state: state, today: today, onTap: openOS)
                : _DayView(state: state, today: today, onTap: openOS);
        }
      },
    );
  }
}

DateTime _todayDate() {
  final d = DateTime.tryParse(todayLocalDate()) ?? DateTime.now();
  return DateTime(d.year, d.month, d.day);
}

/* ─────────────────────────── Semana (desktop) ─────────────────────────── */

class _WeekView extends StatelessWidget {
  const _WeekView({required this.state, required this.today, required this.onTap});
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final ws = startOfWeek(state.anchor);
    final days = [for (var i = 0; i < 7; i++) addDays(ws, i)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho: canto + 7 dias.
        Container(
          decoration: BoxDecoration(
            color: clx.bg3,
            border: Border(bottom: BorderSide(color: clx.line)),
          ),
          child: Row(
            children: [
              const SizedBox(width: _kTimeColW),
              for (final d in days)
                Expanded(child: _WeekDayHeader(day: d, isToday: sameDay(d, today))),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final h in kAgendaHours)
                  // IntrinsicHeight dá uma altura LIMITADA ao `stretch` da Row:
                  // dentro do scroll vertical a altura entrante é infinita e o
                  // stretch sozinho forçaria altura infinita nas células (crash).
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HourLabel(hour: h),
                        for (final d in days)
                          Expanded(
                            child: _WeekCell(
                              events: state.eventsForHour(d, h),
                              onTap: onTap,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekDayHeader extends StatelessWidget {
  const _WeekDayHeader({required this.day, required this.isToday});
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: clx.line)),
      ),
      child: Column(
        children: [
          Text(
            kDowShort[day.weekday % 7],
            style: tt.labelSmall?.copyWith(
              color: isToday ? clx.primary : clx.ink3,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${day.day}',
            style: tt.titleSmall?.copyWith(
              color: isToday ? clx.primary : clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HourLabel extends StatelessWidget {
  const _HourLabel({required this.hour});
  final int hour;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      width: _kTimeColW,
      constraints: const BoxConstraints(minHeight: _kHourRowH),
      alignment: Alignment.topRight,
      padding: const EdgeInsets.only(right: ClxSpace.x2, top: ClxSpace.x1),
      decoration: BoxDecoration(
        color: clx.bg2,
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Text(
        '${hour}h',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: clx.ink3),
      ),
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({required this.events, required this.onTap});
  final List<OrdemServico> events;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      constraints: const BoxConstraints(minHeight: _kHourRowH),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: clx.line),
          bottom: BorderSide(color: clx.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final os in events) _EventChip(os: os, onTap: onTap),
        ],
      ),
    );
  }
}

/// Evento compacto (semana/mês): hora + nome curto, cor do status.
class _EventChip extends StatelessWidget {
  const _EventChip({required this.os, required this.onTap});
  final OrdemServico os;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return GestureDetector(
      onTap: () => onTap(os),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x2, vertical: 2),
        decoration: BoxDecoration(
          color: clx.statusBg(os.status),
          borderRadius: ClxRadii.rSm,
          border: Border(
            left: BorderSide(color: clx.statusColor(os.status), width: 3),
          ),
        ),
        child: Text(
          '${formatTime(os.dataHora)} ${os.nomeCurto.isEmpty ? '—' : os.nomeCurto}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: clx.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────────── Mês (desktop) ─────────────────────────── */

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.state,
    required this.today,
    required this.onTap,
    required this.onDayClick,
  });
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;
  final ValueChanged<DateTime> onDayClick;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final weeks = monthCalendar(state.anchor.year, state.anchor.month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: clx.bg3,
            border: Border(bottom: BorderSide(color: clx.line)),
          ),
          child: Row(
            children: [
              for (final d in kDowShort)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: ClxSpace.x2),
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: clx.ink3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              for (final week in weeks)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final day in week)
                        Expanded(
                          child: _MonthDayCell(
                            day: day,
                            isToday: sameDay(day, today),
                            isOtherMonth: day.month != state.anchor.month,
                            events: state.eventsForDay(day),
                            onTap: onTap,
                            onDayClick: () => onDayClick(day),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.isToday,
    required this.isOtherMonth,
    required this.events,
    required this.onTap,
    required this.onDayClick,
  });
  final DateTime day;
  final bool isToday;
  final bool isOtherMonth;
  final List<OrdemServico> events;
  final ValueChanged<OrdemServico> onTap;
  final VoidCallback onDayClick;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return InkWell(
      onTap: onDayClick,
      child: Container(
        padding: const EdgeInsets.all(ClxSpace.x1),
        decoration: BoxDecoration(
          color: isOtherMonth ? clx.bg2 : clx.bg,
          border: Border(
            left: BorderSide(color: clx.line),
            bottom: BorderSide(color: clx.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(color: clx.primary, shape: BoxShape.circle)
                    : null,
                child: Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isToday
                        ? Colors.white
                        : (isOtherMonth ? clx.ink3 : clx.ink),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final os in events.take(3))
                      _EventChip(os: os, onTap: onTap),
                    if (events.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, top: 1),
                        child: Text(
                          '+${events.length - 3} mais',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: clx.ink3),
                        ),
                      ),
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

/* ─────────────────────────── Dia (desktop) ─────────────────────────── */

class _DayView extends StatelessWidget {
  const _DayView({required this.state, required this.today, required this.onTap});
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final day = state.anchor;
    final isToday = sameDay(day, today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ClxSpace.x6,
            vertical: ClxSpace.x3,
          ),
          decoration: BoxDecoration(
            color: clx.bg3,
            border: Border(bottom: BorderSide(color: clx.line)),
          ),
          child: Text(
            '${agendaDayLabelLong(day)}${isToday ? ' — Hoje' : ''}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: clx.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final h in kAgendaHours)
                  _DaySlot(hour: h, events: state.eventsForHour(day, h), onTap: onTap),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DaySlot extends StatelessWidget {
  const _DaySlot({required this.hour, required this.events, required this.onTap});
  final int hour;
  final List<OrdemServico> events;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Container(
      constraints: const BoxConstraints(minHeight: _kHourRowH),
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x4,
        vertical: ClxSpace.x2,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '${hour}h',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: clx.ink3),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final os in events) _DayEventTile(os: os, onTap: onTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayEventTile extends StatelessWidget {
  const _DayEventTile({required this.os, required this.onTap});
  final OrdemServico os;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final prof = os.expand?.profissional?.displayName;
    return InkWell(
      onTap: () => onTap(os),
      borderRadius: ClxRadii.rMd,
      child: Container(
        margin: const EdgeInsets.only(bottom: ClxSpace.x2),
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x3,
          vertical: ClxSpace.x2,
        ),
        decoration: BoxDecoration(
          color: clx.statusBg(os.status),
          borderRadius: ClxRadii.rMd,
          border: Border(
            left: BorderSide(color: clx.statusColor(os.status), width: 3),
          ),
        ),
        child: Row(
          children: [
            Text(
              formatTime(os.dataHora),
              style: tt.bodyMedium?.copyWith(
                color: clx.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: ClxSpace.x2),
            Expanded(
              child: Text(
                '${os.nomeCurto.isEmpty ? '—' : os.nomeCurto} — '
                '${os.tipoServicoNome ?? '—'}'
                '${prof != null && prof != '—' ? ' · $prof' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(color: clx.ink2),
              ),
            ),
            StatusBadge(status: os.status, dense: true),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────── Mobile ─────────────────────────── */

/// Mini-card usado nas visões mobile (dia/semana/mês).
class _AgendaMiniCard extends StatelessWidget {
  const _AgendaMiniCard({required this.os, required this.onTap});
  final OrdemServico os;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final prof = os.expand?.profissional?.displayName;
    return InkWell(
      onTap: () => onTap(os),
      borderRadius: ClxRadii.rMd,
      child: Container(
        constraints: const BoxConstraints(minHeight: ClxLayout.minTouchTarget),
        margin: const EdgeInsets.only(bottom: ClxSpace.x2),
        padding: const EdgeInsets.symmetric(
          horizontal: ClxSpace.x3,
          vertical: ClxSpace.x2,
        ),
        decoration: BoxDecoration(
          color: clx.statusBg(os.status),
          borderRadius: ClxRadii.rMd,
          border: Border(
            left: BorderSide(color: clx.statusColor(os.status), width: 3),
          ),
        ),
        child: Row(
          children: [
            Text(
              formatTime(os.dataHora),
              style: tt.bodyMedium?.copyWith(
                color: clx.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: ClxSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    os.nomeCurto.isEmpty ? '—' : os.nomeCurto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${os.tipoServicoNome ?? '—'}'
                    '${prof != null && prof != '—' ? ' · $prof' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: clx.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ClxSpace.x2),
            StatusBadge(status: os.status, dense: true),
          ],
        ),
      ),
    );
  }
}

class _MobileDayView extends StatelessWidget {
  const _MobileDayView({
    required this.state,
    required this.today,
    required this.onTap,
  });
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final day = state.anchor;
    final events = state.eventsForDay(day)
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        Text(
          '${agendaDayLabelLong(day)}${sameDay(day, today) ? ' — Hoje' : ''}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: clx.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ClxSpace.x3),
        if (events.isEmpty)
          const _EmptyDay()
        else
          for (final os in events) _AgendaMiniCard(os: os, onTap: onTap),
      ],
    );
  }
}

class _MobileWeekView extends StatelessWidget {
  const _MobileWeekView({
    required this.state,
    required this.today,
    required this.onTap,
  });
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final ws = startOfWeek(state.anchor);
    final days = [for (var i = 0; i < 7; i++) addDays(ws, i)];
    final anyEvents = days.any((d) => state.eventsForDay(d).isNotEmpty);
    if (!anyEvents) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(ClxSpace.x6),
          child: EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Semana sem atendimentos',
            message: 'Nenhum atendimento agendado nesta semana.',
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        for (final d in days)
          if (state.eventsForDay(d).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: ClxSpace.x2, top: ClxSpace.x1),
              child: Row(
                children: [
                  Text(
                    agendaDayLabelShort(d),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: sameDay(d, today) ? clx.primary : clx.ink3,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (sameDay(d, today)) ...[
                    const SizedBox(width: ClxSpace.x2),
                    ClxChip(label: 'Hoje', color: clx.primary, dense: true),
                  ],
                ],
              ),
            ),
            for (final os in state.eventsForDay(d)
              ..sort((a, b) => a.dataHora.compareTo(b.dataHora)))
              _AgendaMiniCard(os: os, onTap: onTap),
            const SizedBox(height: ClxSpace.x3),
          ],
      ],
    );
  }
}

class _MobileMonthView extends StatelessWidget {
  const _MobileMonthView({
    required this.state,
    required this.today,
    required this.onTap,
    required this.onSelectDay,
  });
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final weeks = monthCalendar(state.anchor.year, state.anchor.month);
    final selected = state.selectedDay;
    final selectedEvents = state.eventsForDay(selected)
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    return ListView(
      padding: const EdgeInsets.all(ClxSpace.x4),
      children: [
        Row(
          children: [
            for (final d in kDowShort)
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: clx.ink3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: ClxSpace.x1),
        for (final week in weeks)
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: _MobileMonthDay(
                    day: day,
                    isToday: sameDay(day, today),
                    isSelected: sameDay(day, selected),
                    isOtherMonth: day.month != state.anchor.month,
                    events: state.eventsForDay(day),
                    onTap: () => onSelectDay(day),
                  ),
                ),
            ],
          ),
        const SizedBox(height: ClxSpace.x4),
        Text(
          agendaDayLabelLong(selected),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: clx.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ClxSpace.x2),
        if (selectedEvents.isEmpty)
          const _EmptyDay()
        else
          for (final os in selectedEvents) _AgendaMiniCard(os: os, onTap: onTap),
      ],
    );
  }
}

class _MobileMonthDay extends StatelessWidget {
  const _MobileMonthDay({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isOtherMonth,
    required this.events,
    required this.onTap,
  });
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isOtherMonth;
  final List<OrdemServico> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return InkWell(
      onTap: onTap,
      borderRadius: ClxRadii.rSm,
      child: Container(
        height: 44,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected ? clx.primary.withValues(alpha: 0.14) : null,
          borderRadius: ClxRadii.rSm,
          border: isToday ? Border.all(color: clx.primary, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isOtherMonth ? clx.ink3 : clx.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            if (events.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final os in events.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: clx.statusColor(os.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ClxSpace.x4),
      child: Text(
        'Sem atendimentos neste dia',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: clx.ink3),
      ),
    );
  }
}

/* ─────────────────────────── Detalhe da OS ─────────────────────────── */

class _OSDetailDialog extends StatelessWidget {
  const _OSDetailDialog({required this.os});
  final OrdemServico os;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final prof = os.expand?.profissional?.displayName;
    return AlertDialog(
      backgroundColor: clx.bg,
      shape: const RoundedRectangleBorder(borderRadius: ClxRadii.rXl),
      title: Row(
        children: [
          Expanded(
            child: Text(
              os.nomeCurto.isEmpty ? 'Ordem de serviço' : os.nomeCurto,
              style: tt.titleMedium?.copyWith(
                color: clx.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          StatusBadge(status: os.status, dense: true),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(clx, tt, 'Bairro', os.bairro.isEmpty ? '—' : os.bairro),
          _row(clx, tt, 'Serviço', os.tipoServicoNome ?? '—'),
          _row(clx, tt, 'Data / Hora', formatDateTime(os.dataHora)),
          _row(clx, tt, 'Profissional', (prof == null || prof == '—') ? '—' : prof),
          if (os.status == OSStatus.concluida) ...[
            const SizedBox(height: ClxSpace.x2),
            Text(
              'Financeiro',
              style: tt.labelMedium?.copyWith(
                color: clx.ink3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ClxSpace.x1),
            _row(
              clx,
              tt,
              'Valor pago',
              os.valorPago != null ? formatCurrency(os.valorPago!) : '—',
            ),
            if (os.formaPagamento != null)
              _row(clx, tt, 'Forma', os.formaPagamento!.label),
          ],
        ],
      ),
      actions: [
        ClxButton(
          label: 'Fechar',
          variant: ClxButtonVariant.ghost,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _row(CleanoxColors clx, TextTheme tt, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: ClxSpace.x2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              child: Text(
                label,
                style: tt.bodyMedium?.copyWith(color: clx.ink3),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: tt.bodyLarge?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}
