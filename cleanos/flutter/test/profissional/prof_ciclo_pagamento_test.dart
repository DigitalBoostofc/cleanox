/// Ciclo de pagamento (janela domingo→sábado etc.).
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/prof_comissao.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/financeiro/prof_pagamento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `now` é instante UTC real; brtWallDate subtrai 3h → usar ~15:00 UTC
  // para o dia civil BRT bater com o calendário.
  // Segunda 27/07/2026 BRT — semana fecha sábado 01/08.
  final seg27 = DateTime.utc(2026, 7, 27, 15);
  // Domingo 26/07/2026 BRT
  final dom26 = DateTime.utc(2026, 7, 26, 15);
  // Sábado 25/07/2026 BRT
  final sab25 = DateTime.utc(2026, 7, 25, 15);

  const hendrio = User(
    id: 'h1',
    name: 'Hendrio',
    role: Role.profissional,
    comissaoTipo: ComissaoTipo.percentual,
    comissaoValor: 30,
    pagamentoFrequencia: PagamentoFrequencia.semanal,
    pagamentoDia: 6, // sábado
  );

  group('cicloCorrente semanal (sábado)', () {
    test('domingo 26/07 → ciclo 26/07 a 01/08', () {
      final w = cicloCorrente(hendrio, now: dom26)!;
      expect(w.inicioYmd, '2026-07-26');
      expect(w.fimYmd, '2026-08-01');
      expect(w.labelBr, contains('26/07'));
      expect(w.labelBr, contains('01/08/2026'));
    });

    test('sábado 25/07 → ciclo 19/07 a 25/07 (fecha no dia)', () {
      final w = cicloCorrente(hendrio, now: sab25)!;
      expect(w.inicioYmd, '2026-07-19');
      expect(w.fimYmd, '2026-07-25');
    });

    test('segunda 27/07 → ainda no ciclo que fecha 01/08', () {
      final w = cicloCorrente(hendrio, now: seg27)!;
      expect(w.inicioYmd, '2026-07-26');
      expect(w.fimYmd, '2026-08-01');
    });
  });

  group('comissoesPendentesDoCiclo', () {
    test('só entra OS com data no ciclo; sem data entra (legado)', () {
      final coms = [
        const ProfComissao(
          id: 'c1',
          profissional: 'h1',
          os: 'a',
          valorComissao: 60,
          status: ComissaoStatus.pendente,
          data: '2026-07-26 00:00:00.000Z', // domingo — no ciclo
        ),
        const ProfComissao(
          id: 'c2',
          profissional: 'h1',
          os: 'b',
          valorComissao: 60,
          status: ComissaoStatus.pendente,
          data: '2026-07-25 00:00:00.000Z', // sábado anterior — fora
        ),
        const ProfComissao(
          id: 'c3',
          profissional: 'h1',
          os: 'c',
          valorComissao: 60,
          status: ComissaoStatus.pendente,
          // sem data
        ),
      ];
      final noCiclo = comissoesPendentesDoCiclo(hendrio, coms, now: dom26);
      expect(noCiclo.map((c) => c.id).toSet(), {'c1', 'c3'});
    });
  });

  group('formatDateOnlyBr / data de parede', () {
    test('meia-noite UTC não vira dia anterior', () {
      // formatDateOnlyBr está em fin_derivations — comissaoYmd só corta.
      expect(comissaoYmd(const ProfComissao(
        id: 'x',
        profissional: 'h',
        os: 'o',
        valorComissao: 1,
        data: '2026-07-26 00:00:00.000Z',
      )), '2026-07-26');
    });
  });
}
