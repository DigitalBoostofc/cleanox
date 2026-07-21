/// CSV export helpers.
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finLancamentosToCsv inclui cabeçalho e linha', () {
    final csv = finLancamentosToCsv(
      lancs: [
        const FinLancamento(
          id: '1',
          descricao: 'Aluguel; moto',
          valor: 300,
          tipo: TipoLancamento.despesa,
          status: LancamentoStatus.pago,
          data: '2026-07-10',
          categoriaId: 'c1',
          contaId: 'a1',
          tags: ['fixo', 'op'],
        ),
      ],
      catById: {
        'c1': const FinCategoria(id: 'c1', nome: 'Transporte'),
      },
      contaById: {
        'a1': const FinConta(id: 'a1', nome: 'Carteira'),
      },
    );
    expect(csv, contains('data;tipo;descricao'));
    expect(csv, contains('2026-07-10'));
    expect(csv, contains('despesa'));
    expect(csv, contains('"Aluguel; moto"'));
    expect(csv, contains('fixo|op'));
    expect(csv, contains('Transporte'));
    expect(csv, contains('Carteira'));
  });
}
