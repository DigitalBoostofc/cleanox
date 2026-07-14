/// agenda_drag_gestures_test.dart — GESTOS do arraste na grade (Fase 2, §11).
///
/// Exercita o ponteiro de verdade (`WidgetTester.drag`/`timedDrag`) por cima do
/// [DayColumn] e cobra o que a spec promete:
/// - arrastar o CORPO move (novo `data_hora` = dia + minuto-BRT);
/// - arrastar a BORDA INFERIOR redimensiona (`duracao_min`, snap 15/mín 15);
/// - cross-day na semana (D8) e bloqueio de dia anterior (D7);
/// - status não-arrastável (D6) e OS com drop em voo NÃO têm alça nem arrastam.
library;

import 'package:cleanos/core/agenda/agenda_layout.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/painel/agenda/day_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painel_test_helpers.dart';

/// Dia da coluna: SEMPRE no futuro, para o piso do D7 nunca recortar o teste.
final DateTime _hoje = DateTime.parse(todayLocalDate());
final DateTime _dia = _hoje.add(const Duration(days: 2));

OrdemServico _os({
  String id = 'os1',
  String hhmm = '08:00',
  int? duracaoMin = 60,
  String nomeCurto = 'Ana',
  OSStatus status = OSStatus.agendada,
  DateTime? dia,
}) {
  final d = dia ?? _dia;
  return OrdemServico(
    id: id,
    nomeCurto: nomeCurto,
    status: status,
    duracaoMin: duracaoMin,
    dataHora: localInputToPBDate(
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}T$hhmm',
    ),
  );
}

/// Captura o que o drop mandou persistir.
class _Drops {
  DateTime? dia;
  int? startMin;
  int? duracaoMin;
  int movidas = 0;
  int redimensionadas = 0;
}

/// Sobe UMA coluna (visão dia) ou SETE (visão semana, com cross-day).
Future<_Drops> _pumpGrade(
  WidgetTester tester,
  List<OrdemServico> eventos, {
  bool semana = false,
  Set<String> pendentes = const {},
  bool editable = true,
  double larguraColuna = 160,
}) async {
  final drops = _Drops();
  final janela = janelaCompartilhada([
    [for (final os in eventos) intervaloDaOs(os)],
  ]);

  DayColumn coluna(DateTime dia, List<OrdemServico> doDia) => DayColumn(
    day: dia,
    events: doDia,
    onTap: (_) {},
    dayStart: janela.inicio,
    dayEnd: janela.fim,
    editable: editable,
    permiteCrossDay: semana,
    hoje: _hoje,
    pendentes: pendentes,
    onMover: (os, d, startMin) {
      drops.movidas++;
      drops.dia = d;
      drops.startMin = startMin;
    },
    onRedimensionar: (os, dur) {
      drops.redimensionadas++;
      drops.duracaoMin = dur;
    },
  );

  final dias = semana
      ? [for (var i = -1; i <= 2; i++) _dia.add(Duration(days: i))]
      : [_dia];

  await pumpPainel(
    tester,
    overrides: [...painelOverrides(user: painelUser())],
    SingleChildScrollView(
      // Reproduz a grade real: a coluna vive DENTRO de um scroll vertical — o
      // arraste do bloco precisa vencer o scroll na arena de gestos.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgendaHourGutter(dayStart: janela.inicio, dayEnd: janela.fim),
          for (final d in dias)
            SizedBox(
              width: larguraColuna,
              child: coluna(
                d,
                [
                  for (final os in eventos)
                    if (_mesmoDia(os, d)) os,
                ],
              ),
            ),
        ],
      ),
    ),
  );
  return drops;
}

bool _mesmoDia(OrdemServico os, DateTime d) {
  final brt = parsePbUtc(os.dataHora)!.subtract(kBrtOffset);
  return brt.year == d.year && brt.month == d.month && brt.day == d.day;
}

/// Centro do bloco (corpo) — pega o texto da faixa e sobe até o Material.
Finder _bloco(String faixa) =>
    find.ancestor(of: find.text(faixa), matching: find.byType(Material)).first;

void main() {
  testWidgets('arrastar o CORPO pra baixo move a OS (+1h, snap 15)', (
    tester,
  ) async {
    final drops = await _pumpGrade(tester, [_os(hhmm: '08:00')]);

    // 56px = 1 hora na escala da grade.
    await tester.drag(_bloco('08:00–09:00'), const Offset(0, 56));
    await tester.pumpAndSettle();

    expect(drops.movidas, 1);
    expect(drops.startMin, 9 * 60);
    expect(drops.dia, _dia);
    expect(drops.redimensionadas, 0, reason: 'o corpo não redimensiona');
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrastar o corpo pra CIMA (mais cedo no mesmo dia) é permitido', (
    tester,
  ) async {
    final drops = await _pumpGrade(tester, [_os(hhmm: '10:00')]);

    await tester.drag(_bloco('10:00–11:00'), const Offset(0, -28)); // −30 min
    await tester.pumpAndSettle();

    expect(drops.movidas, 1);
    expect(drops.startMin, 9 * 60 + 30);
  });

  testWidgets('arrastar a BORDA INFERIOR redimensiona (1h → 2h)', (
    tester,
  ) async {
    final drops = await _pumpGrade(tester, [_os(hhmm: '08:00')]);

    final r = tester.getRect(_bloco('08:00–09:00'));
    // A alça mora nos últimos ~8px do bloco.
    final naAlca = Offset(r.center.dx, r.bottom - 3);
    await tester.timedDragFrom(
      naAlca,
      const Offset(0, 56),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(drops.redimensionadas, 1);
    expect(drops.duracaoMin, 120);
    expect(drops.movidas, 0, reason: 'a alça não move a OS');
    expect(tester.takeException(), isNull);
  });

  testWidgets('resize não encolhe abaixo de 15 min', (tester) async {
    final drops = await _pumpGrade(tester, [_os(hhmm: '08:00', duracaoMin: 60)]);

    final r = tester.getRect(_bloco('08:00–09:00'));
    await tester.timedDragFrom(
      Offset(r.center.dx, r.bottom - 3),
      const Offset(0, -300),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(drops.redimensionadas, 1);
    expect(drops.duracaoMin, kDuracaoMinimaMin);
  });

  testWidgets('SEMANA: arrastar pra coluna da direita muda o DIA (D8)', (
    tester,
  ) async {
    final drops = await _pumpGrade(
      tester,
      [_os(hhmm: '09:00')],
      semana: true,
      larguraColuna: 160,
    );

    // 1 coluna à direita (160px) + 30 min pra baixo (28px).
    await tester.drag(_bloco('09:00–10:00'), const Offset(160, 28));
    await tester.pumpAndSettle();

    expect(drops.movidas, 1);
    expect(drops.dia, _dia.add(const Duration(days: 1)));
    expect(drops.startMin, 9 * 60 + 30);
  });

  testWidgets('SEMANA: não solta num dia ANTERIOR a hoje (D7)', (tester) async {
    // OS amanhã; arrasta 3 colunas pra esquerda → cairia ANTES de hoje.
    final amanha = _hoje.add(const Duration(days: 1));
    final drops = await _pumpGrade(
      tester,
      [_os(hhmm: '09:00', dia: amanha)],
      semana: true,
      larguraColuna: 160,
    );

    await tester.drag(_bloco('09:00–10:00'), const Offset(-480, 0));
    await tester.pumpAndSettle();

    expect(drops.movidas, 1);
    expect(drops.dia, _hoje, reason: 'recortado em hoje, não 2 dias atrás');
  });

  testWidgets('status NÃO arrastável (D6): sem alça e sem drop', (tester) async {
    final drops = await _pumpGrade(tester, [
      _os(id: 'ok', hhmm: '08:00', status: OSStatus.agendada),
      _os(id: 'trava', hhmm: '14:00', status: OSStatus.concluida),
      _os(id: 'trava2', hhmm: '16:00', status: OSStatus.cancelada),
      _os(id: 'trava3', hhmm: '18:00', status: OSStatus.emAndamento),
    ]);

    // Só a `agendada` tem alça de resize.
    expect(find.byKey(const ValueKey('agenda-alca-ok')), findsOneWidget);
    expect(find.byKey(const ValueKey('agenda-alca-trava')), findsNothing);
    expect(find.byKey(const ValueKey('agenda-alca-trava2')), findsNothing);
    expect(find.byKey(const ValueKey('agenda-alca-trava3')), findsNothing);

    // E arrastar a concluída não persiste nada.
    await tester.drag(_bloco('14:00–15:00'), const Offset(0, 56));
    await tester.pumpAndSettle();
    expect(drops.movidas, 0);
    expect(drops.redimensionadas, 0);
  });

  testWidgets('OS com drop EM VOO não arrasta de novo (R-A3)', (tester) async {
    final drops = await _pumpGrade(
      tester,
      [_os(id: 'voando', hhmm: '08:00')],
      pendentes: {'voando'},
    );

    expect(find.byKey(const ValueKey('agenda-alca-voando')), findsNothing);
    await tester.drag(_bloco('08:00–09:00'), const Offset(0, 56));
    await tester.pumpAndSettle();
    expect(drops.movidas, 0);
  });

  testWidgets('grade NÃO editável (Fase 1): nenhum bloco arrasta', (
    tester,
  ) async {
    final drops = await _pumpGrade(
      tester,
      [_os(hhmm: '08:00')],
      editable: false,
    );

    expect(find.byKey(const ValueKey('agenda-alca-os1')), findsNothing);
    await tester.drag(_bloco('08:00–09:00'), const Offset(0, 56));
    await tester.pumpAndSettle();
    expect(drops.movidas, 0);
  });

  testWidgets('arraste ínfimo (< 1 slot) não gera PATCH (drop inerte)', (
    tester,
  ) async {
    final drops = await _pumpGrade(tester, [_os(hhmm: '08:00')]);

    await tester.drag(_bloco('08:00–09:00'), const Offset(0, 3));
    await tester.pumpAndSettle();

    expect(drops.movidas, 0, reason: '3px < meio slot → mesma posição');
  });
}
