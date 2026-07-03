/// pb_evidencias_repository.dart — Impl PB da coleção `os_evidencias`.
///
/// Implementa a INTERFACE congelada do core (`EvidenciasRepository`) SEM tocar no
/// core — a impl mora na camada de feature do profissional (Time B). Porte fiel de
/// `web/src/lib/os/osStore.ts` (listEvidencias/createEvidencia/updateEvidencia/
/// deleteEvidencia). Fotos são PROTEGIDAS: a URL só serve o arquivo com um file
/// token (gerado 1× por load). 🔒 o profissional só enxerga evidências das suas OS
/// (o servidor barra o resto com 403).
library;

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/os_execucao.dart';
import '../../core/repositories/evidencias_repository.dart';

/// Extensão opcional do contrato de evidências (mora na camada do profissional,
/// não toca o core congelado): permite enviar um `idempotency_key` no multipart
/// para o backend deduplicar por `(os, idempotency_key)` — assim um retry cujo
/// commit se perdeu não cria uma 2ª evidência. A fila de upload usa esta
/// capacidade quando o repositório concreto a implementa.
abstract class IdempotentEvidenciasRepository {
  Future<EvidenciaFoto> createIdempotent(
    String osId,
    CreateEvidenciaInput input, {
    required String idempotencyKey,
  });
}

class PbEvidenciasRepository
    implements EvidenciasRepository, IdempotentEvidenciasRepository {
  PbEvidenciasRepository(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.osEvidencias);

  /// Monta a URL protegida (com token) e mapeia para o tipo de domínio.
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
    // Gera UM file token por load (só se houver ao menos uma foto). Expira ~2min.
    final temFoto = recs.any((r) => r.getStringValue('foto').isNotEmpty);
    final token = temFoto ? await _pb.files.getToken() : null;
    return recs.map((r) => _toFoto(r, token)).toList();
  }

  @override
  Future<EvidenciaFoto> create(String osId, CreateEvidenciaInput input) =>
      _create(osId, input, idempotencyKey: null);

  @override
  Future<EvidenciaFoto> createIdempotent(
    String osId,
    CreateEvidenciaInput input, {
    required String idempotencyKey,
  }) => _create(osId, input, idempotencyKey: idempotencyKey);

  Future<EvidenciaFoto> _create(
    String osId,
    CreateEvidenciaInput input, {
    required String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'os': osId,
      'fase': input.fase.wire,
      if ((input.legenda ?? '').isNotEmpty) 'legenda': input.legenda,
      if ((input.checklistItemId ?? '').isNotEmpty)
        'checklist_item_id': input.checklistItemId,
      if ((input.observacaoId ?? '').isNotEmpty)
        'observacao_id': input.observacaoId,
      if ((input.adicionalId ?? '').isNotEmpty)
        'adicional_id': input.adicionalId,
      if ((input.enviadoPorId ?? '').isNotEmpty)
        'enviado_por': input.enviadoPorId,
      // Campo extra do multipart p/ dedupe idempotente no backend (não é campo
      // do core `CreateEvidenciaInput`). Nome do form field: `idempotency_key`.
      if ((idempotencyKey ?? '').isNotEmpty) 'idempotency_key': idempotencyKey,
    };
    final rec = await _col.create(
      body: body,
      files: [
        http.MultipartFile.fromBytes(
          'foto',
          input.bytes,
          filename: input.filename,
        ),
      ],
      expand: 'enviado_por',
    );
    final token = rec.getStringValue('foto').isNotEmpty
        ? await _pb.files.getToken()
        : null;
    return _toFoto(rec, token);
  }

  @override
  Future<EvidenciaFoto> updateMeta(
    String id,
    EvidenciaUpdatePatch patch,
  ) async {
    // String vazia LIMPA o campo (paridade com o web).
    final body = <String, dynamic>{
      if (patch.legenda != null) 'legenda': patch.legenda,
      if (patch.checklistItemId != null)
        'checklist_item_id': patch.checklistItemId,
      if (patch.observacaoId != null) 'observacao_id': patch.observacaoId,
      if (patch.adicionalId != null) 'adicional_id': patch.adicionalId,
    };
    final rec = await _col.update(id, body: body, expand: 'enviado_por');
    final token = rec.getStringValue('foto').isNotEmpty
        ? await _pb.files.getToken()
        : null;
    return _toFoto(rec, token);
  }

  @override
  Future<void> delete(String id) => _col.delete(id);
}
