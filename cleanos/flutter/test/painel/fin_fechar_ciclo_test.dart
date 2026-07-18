/// Agrupamento do fechar ciclo de pagamento (admin).
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/prof_comissao.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/financeiro/fin_fechar_ciclo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agrupa pendentes por prof e ignora pagas', () {
    const joao = User(
      id: 'j1',
      nome: 'João',
      role: Role.profissional,
      comissaoTipo: ComissaoTipo.percentual,
      comissaoValor: 30,
      pagamentoFrequencia: PagamentoFrequencia.quinzenal,
    );
    const hendrio = User(
      id: 'h1',
      nome: 'Hendrio',
      role: Role.profissional,
      comissaoTipo: ComissaoTipo.diaria,
      comissaoValor: 150,
      pagamentoFrequencia: PagamentoFrequencia.quinzenal,
    );
    final linhas = buildFecharCicloLinhas(
      profs: [joao, hendrio],
      comissoes: [
        const ProfComissao(
          id: 'c1',
          profissional: 'j1',
          os: 'a',
          valorComissao: 90,
          status: ComissaoStatus.pendente,
        ),
        const ProfComissao(
          id: 'c2',
          profissional: 'j1',
          os: 'b',
          valorComissao: 60,
          status: ComissaoStatus.pendente,
        ),
        const ProfComissao(
          id: 'c3',
          profissional: 'j1',
          os: 'c',
          valorComissao: 99,
          status: ComissaoStatus.paga,
        ),
        const ProfComissao(
          id: 'c4',
          profissional: 'h1',
          os: 'd',
          valorComissao: 150,
          status: ComissaoStatus.pendente,
        ),
      ],
    );
    expect(linhas, hasLength(2));
    expect(linhas.first.prof.id, 'j1'); // maior total primeiro
    expect(linhas.first.total, 150);
    expect(linhas.first.qtd, 2);
    expect(linhas.last.prof.id, 'h1');
    expect(linhas.last.total, 150);
  });

  test('sem pendentes → lista vazia', () {
    expect(
      buildFecharCicloLinhas(
        profs: const [],
        comissoes: [
          const ProfComissao(
            id: 'c',
            profissional: 'x',
            os: 'o',
            valorComissao: 10,
            status: ComissaoStatus.paga,
          ),
        ],
      ),
      isEmpty,
    );
  });
}
