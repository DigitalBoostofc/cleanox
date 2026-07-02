/// Testes do fuso BRT (UTC-3) e utilitários puros. Espelha os casos de
/// getBrtDayBounds/localInputToPBDate/assertServiceIsToday do web — com `now`
/// injetado para serem DETERMINÍSTICOS em qualquer máquina/CI (gate G-8).
library;

import 'package:cleanos/core/formatters/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getBrtDayBounds (UTC-3)', () {
    test('UTC 02:00 ainda é o dia ANTERIOR em BRT', () {
      // UTC 2026-07-01 02:00 = BRT 2026-06-30 23:00 → dia BRT = 30/06.
      final b = getBrtDayBounds(now: DateTime.utc(2026, 7, 1, 2, 0, 0));
      expect(b.todayStart, '2026-06-30 03:00:00');
      expect(b.tomorrowStart, '2026-07-01 03:00:00');
    });

    test('UTC 15:00 é o mesmo dia em BRT', () {
      final b = getBrtDayBounds(now: DateTime.utc(2026, 7, 1, 15, 0, 0));
      expect(b.todayStart, '2026-07-01 03:00:00');
      expect(b.tomorrowStart, '2026-07-02 03:00:00');
    });
  });

  group('getBrtMonthBounds (1-based)', () {
    test('julho/2026', () {
      final r = getBrtMonthBounds(2026, 7);
      expect(r.start, '2026-07-01 03:00:00');
      expect(r.end, '2026-08-01 03:00:00');
    });
  });

  group('localInputToPBDate / pbDateToLocalInput', () {
    test('BRT 14:30 → UTC 17:30', () {
      expect(localInputToPBDate('2026-07-01T14:30'), '2026-07-01 17:30:00');
    });

    test('UTC 17:30 → BRT 14:30 (ida e volta)', () {
      expect(
        pbDateToLocalInput('2026-07-01 17:30:00.000Z'),
        '2026-07-01T14:30',
      );
      expect(pbDateToLocalInput('2026-07-01T17:30:00Z'), '2026-07-01T14:30');
    });

    test('vazio → vazio', () {
      expect(localInputToPBDate(''), '');
      expect(pbDateToLocalInput(''), '');
    });
  });

  group('parsePbUtc (A-07: offset explícito ±HH:MM)', () {
    test('formatos UTC do PB (com/sem Z, espaço ou T)', () {
      expect(
        parsePbUtc('2026-07-01 17:30:00.000Z'),
        DateTime.utc(2026, 7, 1, 17, 30),
      );
      expect(parsePbUtc('2026-07-01T17:30:00'), DateTime.utc(2026, 7, 1, 17, 30));
    });

    test('offset NEGATIVO -03:00 não ganha Z e converte pra UTC', () {
      expect(
        parsePbUtc('2026-07-01T14:30:00-03:00'),
        DateTime.utc(2026, 7, 1, 17, 30),
      );
      expect(
        parsePbUtc('2026-07-01 14:30:00-0300'),
        DateTime.utc(2026, 7, 1, 17, 30),
      );
    });

    test('offset POSITIVO segue funcionando', () {
      expect(
        parsePbUtc('2026-07-01T20:30:00+03:00'),
        DateTime.utc(2026, 7, 1, 17, 30),
      );
    });

    test('data sem hora não é confundida com offset (…-07-02)', () {
      // '-07-02' no fim NÃO pode casar o padrão de offset. Se casasse, o valor
      // seria parseado como HORÁRIO LOCAL do device (errado e não-determinístico);
      // sem casar, ganha 'Z' e o parse falha → null → placeholder ('—'), o
      // mesmo comportamento de antes do A-07 (o PB nunca manda data sem hora).
      expect(parsePbUtc('2026-07-02'), isNull);
    });

    test('vazio/inválido → null', () {
      expect(parsePbUtc(''), isNull);
      expect(parsePbUtc('não-é-data'), isNull);
    });
  });

  group('exibição em BRT', () {
    test('formatDate converte para o dia BRT', () {
      expect(formatDate('2026-07-01 02:00:00.000Z'), '30/06/2026');
    });
    test('formatHour em BRT', () {
      expect(formatHour('2026-07-01 17:00:00.000Z'), '14:00');
    });
    test('formatDateTime em BRT', () {
      expect(formatDateTime('2026-07-01 02:00:00.000Z'), '30/06/2026 23:00');
    });
    test('placeholders para vazio', () {
      expect(formatHour(''), '--:--');
      expect(formatDate(''), '—');
    });
  });

  group('moeda', () {
    test('formata BRL pt-BR', () {
      final s = formatCurrency(1234.5);
      expect(s.contains('1.234,50'), isTrue, reason: s);
      expect(s.startsWith(r'R$'), isTrue, reason: s);
    });
  });

  group('máscaras', () {
    test('telefone celular e fixo', () {
      expect(maskPhoneBR('11999990001'), '(11) 99999-0001');
      expect(maskPhoneBR('1133334444'), '(11) 3333-4444');
      expect(maskPhoneBR(''), '');
    });
    test('onlyDigitsPhone', () {
      expect(onlyDigitsPhone('(11) 99999-0001'), '11999990001');
    });
    test('CEP', () {
      expect(maskCEP('01310100'), '01310-100');
      expect(maskCEP('013'), '013');
    });
    test('splitNome', () {
      final r = splitNome('Carlos Silva Souza');
      expect(r.nome, 'Carlos');
      expect(r.sobrenome, 'Silva Souza');
      final u = splitNome('Ana');
      expect(u.sobrenome, '');
    });
  });

  group('gerarSlotsDisponiveis', () {
    test('dia ativo gera slots de 15 em 15', () {
      final slots = gerarSlotsDisponiveis(
        const DisponibilidadeDia(ativo: true, inicio: '08:00', fim: '10:00'),
        60,
        const [],
      );
      expect(slots, contains('08:00'));
      expect(slots, contains('09:00'));
      expect(slots.length, 5); // 08:00,08:15,08:30,08:45,09:00
    });

    test('dia inativo → vazio', () {
      final slots = gerarSlotsDisponiveis(
        const DisponibilidadeDia(ativo: false, inicio: '08:00', fim: '10:00'),
        60,
        const [],
      );
      expect(slots, isEmpty);
    });

    test('horário ocupado remove slots que colidem', () {
      final livre = gerarSlotsDisponiveis(
        const DisponibilidadeDia(ativo: true, inicio: '08:00', fim: '12:00'),
        60,
        const [],
      );
      final comOcupado = gerarSlotsDisponiveis(
        const DisponibilidadeDia(ativo: true, inicio: '08:00', fim: '12:00'),
        60,
        const ['10:00'],
      );
      expect(comOcupado.length, lessThan(livre.length));
      // slot 10:00 colide diretamente
      expect(comOcupado, isNot(contains('10:00')));
    });
  });
}
