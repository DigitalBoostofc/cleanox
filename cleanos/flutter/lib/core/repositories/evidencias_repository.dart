/// evidencias_repository.dart — Contrato de `os_evidencias` (fotos antes/durante/depois).
///
/// Porte de os/osStore.ts (listEvidencias/createEvidencia/updateEvidencia/delete).
/// Arquivos são PROTEGIDOS (file token). 🔒 profissional só vê evidências de OS suas.
library;

import 'dart:typed_data';

import '../models/os_execucao.dart';

/// Entrada de criação de evidência (upload multipart).
class CreateEvidenciaInput {
  const CreateEvidenciaInput({
    required this.bytes,
    required this.filename,
    required this.fase,
    this.legenda,
    this.checklistItemId,
    this.observacaoId,
    this.adicionalId,
    this.enviadoPorId,
  });

  final Uint8List bytes;
  final String filename;
  final FaseFoto fase;
  final String? legenda;
  final String? checklistItemId;
  final String? observacaoId;
  final String? adicionalId;

  /// ID do usuário atual (relation enviado_por).
  final String? enviadoPorId;
}

/// Patch de metadados (legenda/vínculos). String vazia LIMPA o campo.
class EvidenciaUpdatePatch {
  const EvidenciaUpdatePatch({
    this.legenda,
    this.checklistItemId,
    this.observacaoId,
    this.adicionalId,
  });

  final String? legenda;
  final String? checklistItemId;
  final String? observacaoId;
  final String? adicionalId;
}

abstract class EvidenciasRepository {
  /// Todas as evidências de uma OS (já com file token nas URLs).
  Future<List<EvidenciaFoto>> listDaOS(String osId);
  Future<EvidenciaFoto> create(String osId, CreateEvidenciaInput input);
  Future<EvidenciaFoto> updateMeta(String id, EvidenciaUpdatePatch patch);
  Future<void> delete(String id);
}

/// Stub congelado (Fase 1). Impl real na Fase 2 (Time B / Profissional — Slice B2).
class UnimplementedEvidenciasRepository implements EvidenciasRepository {
  const UnimplementedEvidenciasRepository();

  Never _todo() =>
      throw UnimplementedError('TODO Fase 2: EvidenciasRepository (upload PB)');

  @override
  Future<List<EvidenciaFoto>> listDaOS(String osId) => _todo();
  @override
  Future<EvidenciaFoto> create(String osId, CreateEvidenciaInput input) =>
      _todo();
  @override
  Future<EvidenciaFoto> updateMeta(String id, EvidenciaUpdatePatch patch) =>
      _todo();
  @override
  Future<void> delete(String id) => _todo();
}
