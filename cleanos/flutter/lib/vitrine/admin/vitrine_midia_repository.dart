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
    this.servicoId = '',
    this.papel = '',
    this.parId = '',
    this.legenda = '',
    this.focoX = 50,
    this.focoY = 50,
  });

  final String id;
  final String chave;
  final String titulo;
  final String urlExterna;
  final String arquivo;
  final int ordem;
  final bool ativo;
  final String? fileUrl;
  final String servicoId;
  final String papel;
  final String parId;
  final String legenda;
  final double focoX;
  final double focoY;

  String? get displayUrl {
    if (fileUrl != null && fileUrl!.isNotEmpty) return fileUrl;
    if (urlExterna.isNotEmpty) return urlExterna;
    return null;
  }

  String get papelLabel => switch (papel) {
    'capa' => 'Capa',
    'antes' => 'Antes',
    'depois' => 'Depois',
    _ => 'Galeria',
  };
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
      servicoId: '${data['servico'] ?? ''}',
      papel: '${data['papel'] ?? ''}',
      parId: '${data['par_id'] ?? ''}',
      legenda: '${data['legenda'] ?? ''}',
      focoX: (data['foco_x'] as num?)?.toDouble() ?? 50,
      focoY: (data['foco_y'] as num?)?.toDouble() ?? 50,
    );
  }

  Future<VitrineMidiaItem> create({
    required String chave,
    String titulo = '',
    String urlExterna = '',
    int ordem = 0,
    bool ativo = true,
    String servicoId = '',
    String papel = '',
    String parId = '',
    String legenda = '',
    double focoX = 50,
    double focoY = 50,
    List<int>? fileBytes,
    String? filename,
  }) async {
    final body = <String, dynamic>{
      'chave': chave,
      'titulo': titulo,
      'url_externa': urlExterna,
      'ordem': ordem,
      'ativo': ativo,
      'servico': servicoId,
      'papel': papel,
      'par_id': parId,
      'legenda': legenda,
      'foco_x': focoX,
      'foco_y': focoY,
    };
    final files = <http.MultipartFile>[];
    if (fileBytes != null && fileBytes.isNotEmpty && filename != null) {
      files.add(
        http.MultipartFile.fromBytes('arquivo', fileBytes, filename: filename),
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
    String? servicoId,
    String? papel,
    String? parId,
    String? legenda,
    double? focoX,
    double? focoY,
    List<int>? fileBytes,
    String? filename,
  }) async {
    final body = <String, dynamic>{
      if (chave != null) 'chave': chave,
      if (titulo != null) 'titulo': titulo,
      if (urlExterna != null) 'url_externa': urlExterna,
      if (ordem != null) 'ordem': ordem,
      if (ativo != null) 'ativo': ativo,
      if (servicoId != null) 'servico': servicoId,
      if (papel != null) 'papel': papel,
      if (parId != null) 'par_id': parId,
      if (legenda != null) 'legenda': legenda,
      if (focoX != null) 'foco_x': focoX,
      if (focoY != null) 'foco_y': focoY,
    };
    final files = <http.MultipartFile>[];
    if (fileBytes != null && fileBytes.isNotEmpty && filename != null) {
      files.add(
        http.MultipartFile.fromBytes('arquivo', fileBytes, filename: filename),
      );
    }
    final rec = files.isEmpty
        ? await _col.update(id, body: body)
        : await _col.update(id, body: body, files: files);
    return _fromRec(rec);
  }

  Future<void> delete(String id) => _col.delete(id);
}
