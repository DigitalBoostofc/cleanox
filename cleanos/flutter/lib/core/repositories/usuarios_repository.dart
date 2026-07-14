/// usuarios_repository.dart — Contrato do CRUD de `users` (papéis) — admin/gerente.
library;

import '../models/user.dart';

/// Bytes + nome de arquivo para upload de avatar (multipart).
class AvatarUpload {
  const AvatarUpload({required this.bytes, required this.filename});
  final List<int> bytes;
  final String filename;
}

abstract class UsuariosRepository {
  Future<List<User>> list({String? filter, String sort});
  Future<User> getOne(String id);
  Future<User> create(Map<String, dynamic> data, {AvatarUpload? avatar});
  Future<User> update(
    String id,
    Map<String, dynamic> data, {
    AvatarUpload? avatar,
  });
  Future<void> delete(String id);
}

/// Stub congelado (Fase 1). Impl real na Fase 2 (Time A / Painel).
class UnimplementedUsuariosRepository implements UsuariosRepository {
  const UnimplementedUsuariosRepository();

  Never _todo() =>
      throw UnimplementedError('TODO Fase 2 (Painel): UsuariosRepository');

  @override
  Future<List<User>> list({String? filter, String sort = 'nome'}) => _todo();
  @override
  Future<User> getOne(String id) => _todo();
  @override
  Future<User> create(Map<String, dynamic> data, {AvatarUpload? avatar}) =>
      _todo();
  @override
  Future<User> update(
    String id,
    Map<String, dynamic> data, {
    AvatarUpload? avatar,
  }) =>
      _todo();
  @override
  Future<void> delete(String id) => _todo();
}
