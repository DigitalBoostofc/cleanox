/// pb_disponibilidade_repository.dart — Impl PB da interface congelada
/// `DisponibilidadeRepository` do core (coleção `disponibilidade`), camada do
/// PAINEL (Onda 3 — Agenda + editor de disponibilidade por profissional).
///
/// Cada profissional tem NO MÁXIMO um registro de disponibilidade (semana + duração
/// do slot). O editor faz upsert: procura o registro do profissional e cria/atualiza.
///
/// Convenções (skill pocketbase-cleanos): `Collections.disponibilidade`,
/// `pb.filter` com params (nunca interpolação), `getList` paginado na listagem de
/// UI, `RecordModel` → `Disponibilidade`.
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/disponibilidade.dart';
import '../../core/repositories/disponibilidade_repository.dart';
import '../../core/repositories/repo_types.dart';

class PbDisponibilidadeRepository implements DisponibilidadeRepository {
  PbDisponibilidadeRepository(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.disponibilidade);

  @override
  Future<PageResult<Disponibilidade>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'profissional',
  }) async {
    final res = await _col.getList(
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort,
    );
    return PageResult<Disponibilidade>(
      items: res.items.map(Disponibilidade.fromRecord).toList(),
      page: res.page,
      perPage: res.perPage,
      totalItems: res.totalItems,
      totalPages: res.totalPages,
    );
  }

  @override
  Future<Disponibilidade> getOne(String id) async {
    final rec = await _col.getOne(id);
    return Disponibilidade.fromRecord(rec);
  }

  @override
  Future<Disponibilidade> create(Map<String, dynamic> data) async {
    final rec = await _col.create(body: data);
    return Disponibilidade.fromRecord(rec);
  }

  @override
  Future<Disponibilidade> update(String id, Map<String, dynamic> data) async {
    final rec = await _col.update(id, body: data);
    return Disponibilidade.fromRecord(rec);
  }

  @override
  Future<void> delete(String id) => _col.delete(id);
}
