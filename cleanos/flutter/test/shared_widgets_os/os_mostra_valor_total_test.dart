import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/shared_widgets_os/os_financeiro_resumo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sem extra e sem desconto, não mostra Valor total', () {
    final os = OrdemServico(id: 'a', valorServico: 200, valorPago: 250);
    expect(osMostraValorTotal(os), isFalse);
    expect(os.valorTotal, 200);
  });

  test('com extra cobrável, mostra Valor total', () {
    final os = OrdemServico(
      id: 'b',
      valorServico: 200,
      adicionais: const [
        ServicoAdicionalOS(nome: 'Tapete', valor: 50),
      ],
    );
    expect(osMostraValorTotal(os), isTrue);
    expect(os.valorTotal, 250);
  });

  test('com desconto, mostra Valor total', () {
    final os = OrdemServico(id: 'c', valorServico: 200, descontos: 20);
    expect(osMostraValorTotal(os), isTrue);
    expect(os.valorTotal, 180);
  });
}
