/// CRUD de mídia da vitrine via SDK PocketBase (coleção `vitrine_midia`).
library;

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

class VitrineMidiaItem {
  const VitrineMidiaItem({
    required this.id,
    required this.chave,
    required this.titulo,
    required this.urlExterna,
    required this.arquivo,
    required this.ordem,
    required this.ativo,
    this.fileUrl,
  });

  final String id;
  final String chave;
  final String titulo;
  final String urlExterna;
  final String arquivo;
  final int ordem;
  final bool ativo;
  final String? fileUrl;

  String? get displayUrl {
    if (fileUrl != null && fileUrl!.isNotEmpty) return fileUrl;
    if (urlExterna.isNotEmpty) return urlExterna;
    return null;
  }
}

class VitrineMidiaRepository {
  VitrineMidiaRepository(this._pb);

  final PocketBase _pb;
  static const _colName = 'vitrine_midia';

  RecordService get _col => _pb.collection(_colName);

  Future<List<VitrineMidiaItem>> list() async {
    final recs = await _col.getFullList(sort: 'ordem');
    return recs.map(_fromRec).toList();
  }

  VitrineMidiaItem _fromRec(RecordModel r) {
    final data = r.data;
    final arquivo = '${data['arquivo'] ?? ''}';
    String? fileUrl;
    if (arquivo.isNotEmpty) {
      try {
        fileUrl = _pb.files.getUrl(r, arquivo).toString();
      } catch (_) {
        fileUrl = null;
      }
    }
    final ordemRaw = data['ordem'];
    final ordem = ordemRaw is num
        ? ordemRaw.toInt()
        : int.tryParse('$ordemRaw') ?? 0;
    final ativoRaw = data['ativo'];
    final ativo = ativoRaw != false && ativoRaw != 0 && ativoRaw != 'false';
    return VitrineMidiaItem(
      id: r.id,
      chave: '${data['chave'] ?? ''}',
      titulo: '${data['titulo'] ?? ''}',
      urlExterna: '${data['url_externa'] ?? ''}',
      arquivo: arquivo,
      ordem: ordem,
      ativo: ativo,
      fileUrl: fileUrl,
    );
  }

  Future<VitrineMidiaItem> create({
    required String chave,
    String titulo = '',
    String urlExterna = '',
    int ordem = 0,
    bool ativo = true,
    List<int>? fileBytes,
    String? filename,
  }) async {
    final body = <String, dynamic>{
      'chave': chave,
      'titulo': titulo,
      'url_externa': urlExterna,
      'ordem': ordem,
      'ativo': ativo,
    };
    final files = <http.MultipartFile>[];
    if (fileBytes != null && fileBytes.isNotEmpty && filename != null) {
      files.add(
        http.MultipartFile.fromBytes(
          'arquivo',
          fileBytes,
          filename: filename,
        ),
      );
    }
    final rec = files.isEmpty
        ? await _col.create(body: body)
        : await _col.create(body: body, files: files);
    return _fromRec(rec);
  }

  Future<VitrineMidiaItem> update(
    String id, {
    String? chave,
    String? titulo,
    String? urlExterna,
    int? ordem,
    bool? ativo,
    List<int>? fileBytes,
    String? filename,
  }) async {
    final body = <String, dynamic>{
      if (chave != null) 'chave': chave,
      if (titulo != null) 'titulo': titulo,
      if (urlExterna != null) 'url_externa': urlExterna,
      if (ordem != null) 'ordem': ordem,
      if (ativo != null) 'ativo': ativo,
    };
    final files = <http.MultipartFile>[];
    if (fileBytes != null && fileBytes.isNotEmpty && filename != null) {
      files.add(
        http.MultipartFile.fromBytes(
          'arquivo',
          fileBytes,
          filename: filename,
        ),
      );
    }
    final rec = files.isEmpty
        ? await _col.update(id, body: body)
        : await _col.update(id, body: body, files: files);
    return _fromRec(rec);
  }

  Future<void> delete(String id) => _col.delete(id);
}
