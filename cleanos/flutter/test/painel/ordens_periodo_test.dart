/// ordens_periodo_test.dart — Janela BRT do filtro de período da lista de OS.
library;

import 'package:cleanos/painel/ordens/ordens_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ordensPeriodoRange — presets', () {
    final now = DateTime.utc(2026, 8, 14, 15);

    test('hoje / semana / mês / tudo não mudam', () {
      expect(ordensPeriodoRange(OrdensPeriodo.tudo, now: now), isNull);

      final hoje = ordensPeriodoRange(OrdensPeriodo.hoje, now: now)!;
      expect(hoje.start, '2026-08-14 03:00:00');
      expect(hoje.end, '2026-08-15 03:00:00');

      final semana = ordensPeriodoRange(OrdensPeriodo.semana, now: now)!;
      expect(semana.start, '2026-08-10 03:00:00'); // segunda
      expect(semana.end, '2026-08-17 03:00:00');

      final mes = ordensPeriodoRange(OrdensPeriodo.mes, now: now)!;
      expect(mes.start, '2026-08-01 03:00:00');
      expect(mes.end, '2026-09-01 03:00:00');
    });
  });

  group('ordensPeriodoRange — personalizado', () {
    test('um dia civil BRT vira [00:00, +1d) em UTC do PB', () {
      final range = ordensPeriodoRange(
        OrdensPeriodo.personalizado,
        personalizadoInicio: DateTime(2026, 7, 10),
      )!;
      expect(range.start, '2026-07-10 03:00:00');
      expect(range.end, '2026-07-11 03:00:00');
    });

    test('intervalo de–até é inclusivo no fim (half-open no PB)', () {
      final range = ordensPeriodoRange(
        OrdensPeriodo.personalizado,
        personalizadoInicio: DateTime(2026, 7, 10),
        personalizadoFim: DateTime(2026, 7, 12),
      )!;
      expect(range.start, '2026-07-10 03:00:00');
      expect(range.end, '2026-07-13 03:00:00');
    });

    test('sem data escolhida não vaza "Tudo" — devolve null sem crashar', () {
      expect(ordensPeriodoRange(OrdensPeriodo.personalizado), isNull);
    });
  });

  group('ordensPeriodoRotulo', () {
    test('presets usam o label do enum', () {
      expect(ordensPeriodoRotulo(const OrdensFilter()), 'Esta semana');
      expect(
        ordensPeriodoRotulo(const OrdensFilter(periodo: OrdensPeriodo.tudo)),
        'Tudo',
      );
    });

    test('personalizado de um dia mostra dd/MM/yyyy', () {
      expect(
        ordensPeriodoRotulo(
          OrdensFilter(
            periodo: OrdensPeriodo.personalizado,
            personalizadoInicio: DateTime(2026, 7, 10),
            personalizadoFim: DateTime(2026, 7, 10),
          ),
        ),
        '10/07/2026',
      );
    });

    test('personalizado com intervalo mostra de–até', () {
      expect(
        ordensPeriodoRotulo(
          OrdensFilter(
            periodo: OrdensPeriodo.personalizado,
            personalizadoInicio: DateTime(2026, 7, 10),
            personalizadoFim: DateTime(2026, 7, 12),
          ),
        ),
        '10/07/2026 – 12/07/2026',
      );
    });
  });
}
