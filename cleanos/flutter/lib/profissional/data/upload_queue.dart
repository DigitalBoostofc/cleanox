/// upload_queue.dart — Fila de upload de evidências PERSISTENTE e resiliente a offline.
///
/// Enfileira fotos (caminho de arquivo + metadados), persiste a fila em armazenamento
/// seguro (sobrevive a reinício do app) e processa sequencialmente contra o
/// `EvidenciasRepository` do core. Offline / erro → o item fica na fila para retry
/// (o servidor é a linha de defesa; o cliente só reflete o estado). Upload OTIMISTA:
/// o pai mostra o preview local na hora; ao concluir, troca pelo registro real do PB.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/models/os_execucao.dart';
import '../../core/repositories/evidencias_repository.dart';
import '../../core/storage/local_store_keys.dart';
import 'pb_evidencias_repository.dart' show IdempotentEvidenciasRepository;

/// Item enfileirado (serializável). Guarda o CAMINHO do arquivo — os bytes são
/// lidos só na hora do upload (mantém a fila leve). O [filePath] deve apontar
/// para um diretório app-private ESTÁVEL (não o cache do image_picker, que o SO
/// pode limpar após um kill).
class QueuedUpload {
  QueuedUpload({
    required this.localId,
    required this.osId,
    required this.filePath,
    required this.fase,
    required this.idempotencyKey,
    this.legenda,
    this.checklistItemId,
  });

  final String localId;
  final String osId;
  final String filePath;
  final FaseFoto fase;

  /// Chave de idempotência (uuid) estável por item enfileirado. Persistida e
  /// reenviada IDÊNTICA em todos os retries → o backend deduplica por
  /// `(os, idempotency_key)` se um commit anterior teve a resposta perdida.
  final String idempotencyKey;
  final String? legenda;
  final String? checklistItemId;

  String get filename {
    final parts = filePath.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? 'foto.jpg' : parts.last;
  }

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'osId': osId,
    'filePath': filePath,
    'fase': fase.wire,
    'idempotencyKey': idempotencyKey,
    if (legenda != null) 'legenda': legenda,
    if (checklistItemId != null) 'checklistItemId': checklistItemId,
  };

  static QueuedUpload fromJson(Map<String, dynamic> j) => QueuedUpload(
    localId: j['localId'] as String,
    osId: j['osId'] as String,
    filePath: j['filePath'] as String,
    fase: switch (j['fase'] as String?) {
      'durante' => FaseFoto.durante,
      'depois' => FaseFoto.depois,
      _ => FaseFoto.antes,
    },
    // Itens persistidos antes desta versão não têm key → o localId (único e
    // estável) serve de chave de idempotência retroativa.
    idempotencyKey:
        (j['idempotencyKey'] as String?) ?? (j['localId'] as String),
    legenda: j['legenda'] as String?,
    checklistItemId: j['checklistItemId'] as String?,
  );
}

/// Fila de upload de UMA OS. Instanciada pela tela de execução; persiste sob uma
/// chave por OS, então reabrir a OS retoma uploads pendentes.
class UploadQueue {
  UploadQueue({
    required EvidenciasRepository repo,
    required FlutterSecureStorage storage,
    required this.osId,
    this.enviadoPorId,
  }) : _repo = repo,
       _storage = storage;

  final EvidenciasRepository _repo;
  final FlutterSecureStorage _storage;
  final String osId;
  final String? enviadoPorId;

  final List<QueuedUpload> _items = [];
  bool _processing = false;

  /// Sucesso: troca o item otimista [localId] pelo registro real do PB.
  void Function(String localId, EvidenciaFoto real)? onUploaded;

  /// Falha (offline/erro): o item continua na fila; o pai marca como "falhou".
  void Function(String localId, Object error)? onFailed;

  /// Descarte gracioso: o arquivo de origem sumiu (cache limpo pelo SO após um
  /// kill) — o item é REMOVIDO da fila (não fica "failed" pra sempre) e o pai é
  /// notificado para tirar o preview fantasma.
  void Function(String localId)? onDiscarded;

  String get _key => '$kUploadQueueKeyPrefix$osId';

  List<QueuedUpload> get pending => List.unmodifiable(_items);

  /// Carrega a fila persistida (chamar ao abrir a OS) e tenta processar.
  Future<void> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(
            list.map((e) => QueuedUpload.fromJson(e as Map<String, dynamic>)),
          );
      }
    } catch (_) {
      /* fila corrompida/indisponível — começa vazia */
    }
    if (_items.isNotEmpty) unawaitedProcess();
  }

  Future<void> _persist() async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      /* best-effort */
    }
  }

  /// Enfileira uma nova foto e dispara o processamento.
  Future<void> enqueue(QueuedUpload item) async {
    _items.add(item);
    await _persist();
    unawaitedProcess();
  }

  /// Reprocessa a fila (ex.: botão "Reenviar" ou reconexão).
  Future<void> retry() => process();

  /// Remove um item local (ex.: usuário descartou antes de subir). Apaga também
  /// a cópia local da foto — descartada, ela é só resíduo LGPD (A-01).
  Future<void> removeLocal(String localId) async {
    final removed = _items.where((q) => q.localId == localId).toList();
    _items.removeWhere((q) => q.localId == localId);
    await _persist();
    for (final q in removed) {
      await _deleteLocalFile(q.filePath);
    }
  }

  /// Apaga a cópia local best-effort (nunca falha o fluxo por erro de disco).
  Future<void> _deleteLocalFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      /* best-effort — a purga do logout varre o diretório como rede de segurança */
    }
  }

  /// Dispara [process] sem aguardar (fire-and-forget seguro).
  void unawaitedProcess() {
    // ignore: discarded_futures
    process();
  }

  /// Processa a fila sequencialmente. Para na primeira falha (provável offline);
  /// os itens restantes ficam para o próximo retry.
  Future<void> process() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_items.isNotEmpty) {
        final q = _items.first;
        final file = File(q.filePath);
        // O arquivo sumiu (cache do SO limpo após kill) → descarta o item em vez
        // de retê-lo "failed" pra sempre, e notifica pra remover o preview.
        if (!await file.exists()) {
          _items.removeWhere((x) => x.localId == q.localId);
          await _persist();
          onDiscarded?.call(q.localId);
          continue;
        }
        try {
          final bytes = await file.readAsBytes();
          final input = CreateEvidenciaInput(
            bytes: bytes,
            filename: q.filename,
            fase: q.fase,
            legenda: q.legenda,
            checklistItemId: q.checklistItemId,
            enviadoPorId: enviadoPorId,
          );
          final repo = _repo;
          // Envia o idempotency key quando o repositório concreto o suporta
          // (o backend deduplica por `(os, idempotency_key)`).
          final real = repo is IdempotentEvidenciasRepository
              ? await (repo as IdempotentEvidenciasRepository).createIdempotent(
                  q.osId,
                  input,
                  idempotencyKey: q.idempotencyKey,
                )
              : await repo.create(q.osId, input);
          _items.removeWhere((x) => x.localId == q.localId);
          await _persist();
          onUploaded?.call(q.localId, real);
          // Upload CONFIRMADO pelo servidor → o registro do PB é a fonte; a
          // cópia local (foto da casa do cliente) vira resíduo LGPD (A-01).
          // Só deletamos aqui, nunca antes da confirmação — e DEPOIS do
          // onUploaded, para o preview já ter trocado para a URL do PB.
          await _deleteLocalFile(q.filePath);
        } catch (e) {
          onFailed?.call(q.localId, e);
          break; // não martela o servidor; aguarda retry
        }
      }
    } finally {
      _processing = false;
    }
  }
}
