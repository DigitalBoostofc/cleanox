/// Salário fixo no save e no extrato por profissional.
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/data/pb_comissao_repository.dart';
import 'package:cleanos/painel/financeiro/fin_comissoes_screen.dart';
import 'package:cleanos/painel/financeiro/salario_ocorrencias.dart';
import 'package:flutter_test/flutter_test.dart';

User _u({
  required String id,
  bool ativo = true,
  ComissaoTipo tipo = ComissaoTipo.nenhuma,
  double valor = 0,
  RemuneracaoTipo rem = RemuneracaoTipo.nenhuma,
  double remValor = 0,
  PagamentoFrequencia? freq,
  int dia = 0,
  int dia2 = 0,
}) =>
    User(
      id: id,
      role: Role.profissional,
      ativo: ativo,
      comissaoTipo: tipo,
      comissaoValor: valor,
      remuneracaoTipo: rem,
      remuneracaoValor: remValor,
      pagamentoFrequencia: freq,
      pagamentoDia: dia,
      pagamentoDia2: dia2,
    );

void main() {
  test('salário fixo grava ciclo quinzenal', () {
    final body = comissaoUserUpdateBody(
      tipo: ComissaoTipo.nenhuma,
      valor: 0,
      remuneracaoTipo: RemuneracaoTipo.salarioFixo,
      remuneracaoValor: 1500,
      pagamentoFrequencia: PagamentoFrequencia.quinzenal,
      pagamentoDia: 15,
      pagamentoDia2: 0,
    );
    expect(body['remuneracao_tipo'], 'salario_fixo');
    expect(body['remuneracao_valor'], 1500);
    expect(body['comissao_valor'], 0);
    expect(body['pagamento_frequencia'], isNotEmpty);
    expect(body['pagamento_dia'], 15);
  });

  test('sem comissão e sem salário limpa o ciclo', () {
    final body = comissaoUserUpdateBody(
      tipo: ComissaoTipo.nenhuma,
      valor: 0,
      remuneracaoTipo: RemuneracaoTipo.nenhuma,
      pagamentoFrequencia: PagamentoFrequencia.quinzenal,
      pagamentoDia: 15,
    );
    expect(body['pagamento_frequencia'], '');
    expect(body['pagamento_dia'], 0);
    expect(body['remuneracao_valor'], 0);
  });

  test('extrato lista salário mesmo sem linha de comissão', () {
    final breno = _u(
      id: 'breno',
      rem: RemuneracaoTipo.salarioFixo,
      remValor: 1500,
    );
    final hendrio = _u(
      id: 'hendrio',
      tipo: ComissaoTipo.percentual,
      valor: 30,
    );
    final ids = idsProfissionaisNoExtrato(
      profs: [breno, hendrio],
      items: const [],
    );
    expect(ids, containsAll(['breno', 'hendrio']));
  });

  test('extrato não lista inativo sem histórico', () {
    final ids = idsProfissionaisNoExtrato(
      profs: [
        _u(
          id: 'x',
          ativo: false,
          rem: RemuneracaoTipo.salarioFixo,
          remValor: 1500,
        ),
      ],
      items: const [],
    );
    expect(ids, isEmpty);
  });

  test('quinzena 15 pago e último dia do mês em aberto', () {
    final breno = _u(
      id: 'breno',
      rem: RemuneracaoTipo.salarioFixo,
      remValor: 1500,
      freq: PagamentoFrequencia.quinzenal,
      dia: 15,
      dia2: 0,
    );
    final planos = planejarOcorrenciasSalario(
      breno,
      now: DateTime.utc(2026, 8, 19),
    );
    expect(planos.map((p) => p.ymd), containsAll(['2026-08-15', '2026-08-31']));
    expect(
      planos.firstWhere((p) => p.ymd == '2026-08-15').status,
      ComissaoStatus.paga,
    );
    expect(
      planos.firstWhere((p) => p.ymd == '2026-08-31').status,
      ComissaoStatus.pendente,
    );
    expect(planos.map((p) => p.ymd), contains('2026-09-30'));
    expect(
      planos.firstWhere((p) => p.ymd == '2026-09-30').status,
      ComissaoStatus.pendente,
    );
  });
}
