/// pb_usuarios_repository.dart — Impl PB da interface congelada
/// `UsuariosRepository` do core (coleção auth `users`), camada do PAINEL.
library;

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/user.dart';
import '../../core/repositories/usuarios_repository.dart';

class PbUsuariosRepository implements UsuariosRepository {
  PbUsuariosRepository(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.users);

  List<http.MultipartFile> _files(AvatarUpload? avatar) {
    if (avatar == null) return const [];
    return [
      http.MultipartFile.fromBytes(
        'avatar',
        avatar.bytes,
        filename: avatar.filename,
      ),
    ];
  }

  @override
  Future<List<User>> list({String? filter, String sort = 'nome'}) async {
    final recs = await _col.getFullList(filter: filter, sort: sort);
    return recs.map(User.fromRecord).toList();
  }

  @override
  Future<User> getOne(String id) async {
    final rec = await _col.getOne(id);
    return User.fromRecord(rec);
  }

  @override
  Future<User> create(
    Map<String, dynamic> data, {
    AvatarUpload? avatar,
  }) async {
    final files = _files(avatar);
    final rec = files.isEmpty
        ? await _col.create(body: data)
        : await _col.create(body: data, files: files);
    return User.fromRecord(rec);
  }

  @override
  Future<User> update(
    String id,
    Map<String, dynamic> data, {
    AvatarUpload? avatar,
  }) async {
    final files = _files(avatar);
    final rec = files.isEmpty
        ? await _col.update(id, body: data)
        : await _col.update(id, body: data, files: files);
    return User.fromRecord(rec);
  }

  @override
  Future<void> delete(String id) => _col.delete(id);
}
