/// Nó da taxonomia editável (coleção `servicos_taxonomia`).
///
/// Hierarquia visível: Categoria → Grupo → Serviço. `TaxonomiaTipo.subgrupo`
/// permanece só para parsear registros legados; a UI não cria nem edita.
library;

enum TaxonomiaTipo {
  categoria,
  grupo,
  subgrupo;

  static TaxonomiaTipo? tryParse(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    for (final t in TaxonomiaTipo.values) {
      if (t.name == s) return t;
    }
    return null;
  }
}

class TaxonomiaNo {
  const TaxonomiaNo({
    required this.id,
    required this.tipo,
    required this.slug,
    required this.nome,
    required this.parent,
    required this.ordem,
    required this.ativo,
  });

  final String id;
  final TaxonomiaTipo tipo;
  final String slug;
  final String nome;
  final String parent;
  final int ordem;
  final bool ativo;

  factory TaxonomiaNo.fromRecord(Map<String, dynamic> json) {
    final tipo =
        TaxonomiaTipo.tryParse(json['tipo']?.toString()) ??
        TaxonomiaTipo.categoria;
    return TaxonomiaNo(
      id: json['id']?.toString() ?? '',
      tipo: tipo,
      slug: (json['slug'] ?? '').toString().trim(),
      nome: (json['nome'] ?? '').toString().trim(),
      parent: (json['parent'] ?? '').toString().trim(),
      ordem: _asInt(json['ordem']),
      ativo: json['ativo'] == true || json['ativo'] == null,
    );
  }

  Map<String, dynamic> toBody() => {
    'tipo': tipo.name,
    'slug': slug,
    'nome': nome,
    'parent': parent,
    'ordem': ordem,
    'ativo': ativo,
  };

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

/// Árvore em memória: categorias → grupos. Subgrupos legados são ignorados na UI.
class TaxonomiaArvore {
  TaxonomiaArvore(this.nos);

  final List<TaxonomiaNo> nos;

  List<TaxonomiaNo> get categorias {
    final list = [
      for (final n in nos)
        if (n.tipo == TaxonomiaTipo.categoria && n.ativo) n,
    ]..sort((a, b) => a.ordem.compareTo(b.ordem));
    return list;
  }

  List<TaxonomiaNo> gruposDe(String categoriaId) {
    final list = [
      for (final n in nos)
        if (n.tipo == TaxonomiaTipo.grupo &&
            n.ativo &&
            n.parent == categoriaId)
          n,
    ]..sort((a, b) => a.ordem.compareTo(b.ordem));
    return list;
  }

  List<TaxonomiaNo> subgruposDe(String grupoId) {
    final list = [
      for (final n in nos)
        if (n.tipo == TaxonomiaTipo.subgrupo &&
            n.ativo &&
            n.parent == grupoId)
          n,
    ]..sort((a, b) => a.ordem.compareTo(b.ordem));
    return list;
  }

  TaxonomiaNo? byId(String id) {
    for (final n in nos) {
      if (n.id == id) return n;
    }
    return null;
  }

  TaxonomiaNo? categoriaBySlug(String slug) {
    final s = slug.trim();
    for (final n in categorias) {
      if (n.slug == s) return n;
    }
    return null;
  }

  TaxonomiaNo? grupoBySlug(String categoriaId, String slug) {
    final s = slug.trim();
    for (final n in gruposDe(categoriaId)) {
      if (n.slug == s) return n;
    }
    return null;
  }

  /// Resolve nome amigável de um slug em um nível (fallback = slug).
  String labelCategoria(String slug) =>
      categoriaBySlug(slug)?.nome ?? _fallbackCat(slug);

  String labelGrupo(String categoriaSlug, String grupoSlug) {
    final cat = categoriaBySlug(categoriaSlug);
    if (cat == null) return _fallbackGrupo(grupoSlug);
    return grupoBySlug(cat.id, grupoSlug)?.nome ?? _fallbackGrupo(grupoSlug);
  }

  String labelSubgrupo(String grupoId, String subSlug) {
    final s = subSlug.trim();
    if (s.isEmpty) return '';
    for (final n in subgruposDe(grupoId)) {
      if (n.slug == s) return n.nome;
    }
    return s;
  }

  static String _fallbackCat(String slug) {
    switch (slug) {
      case 'veicular':
        return 'Veicular';
      case 'residencial':
        return 'Residencial';
      default:
        return slug;
    }
  }

  static String _fallbackGrupo(String slug) {
    switch (slug) {
      case 'plano':
        return 'Plano';
      case 'promocao':
        return 'Promoção';
      case 'adicional':
        return 'Adicional';
      case 'avulsos':
        return 'Avulsos';
      case 'sofa':
        return 'Sofá';
      case 'colchao':
        return 'Colchão';
      case 'outros':
        return 'Outros';
      default:
        return slug;
    }
  }
}
