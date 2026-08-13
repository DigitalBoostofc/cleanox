import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VitrineAdminServico s({
    String categoria = '',
    String grupo = '',
    String nome = 'x',
  }) =>
      VitrineAdminServico(
        id: '1',
        nome: nome,
        grupo: grupo,
        categoria: categoria,
        valorBase: 10,
        vitrine: true,
        vitrineDestaque: false,
        ativo: true,
      );

  test('macroCategoria classifica veicular e residencial', () {
    expect(s(categoria: 'veicular').macroCategoria, 'veicular');
    expect(s(categoria: 'residencial').macroCategoria, 'residencial');
    expect(s(grupo: 'colchao').macroCategoria, 'residencial');
    expect(s(grupo: 'auto').macroCategoria, 'veicular');
    expect(s(categoria: 'misc', grupo: 'plano').macroCategoria, 'outros');
  });
}
