/// Payload de reatribuição solo/dupla no detalhe da OS.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/painel/ordens/os_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bodyReatribuicaoOs', () {
    test('solo com 1 profissional → atribuida, sem p2', () {
      final b = bodyReatribuicaoOs(
        profissionalId: 'p1',
        profissional2Id: 'p2',
        modo: ExecucaoModo.solo,
      );
      expect(b['profissional'], 'p1');
      expect(b['profissional2'], isNull);
      expect(b['execucao_modo'], 'solo');
      expect(b['status'], 'atribuida');
    });

    test('dupla com 2 distintos → modo dupla + p2', () {
      final b = bodyReatribuicaoOs(
        profissionalId: 'p1',
        profissional2Id: 'p2',
        modo: ExecucaoModo.dupla,
      );
      expect(b['profissional'], 'p1');
      expect(b['profissional2'], 'p2');
      expect(b['execucao_modo'], 'dupla');
      expect(b['status'], 'atribuida');
    });

    test('dupla com p2 == p1 vira solo (defesa)', () {
      final b = bodyReatribuicaoOs(
        profissionalId: 'p1',
        profissional2Id: 'p1',
        modo: ExecucaoModo.dupla,
      );
      expect(b['execucao_modo'], 'solo');
      expect(b['profissional2'], isNull);
    });

    test('sem profissional → agendada', () {
      final b = bodyReatribuicaoOs(
        profissionalId: '',
        profissional2Id: 'p2',
        modo: ExecucaoModo.solo,
      );
      expect(b['profissional'], isNull);
      expect(b['status'], 'agendada');
    });
  });
}
