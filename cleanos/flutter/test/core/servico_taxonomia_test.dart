import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/servico_taxonomia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada categoria tem grupos próprios (fallback estático)', () {
    final v = gruposDaCategoria(Categoria.veicular);
    final r = gruposDaCategoria(Categoria.residencial);
    expect(v, containsAll([Grupo.plano, Grupo.avulsos]));
    expect(v, isNot(contains(Grupo.sofa)));
    expect(r, containsAll([Grupo.sofa, Grupo.colchao, Grupo.outros]));
    expect(r, isNot(contains(Grupo.plano)));
  });

  test('subgrupos mudam com o grupo (fallback estático)', () {
    final bancos = subgruposDoGrupo(Categoria.veicular, Grupo.avulsos);
    expect(bancos.map((e) => e.wire), contains('bancos'));
    final sofa = subgruposDoGrupo(Categoria.residencial, Grupo.sofa);
    expect(sofa.map((e) => e.wire), contains('sofa_3'));
  });
}
