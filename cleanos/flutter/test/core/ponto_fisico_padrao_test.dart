import 'package:cleanos/core/models/ponto_fisico.dart';
import 'package:flutter_test/flutter_test.dart';

PontoFisico _p(String id, {String nome = 'Sede'}) => PontoFisico(
  id: id,
  nome: nome,
  enderecoRua: 'Rua A',
  enderecoNumero: '1',
  enderecoBairro: 'Centro',
  enderecoCidade: 'Fortaleza',
  enderecoEstado: 'CE',
);

void main() {
  test('pontosFisicosUnicos remove id vazio e repetido', () {
    expect(
      pontosFisicosUnicos([
        _p('a'),
        _p(''),
        _p('a', nome: 'Sede 2'),
        _p('b', nome: 'Filial'),
      ]).map((p) => p.id),
      ['a', 'b'],
    );
  });

  test('idPontoFisicoPadrao escolhe o único cadastrado', () {
    expect(idPontoFisicoPadrao(pontos: [_p('sede')]), 'sede');
  });

  test('idPontoFisicoPadrao não escolhe quando há 0 ou 2 pontos', () {
    expect(idPontoFisicoPadrao(pontos: const []), isNull);
    expect(
      idPontoFisicoPadrao(pontos: [_p('a'), _p('b', nome: 'Filial')]),
      isNull,
    );
  });

  test('idPontoFisicoPadrao mantém o ponto já escolhido', () {
    expect(
      idPontoFisicoPadrao(
        pontos: [_p('a'), _p('b', nome: 'Filial')],
        atual: 'b',
      ),
      'b',
    );
    expect(idPontoFisicoPadrao(pontos: [_p('sede')], atual: 'antigo'), 'antigo');
  });
}
