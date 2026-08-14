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

  test('hierarquia de produto para em grupo (serviço não exige subgrupo)', () {
    expect(
      grupoPertenceACategoria(Categoria.veicular, Grupo.avulsos),
      isTrue,
    );
    expect(
      grupoPertenceACategoria(Categoria.residencial, Grupo.plano),
      isFalse,
    );
    // Helpers de subgrupo permanecem só por compatibilidade do campo legado.
    expect(
      normalizarSubgrupo(
        categoria: Categoria.veicular,
        grupo: Grupo.avulsos,
        subgrupo: '',
      ),
      isNotEmpty,
    );
  });
}
