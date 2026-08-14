import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/painel/servicos/taxonomia/taxonomia_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('árvore agrupa categoria → grupo (subgrupo legado só parseia)', () {
    final arvore = TaxonomiaArvore([
      const TaxonomiaNo(id: 'c1', tipo: TaxonomiaTipo.categoria, slug: 'veicular', nome: 'Veicular', parent: '', ordem: 1, ativo: true),
      const TaxonomiaNo(id: 'g1', tipo: TaxonomiaTipo.grupo, slug: 'plano', nome: 'Plano', parent: 'c1', ordem: 1, ativo: true),
      const TaxonomiaNo(id: 's1', tipo: TaxonomiaTipo.subgrupo, slug: 'premium', nome: 'Premium', parent: 'g1', ordem: 1, ativo: true),
    ]);
    expect(arvore.categorias, hasLength(1));
    expect(arvore.categorias.single.tipo, TaxonomiaTipo.categoria);
    expect(arvore.gruposDe('c1').single.slug, 'plano');
    expect(arvore.gruposDe('c1').single.tipo, TaxonomiaTipo.grupo);
    // Nós antigos continuam no modelo, mas a UI de produto para no grupo.
    expect(arvore.subgruposDe('g1').single.nome, 'Premium');
    expect(arvore.labelCategoria('veicular'), 'Veicular');
  });

  test('ordena catálogo achatado por categoria, grupo e serviço', () {
    final arvore = TaxonomiaArvore(const [
      TaxonomiaNo(id: 'c-z', tipo: TaxonomiaTipo.categoria, slug: 'z-cat', nome: 'Z', parent: '', ordem: 10, ativo: true),
      TaxonomiaNo(id: 'c-a', tipo: TaxonomiaTipo.categoria, slug: 'a-cat', nome: 'A', parent: '', ordem: 20, ativo: true),
      TaxonomiaNo(id: 'g-z', tipo: TaxonomiaTipo.grupo, slug: 'z-grupo', nome: 'Z', parent: 'c-z', ordem: 10, ativo: true),
      TaxonomiaNo(id: 'g-a', tipo: TaxonomiaTipo.grupo, slug: 'a-grupo', nome: 'A', parent: 'c-z', ordem: 20, ativo: true),
    ]);
    final ordenados = ordenarServicosDoCatalogo(const [
      ServicoPB(id: 'a-cat', nome: 'A categoria', categoria: 'a-cat', grupo: '', ordem: 10),
      ServicoPB(id: 'a-grupo', nome: 'A grupo', categoria: 'z-cat', grupo: 'a-grupo', ordem: 10),
      ServicoPB(id: 'segundo', nome: 'Alfa', categoria: 'z-cat', grupo: 'z-grupo', ordem: 20),
      ServicoPB(id: 'primeiro', nome: 'Zeta', categoria: 'z-cat', grupo: 'z-grupo', ordem: 10),
    ], arvore);

    expect(ordenados.map((s) => s.id), [
      'primeiro',
      'segundo',
      'a-grupo',
      'a-cat',
    ]);
  });

  test('ordena opções de categoria e grupo pela árvore configurada', () {
    final arvore = TaxonomiaArvore(const [
      TaxonomiaNo(id: 'cat-z', tipo: TaxonomiaTipo.categoria, slug: 'zeta', nome: 'Zeta', parent: '', ordem: 10, ativo: true),
      TaxonomiaNo(id: 'cat-a', tipo: TaxonomiaTipo.categoria, slug: 'alfa', nome: 'Alfa', parent: '', ordem: 20, ativo: true),
      TaxonomiaNo(id: 'grupo-z', tipo: TaxonomiaTipo.grupo, slug: 'zulu', nome: 'Zulu', parent: 'cat-z', ordem: 10, ativo: true),
      TaxonomiaNo(id: 'grupo-a', tipo: TaxonomiaTipo.grupo, slug: 'alfa-grupo', nome: 'Alfa grupo', parent: 'cat-z', ordem: 20, ativo: true),
    ]);

    expect(
      ordenarCategoriasDisponiveis({'alfa', 'zeta'}, arvore),
      ['zeta', 'alfa'],
    );
    expect(
      ordenarGruposDisponiveis({'alfa-grupo', 'zulu'}, arvore, 'zeta'),
      ['zulu', 'alfa-grupo'],
    );
  });
}
