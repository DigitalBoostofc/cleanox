/// pb_painel_evidencias_repository.dart — Impl PB (leitura) de `os_evidencias`
/// para a visão de EXECUÇÃO do Painel (admin/gerente).
///
/// Implementa a interface congelada `EvidenciasRepository` do core SEM tocar no
/// core. Nesta onda a execução do Painel é de LEITURA (o admin visualiza o que o
/// profissional registrou e gera/envia o laudo): só [listDaOS] é usada. As
/// mutações (create/updateMeta/delete) pertencem ao app do profissional (Slice B2)
/// e à edição de evidências no Painel, que chega numa onda futura — aqui lançam
/// `UnimplementedError` para flagrar uso indevido, em vez de fingir sucesso.
///
/// Fotos são PROTEGIDAS: a URL só serve o arquivo com um file token de vida curta,
/// gerado UMA vez por load (ver skill pocketbase-cleanos / `pb_evidencias_repository`).
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/os_execucao.dart';
import '../../core/repositories/evidencias_repository.dart';

class PbPainelEvidenciasRepository implements EvidenciasRepository {
  PbPainelEvidenciasRepository(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.osEvidencias);

  EvidenciaFoto _toFoto(RecordModel rec, String? token) {
    final pb = OSEvidenciaPB.fromRecord(rec);
    final foto = rec.getStringValue('foto');
    final url = foto.isEmpty
        ? ''
        : _pb.files.getUrl(rec, foto, token: token).toString();
    return EvidenciaFoto.fromPB(pb, url: url);
  }

  @override
  Future<List<EvidenciaFoto>> listDaOS(String osId) async {
    final recs = await _col.getFullList(
      filter: _pb.filter('os = {:os}', {'os': osId}),
      sort: 'created',
      expand: 'enviado_por',
    );
    final temFoto = recs.any((r) => r.getStringValue('foto').isNotEmpty);
    final token = temFoto ? await _pb.files.getToken() : null;
    return recs.map((r) => _toFoto(r, token)).toList();
  }

  Never _readOnly() => throw UnimplementedError(
    'A execução do Painel é de leitura nesta onda — mutação de evidências '
    'pertence ao app do profissional / a uma onda futura do Painel.',
  );

  @override
  Future<EvidenciaFoto> create(String osId, CreateEvidenciaInput input) =>
      _readOnly();

  @override
  Future<EvidenciaFoto> updateMeta(String id, EvidenciaUpdatePatch patch) =>
      _readOnly();

  @override
  Future<void> delete(String id) => _readOnly();
}
