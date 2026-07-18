/// agenda_day_column_test.dart — A coluna de um dia (grade time-grid do desktop).
///
/// Trava o que a spec §6 promete no RENDER: bloco proporcional à duração (2h é o
/// dobro de 1h), OS sobrepostas lado a lado (metade da largura cada), excedente do
/// aglomerado virando chip "+N" e altura visual mínima para blocos curtos. Nada de
/// pacote de calendário — só o núcleo puro + Stack posicionado por minuto.
library;

import 'package:cleanos/core/agenda/agenda_layout.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/painel/agenda/day_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painel_test_helpers.dart';

final DateTime _dia = DateTime.parse(todayLocalDate());

OrdemServico _os({
  required String id,
  required String hhmm,
  int? duracaoMin,
  String nomeCurto = 'Cliente',
  OSStatus status = OSStatus.agendada,
  String? tipoServicoNome,
  double? valorServico,
  String bairro = '',
}) => OrdemServico(
  id: id,
  nomeCurto: nomeCurto,
  status: status,
  duracaoMin: duracaoMin,
  tipoServicoNome: tipoServicoNome,
  valorServico: valorServico,
  bairro: bairro,
  dataHora: localInputToPBDate(
    '${_dia.year.toString().padLeft(4, '0')}-'
    '${_dia.month.toString().padLeft(2, '0')}-'
    '${_dia.day.toString().padLeft(2, '0')}T$hhmm',
  ),
);

Future<void> _pump(WidgetTester tester, List<OrdemServico> eventos) async {
  final janela = janelaCompartilhada([
    [for (final os in eventos) intervaloDaOs(os)],
  ]);
  await pumpPainel(
    tester,
    overrides: [...painelOverrides(user: painelUser())],
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AgendaHourGutter(dayStart: janela.inicio, dayEnd: janela.fim),
        Expanded(
          child: DayColumn(
            day: _dia,
            events: eventos,
            onTap: (_) {},
            dayStart: janela.inicio,
            dayEnd: janela.fim,
          ),
        ),
      ],
    ),
  );
  await tester.pump();
}

/// Retângulo do bloco de uma OS (o Material colorido dentro do Positioned).
Rect _rectDe(WidgetTester tester, String faixa) {
  final bloco = find
      .ancestor(of: find.text(faixa), matching: find.byType(Material))
      .first;
  return tester.getRect(bloco);
}

void main() {
  testWidgets('bloco é proporcional à duração (2h = o dobro de 1h)', (
    tester,
  ) async {
    await _pump(tester, [
      _os(id: 'curta', hhmm: '08:00', duracaoMin: 60, nomeCurto: 'Ana'),
      _os(id: 'longa', hhmm: '14:00', duracaoMin: 120, nomeCurto: 'Bia'),
    ]);

    final curta = _rectDe(tester, '08:00–09:00');
    final longa = _rectDe(tester, '14:00–16:00');
    expect(curta.height, closeTo(60 * kAgendaPxPorMin, 2));
    expect(longa.height, closeTo(120 * kAgendaPxPorMin, 2));
    expect(longa.height, closeTo(curta.height * 2, 2));
    // Posição vertical proporcional ao início (14h está abaixo de 8h).
    expect(longa.top, greaterThan(curta.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('OS sobrepostas ficam lado a lado (metade da largura cada)', (
    tester,
  ) async {
    await _pump(tester, [
      _os(id: 'a', hhmm: '09:00', duracaoMin: 120, nomeCurto: 'Ana'),
      _os(id: 'b', hhmm: '10:00', duracaoMin: 120, nomeCurto: 'Bia'),
    ]);

    final a = _rectDe(tester, '09:00–11:00');
    final b = _rectDe(tester, '10:00–12:00');
    // Mesma largura (~metade da coluna) e colunas distintas — B à direita de A.
    expect(b.width, closeTo(a.width, 4));
    expect(b.left, greaterThan(a.left));
    expect(a.left + a.width, lessThanOrEqualTo(b.left + 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bloco curto (15min) respeita a altura visual mínima', (
    tester,
  ) async {
    await _pump(tester, [
      _os(id: 'curtinha', hhmm: '08:00', duracaoMin: 15, nomeCurto: 'Ana'),
    ]);
    final r = _rectDe(tester, '08:00–08:15 Ana');
    // 15min × escala daria ~14px; o piso visual sobe pra ~24px (−1px do respiro
    // entre blocos). Sem isso o bloco curto vira um risco ilegível.
    expect(r.height, greaterThanOrEqualTo(kAgendaAlturaMinBlocoPx - 1.5));
    expect(r.height, greaterThan(15 * kAgendaPxPorMin));
    expect(tester.takeException(), isNull);
  });

  testWidgets('além do teto de colunas, o excedente vira chip "+N"', (
    tester,
  ) async {
    await _pump(tester, [
      for (var i = 0; i < 8; i++)
        _os(
          id: 'os$i',
          hhmm: '13:00',
          duracaoMin: 60,
          nomeCurto: 'Cliente $i',
        ),
    ]);

    // 5 colunas no desktop → 3 sobram.
    expect(find.text('+3'), findsOneWidget);
    expect(find.textContaining('13:00–14:00'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('OS antiga (sem duracao_min) cai no padrão de 60 min', (
    tester,
  ) async {
    await _pump(tester, [_os(id: 'velha', hhmm: '08:00', nomeCurto: 'Ana')]);
    expect(find.text('08:00–09:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('evento fora da janela padrão (5h) aparece — janela expande', (
    tester,
  ) async {
    await _pump(tester, [
      _os(id: 'cedo', hhmm: '05:30', duracaoMin: 60, nomeCurto: 'Ana'),
    ]);
    expect(find.text('05:30–06:30'), findsOneWidget);
    // A régua ganhou a linha das 5h.
    expect(find.text('5h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bloco alto mostra serviço, valor e bairro além de horário/cliente',
    (tester) async {
      // 2h ≈ 112px → cabem faixa + cliente + serviço + valor·bairro.
      await _pump(tester, [
        _os(
          id: 'cheia',
          hhmm: '08:00',
          duracaoMin: 120,
          nomeCurto: 'Andreia Araujo',
          tipoServicoNome: 'Higienização de sofá',
          valorServico: 280,
          bairro: 'Centro',
        ),
      ]);

      expect(find.text('08:00–10:00'), findsOneWidget);
      expect(find.text('Andreia Araujo'), findsOneWidget);
      expect(find.text('Higienização de sofá'), findsOneWidget);
      // Valor + bairro na mesma linha (meta).
      expect(find.textContaining('Centro'), findsOneWidget);
      expect(find.textContaining('R\$'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bloco curto (<45min) não empilha serviço/valor/bairro', (
    tester,
  ) async {
    await _pump(tester, [
      _os(
        id: 'curta',
        hhmm: '08:00',
        duracaoMin: 30,
        nomeCurto: 'Ana',
        tipoServicoNome: 'Higienização de sofá',
        valorServico: 150,
        bairro: 'Centro',
      ),
    ]);

    // Compacto: faixa + cliente na mesma linha; sem linhas extras.
    expect(find.text('08:00–08:30 Ana'), findsOneWidget);
    expect(find.text('Higienização de sofá'), findsNothing);
    expect(find.textContaining('Centro'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
