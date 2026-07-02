/// agenda_controller.dart — Estado/dados da Agenda do Painel (grade densa de slots).
///
/// A Agenda cruza, para um DIA (BRT), a DISPONIBILIDADE semanal de cada profissional
/// (gera os slots 'HH:MM' via `gerarSlotsDisponiveis` do core) com as ORDENS DE
/// SERVIÇO daquele dia (marca o slot ocupado). Consome só interfaces congeladas:
/// `UsuariosRepository`, `DisponibilidadeRepository`, `OrdensRepository`.
///
/// ⭐ Fuso BRT centralizado: os limites do dia saem de `localInputToPBDate` (core),
/// nunca de conta de fuso solta. A montagem da grade [buildAgendaGrid] é uma função
/// PURA (testável sem rede).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/disponibilidade.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';
import '../data/painel_filters.dart';
import '../data/painel_providers.dart';

/// Tipo de célula da grade.
enum AgendaCellKind { vazio, livre, ocupado }

/// Célula (profissional × horário).
class AgendaCell {
  const AgendaCell(this.kind, [this.os]);
  final AgendaCellKind kind;
  final OrdemServico? os;

  static const AgendaCell vazio = AgendaCell(AgendaCellKind.vazio);
}

/// Grade derivada: colunas (profissionais) × linhas (horários), + índice de células.
class AgendaGrid {
  const AgendaGrid({
    required this.profissionais,
    required this.times,
    required this.cells,
  });

  final List<User> profissionais;

  /// Horários 'HH:MM' ordenados (união dos slots + horários de OS do dia).
  final List<String> times;

  /// cells[profId][time] → célula. Ausência = vazio.
  final Map<String, Map<String, AgendaCell>> cells;

  bool get isEmpty => times.isEmpty || profissionais.isEmpty;

  AgendaCell cell(String profId, String time) =>
      cells[profId]?[time] ?? AgendaCell.vazio;

  /// Total de OS agendadas no dia (para o cabeçalho de resumo).
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

/// Monta a grade (função PURA). [dispByProf] = disponibilidade por id de profissional
/// (pode faltar); [osList] = OS do dia (com `profissional` preenchido).
AgendaGrid buildAgendaGrid({
  required String date,
  required List<User> profissionais,
  required Map<String, Disponibilidade> dispByProf,
  required List<OrdemServico> osList,
}) {
  final weekday = weekdayIndexOf(date);
  final cells = <String, Map<String, AgendaCell>>{};
  final timeSet = <String>{};

  // OS por profissional (horário BRT 'HH:MM').
  final osByProf = <String, List<OrdemServico>>{};
  for (final os in osList) {
    final pid = os.profissional ?? '';
    if (pid.isEmpty) continue;
    (osByProf[pid] ??= []).add(os);
  }

  for (final prof in profissionais) {
    final byTime = <String, AgendaCell>{};
    // 1) Slots livres da disponibilidade do dia.
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
    // 2) OS do dia sobrescrevem o slot como ocupado (e criam linha se off-grid).
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

class AgendaState {
  const AgendaState({
    required this.date,
    this.profissionais = const [],
    this.dispByProf = const {},
    this.osList = const [],
    this.loading = true,
    this.error,
    this.filterProfId,
  });

  /// Dia selecionado 'yyyy-MM-dd' (BRT).
  final String date;
  final List<User> profissionais;
  final Map<String, Disponibilidade> dispByProf;
  final List<OrdemServico> osList;
  final bool loading;
  final String? error;

  /// Filtro opcional: só um profissional (null = todos).
  final String? filterProfId;

  /// Profissionais visíveis após o filtro.
  List<User> get visibleProfissionais => filterProfId == null
      ? profissionais
      : profissionais.where((p) => p.id == filterProfId).toList();

  AgendaGrid get grid => buildAgendaGrid(
    date: date,
    profissionais: visibleProfissionais,
    dispByProf: dispByProf,
    osList: osList,
  );

  AgendaState copyWith({
    String? date,
    List<User>? profissionais,
    Map<String, Disponibilidade>? dispByProf,
    List<OrdemServico>? osList,
    bool? loading,
    Object? error = _s,
    Object? filterProfId = _s,
  }) => AgendaState(
    date: date ?? this.date,
    profissionais: profissionais ?? this.profissionais,
    dispByProf: dispByProf ?? this.dispByProf,
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
  AgendaController(this._ref) : super(AgendaState(date: todayLocalDate())) {
    load();
  }

  final Ref _ref;

  /// Limites [start, end) do dia [date] em string UTC do PB (BRT centralizado).
  static ({String start, String end}) _dayBounds(String date) {
    final start = localInputToPBDate('${date}T00:00');
    final d = DateTime.tryParse(date) ?? DateTime.now();
    final next = DateTime(d.year, d.month, d.day + 1);
    final nextDate =
        '${next.year.toString().padLeft(4, '0')}-'
        '${next.month.toString().padLeft(2, '0')}-'
        '${next.day.toString().padLeft(2, '0')}';
    final end = localInputToPBDate('${nextDate}T00:00');
    return (start: start, end: end);
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final bounds = _dayBounds(state.date);
      // Profissionais (equipe pequena) + disponibilidades (1 por prof) + OS do dia.
      final profs = await _ref
          .read(usuariosRepositoryProvider)
          .list(filter: profissionaisFilter(), sort: 'nome,name');

      final dispRes = await _ref
          .read(disponibilidadeRepositoryProvider)
          .list(page: 1, perPage: 200);
      final dispByProf = {
        for (final d in dispRes.items)
          if (d.profissional.isNotEmpty) d.profissional: d,
      };

      final osRes = await _ref
          .read(ordensRepositoryProvider)
          .list(
            page: 1,
            perPage: 200,
            filter: ordensFilter(dataInicio: bounds.start, dataFim: bounds.end),
            sort: 'data_hora',
            expand: 'profissional',
          );

      state = state.copyWith(
        profissionais: profs,
        dispByProf: dispByProf,
        osList: osRes.items,
        loading: false,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Não foi possível carregar a agenda.',
      );
    }
  }

  void setDate(String date) {
    if (date == state.date) return;
    state = state.copyWith(date: date);
    load();
  }

  /// Avança/retrocede [days] dias a partir do dia atual.
  void shiftDays(int days) {
    final d = DateTime.tryParse(state.date) ?? DateTime.now();
    final n = DateTime(d.year, d.month, d.day + days);
    setDate(
      '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}',
    );
  }

  void goToday() => setDate(todayLocalDate());

  void setFilterProf(String? profId) {
    if (profId == state.filterProfId) return;
    state = state.copyWith(filterProfId: profId);
  }
}

final agendaControllerProvider =
    StateNotifierProvider.autoDispose<AgendaController, AgendaState>(
      AgendaController.new,
    );
