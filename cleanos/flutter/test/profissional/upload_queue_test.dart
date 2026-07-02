/// upload_queue_test.dart — Resiliência da fila de upload (M1 + M2).
///
///  - M1: se o arquivo de origem sumiu, o item é DESCARTADO (não fica "failed"
///    pra sempre) e o pai é notificado (onDiscarded),
///  - M2: cada item enfileirado carrega um idempotency key ESTÁVEL, enviado ao
///    backend (createIdempotent) igual em todos os retries.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/core/repositories/evidencias_repository.dart';
import 'package:cleanos/profissional/data/pb_evidencias_repository.dart';
import 'package:cleanos/profissional/data/upload_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Repo que captura o idempotency key recebido e pode falhar uma vez.
class CapturingEvidenciasRepository
    implements EvidenciasRepository, IdempotentEvidenciasRepository {
  final List<String> keys = [];
  int failFirst = 0;

  @override
  Future<EvidenciaFoto> createIdempotent(
    String osId,
    CreateEvidenciaInput input, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (failFirst > 0) {
      failFirst--;
      throw Exception('transiente');
    }
    return EvidenciaFoto(
      id: 'ev_${keys.length}',
      url: 'https://x',
      fase: input.fase,
    );
  }

  @override
  Future<EvidenciaFoto> create(String osId, CreateEvidenciaInput input) =>
      createIdempotent(osId, input, idempotencyKey: 'nokey');

  @override
  Future<List<EvidenciaFoto>> listDaOS(String osId) async => const [];
  @override
  Future<EvidenciaFoto> updateMeta(
    String id,
    EvidenciaUpdatePatch patch,
  ) async => EvidenciaFoto(id: id, fase: FaseFoto.antes);
  @override
  Future<void> delete(String id) async {}
}

void main() {
  test('arquivo sumido → item DESCARTADO e onDiscarded notificado', () async {
    final repo = CapturingEvidenciasRepository();
    final q = UploadQueue(
      repo: repo,
      storage: FakeSecureStorage(),
      osId: 'os1',
    );
    final discarded = <String>[];
    q.onDiscarded = discarded.add;

    await q.enqueue(
      QueuedUpload(
        localId: 'l1',
        osId: 'os1',
        filePath: '/caminho/que/nao/existe/foto.jpg',
        fase: FaseFoto.antes,
        idempotencyKey: 'k1',
      ),
    );
    // enqueue já dispara o process (fire-and-forget); deixa terminar.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(discarded, ['l1']);
    expect(q.pending, isEmpty, reason: 'não pode reter "failed" pra sempre');
    expect(repo.keys, isEmpty, reason: 'nada foi enviado ao servidor');
  });

  test('idempotency key é enviado e é o MESMO em todos os retries', () async {
    final dir = Directory.systemTemp.createTempSync('cleanos_uq_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/foto.jpg')
      ..writeAsBytesSync(Uint8List.fromList([1, 2, 3]));

    final repo = CapturingEvidenciasRepository()..failFirst = 1; // 1ª falha
    final q = UploadQueue(
      repo: repo,
      storage: FakeSecureStorage(),
      osId: 'os1',
    );

    await q.enqueue(
      QueuedUpload(
        localId: 'l1',
        osId: 'os1',
        filePath: file.path,
        fase: FaseFoto.depois,
        idempotencyKey: 'idem-123',
      ),
    );
    // enqueue dispara a 1ª tentativa (fire-and-forget) → falha (failFirst).
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(q.pending, hasLength(1));
    expect(repo.keys, ['idem-123']);

    await q.retry(); // 2ª tentativa sucede — MESMO key.
    expect(repo.keys, ['idem-123', 'idem-123']);
    expect(q.pending, isEmpty);
  });

  test('QueuedUpload persiste e recupera o idempotency key', () {
    final item = QueuedUpload(
      localId: 'l1',
      osId: 'os1',
      filePath: '/x/foto.jpg',
      fase: FaseFoto.antes,
      idempotencyKey: 'idem-xyz',
    );
    final round = QueuedUpload.fromJson(item.toJson());
    expect(round.idempotencyKey, 'idem-xyz');

    // Item legado (sem key) → cai no localId como key retroativa.
    final legacy = QueuedUpload.fromJson({
      'localId': 'old1',
      'osId': 'os1',
      'filePath': '/x/y.jpg',
      'fase': 'antes',
    });
    expect(legacy.idempotencyKey, 'old1');
  });
}
