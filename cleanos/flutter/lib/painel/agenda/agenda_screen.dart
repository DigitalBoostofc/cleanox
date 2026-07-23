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

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/agenda/agenda_layout.dart';
import '../../core/agenda/agenda_prof_cor.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/design/app_surface_provider.dart';
import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/disponibilidade.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';
import '../ordens/os_detail.dart';
import '../ordens/os_form.dart';
import '../usuarios/disponibilidade_editor.dart';
import 'agenda_controller.dart';
import 'ajuste_sheet.dart';
import 'day_column.dart';

/// Abaixo disto, usa as variantes mobile (listas/compacto).
const double _kMobileBreakpoint = 760;

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  /// REFRESH-ON-FOCUS (spec §9 / R-M7). O `StatefulShellRoute.indexedStack`
  /// mantém esta tela VIVA para sempre (o branch fica offstage, não é destruído),
  /// então sem isto a agenda ficaria congelada no dia/estado de quando foi aberta
  /// — inclusive "hoje", depois da meia-noite.
  ///
  /// O go_router embrulha cada branch num `TickerMode(enabled: isActive)`; o
  /// notifier dele é o sinal de foco mais barato e confiável que existe aqui.
  ValueListenable<bool>? _foco;
  bool _visivel = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = TickerMode.getNotifier(context);
    if (n != _foco) {
      _foco?.removeListener(_onFoco);
      _foco = n..addListener(_onFoco);
      _visivel = n.value;
    }
  }

  void _onFoco() {
    final visivel = _foco?.value ?? true;
    final voltou = visivel && !_visivel;
    _visivel = visivel;
    if (voltou && mounted) {
      ref.read(agendaControllerProvider.notifier).refreshOnFocus();
    }
  }

  @override
  void dispose() {
    _foco?.removeListener(_onFoco);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agendaControllerProvider);
    final easypay =
        ref.watch(isFintechCleanProvider) || ref.watch(isNarrowWebProvider);

    // Falha no drop: avisa e devolve o bloco ao lugar (o rollback já rodou).
    ref.listen<AgendaState>(agendaControllerProvider, (prev, next) {
      final msg = next.dragError;
      if (msg == null || msg == prev?.dragError) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      ref.read(agendaControllerProvider.notifier).limparDragError();
    });

    return Column(
      children: [
        if (easypay) const _EasypayToolbar() else const _Toolbar(),
        // Legenda das cores (= status da OS) — some no APK fintech onde as
        // abas de status já explicam o esquema; aparece na web do painel.
        if (!easypay) const _StatusLegenda(),
        Expanded(child: _Body(state: state, easypay: easypay)),
      ],
    );
  }
}

/// Legenda: cor = profissional; foto só em atribuída/em andamento; check = concluída.
class _StatusLegenda extends ConsumerWidget {
  const _StatusLegenda();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;
    final profs = ref.watch(agendaControllerProvider).profissionais;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ClxSpace.x6,
        vertical: ClxSpace.x2,
      ),
      decoration: BoxDecoration(
        color: clx.bg2,
        border: Border(bottom: BorderSide(color: clx.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Cor = profissional:',
              style: tt.labelSmall?.copyWith(color: clx.ink3),
            ),
            const SizedBox(width: ClxSpace.x3),
            if (profs.isEmpty)
              Text(
                'sem profissionais',
                style: tt.labelSmall?.copyWith(color: clx.ink3),
              )
            else
              for (final p in profs) ...[
                _LegendaItem(
                  cor: corAgendaProfissional(p),
                  label: p.displayName,
                ),
                const SizedBox(width: ClxSpace.x4),
              ],
            Icon(Icons.person, size: 13, color: clx.ink3),
            const SizedBox(width: 4),
            Text(
              'foto = atribuída/em andamento',
              style: tt.labelSmall?.copyWith(color: clx.ink3),
            ),
            const SizedBox(width: ClxSpace.x4),
            Icon(Icons.check_circle, size: 13, color: clx.ink3),
            const SizedBox(width: 4),
            Text(
              'check = concluída',
              style: tt.labelSmall?.copyWith(color: clx.ink3),
            ),
            const SizedBox(width: ClxSpace.x4),
            Text(
              'cancelada oculta',
              style: tt.labelSmall?.copyWith(color: clx.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendaItem extends StatelessWidget {
  const _LegendaItem({required this.cor, required this.label});
  final Color cor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: clx.ink2),
        ),
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
                // 260: "Todos os profissionais" + prefixIcon cabem sem cortar.
                width: 260,
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
                  hint: const Text(
                    'Todos os profissionais',
                    overflow: TextOverflow.ellipsis,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'Todos os profissionais',
                        overflow: TextOverflow.ellipsis,
                      ),
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

/* ─────────────────────────── Toolbar Easypay ─────────────────────────── */

class _EasypayToolbar extends ConsumerWidget {
  const _EasypayToolbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clx = context.clx;
    final state = ref.watch(agendaControllerProvider);
    final notifier = ref.read(agendaControllerProvider.notifier);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Anterior',
                onPressed: notifier.goPrev,
                icon: Icon(Icons.chevron_left_rounded, color: clx.ink2),
              ),
              Expanded(
                child: Text(
                  agendaPeriodLabel(state.view, state.anchor),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: clx.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Próximo',
                onPressed: notifier.goNext,
                icon: Icon(Icons.chevron_right_rounded, color: clx.ink2),
              ),
              TextButton(
                onPressed: notifier.goToday,
                child: const Text('Hoje'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SegmentedButton<AgendaView>(
            segments: const [
              ButtonSegment(value: AgendaView.dia, label: Text('Dia')),
              ButtonSegment(value: AgendaView.semana, label: Text('Semana')),
              ButtonSegment(value: AgendaView.mes, label: Text('Mês')),
            ],
            selected: {state.view},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) {
                  return clx.primary.withValues(alpha: 0.16);
                }
                return clx.bg;
              }),
            ),
            onSelectionChanged: (s) => notifier.setView(s.first),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────────── Corpo ─────────────────────────── */

class _Body extends ConsumerWidget {
  const _Body({required this.state, this.easypay = false});
  final AgendaState state;
  final bool easypay;

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

    /// Detalhe completo (mesmo de Ordens) + Editar / Execução. Ao voltar,
    /// recarrega a agenda para refletir mudanças de horário, valor etc.
    Future<void> openOS(OrdemServico os) async {
      final result = await showOSDetail(context, os);
      if (result == null) return;
      final notifier = ref.read(agendaControllerProvider.notifier);
      if (result.changed) await notifier.load();
      if (!context.mounted) return;
      // `result.os` é o registro ATUAL (pode ter sido reatribuído no detalhe).
      final atual = result.os ?? os;
      switch (result.intent) {
        case OSDetailIntent.editar:
          final salva = await showOSForm(context, editing: atual);
          if (salva != null) await notifier.load();
        case OSDetailIntent.execucao:
          await context.push('/painel/ordens/${atual.id}/execucao');
          if (context.mounted) await notifier.load();
        case null:
          break;
      }
    }

    final notifier = ref.read(agendaControllerProvider.notifier);

    /// FASE 3 (APK / web estreita): long-press no card → sheet de ajuste (D3).
    /// Sem grade nem arraste no celular (R4) — os steppers de ±15 fazem o papel.
    void ajustarOS(OrdemServico os) {
      final brt = agendaEventBrt(os);
      // D6 + drop em voo: sem sheet (o card nem chama, mas a guarda fica aqui
      // também — é o único caminho de escrita da agenda no celular).
      if (brt == null || !osAjustavel(os) || state.pendentes.contains(os.id)) {
        return;
      }
      final dia = DateTime(brt.year, brt.month, brt.day);
      showAjusteOsSheet(
        context,
        os: os,
        dia: dia,
        hoje: state.hoje,
        disp: state.dispByProf[os.profissional ?? ''],
        ocupados: _ocupadosDoDia(state, os, dia),
        onSalvar: (d, startMin, duracaoMin) => notifier.ajustarOs(
          os,
          dia: d,
          startMin: startMin,
          duracaoMin: duracaoMin,
        ),
      );
    }

    // "Hoje" vem do estado (recalculado no refresh-on-focus — R-M7), não de um
    // `DateTime.now()` solto: é o piso do arraste (D7) e o realce da coluna.
    final today = state.hoje;

    return LayoutBuilder(
      builder: (context, c) {
        final mobile = c.maxWidth < _kMobileBreakpoint || easypay;
        switch (state.view) {
          case AgendaView.semana:
            return mobile
                ? _MobileWeekView(
                    state: state,
                    today: today,
                    onTap: openOS,
                    onAjustar: ajustarOS,
                    easypay: easypay,
                    // Toque só seleciona o dia; arraste da faixa muda o período.
                    onSelectDay: notifier.setSelectedDay,
                    onWindowStart: (d) => notifier.setWeekWindowStart(d),
                  )
                : _WeekView(
                    state: state,
                    today: today,
                    onTap: openOS,
                    notifier: notifier,
                  );
          case AgendaView.mes:
            return mobile
                ? _MobileMonthView(
                    state: state,
                    today: today,
                    onTap: openOS,
                    onAjustar: ajustarOS,
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
                ? _MobileDayView(
                    state: state,
                    today: today,
                    onTap: openOS,
                    onAjustar: ajustarOS,
                    easypay: easypay,
                  )
                : _DayView(
                    state: state,
                    today: today,
                    onTap: openOS,
                    notifier: notifier,
                  );
        }
      },
    );
  }
}

/// OS que OCUPAM a agenda do MESMO profissional no [dia] — base do aviso de
/// sobreposição do sheet (D11, a mesma regra do formulário): fora `concluida` e
/// `cancelada` (reagendar no mesmo dia não pode gerar aviso fantasma) e fora a
/// própria [os].
///
/// Sai do estado JÁ carregado (nenhuma ida ao servidor) e ignora o filtro de
/// profissional da tela — filtrar a VISTA não pode esconder um conflito real.
/// OS sem profissional não tem agenda a colidir: sem aviso (idem formulário).
List<Intervalo> _ocupadosDoDia(
  AgendaState state,
  OrdemServico os,
  DateTime dia,
) {
  final prof = os.profissional ?? '';
  if (prof.isEmpty) return const [];
  final disp = state.dispByProf[prof];
  return [
    for (final o in state.osList)
      if (o.id != os.id &&
          (o.profissional ?? '') == prof &&
          o.status != OSStatus.concluida &&
          o.status != OSStatus.cancelada)
        if (agendaEventBrt(o) case final brt? when sameDay(brt, dia))
          intervaloDaOs(o, disp),
  ];
}

/* ─────────────────────────── Semana (desktop) ─────────────────────────── */

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.state,
    required this.today,
    required this.onTap,
    required this.notifier,
  });
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;
  final AgendaController notifier;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final ws = startOfWeek(state.anchor);
    final days = [for (var i = 0; i < 7; i++) addDays(ws, i)];
    final eventosPorDia = [for (final d in days) state.eventsForDay(d)];
    // Janela ÚNICA para os 7 dias: sem isso as linhas de hora não alinham entre
    // as colunas (um evento às 5h num dia deslocaria só aquela coluna).
    final janela = janelaCompartilhada([
      for (final eventos in eventosPorDia)
        [
          for (final os in eventos)
            intervaloDaOs(os, state.dispByProf[os.profissional ?? '']),
        ],
    ]);

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
              const SizedBox(width: kAgendaReguaW),
              for (final d in days)
                Expanded(child: _WeekDayHeader(day: d, isToday: sameDay(d, today))),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AgendaHourGutter(dayStart: janela.inicio, dayEnd: janela.fim),
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: DayColumn(
                      day: days[i],
                      events: eventosPorDia[i],
                      onTap: onTap,
                      dayStart: janela.inicio,
                      dayEnd: janela.fim,
                      dispByProf: state.dispByProf,
                      // 1º prof da lista (nome) → esquerda; 2º → direita; …
                      profOrder: [
                        for (final p in state.profissionais) p.id,
                      ],
                      // Semana desktop: arrasta e MUDA DE DIA (D8).
                      editable: true,
                      permiteCrossDay: true,
                      hoje: today,
                      pendentes: state.pendentes,
                      onMover: (os, dia, startMin) =>
                          notifier.moverOs(os, dia: dia, startMin: startMin),
                      onRedimensionar: notifier.redimensionarOs,
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

/// Evento compacto (mês): hora + nome curto, cor do profissional.
class _EventChip extends StatelessWidget {
  const _EventChip({required this.os, required this.onTap});
  final OrdemServico os;
  final ValueChanged<OrdemServico> onTap;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final cor = corAgendaOs(os);
    final prof = os.expand?.profissional;
    final mostraAvatar =
        agendaMostraAvatar(os) && prof != null && prof.displayName != '—';
    final concluida = agendaMostraCheckConcluida(os);
    return GestureDetector(
      onTap: () => onTap(os),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: ClxSpace.x2, vertical: 2),
        decoration: BoxDecoration(
          color: corAgendaBg(cor),
          borderRadius: ClxRadii.rSm,
          border: Border(
            left: BorderSide(color: cor, width: 3),
          ),
        ),
        child: Row(
          children: [
            if (mostraAvatar) ...[
              Tooltip(
                message: prof.displayName,
                child: UserAvatar(user: prof, radius: 7),
              ),
              const SizedBox(width: 4),
            ],
            if (concluida) ...[
              Icon(Icons.check_circle, size: 12, color: cor),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                '${formatTime(os.dataHora)} ${os.clienteNomeExibicao.isEmpty ? '—' : os.clienteNomeExibicao}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: clx.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
  const _DayView({
    required this.state,
    required this.today,
    required this.onTap,
    required this.notifier,
  });
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;
  final AgendaController notifier;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final day = state.anchor;
    final isToday = sameDay(day, today);
    final events = state.eventsForDay(day);
    final janela = janelaCompartilhada([
      [
        for (final os in events)
          intervaloDaOs(os, state.dispByProf[os.profissional ?? '']),
      ],
    ]);

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
            padding: const EdgeInsets.only(right: ClxSpace.x4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AgendaHourGutter(dayStart: janela.inicio, dayEnd: janela.fim),
                Expanded(
                  child: DayColumn(
                    day: day,
                    events: events,
                    onTap: onTap,
                    dayStart: janela.inicio,
                    dayEnd: janela.fim,
                    dispByProf: state.dispByProf,
                    // 1º prof da lista (nome) → esquerda; 2º → direita; …
                    profOrder: [
                      for (final p in state.profissionais) p.id,
                    ],
                    // Visão dia: arrasta no tempo, mas não há coluna vizinha —
                    // sem cross-day (o arraste horizontal é ignorado).
                    editable: true,
                    hoje: today,
                    pendentes: state.pendentes,
                    onMover: (os, dia, startMin) =>
                        notifier.moverOs(os, dia: dia, startMin: startMin),
                    onRedimensionar: notifier.redimensionarOs,
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

/* ─────────────────────────── Mobile ─────────────────────────── */

/// Mini-card usado nas visões mobile (dia/semana/mês).
///
/// **Toque** abre o detalhe; **long-press** abre o sheet de ajuste (Fase 3/D3) —
/// só nas OS `agendada`/`atribuida` (D6): nas demais o gesto simplesmente não
/// existe, e nenhum enfeite promete o que a OS não pode fazer.
class _AgendaMiniCard extends StatelessWidget {
  const _AgendaMiniCard({
    required this.os,
    required this.onTap,
    this.onAjustar,
    this.disp,
    this.easypay = false,
  });
  final OrdemServico os;
  final ValueChanged<OrdemServico> onTap;

  /// Long-press → ajuste por sheet. Null (ou status travado) = sem gesto.
  final ValueChanged<OrdemServico>? onAjustar;

  /// Disponibilidade do profissional — 2º degrau do fallback de duração (D9).
  final Disponibilidade? disp;
  final bool easypay;

  @override
  Widget build(BuildContext context) {
    final card = KeyedSubtree(
      key: ValueKey('agenda-card-${os.id}'),
      child: _card(context),
    );
    final ajustar = onAjustar;
    if (ajustar == null || !osAjustavel(os)) return card;
    return GestureDetector(
      // Presente SÓ nas OS ajustáveis (D6) — é a afordância do long-press.
      key: ValueKey('agenda-card-lp-${os.id}'),
      // O toque continua chegando no InkWell do card (a arena dá o tap pra ele e
      // o long-press pra este detector, como num ListTile).
      onLongPress: () {
        HapticFeedback.mediumImpact();
        ajustar(os);
      },
      child: card,
    );
  }

  Widget _card(BuildContext context) {
    final clx = context.clx;
    final cor = corAgendaOs(os);
    final profUser = os.expand?.profissional;
    final prof = profUser?.displayName;
    final mostraAvatar =
        agendaMostraAvatar(os) && prof != null && prof != '—';
    final concluida = agendaMostraCheckConcluida(os);
    // Faixa "08:00–10:00" (duração efetiva: OS > profissional > 60). Card, nunca
    // tabela — R4.
    final faixa = faixaHorariaDaOs(os, disp);
    final sub = _agendaCardSubtitle(os);
    if (easypay) {
      return Padding(
        padding: const EdgeInsets.only(bottom: ClxSpace.x2),
        child: ClxFadeSlide(
          child: EasypayListCard(
            onTap: () => onTap(os),
            stripeColor: cor,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    cor.withValues(alpha: 0.22),
                    cor.withValues(alpha: 0.08),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: concluida
                  ? Icon(Icons.check_circle, color: cor, size: 22)
                  : Text(
                      formatTime(os.dataHora),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cor,
                      ),
                    ),
            ),
            title: os.clienteNomeExibicao.isEmpty ? '—' : os.clienteNomeExibicao,
            subtitle: '$faixa · $sub',
            trailing: StatusBadge(status: os.status, dense: true, refazer: os.refazer, vitrine: os.isVitrine),
          ),
        ),
      );
    }
    final tt = Theme.of(context).textTheme;
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
          color: corAgendaBg(cor),
          borderRadius: ClxRadii.rMd,
          border: Border(
            left: BorderSide(color: cor, width: 3),
          ),
        ),
        child: Row(
          children: [
            if (mostraAvatar && profUser != null) ...[
              Tooltip(
                message: profUser.displayName,
                child: UserAvatar(user: profUser, radius: 14),
              ),
              const SizedBox(width: ClxSpace.x2),
            ] else if (concluida) ...[
              Icon(Icons.check_circle, size: 20, color: cor),
              const SizedBox(width: ClxSpace.x2),
            ],
            Text(
              faixa,
              style: tt.bodySmall?.copyWith(
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
                    os.clienteNomeExibicao.isEmpty ? '—' : os.clienteNomeExibicao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      color: clx.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: clx.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ClxSpace.x2),
            StatusBadge(status: os.status, dense: true, refazer: os.refazer, vitrine: os.isVitrine),
          ],
        ),
      ),
    );
  }
}

/// Subtítulo do card mobile: serviço · valor · bairro.
/// Profissional fica só no avatar (quando atribuída/em andamento).
String _agendaCardSubtitle(OrdemServico os) {
  final servico = (os.tipoServicoNome ?? '').trim();
  final valor = os.valorServico;
  final end = (os.enderecoLiberado ?? '').trim();
  final bairro = os.bairro.trim();
  final local = end.isNotEmpty ? end : bairro;
  final parts = <String>[
    if (servico.isNotEmpty) servico else '—',
    if (valor != null && valor > 0) formatCurrency(valor),
    if (local.isNotEmpty) local,
  ];
  return parts.join(' · ');
}

class _MobileDayView extends StatelessWidget {
  const _MobileDayView({
    required this.state,
    required this.today,
    required this.onTap,
    this.onAjustar,
    this.easypay = false,
  });
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;
  final ValueChanged<OrdemServico>? onAjustar;
  final bool easypay;

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
          for (final os in events)
            _AgendaMiniCard(
              os: os,
              onTap: onTap,
              onAjustar: onAjustar,
              easypay: easypay,
              disp: state.dispByProf[os.profissional ?? ''],
            ),
      ],
    );
  }
}

class _MobileWeekView extends StatelessWidget {
  const _MobileWeekView({
    required this.state,
    required this.today,
    required this.onTap,
    this.onAjustar,
    this.easypay = false,
    this.onSelectDay,
    this.onWindowStart,
  });
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;
  final ValueChanged<OrdemServico>? onAjustar;
  final bool easypay;
  final ValueChanged<DateTime>? onSelectDay;
  final ValueChanged<DateTime>? onWindowStart;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    // Janela rolante: 7 dias a partir de [anchor] (não força segunda-feira).
    final ws = DateTime(state.anchor.year, state.anchor.month, state.anchor.day);
    final days = [for (var i = 0; i < 7; i++) addDays(ws, i)];
    final focus = state.selectedDay;
    final focusDay = days.any((d) => sameDay(d, focus))
        ? focus
        : (sameDay(focus, today) ? today : days.first);
    final dayEvents = state.eventsForDay(focusDay)
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

    if (easypay) {
      return Column(
        children: [
          EasypayWeekStrip(
            selected: focusDay,
            today: today,
            windowStart: ws,
            onSelect: (d) => onSelectDay?.call(d),
            onWindowStart: (d) => onWindowStart?.call(d),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: ClxMotion.standardDuration,
              switchInCurve: ClxMotion.emphasized,
              switchOutCurve: Curves.easeIn,
              child: dayEvents.isEmpty
                  ? const Center(
                      key: ValueKey('empty-day'),
                      child: EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: 'Sem atendimentos neste dia',
                        message:
                            'Arraste a faixa para ver outros dias, ou toque num dia.',
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey(
                        'day-${focusDay.year}-${focusDay.month}-${focusDay.day}',
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: dayEvents.length,
                      itemBuilder: (context, i) => _AgendaMiniCard(
                        os: dayEvents[i],
                        onTap: onTap,
                        onAjustar: onAjustar,
                        easypay: true,
                        disp:
                            state.dispByProf[dayEvents[i].profissional ?? ''],
                      ),
                    ),
            ),
          ),
        ],
      );
    }

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
              _AgendaMiniCard(
                os: os,
                onTap: onTap,
                onAjustar: onAjustar,
                disp: state.dispByProf[os.profissional ?? ''],
              ),
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
    this.onAjustar,
  });
  final AgendaState state;
  final DateTime today;
  final ValueChanged<OrdemServico> onTap;
  final ValueChanged<OrdemServico>? onAjustar;
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
          for (final os in selectedEvents)
            _AgendaMiniCard(
              os: os,
              onTap: onTap,
              onAjustar: onAjustar,
              disp: state.dispByProf[os.profissional ?? ''],
            ),
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
                    if (agendaMostraCheckConcluida(os))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.5),
                        child: Icon(
                          Icons.check_circle,
                          size: 7,
                          color: corAgendaOs(os),
                        ),
                      )
                    else
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: corAgendaOs(os),
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
