/// agenda_controller.dart — Estado/dados da Agenda do Painel (calendário de OS).
///
/// Espelha `Agenda.tsx`: um CALENDÁRIO de ordens de serviço com três visões —
/// **dia**, **semana** e **mês** — navegáveis por período. Carrega as OS da janela
/// visível (`[from, to)` em BRT) com o profissional expandido e as posiciona por
/// dia/horário. O filtro de profissional é aplicado EM MEMÓRIA (como no React).
///
/// ⭐ Fuso BRT centralizado (gate G-8): os limites da janela saem de
/// `localInputToPBDate` (core) e o horário de cada OS é o relógio de parede BRT
/// (`parsePbUtc(...).subtract(kBrtOffset)`) — nunca conta de fuso solta.
///
/// ⚠️ As funções puras [buildAgendaGrid]/[weekdayIndexOf] (grade de slots por
/// disponibilidade) permanecem aqui por serem reusadas fora da Agenda
/// (`ordens/os_form.dart`) e cobertas por teste — a UI de calendário não as usa.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/disponibilidade.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';
import '../data/painel_filters.dart';
import '../data/painel_providers.dart';

/* ══════════════════════════════════════════════════════════════════════════
   HELPERS PUROS DE DISPONIBILIDADE (reuso por os_form.dart + testes)
   ────────────────────────────────────────────────────────────────────────── */

/// Tipo de célula da grade (grade de slots por disponibilidade — legado).
enum AgendaCellKind { vazio, livre, ocupado }

/// Célula (profissional × horário).
class AgendaCell {
  const AgendaCell(this.kind, [this.os]);
  final AgendaCellKind kind;
  final OrdemServico? os;

  static const AgendaCell vazio = AgendaCell(AgendaCellKind.vazio);
}

/// Grade derivada: colunas (profissionais) × linhas (horários), + índice.
class AgendaGrid {
  const AgendaGrid({
    required this.profissionais,
    required this.times,
    required this.cells,
  });

  final List<User> profissionais;
  final List<String> times;
  final Map<String, Map<String, AgendaCell>> cells;

  bool get isEmpty => times.isEmpty || profissionais.isEmpty;

  AgendaCell cell(String profId, String time) =>
      cells[profId]?[time] ?? AgendaCell.vazio;

  int get totalOcupados {
    var n = 0;
    for (final byTime in cells.values) {
      for (final c in byTime.values) {
        if (c.kind == AgendaCellKind.ocupado) n++;
      }
    }
    return n;
  }
}

/// Índice do dia da semana 0=Dom … 6=Sáb a partir de 'yyyy-MM-dd'.
int weekdayIndexOf(String date) {
  final d = DateTime.tryParse(date);
  if (d == null) return 0;
  return d.weekday % 7; // Dart: Seg=1..Dom=7 → Dom=0..Sáb=6
}

/// Monta a grade de slots por disponibilidade (função PURA — usada fora da
/// Agenda de calendário e coberta por teste).
AgendaGrid buildAgendaGrid({
  required String date,
  required List<User> profissionais,
  required Map<String, Disponibilidade> dispByProf,
  required List<OrdemServico> osList,
}) {
  final weekday = weekdayIndexOf(date);
  final cells = <String, Map<String, AgendaCell>>{};
  final timeSet = <String>{};

  final osByProf = <String, List<OrdemServico>>{};
  for (final os in osList) {
    final pid = os.profissional ?? '';
    if (pid.isEmpty) continue;
    (osByProf[pid] ??= []).add(os);
  }

  for (final prof in profissionais) {
    final byTime = <String, AgendaCell>{};
    final disp = dispByProf[prof.id];
    if (disp != null && weekday < disp.dias.length) {
      final dia = disp.dias[weekday];
      if (dia.ativo) {
        final slots = gerarSlotsDisponiveis(
          DisponibilidadeDia(ativo: true, inicio: dia.inicio, fim: dia.fim),
          disp.duracaoMin,
          const [],
        );
        for (final t in slots) {
          byTime[t] = const AgendaCell(AgendaCellKind.livre);
          timeSet.add(t);
        }
      }
    }
    for (final os in osByProf[prof.id] ?? const <OrdemServico>[]) {
      final t = formatTime(os.dataHora);
      if (t == '—') continue;
      byTime[t] = AgendaCell(AgendaCellKind.ocupado, os);
      timeSet.add(t);
    }
    cells[prof.id] = byTime;
  }

  final times = timeSet.toList()..sort();
  return AgendaGrid(profissionais: profissionais, times: times, cells: cells);
}

/* ══════════════════════════════════════════════════════════════════════════
   CALENDÁRIO — visões dia/semana/mês (espelha Agenda.tsx)
   ────────────────────────────────────────────────────────────────────────── */

/// Visão do calendário.
enum AgendaView { dia, semana, mes }

/// Horários exibidos na grade (6h → 22h, como no React).
const List<int> kAgendaHours = [
  6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
];

const List<String> kDowShort = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

const List<String> _mesLong = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];
const List<String> _mesAbbr = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];
const List<String> _dowLong = [
  'domingo', 'segunda-feira', 'terça-feira', 'quarta-feira',
  'quinta-feira', 'sexta-feira', 'sábado',
];

/// Dia da semana 0=Dom … 6=Sáb de um [DateTime].
int _dow(DateTime d) => d.weekday % 7;

/// Início da semana (segunda-feira) de [d] — espelha `startOfWeek` do React.
DateTime startOfWeek(DateTime d) {
  final r = DateTime(d.year, d.month, d.day);
  final day = r.weekday % 7; // 0=Dom
  return r.subtract(Duration(days: day == 0 ? 6 : day - 1));
}

/// [d] + [n] dias (aritmética date-only, imune a fuso).
DateTime addDays(DateTime d, int n) =>
    DateTime(d.year, d.month, d.day).add(Duration(days: n));

/// Mesmo dia do calendário (ano/mês/dia).
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 6 semanas do mês [year]/[month] (0-based month) — espelha `getMonthCalendar`.
List<List<DateTime>> monthCalendar(int year, int month) {
  var d = startOfWeek(DateTime(year, month, 1));
  final weeks = <List<DateTime>>[];
  for (var w = 0; w < 6; w++) {
    final week = <DateTime>[];
    for (var i = 0; i < 7; i++) {
      week.add(d);
      d = addDays(d, 1);
    }
    weeks.add(week);
    if (d.month > month || d.year > year) break;
  }
  return weeks;
}

/// Relógio de parede BRT de uma OS (para posicionar por dia/hora). Null se vazio.
DateTime? agendaEventBrt(OrdemServico os) {
  final utc = parsePbUtc(os.dataHora);
  return utc?.subtract(kBrtOffset);
}

/// Hora-slot (6..22) de uma OS no relógio BRT, com clamp nos extremos.
int agendaEventHour(OrdemServico os) {
  final brt = agendaEventBrt(os);
  final h = brt?.hour ?? kAgendaHours.first;
  return h.clamp(kAgendaHours.first, kAgendaHours.last);
}

/// Rótulo do período conforme a visão (PT-BR, BRT).
///
/// Na visão **semana**, [anchor] é o **início da janela de 7 dias** (rolante:
/// pode ser quarta→quarta/terça, não precisa ser segunda→domingo).
String agendaPeriodLabel(AgendaView view, DateTime anchor) {
  switch (view) {
    case AgendaView.dia:
      return '${_dowLong[_dow(anchor)]}, ${_dd(anchor.day)} de '
          '${_mesLong[anchor.month - 1]} de ${anchor.year}';
    case AgendaView.semana:
      // Janela rolante de 7 dias a partir de [anchor] (inclusive).
      // Ex.: quarta→terça, ou se começar num dia qualquer: "de X a Y".
      final ws = DateTime(anchor.year, anchor.month, anchor.day);
      final we = addDays(ws, 6);
      final sameMonth = ws.month == we.month && ws.year == we.year;
      if (sameMonth) {
        return '${kDowShort[_dow(ws)]} ${_dd(ws.day)} – '
            '${kDowShort[_dow(we)]} ${_dd(we.day)} '
            '${_mesAbbr[we.month - 1]} ${we.year}';
      }
      return '${kDowShort[_dow(ws)]} ${_dd(ws.day)} ${_mesAbbr[ws.month - 1]} – '
          '${kDowShort[_dow(we)]} ${_dd(we.day)} ${_mesAbbr[we.month - 1]} ${we.year}';
    case AgendaView.mes:
      return '${_mesLong[anchor.month - 1]} de ${anchor.year}';
  }
}

String _dd(int n) => n.toString().padLeft(2, '0');

/// Rótulo curto de um dia (mobile), ex.: 'SEG, 01 JUL'.
String agendaDayLabelShort(DateTime d) =>
    '${kDowShort[_dow(d)].toUpperCase()}, ${_dd(d.day)} '
    '${_mesAbbr[d.month - 1].toUpperCase()}';

/// Rótulo longo de um dia (cabeçalhos), ex.: 'segunda-feira, 01 de julho'.
String agendaDayLabelLong(DateTime d) =>
    '${_dowLong[_dow(d)]}, ${_dd(d.day)} de ${_mesLong[d.month - 1]}';

class AgendaState {
  const AgendaState({
    required this.anchor,
    required this.selectedDay,
    this.view = AgendaView.semana,
    this.profissionais = const [],
    this.osList = const [],
    this.loading = true,
    this.error,
    this.filterProfId,
  });

  /// Visão atual (dia/semana/mês).
  final AgendaView view;

  /// Âncora do período (date-only, BRT).
  final DateTime anchor;

  /// Dia selecionado na visão mês mobile (date-only, BRT).
  final DateTime selectedDay;

  final List<User> profissionais;
  final List<OrdemServico> osList;
  final bool loading;
  final String? error;

  /// Filtro opcional: só um profissional (null = todos).
  final String? filterProfId;

  /// OS após aplicar o filtro de profissional (em memória, como no React).
  List<OrdemServico> get filteredOs => filterProfId == null
      ? osList
      : osList.where((o) => o.profissional == filterProfId).toList();

  /// OS de um [dia] específico (relógio BRT).
  List<OrdemServico> eventsForDay(DateTime dia) => filteredOs.where((o) {
    final brt = agendaEventBrt(o);
    return brt != null && sameDay(brt, dia);
  }).toList();

  /// OS de um [dia] no slot de [hour].
  List<OrdemServico> eventsForHour(DateTime dia, int hour) => filteredOs.where((
    o,
  ) {
    final brt = agendaEventBrt(o);
    return brt != null && sameDay(brt, dia) && agendaEventHour(o) == hour;
  }).toList();

  AgendaState copyWith({
    AgendaView? view,
    DateTime? anchor,
    DateTime? selectedDay,
    List<User>? profissionais,
    List<OrdemServico>? osList,
    bool? loading,
    Object? error = _s,
    Object? filterProfId = _s,
  }) => AgendaState(
    view: view ?? this.view,
    anchor: anchor ?? this.anchor,
    selectedDay: selectedDay ?? this.selectedDay,
    profissionais: profissionais ?? this.profissionais,
    osList: osList ?? this.osList,
    loading: loading ?? this.loading,
    error: error == _s ? this.error : error as String?,
    filterProfId: filterProfId == _s
        ? this.filterProfId
        : filterProfId as String?,
  );

  static const Object _s = Object();
}

class AgendaController extends StateNotifier<AgendaState> {
  AgendaController(this._ref)
    : super(
        AgendaState(anchor: _todayDate(), selectedDay: _todayDate()),
      ) {
    _loadProfs();
    load();
  }

  final Ref _ref;

  /// Hoje como date-only (BRT).
  static DateTime _todayDate() {
    final d = DateTime.tryParse(todayLocalDate()) ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  /// Janela [from, to) da visão atual, em string UTC do PB (BRT centralizado).
  ({String start, String end}) _loadRange() {
    final view = state.view;
    final anchor = state.anchor;
    final DateTime from;
    final DateTime to;
    switch (view) {
      case AgendaView.dia:
        from = anchor;
        to = addDays(anchor, 1);
      case AgendaView.semana:
        // Janela rolante: carrega margem ampla p/ scroll contínuo da faixa.
        // [anchor] = primeiro dia visível (não força segunda-feira).
        from = addDays(anchor, -21);
        to = addDays(anchor, 28);
      case AgendaView.mes:
        from = startOfWeek(DateTime(anchor.year, anchor.month, 1));
        to = addDays(from, 42);
    }
    return (start: _pbMidnight(from), end: _pbMidnight(to));
  }

  /// 00:00 BRT de [d] como string UTC do PB.
  static String _pbMidnight(DateTime d) => localInputToPBDate(
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}T00:00',
  );

  Future<void> _loadProfs() async {
    try {
      final profs = await _ref
          .read(usuariosRepositoryProvider)
          .list(filter: profissionaisFilter(), sort: 'nome,name');
      if (mounted) state = state.copyWith(profissionais: profs);
    } catch (_) {
      /* filtro de profissional é opcional — silencioso */
    }
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final range = _loadRange();
      final res = await _ref
          .read(ordensRepositoryProvider)
          .list(
            page: 1,
            perPage: 500,
            filter: ordensFilter(
              dataInicio: range.start,
              dataFim: range.end,
            ),
            sort: 'data_hora',
            expand: 'profissional',
          );
      state = state.copyWith(osList: res.items, loading: false, error: null);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Não foi possível carregar a agenda.',
      );
    }
  }

  void setView(AgendaView view) {
    if (view == state.view) return;
    state = state.copyWith(view: view);
    load();
  }

  void goToday() {
    final hoje = _todayDate();
    state = state.copyWith(anchor: hoje, selectedDay: hoje);
    load();
  }

  void goPrev() => _shift(-1);
  void goNext() => _shift(1);

  /// Define o primeiro dia da janela de 7 dias (scroll contínuo da faixa).
  /// Não recarrega a cada pixel — só se a janela sair da margem carregada.
  ///
  /// Se o dia selecionado sair da nova janela [start, start+6], move a
  /// seleção para o dia mais próximo dentro dela (mantém o foco coerente).
  void setWeekWindowStart(DateTime start, {bool forceLoad = false}) {
    final s = DateTime(start.year, start.month, start.day);
    if (sameDay(s, state.anchor) && !forceLoad) return;
    final prev = state.anchor;
    final we = addDays(s, 6);
    var sel = state.selectedDay;
    if (sel.isBefore(s)) {
      sel = s;
    } else if (sel.isAfter(we)) {
      sel = we;
    }
    state = state.copyWith(anchor: s, selectedDay: sel);
    // Recarrega se avançou/recuou bastante (margem no buffer de load).
    if (forceLoad || (s.difference(prev).inDays).abs() >= 10) {
      load();
    }
  }

  void _shift(int dir) {
    final a = state.anchor;
    final DateTime next;
    switch (state.view) {
      case AgendaView.dia:
        next = addDays(a, dir);
      case AgendaView.semana:
        // Avança a janela rolante em 7 dias (setas ◀ ▶).
        next = addDays(a, dir * 7);
      case AgendaView.mes:
        next = DateTime(a.year, a.month + dir, 1);
    }
    final nextSelected = state.view == AgendaView.semana
        ? addDays(state.selectedDay, dir * 7)
        : state.selectedDay;
    state = state.copyWith(
      anchor: next,
      selectedDay: DateTime(
        nextSelected.year,
        nextSelected.month,
        nextSelected.day,
      ),
    );
    _syncSelectedForMonth(next);
    load();
  }

  /// Ao navegar meses (visão mês mobile), mantém o dia selecionado coerente.
  void _syncSelectedForMonth(DateTime anchor) {
    if (state.view != AgendaView.mes) return;
    final sel = state.selectedDay;
    if (sel.month == anchor.month && sel.year == anchor.year) return;
    final hoje = _todayDate();
    final todayInAnchor =
        hoje.year == anchor.year && hoje.month == anchor.month;
    state = state.copyWith(
      selectedDay: todayInAnchor
          ? hoje
          : DateTime(anchor.year, anchor.month, 1),
    );
  }

  void setSelectedDay(DateTime day) =>
      state = state.copyWith(selectedDay: DateTime(day.year, day.month, day.day));

  /// Clique num dia da visão mês (desktop) → abre a visão dia naquele dia.
  void openDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    state = state.copyWith(view: AgendaView.dia, anchor: d, selectedDay: d);
    load();
  }

  void setFilterProf(String? profId) {
    if (profId == state.filterProfId) return;
    state = state.copyWith(filterProfId: profId);
  }
}

final agendaControllerProvider =
    StateNotifierProvider.autoDispose<AgendaController, AgendaState>(
      AgendaController.new,
    );
