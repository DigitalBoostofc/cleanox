/// fakes.dart — Fakes de repositório para os testes do app do profissional.
///
/// Implementam as INTERFACES congeladas do core sem rede. Gravam as chamadas
/// relevantes (patchExec/updateStatus) para as asserções dos fluxos críticos.
library;

import 'dart:async';

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/core/repositories/evidencias_repository.dart';
import 'package:cleanos/core/repositories/ordens_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/core/repositories/whatsapp_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FakeOrdensRepository implements OrdensRepository {
  FakeOrdensRepository({this.execOS, this.listItems = const []});

  /// OS devolvida por [getExec] (execução).
  OrdemServico? execOS;

  /// Se setado, [getExec] lança este erro (simula offline/403 na validação de
  /// checklist do concluir — A-03).
  Object? getExecError;

  /// Itens devolvidos por [list] (qualquer janela).
  List<OrdemServico> listItems;

  /// Se setado, [patchExec] lança este erro (simula save offline/403).
  Object? patchError;

  /// Se setado, [list] espera este gate antes de responder (simula fetch em voo
  /// para o teste de lost-update).
  Completer<void>? listGate;

  /// Contador de chamadas de [list] (0=hoje, 1=próximas, 2=atrasadas por ciclo).
  int listCallCount = 0;

  /// Se setado, resolve os itens de [list] pela ordem da chamada (índice).
  List<OrdemServico> Function(int index)? listByIndex;

  /// Chamadas gravadas.
  final List<Map<String, dynamic>> patchCalls = [];
  final List<OSStatus> statusCalls = [];

  final StreamController<OrdemServicoEvent> _events =
      StreamController<OrdemServicoEvent>.broadcast();

  void emit(OrdemServicoEvent e) => _events.add(e);

  @override
  Future<OrdemServico> getExec(String osId) async {
    final err = getExecError;
    if (err != null) throw err;
    final os = execOS;
    if (os == null) throw StateError('execOS não configurado');
    return os;
  }

  @override
  Future<OrdemServico> patchExec(String osId, OSExecPatch patch) async {
    patchCalls.add(patch.toBody());
    final err = patchError;
    if (err != null) throw err;
    return execOS ?? _bare(osId);
  }

  @override
  Future<OrdemServico> updateStatus(String osId, OSStatus novo) async {
    statusCalls.add(novo);
    final base = execOS ?? _bare(osId);
    return base.copyWith(status: novo);
  }

  /// Chamadas de [cancelar] gravadas (motivo).
  final List<String> cancelCalls = [];

  @override
  Future<OrdemServico> cancelar(String osId, {required String motivo}) async {
    cancelCalls.add(motivo);
    final base = execOS ?? _bare(osId);
    return base.copyWith(
      status: OSStatus.cancelada,
      motivoCancelamento: motivo,
      canceladoPorNome: 'Teste',
    );
  }

  @override
  Future<OrdemServico> reabrir(String osId) async {
    final base = execOS ?? _bare(osId);
    return base.copyWith(
      status: OSStatus.agendada,
      refazer: true,
      valorPago: 0,
      valorServico: 0,
      profissional: null,
    );
  }

  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async {
    final idx = listCallCount++;
    final items = listByIndex?.call(idx) ?? listItems;
    if (listGate != null) await listGate!.future;
    return PageResult<OrdemServico>(
      items: items,
      page: 1,
      perPage: perPage,
      totalItems: items.length,
      totalPages: 1,
    );
  }

  @override
  Stream<OrdemServicoEvent> subscribe({String topic = '*', String? filter}) =>
      _events.stream;

  @override
  Future<List<OrdemServico>> listDoProfissional(
    String profId, {
    DateRange? janela,
  }) async => listItems;

  @override
  Future<OrdemServico> getOne(String osId, {String? expand}) async =>
      execOS ?? _bare(osId);

  @override
  Future<OrdemServico> create(
    Map<String, dynamic> data, {
    String? expand,
  }) async => _bare('novo');

  @override
  Future<OrdemServico> update(
    String osId,
    Map<String, dynamic> data, {
    String? expand,
  }) async => _bare(osId);

  @override
  Future<void> delete(String osId) async {}

  OrdemServico _bare(String id) =>
      OrdemServico(id: id, status: OSStatus.emAndamento);
}

class FakeWhatsAppRepository implements WhatsAppRepository {
  int avisos = 0;

  @override
  Future<AvisoResult> avisarACaminho(String osId) async {
    avisos++;
    return const AvisoResult(ok: true, sentAt: '2026-07-01 10:00:00Z');
  }

  @override
  Future<ContatoClienteResult> contatoCliente(String osId) async =>
      const ContatoClienteResult(waUrl: 'https://wa.me/5511999999999');

  @override
  Future<void> enviarRelatorio(String osId) async {}
  @override
  Future<WhatsAppStatus> status() async =>
      const WhatsAppStatus(connected: true);
  @override
  Future<WhatsAppStatus> connect() async =>
      const WhatsAppStatus(connected: true);
  @override
  Future<void> disconnect() async {}
}

class FakeEvidenciasRepository implements EvidenciasRepository {
  List<EvidenciaFoto> fotos = const [];

  @override
  Future<List<EvidenciaFoto>> listDaOS(String osId) async => fotos;

  @override
  Future<EvidenciaFoto> create(String osId, CreateEvidenciaInput input) async =>
      EvidenciaFoto(id: 'ev1', url: 'https://x/ev1', fase: input.fase);

  @override
  Future<EvidenciaFoto> updateMeta(
    String id,
    EvidenciaUpdatePatch patch,
  ) async => EvidenciaFoto(id: id, url: 'https://x/$id', fase: FaseFoto.antes);

  @override
  Future<void> delete(String id) async {}
}

/// Secure storage em memória (o plugin nativo não existe na VM de teste).
/// Estende [FlutterSecureStorage] para casar com o tipo do provider; sobrescreve
/// só o necessário (read/write/delete).
class FakeSecureStorage extends FlutterSecureStorage {
  FakeSecureStorage([Map<String, String>? seed]) : store = {...?seed}, super();

  final Map<String, String> store;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map<String, String>.from(store);
}
