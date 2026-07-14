/// Fronteira de privacidade do nome do cliente.
///
/// O Painel mostra o nome INTEIRO (vem do cofre, via `expand=cliente`).
/// O app do profissional NUNCA expande `cliente` — então tem que continuar
/// vendo o abreviado ("Carlos S."), sem nenhum `if (isPainel)` na UI.
///
/// Se alguém um dia trocar o fallback de `clienteNomeExibicao`, ou passar a
/// expandir `cliente` no repositório do profissional, estes testes quebram —
/// que é exatamente o ponto. Espelha o teste de integração `anti-desvio` C4,
/// que trava o mesmo contrato do lado do servidor.
library;

import 'package:cleanos/core/models/cliente.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const carlos = Cliente(id: 'c1', nome: 'Carlos', sobrenome: 'Silva');

  group('Cliente', () {
    test('nomeCompleto junta nome e sobrenome', () {
      expect(carlos.nomeCompleto, 'Carlos Silva');
    });

    test('nomeCompleto sem sobrenome não deixa espaço sobrando', () {
      expect(const Cliente(id: 'c2', nome: 'Ana').nomeCompleto, 'Ana');
    });

    test('nomeCurto segue abreviando (contrato do servidor)', () {
      expect(carlos.nomeCurto, 'Carlos S.');
    });
  });

  group('OrdemServico.clienteNomeExibicao', () {
    test('PAINEL: com o cofre expandido, mostra o nome INTEIRO', () {
      const os = OrdemServico(
        id: 'os1',
        nomeCurto: 'Carlos S.',
        expand: OSExpand(cliente: carlos),
      );
      expect(os.clienteNomeExibicao, 'Carlos Silva');
    });

    test('PROFISSIONAL: sem expand, cai no abreviado (não vaza sobrenome)', () {
      const os = OrdemServico(id: 'os1', nomeCurto: 'Carlos S.');
      expect(os.clienteNomeExibicao, 'Carlos S.');
      expect(os.clienteNomeExibicao, isNot(contains('Silva')));
    });

    test('expand presente mas SEM cliente também cai no abreviado', () {
      const os = OrdemServico(
        id: 'os1',
        nomeCurto: 'Carlos S.',
        expand: OSExpand(),
      );
      expect(os.clienteNomeExibicao, 'Carlos S.');
    });

    test('cofre com nome vazio não apaga o rótulo — usa o abreviado', () {
      const os = OrdemServico(
        id: 'os1',
        nomeCurto: 'Carlos S.',
        expand: OSExpand(cliente: Cliente(id: 'c9', nome: '   ')),
      );
      expect(os.clienteNomeExibicao, 'Carlos S.');
    });
  });
}
