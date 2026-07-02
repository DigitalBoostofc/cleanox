/// pb_servicos_repository.dart — Impl PB da interface congelada
/// `ServicosRepository` do core, na camada de dados do PAINEL (Time A).
///
/// [listAtivos] alimenta o dropdown de "Nova OS" (conjunto pequeno → getFullList);
/// [list] pagina o catálogo RICO para a tela de Serviços (Onda 3). O [create]
/// GARANTE um `slug` único (espelha `createServico`/`slugify` de
/// `web/src/lib/servicos/store.ts`): a UI só manda os campos de domínio, o repo
/// resolve o slug e faz retry defensivo contra a corrida do índice parcial.
///
/// Convenções: `Collections.servicos`, `pb.filter`, `getList` paginado (nunca
/// `getFullList` numa lista de UI grande), `RecordModel` → `ServicoPB`.
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/servico.dart';
import '../../core/repositories/repo_types.dart';
import '../../core/repositories/servicos_repository.dart';

class PbServicosRepository implements ServicosRepository {
  PbServicosRepository(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.servicos);

  @override
  Future<List<ServicoPB>> listAtivos() async {
    // Conjunto pequeno e fechado (catálogo ativo para dropdowns) → getFullList OK.
    final recs = await _col.getFullList(
      filter: _pb.filter('ativo = true'),
      sort: 'nome',
    );
    return recs.map(ServicoPB.fromRecord).toList();
  }

  @override
  Future<PageResult<ServicoPB>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'nome',
  }) async {
    final res = await _col.getList(
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort,
    );
    return PageResult<ServicoPB>(
      items: res.items.map(ServicoPB.fromRecord).toList(),
      page: res.page,
      perPage: res.perPage,
      totalItems: res.totalItems,
      totalPages: res.totalPages,
    );
  }

  @override
  Future<ServicoPB> getOne(String id) async {
    final rec = await _col.getOne(id);
    return ServicoPB.fromRecord(rec);
  }

  @override
  Future<ServicoPB> create(Map<String, dynamic> data) async {
    // A UI manda os campos de domínio; garantimos um `slug` único aqui (espelha
    // `createServico`). Se o payload já trouxer slug, respeitamos.
    var slug = (data['slug'] as String?)?.trim() ?? '';
    if (slug.isEmpty) {
      final base = slugify((data['nome'] as String?) ?? '');
      final taken = await _takenSlugs();
      slug = _nextFreeSlug(base, taken);
      // Retry defensivo contra a corrida entre _takenSlugs() e create(): o índice
      // parcial de `slug` rejeita duplicatas com 400 → reescolhe e tenta de novo.
      for (var attempt = 0; ; attempt++) {
        try {
          final rec = await _col.create(body: {...data, 'slug': slug});
          return ServicoPB.fromRecord(rec);
        } on ClientException catch (e) {
          if (attempt < 3 && _isSlugConflict(e)) {
            taken.add(slug);
            slug = _nextFreeSlug(base, taken);
            continue;
          }
          rethrow;
        }
      }
    }
    final rec = await _col.create(body: {...data, 'slug': slug});
    return ServicoPB.fromRecord(rec);
  }

  @override
  Future<ServicoPB> update(String id, Map<String, dynamic> data) async {
    final rec = await _col.update(id, body: data);
    return ServicoPB.fromRecord(rec);
  }

  @override
  Future<void> delete(String id) => _col.delete(id);

  /// Slugs já em uso (o índice parcial ignora os vazios). Campo único → payload leve.
  Future<Set<String>> _takenSlugs() async {
    final rows = await _col.getFullList(fields: 'slug');
    return {
      for (final r in rows)
        if ((r.data['slug'] as String?)?.isNotEmpty ?? false)
          r.data['slug'] as String,
    };
  }

  static bool _isSlugConflict(ClientException e) {
    if (e.statusCode != 400) return false;
    final resp = e.response;
    final rawData = resp['data'];
    return rawData is Map && rawData.containsKey('slug');
  }
}

/// Slugify estável: minúsculas sem acento, não-alfanumérico → "_" (espelha
/// `slugify` de `web/src/lib/servicos/store.ts`).
String slugify(String nome) {
  final base = _stripDiacritics(nome)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return base.isEmpty ? 'servico' : base;
}

/// Primeiro slug livre a partir de [base] (`base`, `base_2`, `base_3`, …).
String _nextFreeSlug(String base, Set<String> taken) {
  if (!taken.contains(base)) return base;
  var i = 2;
  while (taken.contains('${base}_$i')) {
    i++;
  }
  return '${base}_$i';
}

/// Remove diacríticos combinados (equivalente ao `NFD` + strip do web).
String _stripDiacritics(String input) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    final idx = from.indexOf(ch);
    buf.write(idx == -1 ? ch : to[idx]);
  }
  return buf.toString();
}
