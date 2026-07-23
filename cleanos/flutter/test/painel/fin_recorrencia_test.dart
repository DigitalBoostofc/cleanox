/// Testes da expansão de fixas/recorrentes (semanal ≠ mensal).
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_derivations.dart';
import 'package:cleanos/painel/financeiro/fin_recorrencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('datasRecorrenciaFaltantes · semanal', () {
    test('não colapsa o mês inteiro em 1 ocorrência', () {
      // 1ª despesa: 2026-07-01. Já existe só essa.
      // No mês de julho deve faltar 08, 15, 22, 29 — sem a do dia 1.
      final base = DateTime(2026, 7, 1);
      final periodo = Periodo('2026-07-01', '2026-08-01');
      final faltantes = datasRecorrenciaFaltantes(
        baseDate: base,
        frequencia: FrequenciaRecorrencia.semanal,
        periodo: periodo,
        datasExistentes: {'2026-07-01', '2026-07'}, // year-month NÃO bloqueia
      );
      expect(faltantes, [
        '2026-07-08',
        '2026-07-15',
        '2026-07-22',
        '2026-07-29',
      ]);
    });

    test('mensal ainda usa year-month (1 por mês)', () {
      final base = DateTime(2026, 7, 15);
      final periodo = Periodo('2026-07-01', '2026-10-01');
      final faltantes = datasRecorrenciaFaltantes(
        baseDate: base,
        frequencia: FrequenciaRecorrencia.mensal,
        periodo: periodo,
        datasExistentes: {'2026-07-15', '2026-07'},
      );
      // Julho ocupado; agosto e setembro faltam.
      expect(faltantes, ['2026-08-15', '2026-09-15']);
    });
  });

  group('datasRecorrenciaAFrente', () {
    test('semanal gera 52 passos de 7 dias', () {
      final base = DateTime(2026, 7, 21);
      final datas = datasRecorrenciaAFrente(
        baseDate: base,
        frequencia: FrequenciaRecorrencia.semanal,
        passos: 4,
      );
      expect(datas, [
        '2026-07-28',
        '2026-08-04',
        '2026-08-11',
        '2026-08-18',
      ]);
    });
  });

  group('serieJaTemData / chavesExistentesSerie', () {
    test('semanal: só YMD conta', () {
      final ex = chavesExistentesSerie(
        ['2026-07-21'],
        frequencia: FrequenciaRecorrencia.semanal,
      );
      expect(ex.contains('2026-07-21'), isTrue);
      expect(ex.contains('2026-07'), isFalse);
      expect(
        serieJaTemData(ex, '2026-07-28', frequencia: FrequenciaRecorrencia.semanal),
        isFalse,
      );
    });

    test('mensal: year-month bloqueia outro dia do mês', () {
      final ex = chavesExistentesSerie(
        ['2026-07-21'],
        frequencia: FrequenciaRecorrencia.mensal,
      );
      expect(ex.contains('2026-07'), isTrue);
      expect(
        serieJaTemData(ex, '2026-07-28', frequencia: FrequenciaRecorrencia.mensal),
        isTrue,
      );
    });
  });
}
