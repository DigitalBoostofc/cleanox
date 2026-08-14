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
}
