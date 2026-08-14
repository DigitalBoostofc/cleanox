/// Nó da taxonomia editável (coleção `servicos_taxonomia`).
///
/// Hierarquia visível: Categoria → Grupo → Serviço. `TaxonomiaTipo.subgrupo`
/// permanece só para parsear registros legados; a UI não cria nem edita.
library;

import '../../../core/models/servico.dart';
import '../../../core/models/servico_taxonomia.dart';

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

/// Grupos do filtro da lista de Serviços para a [categoriaSlug] selecionada.
///
/// Sem categoria: vazio (a UI fica só em "Todos os grupos").
/// Com árvore: grupos ativos daquela categoria.
/// Sem árvore: fallback estático [gruposDaCategoria].
List<String> gruposDoFiltroServicos({
  required String? categoriaSlug,
  TaxonomiaArvore? arvore,
}) {
  final slug = (categoriaSlug ?? '').trim();
  if (slug.isEmpty) return const [];
  final cat = arvore?.categoriaBySlug(slug);
  if (cat != null) {
    return [for (final g in arvore!.gruposDe(cat.id)) g.slug];
  }
  Categoria? catEnum;
  for (final c in Categoria.values) {
    if (c.wire == slug) {
      catEnum = c;
      break;
    }
  }
  if (catEnum == null) return const [];
  return [for (final g in gruposDaCategoria(catEnum)) g.wire];
}

/// Ordena slugs disponíveis pela sequência configurada das categorias.
/// Valores ainda não cadastrados na árvore ficam ao final em ordem alfabética.
List<String> ordenarCategoriasDisponiveis(
  Set<String> disponiveis,
  TaxonomiaArvore? taxonomia,
) {
  final restantes = {...disponiveis};
  final ordenadas = <String>[];
  for (final no in taxonomia?.categorias ?? const <TaxonomiaNo>[]) {
    if (restantes.remove(no.slug)) ordenadas.add(no.slug);
  }
  final fallback = restantes.toList()..sort();
  return [...ordenadas, ...fallback];
}

/// Ordena grupos disponíveis pela sequência do pai configurado.
List<String> ordenarGruposDisponiveis(
  Set<String> disponiveis,
  TaxonomiaArvore? taxonomia,
  String? categoriaSlug,
) {
  final restantes = {...disponiveis};
  final ordenados = <String>[];
  final categorias = categoriaSlug == null
      ? (taxonomia?.categorias ?? const <TaxonomiaNo>[])
      : [
          if (taxonomia?.categoriaBySlug(categoriaSlug) case final no?) no,
        ];
  for (final categoria in categorias) {
    for (final grupo in taxonomia?.gruposDe(categoria.id) ??
        const <TaxonomiaNo>[]) {
      if (restantes.remove(grupo.slug)) ordenados.add(grupo.slug);
    }
  }
  final fallback = restantes.toList()..sort();
  return [...ordenados, ...fallback];
}

/// Ordena um catálogo achatado pela sequência configurada na árvore e, dentro
/// de cada grupo, pelo campo persistente [ServicoPB.ordem].
///
/// Slugs ainda não cadastrados na taxonomia e serviços antigos sem posição
/// continuam determinísticos por slug/nome/id.
List<ServicoPB> ordenarServicosDoCatalogo(
  Iterable<ServicoPB> servicos,
  TaxonomiaArvore? taxonomia,
) {
  final categorias = taxonomia?.categorias ?? const <TaxonomiaNo>[];
  final categoriaRank = <String, int>{
    for (var i = 0; i < categorias.length; i++) categorias[i].slug: i,
  };
  final grupoRank = <String, int>{};
  for (final categoria in categorias) {
    final grupos = taxonomia?.gruposDe(categoria.id) ?? const <TaxonomiaNo>[];
    for (var i = 0; i < grupos.length; i++) {
      grupoRank['${categoria.slug}\u0000${grupos[i].slug}'] = i;
    }
  }

  final list = servicos.toList();
  list.sort((a, b) {
    const semRank = 1 << 30;
    final catA = categoriaRank[a.categoria] ?? semRank;
    final catB = categoriaRank[b.categoria] ?? semRank;
    var result = catA.compareTo(catB);
    if (result != 0) return result;
    if (catA == semRank) {
      result = a.categoria.compareTo(b.categoria);
      if (result != 0) return result;
    }

    final grupoA = grupoRank['${a.categoria}\u0000${a.grupo}'] ?? semRank;
    final grupoB = grupoRank['${b.categoria}\u0000${b.grupo}'] ?? semRank;
    result = grupoA.compareTo(grupoB);
    if (result != 0) return result;
    if (grupoA == semRank) {
      result = a.grupo.compareTo(b.grupo);
      if (result != 0) return result;
    }

    final ordemA = a.ordem > 0 ? a.ordem : semRank;
    final ordemB = b.ordem > 0 ? b.ordem : semRank;
    result = ordemA.compareTo(ordemB);
    if (result != 0) return result;
    result = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    if (result != 0) return result;
    return a.id.compareTo(b.id);
  });
  return list;
}
