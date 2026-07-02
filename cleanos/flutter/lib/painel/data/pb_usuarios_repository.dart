/// pb_usuarios_repository.dart — Impl PB da interface congelada
/// `UsuariosRepository` do core (coleção auth `users`), camada do PAINEL.
///
/// Nesta onda o Painel consome apenas [list] com filtro por papel (dropdown de
/// profissionais em "Nova OS"). O CRUD de usuários é uma onda futura; a impl honra
/// a interface inteira para reuso.
///
/// Convenções: `Collections.users`, `pb.filter`, `RecordModel` → `User`.
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/user.dart';
import '../../core/repositories/usuarios_repository.dart';

class PbUsuariosRepository implements UsuariosRepository {
  PbUsuariosRepository(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.users);

  @override
  Future<List<User>> list({String? filter, String sort = 'nome'}) async {
    // Equipe pequena e fechada → getFullList é adequado (não é uma lista de UI
    // paginável). Ordena por `nome` (campo extra) com fallback implícito ao `name`.
    final recs = await _col.getFullList(filter: filter, sort: sort);
    return recs.map(User.fromRecord).toList();
  }

  @override
  Future<User> getOne(String id) async {
    final rec = await _col.getOne(id);
    return User.fromRecord(rec);
  }

  @override
  Future<User> create(Map<String, dynamic> data) async {
    final rec = await _col.create(body: data);
    return User.fromRecord(rec);
  }

  @override
  Future<User> update(String id, Map<String, dynamic> data) async {
    final rec = await _col.update(id, body: data);
    return User.fromRecord(rec);
  }

  @override
  Future<void> delete(String id) => _col.delete(id);
}
