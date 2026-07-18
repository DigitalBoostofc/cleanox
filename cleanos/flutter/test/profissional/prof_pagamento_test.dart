/// Próximo pagamento e a receber (ciclo da equipe).
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/prof_comissao.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/financeiro/prof_pagamento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-07-18 sábado 15:00 UTC = 12:00 BRT
  final now = DateTime.utc(2026, 7, 18, 15);

  group('proximaDataPagamento', () {
    test('diario → amanhã', () {
      final d = proximaDataPagamento(PagamentoFrequencia.diario, now: now)!;
      expect(d.day, 19);
      expect(d.month, 7);
    });

    test('semanal → próxima sexta', () {
      // sáb 18 → sexta 24
      final d = proximaDataPagamento(PagamentoFrequencia.semanal, now: now)!;
      expect(d.weekday, DateTime.friday);
      expect(d.day, 24);
    });

    test('quinzenal após dia 16 → dia 1 do mês seguinte', () {
      final d = proximaDataPagamento(PagamentoFrequencia.quinzenal, now: now)!;
      expect(d.day, 1);
      expect(d.month, 8);
    });

    test('quinzenal antes do 16 → dia 16 do mês', () {
      final n = DateTime.utc(2026, 7, 10, 15);
      final d = proximaDataPagamento(PagamentoFrequencia.quinzenal, now: n)!;
      expect(d.day, 16);
      expect(d.month, 7);
    });

    test('mensal → dia 1 do mês seguinte', () {
      final d = proximaDataPagamento(PagamentoFrequencia.mensal, now: now)!;
      expect(d.day, 1);
      expect(d.month, 8);
    });
  });

  group('buildPagamentoSnapshot', () {
    test('soma só pendentes', () {
      const me = User(
        id: 'p1',
        role: Role.profissional,
        comissaoTipo: ComissaoTipo.diaria,
        comissaoValor: 150,
        pagamentoFrequencia: PagamentoFrequencia.quinzenal,
      );
      final snap = buildPagamentoSnapshot(
        me: me,
        now: now,
        comissoes: [
          const ProfComissao(
            id: '1',
            profissional: 'p1',
            os: 'a',
            valorComissao: 150,
            status: ComissaoStatus.pendente,
          ),
          const ProfComissao(
            id: '2',
            profissional: 'p1',
            os: 'b',
            valorComissao: 150,
            status: ComissaoStatus.paga,
          ),
          const ProfComissao(
            id: '3',
            profissional: 'p1',
            os: 'c',
            valorComissao: 150,
            status: ComissaoStatus.pendente,
          ),
        ],
      );
      expect(snap.aReceber, 300);
      expect(snap.qtdPendentes, 2);
      expect(snap.frequencia, PagamentoFrequencia.quinzenal);
      expect(snap.proximoPagamento?.day, 1);
      expect(snap.proximoPagamento?.month, 8);
    });
  });
}
