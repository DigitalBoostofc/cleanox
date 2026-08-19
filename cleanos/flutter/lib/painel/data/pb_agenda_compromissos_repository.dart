/// Impl PocketBase de [AgendaCompromissosRepository].
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/agenda_compromisso.dart';
import '../../core/repositories/agenda_compromissos_repository.dart';
import 'painel_filters.dart';

class PbAgendaCompromissosRepository implements AgendaCompromissosRepository {
  PbAgendaCompromissosRepository(this._pb);
  final PocketBase _pb;

  RecordService get _col => _pb.collection('agenda_compromissos');

  @override
  Future<List<AgendaCompromisso>> list({
    String? dataInicio,
    String? dataFim,
    String? profissionalId,
  }) async {
    final parts = <String>[
      if (dataInicio != null && dataInicio.isNotEmpty)
        'data_hora >= ${pbStringLiteral(dataInicio)}',
      if (dataFim != null && dataFim.isNotEmpty)
        'data_hora < ${pbStringLiteral(dataFim)}',
      if (profissionalId != null && profissionalId.isNotEmpty)
        'profissional.id ?= ${pbStringLiteral(profissionalId)}',
    ];
    final filter = parts.isEmpty ? null : parts.join(' && ');
    final res = await _col.getList(
      page: 1,
      perPage: 500,
      filter: filter,
      sort: 'data_hora',
    );
    return [for (final r in res.items) AgendaCompromisso.fromRecord(r)];
  }

  @override
  Future<AgendaCompromisso> create(Map<String, dynamic> data) async {
    final rec = await _col.create(body: data);
    return AgendaCompromisso.fromRecord(rec);
  }

  @override
  Future<AgendaCompromisso> update(String id, Map<String, dynamic> data) async {
    final rec = await _col.update(id, body: data);
    return AgendaCompromisso.fromRecord(rec);
  }

  @override
  Future<void> delete(String id) async {
    await _col.delete(id);
  }
}
