/// os_execucao_controller.dart — Estado da execução de uma OS (Slice B2).
///
/// Espelha `OSExecucaoApp.tsx`: carrega a OS (getExec), checklist com auto-save
/// DEBOUNCED (~800ms, só `checklist_exec` via patchExec — nunca campos travados),
/// evidências com fila de upload persistente/offline, e a montagem do laudo. Trata
/// 403 do hook graciosamente (describeOSError). Consome só o core + a fila
/// (data layer do profissional) — nada de PocketBase cru aqui.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/errors/os_error.dart';
import '../../core/models/collections.dart' show OSStatus;
import '../../core/models/os_execucao.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/servico.dart';
import '../../core/repositories/evidencias_repository.dart';
import '../../core/repositories/ordens_repository.dart';
import '../../core/repositories/repo_types.dart';
import '../../core/storage/local_store_keys.dart';
import '../../shared_widgets_os/shared_widgets_os.dart';
import '../data/prof_providers.dart';
import '../data/upload_queue.dart';

/// Estado do indicador de auto-save.
enum SaveState { idle, saving, saved, error }

class OSExecucaoState {
  const OSExecucaoState({
    this.os,
    this.snapshot,
    this.checklist = const [],
    this.fotos = const [],
    this.loading = true,
    this.fotosLoading = true,
    this.loadError,
    this.saveState = SaveState.idle,
    this.saveError,
    this.pendingIds = const {},
    this.failedIds = const {},
    this.deletingId,
    this.discardedCount = 0,
  });

  final OrdemServico? os;
  final ServiceSnapshot? snapshot;
  final List<ChecklistExecItem> checklist;
  final List<EvidenciaFoto> fotos;
  final bool loading;
  final bool fotosLoading;
  final String? loadError;
  final SaveState saveState;
  final String? saveError;
  final Set<String> pendingIds;
  final Set<String> failedIds;
  final String? deletingId;

  /// Contador de fotos descartadas porque o arquivo de origem sumiu (a tela
  /// escuta a variação para avisar o profissional). Só cresce.
  final int discardedCount;

  int get checklistDone => checklist.where((i) => i.concluido).length;

  OSExecucaoState copyWith({
    OrdemServico? os,
    ServiceSnapshot? snapshot,
    List<ChecklistExecItem>? checklist,
    List<EvidenciaFoto>? fotos,
    bool? loading,
    bool? fotosLoading,
    Object? loadError = _sentinel,
    SaveState? saveState,
    Object? saveError = _sentinel,
    Set<String>? pendingIds,
    Set<String>? failedIds,
    Object? deletingId = _sentinel,
    int? discardedCount,
  }) {
    return OSExecucaoState(
      os: os ?? this.os,
      snapshot: snapshot ?? this.snapshot,
      checklist: checklist ?? this.checklist,
      fotos: fotos ?? this.fotos,
      loading: loading ?? this.loading,
      fotosLoading: fotosLoading ?? this.fotosLoading,
      loadError: identical(loadError, _sentinel)
          ? this.loadError
          : loadError as String?,
      saveState: saveState ?? this.saveState,
      saveError: identical(saveError, _sentinel)
          ? this.saveError
          : saveError as String?,
      pendingIds: pendingIds ?? this.pendingIds,
      failedIds: failedIds ?? this.failedIds,
      deletingId: identical(deletingId, _sentinel)
          ? this.deletingId
          : deletingId as String?,
      discardedCount: discardedCount ?? this.discardedCount,
    );
  }

  static const Object _sentinel = Object();
}

class OSExecucaoController
    extends AutoDisposeFamilyNotifier<OSExecucaoState, String> {
  Timer? _saveTimer;
  Timer? _savedReset;
  final Map<String, Timer> _legendaTimers = {};
  String? _lastSavedChecklist;
  UploadQueue? _queue;
  int _seq = 0;
  final Random _rand = Random();

  late String _osId;

  OrdensRepository get _repo => ref.read(ordensRepositoryProvider);
  EvidenciasRepository get _evRepo => ref.read(evidenciasRepositoryProvider);
  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  /// Chave do buffer offline do checklist (secure storage) por OS.
  /// Prefixo canônico: entra na purga LGPD do logout (A-05).
  String get _checklistBufKey => '$kChecklistBufKeyPrefix$_osId';

  @override
  OSExecucaoState build(String osId) {
    _osId = osId;
    ref.onDispose(() {
      _saveTimer?.cancel();
      _savedReset?.cancel();
      for (final t in _legendaTimers.values) {
        t.cancel();
      }
    });
    // ignore: discarded_futures
    Future.microtask(load);
    return const OSExecucaoState();
  }

  // ── carga ─────────────────────────────────────────────────────────────────

  String _serialize(List<ChecklistExecItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  Future<void> load() async {
    state = state.copyWith(loading: true, loadError: null);
    OrdemServico os;
    try {
      os = await _repo.getExec(_osId);
    } catch (err) {
      state = state.copyWith(
        loading: false,
        loadError: describeOSError(err).message,
      );
      return;
    }
    final myId = ref.read(currentProfIdProvider);
    if (os.profissional != null && myId != null && os.profissional != myId) {
      state = state.copyWith(
        loading: false,
        loadError: 'Você não tem permissão para esta OS.',
      );
      return;
    }
    _lastSavedChecklist = _serialize(os.checklistExec);
    state = state.copyWith(
      os: os,
      snapshot: os.serviceSnapshot,
      checklist: os.checklistExec,
      loading: false,
      loadError: null,
    );
    // Recupera uma edição offline não salva (buffer em secure storage) e a
    // reenvia — antes disso ela morria com o app.
    await _restoreChecklistBuffer();
    _initQueue();
    await loadFotos();
  }

  /// Se há edição bufferizada (não confirmada no servidor), restaura no estado e
  /// reagenda o envio. Roda no restart/recriação do provider (reconnect).
  Future<void> _restoreChecklistBuffer() async {
    String? buffered;
    try {
      buffered = await _storage.read(key: _checklistBufKey);
    } catch (_) {
      return;
    }
    if (buffered == null || buffered.isEmpty) return;
    if (buffered == _lastSavedChecklist) {
      await _clearChecklistBuffer();
      return;
    }
    try {
      final list = (jsonDecode(buffered) as List)
          .map((e) => ChecklistExecItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(checklist: list);
      // ignore: discarded_futures
      _doSave(buffered);
    } catch (_) {
      // Buffer corrompido — descarta (o servidor continua sendo a verdade).
      await _clearChecklistBuffer();
    }
  }

  Future<void> _writeChecklistBuffer(String serialized) async {
    try {
      await _storage.write(key: _checklistBufKey, value: serialized);
    } catch (_) {
      /* best-effort */
    }
  }

  Future<void> _clearChecklistBuffer() async {
    try {
      await _storage.delete(key: _checklistBufKey);
    } catch (_) {
      /* best-effort */
    }
  }

  // ── checklist (auto-save debounced) ─────────────────────────────────────────

  void setChecklist(List<ChecklistExecItem> items) {
    state = state.copyWith(checklist: items);
    _saveTimer?.cancel();
    final serialized = _serialize(items);
    if (serialized == _lastSavedChecklist) {
      // Voltou ao estado salvo — nada pendente para bufferizar.
      // ignore: discarded_futures
      _clearChecklistBuffer();
      return;
    }
    // Persiste a edição IMEDIATAMENTE (sobrevive a kill/offline antes do
    // debounce) — o flush ao servidor continua debounced.
    // ignore: discarded_futures
    _writeChecklistBuffer(serialized);
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      // ignore: discarded_futures
      _doSave(serialized);
    });
  }

  Future<void> _doSave(String serialized) async {
    if (serialized == _lastSavedChecklist) return;
    state = state.copyWith(saveState: SaveState.saving, saveError: null);
    try {
      // Só `checklist_exec` (campo liberado) — nunca reenvia snapshot/travados.
      await _repo.patchExec(
        _osId,
        OSExecPatch(
          checklistExec: state.checklist.map((e) => e.toJson()).toList(),
        ),
      );
      _lastSavedChecklist = serialized;
      state = state.copyWith(saveState: SaveState.saved, saveError: null);
      // Confirmado no servidor → o buffer offline não é mais necessário
      // (best-effort; não bloqueia o indicador de "salvo").
      // ignore: discarded_futures
      _clearChecklistBuffer();
      _savedReset?.cancel();
      _savedReset = Timer(const Duration(seconds: 2), () {
        if (state.saveState == SaveState.saved) {
          state = state.copyWith(saveState: SaveState.idle);
        }
      });
    } catch (err) {
      final info = describeOSError(err);
      state = state.copyWith(
        saveState: SaveState.error,
        saveError: info.isPermission
            ? 'Sem permissão para salvar alterações nesta OS.'
            : info.message,
      );
    }
  }

  // ── evidências ─────────────────────────────────────────────────────────────

  void _initQueue() {
    final q = UploadQueue(
      repo: _evRepo,
      storage: ref.read(secureStorageProvider),
      osId: _osId,
      enviadoPorId: ref.read(currentProfIdProvider),
    );
    q.onUploaded = (localId, real) {
      state = state.copyWith(
        fotos: state.fotos.map((f) => f.id == localId ? real : f).toList(),
        pendingIds: {...state.pendingIds}..remove(localId),
        failedIds: {...state.failedIds}..remove(localId),
      );
    };
    q.onFailed = (localId, _) {
      state = state.copyWith(
        pendingIds: {...state.pendingIds}..remove(localId),
        failedIds: {...state.failedIds}..add(localId),
      );
    };
    q.onDiscarded = (localId) {
      // Arquivo sumiu — tira o preview fantasma e sinaliza a tela (toast).
      state = state.copyWith(
        fotos: state.fotos.where((f) => f.id != localId).toList(),
        pendingIds: {...state.pendingIds}..remove(localId),
        failedIds: {...state.failedIds}..remove(localId),
        discardedCount: state.discardedCount + 1,
      );
    };
    _queue = q;
    // ignore: discarded_futures
    q.load().then((_) => _resumeQueued());
  }

  /// Reconstrói os previews otimistas de itens que ficaram na fila (restart).
  void _resumeQueued() {
    final queue = _queue;
    if (queue == null || queue.pending.isEmpty) return;
    final existentes = state.fotos.map((f) => f.id).toSet();
    final novas = <EvidenciaFoto>[];
    final pend = {...state.pendingIds};
    for (final item in queue.pending) {
      if (!existentes.contains(item.localId)) {
        novas.add(
          EvidenciaFoto(
            id: item.localId,
            url: item.filePath,
            fase: item.fase,
            legenda: item.legenda,
          ),
        );
        pend.add(item.localId);
      }
    }
    if (novas.isNotEmpty) {
      state = state.copyWith(
        fotos: [...state.fotos, ...novas],
        pendingIds: pend,
      );
    }
  }

  Future<void> loadFotos() async {
    state = state.copyWith(fotosLoading: true);
    try {
      final servidor = await _evRepo.listDaOS(_osId);
      // Preserva os previews locais ainda não persistidos (pending/failed).
      final locais = state.fotos
          .where(
            (f) =>
                state.pendingIds.contains(f.id) ||
                state.failedIds.contains(f.id),
          )
          .toList();
      state = state.copyWith(
        fotos: [...servidor, ...locais],
        fotosLoading: false,
      );
    } catch (_) {
      // Evidências são secundárias; offline mantém o que já há em cache.
      state = state.copyWith(fotosLoading: false);
    }
  }

  String _tmpId() {
    _seq += 1;
    return 'tmp_${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  /// uuid v4 (suficiente para a idempotência do upload).
  String _uuid() {
    final b = List<int>.generate(16, (_) => _rand.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // versão 4
    b[8] = (b[8] & 0x3f) | 0x80; // variante
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
        '-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Copia os bytes da foto para um diretório app-private ESTÁVEL e devolve esse
  /// caminho (o cache do image_picker é volátil). Se a cópia falhar, cai no
  /// caminho original (best-effort — melhor tentar subir do que perder a foto).
  Future<String> _copiarParaAppPrivate(File file, String id) async {
    try {
      final dir = await ref.read(evidenceDirProvider.future);
      final ext = file.path.contains('.') ? file.path.split('.').last : 'jpg';
      final dest = File('${dir.path}/$id.$ext');
      await dest.writeAsBytes(await file.readAsBytes(), flush: true);
      return dest.path;
    } catch (_) {
      return file.path;
    }
  }

  /// Enfileira uma foto local (preview otimista imediato + upload em background).
  Future<void> enqueueFoto({
    required File file,
    required FaseFoto fase,
    String? legenda,
    String? checklistItemId,
  }) async {
    final id = _tmpId();
    final legendaFinal =
        legenda ??
        file.path
            .split(RegExp(r'[\\/]'))
            .last
            .replaceAll(RegExp(r'\.[^.]+$'), '');
    // Copia para armazenamento estável ANTES de enfileirar — o path enfileirado
    // precisa sobreviver a um kill + limpeza do cache do SO.
    final stablePath = await _copiarParaAppPrivate(file, id);
    state = state.copyWith(
      fotos: [
        ...state.fotos,
        EvidenciaFoto(
          id: id,
          url: stablePath,
          fase: fase,
          legenda: legendaFinal,
          checklistItemId: checklistItemId,
        ),
      ],
      pendingIds: {...state.pendingIds}..add(id),
    );
    await _queue?.enqueue(
      QueuedUpload(
        localId: id,
        osId: _osId,
        filePath: stablePath,
        fase: fase,
        idempotencyKey: _uuid(),
        legenda: legendaFinal,
        checklistItemId: checklistItemId,
      ),
    );
  }

  bool _isLocal(String id) =>
      state.pendingIds.contains(id) || state.failedIds.contains(id);

  Future<void> removeFoto(String id) async {
    if (_isLocal(id)) {
      await _queue?.removeLocal(id);
      state = state.copyWith(
        fotos: state.fotos.where((f) => f.id != id).toList(),
        pendingIds: {...state.pendingIds}..remove(id),
        failedIds: {...state.failedIds}..remove(id),
      );
      return;
    }
    state = state.copyWith(deletingId: id);
    try {
      await _evRepo.delete(id);
      state = state.copyWith(
        fotos: state.fotos.where((f) => f.id != id).toList(),
        deletingId: null,
      );
    } catch (_) {
      state = state.copyWith(deletingId: null);
      rethrow;
    }
  }

  void setLegenda(String id, String value) {
    final legenda = value.isEmpty ? null : value;
    state = state.copyWith(
      fotos: state.fotos
          .map((f) => f.id == id ? f.copyWith(legenda: legenda) : f)
          .toList(),
    );
    // Item local: persiste no upload (fila) — não chama updateMeta.
    if (_isLocal(id)) return;
    _legendaTimers[id]?.cancel();
    _legendaTimers[id] = Timer(const Duration(milliseconds: 700), () {
      _legendaTimers.remove(id);
      // ignore: discarded_futures
      _evRepo
          .updateMeta(id, EvidenciaUpdatePatch(legenda: value))
          .catchError(
            (_) => state.fotos.firstWhere(
              (f) => f.id == id,
              orElse: () => EvidenciaFoto(id: id),
            ),
          );
    });
  }

  void setVinculo(String id, Vinculo? v) {
    EvidenciaFoto apply(EvidenciaFoto f) => f.copyWith(
      checklistItemId: v?.kind == VinculoKind.checklist ? v!.id : null,
      observacaoId: v?.kind == VinculoKind.observacao ? v!.id : null,
      adicionalId: v?.kind == VinculoKind.adicional ? v!.id : null,
    );
    state = state.copyWith(
      fotos: state.fotos.map((f) => f.id == id ? apply(f) : f).toList(),
    );
    if (_isLocal(id)) return;
    // ignore: discarded_futures
    _evRepo.updateMeta(
      id,
      EvidenciaUpdatePatch(
        checklistItemId: v?.kind == VinculoKind.checklist ? v!.id : '',
        observacaoId: v?.kind == VinculoKind.observacao ? v!.id : '',
        adicionalId: v?.kind == VinculoKind.adicional ? v!.id : '',
      ),
    );
  }

  Future<void> retryFoto(String id) async {
    if (!state.failedIds.contains(id)) return;
    state = state.copyWith(
      pendingIds: {...state.pendingIds}..add(id),
      failedIds: {...state.failedIds}..remove(id),
    );
    await _queue?.retry();
  }

  // ── conclusão ───────────────────────────────────────────────────────────

  /// Conclui a OS a partir do CTA fixo da tela de execução (reskin Fintech
  /// Clean, doc 12 Onda 2 — espelha `MeusServicosController.concluir`, mas
  /// sem repetir o `getExec`: o checklist já está ao vivo em [state]). A UI
  /// só habilita o botão sem obrigatórios pendentes e com pagamento
  /// registrado; o servidor (`os_logic.js`) segue sendo a trava definitiva.
  Future<void> concluir() async {
    final updated = await _repo.updateStatus(_osId, OSStatus.concluida);
    state = state.copyWith(os: updated);
  }

  // ── laudo ───────────────────────────────────────────────────────────────

  /// Monta o [RelatorioOS] a partir do estado atual. Renova as fotos (tokens
  /// expiram ~2min) antes de montar. Retorna null se a OS não tem serviço.
  /// 🔒 anti-desvio: só usa `endereco_liberado` (nunca endereço completo do
  /// cadastro) e NUNCA telefone do cliente.
  Future<RelatorioOS?> montarLaudo() async {
    final os = state.os;
    final snap = state.snapshot;
    if (os == null || snap == null) return null;
    await loadFotos();
    // 🔒 Só evidências JÁ enviadas (URL protegida do PB). Fotos locais pendentes/
    // falhas guardam um filePath do dispositivo — não podem entrar no laudo.
    final evidenciasEnviadas = state.fotos
        .where(
          (f) =>
              !state.pendingIds.contains(f.id) &&
              !state.failedIds.contains(f.id),
        )
        .toList();
    final profNome =
        os.expand?.profissional?.displayName ??
        ref.read(currentUserProvider)?.displayName ??
        'Profissional';
    return buildRelatorioOS(
      BuildRelatorioOSInput(
        osId: os.id,
        numeroOS: numeroFromId(os.id),
        clienteNome: os.nomeCurto.isNotEmpty ? os.nomeCurto : 'Cliente',
        enderecoCompleto: os.enderecoLiberado,
        bairro: os.bairro.isNotEmpty ? os.bairro : null,
        profissionalNome: profNome,
        dataHora: os.dataHora,
        snapshot: snap,
        adicionais: os.adicionais,
        checklist: state.checklist,
        evidencias: evidenciasEnviadas,
        observacoes: os.observacoesProf,
        descontos: os.descontos,
        avaliacaoNota: os.avaliacaoNota,
        geradoEm: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }
}

final osExecucaoProvider =
    AutoDisposeNotifierProviderFamily<
      OSExecucaoController,
      OSExecucaoState,
      String
    >(OSExecucaoController.new);
