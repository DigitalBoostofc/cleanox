/// Testes de saldo previsto final do dia (Transações v2).
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_derivations.dart';
import 'package:flutter_test/flutter_test.dart';

FinLancamento _l({
  required String id,
  required String data,
  required double valor,
  required TipoLancamento tipo,
  required LancamentoStatus status,
}) =>
    FinLancamento(
      id: id,
      descricao: id,
      valor: valor,
      tipo: tipo,
      status: status,
      data: data,
      categoriaId: 'c1',
      contaId: 'a1',
    );

void main() {
  test('saldoPrevistoPorDia rebobina pagos futuros e projeta pendentes', () {
    // saldo atual 1000: já inclui +200 pago em 10 e -100 pago em 15
    // pendente -50 em 20
    final lancs = [
      _l(
        id: 'p1',
        data: '2026-07-10',
        valor: 200,
        tipo: TipoLancamento.receita,
        status: LancamentoStatus.pago,
      ),
      _l(
        id: 'p2',
        data: '2026-07-15',
        valor: 100,
        tipo: TipoLancamento.despesa,
        status: LancamentoStatus.pago,
      ),
      _l(
        id: 'x1',
        data: '2026-07-20',
        valor: 50,
        tipo: TipoLancamento.despesa,
        status: LancamentoStatus.pendente,
      ),
    ];
    final map = saldoPrevistoPorDia(saldoAtual: 1000, lancs: lancs);

    // Em 10: sem pagos depois rebobinados? há p2 pago depois → 1000 - (-100) = 1100
    // rebobina p2: cents -= (-100) => 1000+100=1100; sem abertos até 10
    expect(map['2026-07-10'], 1100);

    // Em 15: rebobina nada depois pago; sem aberto <=15 → 1000
    expect(map['2026-07-15'], 1000);

    // Em 20: rebobina 0; + aberto -50 → 950
    expect(map['2026-07-20'], 950);
  });
}
