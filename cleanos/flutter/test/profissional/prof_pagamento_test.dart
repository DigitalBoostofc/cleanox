/// Ciclo de pagamento, perspectiva e histórico.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/prof_comissao.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/financeiro/prof_pagamento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-07-18 sábado 15:00 UTC = 12:00 BRT
  final now = DateTime.utc(2026, 7, 18, 15);

  User prof({
    PagamentoFrequencia? freq = PagamentoFrequencia.quinzenal,
    int dia = 0,
    int dia2 = 0,
    ComissaoTipo tipo = ComissaoTipo.percentual,
    double valor = 30,
  }) =>
      User(
        id: 'p1',
        role: Role.profissional,
        comissaoTipo: tipo,
        comissaoValor: valor,
        pagamentoFrequencia: freq,
        pagamentoDia: dia,
        pagamentoDia2: dia2,
      );

  group('proximaDataPagamento', () {
    test('diario → amanhã', () {
      final d = proximaDataPagamento(
        prof(freq: PagamentoFrequencia.diario),
        now: now,
      )!;
      expect(d.day, 19);
      expect(d.month, 7);
    });

    test('semanal sexta → próxima sexta 24', () {
      final d = proximaDataPagamento(
        prof(freq: PagamentoFrequencia.semanal, dia: 5),
        now: now,
      )!;
      expect(d.weekday, DateTime.friday);
      expect(d.day, 24);
    });

    test('quinzenal default 15 e fim → 31/07 (sáb 18)', () {
      final d = proximaDataPagamento(
        prof(freq: PagamentoFrequencia.quinzenal),
        now: now,
      )!;
      // 15 já passou (hoje 18) → próximo é último dia 31
      expect(d.day, 31);
      expect(d.month, 7);
    });

    test('quinzenal antes do 15 → dia 15', () {
      final n = DateTime.utc(2026, 7, 10, 15);
      final d = proximaDataPagamento(
        prof(freq: PagamentoFrequencia.quinzenal),
        now: n,
      )!;
      expect(d.day, 15);
      expect(d.month, 7);
    });

    test('mensal dia 1 → 01/08', () {
      final d = proximaDataPagamento(
        prof(freq: PagamentoFrequencia.mensal, dia: 1),
        now: now,
      )!;
      expect(d.day, 1);
      expect(d.month, 8);
    });

    test('mensal dia 20 configurável', () {
      final d = proximaDataPagamento(
        prof(freq: PagamentoFrequencia.mensal, dia: 20),
        now: now,
      )!;
      expect(d.day, 20);
      expect(d.month, 7);
    });
  });

  group('buildPagamentoSnapshot', () {
    test('a receber = pendentes; perspectiva = abertas no ciclo', () {
      final me = prof();
      final snap = buildPagamentoSnapshot(
        me: me,
        now: now,
        comissoes: [
          const ProfComissao(
            id: '1',
            profissional: 'p1',
            os: 'a',
            valorComissao: 90,
            status: ComissaoStatus.pendente,
            descricao: 'OS A',
          ),
          const ProfComissao(
            id: '2',
            profissional: 'p1',
            os: 'b',
            valorComissao: 90,
            status: ComissaoStatus.paga,
            data: '2026-07-01',
            descricao: 'OS B',
          ),
        ],
        ordensAbertasCiclo: [
          const OrdemServico(
            id: 'x',
            status: OSStatus.atribuida,
            valorServico: 200,
            dataHora: '2026-07-25 11:00:00.000Z',
          ),
          const OrdemServico(
            id: 'y',
            status: OSStatus.atribuida,
            valorServico: 200,
            dataHora: '2026-07-28 11:00:00.000Z',
          ),
        ],
      );
      expect(snap.aReceber, 90);
      expect(snap.qtdPendentes, 1);
      // 30% de 200 = 60 × 2
      expect(snap.perspectiva, 120);
      expect(snap.qtdAbertasCiclo, 2);
      expect(snap.historico, hasLength(1));
      expect(snap.historico.first.total, 90);
      expect(snap.proximoPagamento?.day, 31);
    });
  });

  group('cicloPagamentoLabel', () {
    test('quinzenal', () {
      expect(
        cicloPagamentoLabel(prof(freq: PagamentoFrequencia.quinzenal)),
        contains('Quinzenal'),
      );
    });
  });
}
