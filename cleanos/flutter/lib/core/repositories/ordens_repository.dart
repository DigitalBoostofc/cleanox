/// ordens_repository.dart — Contrato + impl PB do domínio Ordens de Serviço.
///
/// A INTERFACE é a fronteira congelada (§3.1) que os dois times consomem. As
/// features dependem da abstração (injetada por Riverpod), nunca da impl.
library;

import 'dart:async';

import 'package:pocketbase/pocketbase.dart';

import '../models/collections.dart';
import '../models/ordem_servico.dart';
import 'repo_types.dart';

/// Expand padrão da execução (profissional + serviço). NUNCA inclui `cliente`
/// no app do profissional (anti-desvio).
const String kExecExpand = 'profissional,servico';

abstract class OrdensRepository {
  /// OS de um profissional numa janela [start, end) opcional (BRT).
  Future<List<OrdemServico>> listDoProfissional(
    String profId, {
    DateRange? janela,
  });

  /// OS estendida para execução (expand profissional,servico).
  Future<OrdemServico> getExec(String osId);

  /// PATCH parcial dos campos de execução liberados ao profissional.
  Future<OrdemServico> patchExec(String osId, OSExecPatch patch);

  /// Avança o status (atribuida → em_andamento → concluida).
  Future<OrdemServico> updateStatus(String osId, OSStatus novo);

  /// Cancela a OS com motivo (auditoria server-side: quem + quando).
  /// POST /api/cleanos/os/{id}/cancelar — admin, gerente ou prof dono.
  Future<OrdemServico> cancelar(String osId, {required String motivo});

  /// Reabre OS concluída → em agendamento com etiqueta Refazer (valor zerado).
  /// POST /api/cleanos/os/{id}/reabrir — admin/gerente.
  Future<OrdemServico> reabrir(String osId);

  /// Stream realtime da coleção. `topic` = '*' (todas) ou id de uma OS.
  Stream<OrdemServicoEvent> subscribe({String topic, String? filter});

  /* ---- consumo do Painel (admin/gerente) ---- */

  /// Lista paginada genérica (filtros/sort/expand livres) — usada pelo Painel.
  Future<PageResult<OrdemServico>> list({
    int page,
    int perPage,
    String? filter,
    String sort,
    String? expand,
  });

  /// Uma OS por id, com expand opcional.
  Future<OrdemServico> getOne(String osId, {String? expand});

  /// Cria uma OS (Painel). Espelha o CRUD genérico dos demais repos.
  Future<OrdemServico> create(Map<String, dynamic> data, {String? expand});

  /// Edita uma OS (Painel).
  Future<OrdemServico> update(
    String osId,
    Map<String, dynamic> data, {
    String? expand,
  });

  /// Exclui uma OS (Painel).
  Future<void> delete(String osId);
}

/// Implementação sobre o SDK PocketBase.
class PbOrdensRepository implements OrdensRepository {
  PbOrdensRepository(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.ordensServico);

  @override
  Future<List<OrdemServico>> listDoProfissional(
    String profId, {
    DateRange? janela,
  }) async {
    final filterParts = ["profissional = {:prof}"];
    final params = <String, dynamic>{'prof': profId};
    if (janela != null) {
      filterParts.add("data_hora >= {:ini} && data_hora < {:fim}");
      params['ini'] = janela.start;
      params['fim'] = janela.end;
    }
    final res = await _col.getList(
      page: 1,
      perPage: 200,
      filter: _pb.filter(filterParts.join(' && '), params),
      sort: 'data_hora',
      expand: kExecExpand,
    );
    return res.items.map(OrdemServico.fromRecord).toList();
  }

  @override
  Future<OrdemServico> getExec(String osId) async {
    final rec = await _col.getOne(osId, expand: kExecExpand);
    return OrdemServico.fromRecord(rec);
  }

  @override
  Future<OrdemServico> patchExec(String osId, OSExecPatch patch) async {
    final rec = await _col.update(
      osId,
      body: patch.toBody(),
      expand: kExecExpand,
    );
    return OrdemServico.fromRecord(rec);
  }

  @override
  Future<OrdemServico> updateStatus(String osId, OSStatus novo) async {
    final rec = await _col.update(
      osId,
      body: {'status': novo.wire},
      expand: kExecExpand,
    );
    return OrdemServico.fromRecord(rec);
  }

  @override
  Future<OrdemServico> cancelar(String osId, {required String motivo}) async {
    await _pb.send<Map<String, dynamic>>(
      '/api/cleanos/os/$osId/cancelar',
      method: 'POST',
      body: {'motivo': motivo},
    );
    // Recarrega a OS com expand para a UI.
    return getOne(osId, expand: kExecExpand);
  }

  @override
  Future<OrdemServico> reabrir(String osId) async {
    await _pb.send<Map<String, dynamic>>(
      '/api/cleanos/os/$osId/reabrir',
      method: 'POST',
    );
    return getOne(osId, expand: 'profissional,servico,cliente');
  }

  @override
  Stream<OrdemServicoEvent> subscribe({String topic = '*', String? filter}) {
    late final StreamController<OrdemServicoEvent> controller;
    UnsubscribeFunc? unsub;
    var cancelled = false;

    Future<void> start() async {
      final fn = await _col.subscribe(
        topic,
        (e) {
          if (controller.isClosed) return;
          controller.add(
            OrdemServicoEvent(
              action: osEventActionFromWire(e.action),
              record: e.record == null
                  ? null
                  : OrdemServico.fromRecord(e.record!),
            ),
          );
        },
        filter: filter,
        expand: kExecExpand,
      );
      // Se o listener já cancelou antes de o subscribe resolver, `onCancel` não
      // tinha `unsub` para chamar → desfaz aqui para não deixar SSE órfã.
      if (cancelled) {
        await fn();
        return;
      }
      unsub = fn;
    }

    controller = StreamController<OrdemServicoEvent>(
      onListen: () {
        start().catchError((Object err) {
          if (!controller.isClosed) controller.addError(err);
        });
      },
      onCancel: () async {
        cancelled = true;
        await unsub?.call();
      },
    );
    return controller.stream;
  }

  @override
  Future<PageResult<OrdemServico>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data_hora',
    String? expand,
  }) async {
    final res = await _col.getList(
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort,
      expand: expand,
    );
    return PageResult<OrdemServico>(
      items: res.items.map(OrdemServico.fromRecord).toList(),
      page: res.page,
      perPage: res.perPage,
      totalItems: res.totalItems,
      totalPages: res.totalPages,
    );
  }

  @override
  Future<OrdemServico> getOne(String osId, {String? expand}) async {
    final rec = await _col.getOne(osId, expand: expand);
    return OrdemServico.fromRecord(rec);
  }

  @override
  Future<OrdemServico> create(
    Map<String, dynamic> data, {
    String? expand,
  }) async {
    final rec = await _col.create(body: data, expand: expand);
    return OrdemServico.fromRecord(rec);
  }

  @override
  Future<OrdemServico> update(
    String osId,
    Map<String, dynamic> data, {
    String? expand,
  }) async {
    final rec = await _col.update(osId, body: data, expand: expand);
    return OrdemServico.fromRecord(rec);
  }

  @override
  Future<void> delete(String osId) => _col.delete(osId);
}
