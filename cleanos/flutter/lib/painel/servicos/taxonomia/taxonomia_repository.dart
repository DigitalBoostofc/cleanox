/// Repositório PB da taxonomia de serviços.
library;

import 'package:pocketbase/pocketbase.dart';

import 'taxonomia_models.dart';

class TaxonomiaRepository {
  TaxonomiaRepository(this._pb);

  final PocketBase _pb;

  static const collection = 'servicos_taxonomia';

  RecordService get _col => _pb.collection(collection);

  Future<TaxonomiaArvore> load() async {
    final recs = await _col.getFullList(sort: 'ordem,nome');
    final nos = [
      for (final r in recs) TaxonomiaNo.fromRecord(r.toJson()),
    ];
    return TaxonomiaArvore(nos);
  }

  Future<TaxonomiaNo> create({
    required TaxonomiaTipo tipo,
    required String slug,
    required String nome,
    required String parent,
    int ordem = 0,
  }) async {
    final body = {
      'tipo': tipo.name,
      'slug': _slugify(slug.isEmpty ? nome : slug),
      'nome': nome.trim(),
      'parent': parent,
      'ordem': ordem,
      'ativo': true,
    };
    final r = await _col.create(body: body);
    return TaxonomiaNo.fromRecord(r.toJson());
  }

  Future<TaxonomiaNo> update(
    String id, {
    String? nome,
    String? slug,
    int? ordem,
    bool? ativo,
    String? parent,
  }) async {
    final body = <String, dynamic>{};
    if (nome != null) body['nome'] = nome.trim();
    if (slug != null) body['slug'] = _slugify(slug);
    if (ordem != null) body['ordem'] = ordem;
    if (ativo != null) body['ativo'] = ativo;
    if (parent != null) body['parent'] = parent;
    final r = await _col.update(id, body: body);
    return TaxonomiaNo.fromRecord(r.toJson());
  }

  /// Renumera todos os irmãos ativos do escopo em uma transação server-side.
  Future<void> reorderCatalog({
    required String kind,
    required List<String> ids,
  }) async {
    await _pb.send<Map<String, dynamic>>(
      '/api/cleanos/catalogo/reordenar',
      method: 'POST',
      body: {'kind': kind, 'ids': ids},
    );
  }

  Future<void> delete(String id) async {
    // Apaga filhos primeiro (grupos e, se existirem, nós legados).
    final arvore = await load();
    final filhos = [
      for (final n in arvore.nos)
        if (n.parent == id) n,
    ];
    for (final f in filhos) {
      await delete(f.id);
    }
    await _col.delete(id);
  }

  static String _slugify(String raw) {
    var s = raw.trim().toLowerCase();
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final buf = StringBuffer();
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    s = buf.toString();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.replaceAll(RegExp(r'^_|_$'), '');
    if (s.isEmpty) s = 'item';
    if (s.length > 80) s = s.substring(0, 80);
    return s;
  }

  /// Público para o dialog da UI.
  static String slugify(String raw) => _slugify(raw);
}
