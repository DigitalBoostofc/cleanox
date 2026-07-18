/// Regressão: grade do mês alinhada com cabeçalhos Dom…Sáb.
///
/// Bug real (2026-07): `startOfWeek` começava na segunda e `kDowShort` era
/// Dom-first — sábado 18/07/2026 caía na coluna "Sex".
library;

import 'package:cleanos/painel/agenda/agenda_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startOfWeek (domingo)', () {
    test('domingo fica no mesmo dia', () {
      // 2026-07-19 = domingo
      final d = DateTime(2026, 7, 19);
      expect(d.weekday, DateTime.sunday);
      final ws = startOfWeek(d);
      expect(ws, DateTime(2026, 7, 19));
    });

    test('sábado volta 6 dias (ao domingo anterior)', () {
      // 2026-07-18 = sábado
      final d = DateTime(2026, 7, 18);
      expect(d.weekday, DateTime.saturday);
      final ws = startOfWeek(d);
      expect(ws, DateTime(2026, 7, 12)); // domingo
      expect(ws.weekday, DateTime.sunday);
    });

    test('segunda volta 1 dia', () {
      final d = DateTime(2026, 7, 13); // segunda
      expect(startOfWeek(d), DateTime(2026, 7, 12));
    });
  });

  group('monthCalendar × kDowShort', () {
    test('cada coluna bate com o rótulo Dom…Sáb', () {
      final weeks = monthCalendar(2026, 7);
      expect(weeks, isNotEmpty);
      expect(kDowShort, ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']);

      for (final week in weeks) {
        expect(week, hasLength(7));
        for (var i = 0; i < 7; i++) {
          final day = week[i];
          // weekday % 7: Dom=0 … Sáb=6 — igual ao índice da coluna.
          expect(
            day.weekday % 7,
            i,
            reason:
                '${day.day}/${day.month} (weekday=${day.weekday}) '
                'na col $i (${kDowShort[i]})',
          );
        }
      }
    });

    test('18/07/2026 (sábado) fica sob a coluna Sáb — não sob Sex', () {
      final weeks = monthCalendar(2026, 7);
      DateTime? found;
      var col = -1;
      for (final week in weeks) {
        for (var i = 0; i < week.length; i++) {
          final d = week[i];
          if (d.year == 2026 && d.month == 7 && d.day == 18) {
            found = d;
            col = i;
          }
        }
      }
      expect(found, isNotNull);
      expect(col, 6, reason: 'sábado deve ser a última coluna (Sáb)');
      expect(kDowShort[col], 'Sáb');
      expect(found!.weekday, DateTime.saturday);
    });

    test('1/07/2026 (quarta) sob Qua', () {
      final weeks = monthCalendar(2026, 7);
      // primeira semana: 28/06 Dom … 4/07 Sáb; dia 1 = col 3 (Qua)
      final first = weeks.first;
      expect(first[3].day, 1);
      expect(first[3].month, 7);
      expect(kDowShort[3], 'Qua');
      expect(first[3].weekday, DateTime.wednesday);
    });
  });
}
