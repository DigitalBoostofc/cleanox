/// fin_recorrencia_test.dart — datas faltantes por frequência (semanal etc.).
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_derivations.dart';
import 'package:cleanos/painel/financeiro/fin_recorrencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semanal: todas as segundas no mês a partir da base', () {
    // 2026-07-27 é segunda-feira; em agosto: 3,10,17,24,31.
    final base = DateTime(2026, 7, 27);
    final faltam = datasRecorrenciaFaltantes(
      baseDate: base,
      frequencia: FrequenciaRecorrencia.semanal,
      periodo: const Periodo('2026-08-01', '2026-09-01'),
      datasExistentes: {'2026-07-27'},
    );
    expect(faltam, [
      '2026-08-03',
      '2026-08-10',
      '2026-08-17',
      '2026-08-24',
      '2026-08-31',
    ]);
  });

  test('semanal: não recria data que já existe', () {
    final base = DateTime(2026, 7, 27);
    final faltam = datasRecorrenciaFaltantes(
      baseDate: base,
      frequencia: FrequenciaRecorrencia.semanal,
      periodo: const Periodo('2026-08-01', '2026-09-01'),
      datasExistentes: {
        '2026-07-27',
        '2026-08-03',
        '2026-08-10',
        '2026-08-17',
        '2026-08-24',
        '2026-08-31',
      },
    );
    expect(faltam, isEmpty);
  });

  test('mensal: um por mês', () {
    final base = DateTime(2026, 7, 15);
    final faltam = datasRecorrenciaFaltantes(
      baseDate: base,
      frequencia: FrequenciaRecorrencia.mensal,
      periodo: const Periodo('2026-08-01', '2026-09-01'),
      datasExistentes: {'2026-07'},
    );
    expect(faltam, ['2026-08-15']);
  });

  test('a frente semanal: 3 semanas', () {
    final datas = datasRecorrenciaAFrente(
      baseDate: DateTime(2026, 7, 27),
      frequencia: FrequenciaRecorrencia.semanal,
      passos: 3,
    );
    expect(datas, ['2026-08-03', '2026-08-10', '2026-08-17']);
  });
}
