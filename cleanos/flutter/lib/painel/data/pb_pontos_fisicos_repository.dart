/// pb_pontos_fisicos_repository.dart — impl PB de PontosFisicosRepository.
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/ponto_fisico.dart';
import '../../core/repositories/pontos_fisicos_repository.dart';

class PbPontosFisicosRepository implements PontosFisicosRepository {
  PbPontosFisicosRepository(this._pb);
  final PocketBase _pb;

  RecordService get _col => _pb.collection('pontos_fisicos');

  @override
  Future<List<PontoFisico>> list({bool somenteAtivos = false}) async {
    final filter = somenteAtivos ? 'ativo = true' : '';
    final res = await _col.getList(
      page: 1,
      perPage: 200,
      filter: filter.isEmpty ? null : filter,
      sort: 'nome',
    );
    return [for (final r in res.items) PontoFisico.fromRecord(r)];
  }

  @override
  Future<PontoFisico> create(Map<String, dynamic> data) async {
    final rec = await _col.create(body: data);
    return PontoFisico.fromRecord(rec);
  }

  @override
  Future<PontoFisico> update(String id, Map<String, dynamic> data) async {
    final rec = await _col.update(id, body: data);
    return PontoFisico.fromRecord(rec);
  }

  @override
  Future<void> delete(String id) async {
    await _col.delete(id);
  }
}
