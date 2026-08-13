import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/servico_taxonomia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada categoria tem grupos próprios', () {
    final v = gruposDaCategoria(Categoria.veicular);
    final r = gruposDaCategoria(Categoria.residencial);
    expect(v, containsAll([Grupo.plano, Grupo.avulsos]));
    expect(v, isNot(contains(Grupo.sofa)));
    expect(r, containsAll([Grupo.sofa, Grupo.colchao, Grupo.outros]));
    expect(r, isNot(contains(Grupo.plano)));
  });

  test('subgrupos mudam com o grupo', () {
    final bancos = subgruposDoGrupo(Categoria.veicular, Grupo.avulsos);
    expect(bancos.map((e) => e.wire), contains('bancos'));
    final sofa = subgruposDoGrupo(Categoria.residencial, Grupo.sofa);
    expect(sofa.map((e) => e.wire), contains('sofa_3'));
    // sofá não existe sob veicular
    expect(subgruposDoGrupo(Categoria.veicular, Grupo.sofa), isEmpty);
  });

  test('normalizar grupo inválido cai no primeiro da categoria', () {
    final g = normalizarGrupoNaCategoria(Categoria.veicular, Grupo.sofa);
    expect(g, Grupo.plano);
    final ok = normalizarGrupoNaCategoria(Categoria.residencial, Grupo.colchao);
    expect(ok, Grupo.colchao);
  });

  test('normalizar subgrupo inválido', () {
    final s = normalizarSubgrupo(
      categoria: Categoria.residencial,
      grupo: Grupo.sofa,
      subgrupo: 'nao_existe',
    );
    expect(s, isNotEmpty);
    expect(
      subgrupoPertenceAoGrupo(Categoria.residencial, Grupo.sofa, s),
      isTrue,
    );
    expect(
      normalizarSubgrupo(
        categoria: Categoria.veicular,
        grupo: Grupo.plano,
        subgrupo: 'premium',
      ),
      'premium',
    );
  });
}
