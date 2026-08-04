/// os_atividade_repository.dart — Feed da OS + notificações in-app.
library;

import 'package:pocketbase/pocketbase.dart';

import '../models/collections.dart';
import '../models/os_atividade.dart';
import '../models/user.dart';

abstract class OsAtividadeRepository {
  Future<List<OsAtividade>> listByOs(String osId, {int perPage});
  Future<OsAtividade> addComentario({
    required String osId,
    required String texto,
    List<String> mentionIds,
  });

  /// Admin/gerente para autocomplete de @menção.
  Future<List<User>> listMencionaveis();

  Future<List<NotificacaoInApp>> listNotificacoes({int perPage});
  Future<int> countNaoLidas();
  Future<void> marcarLida(String id);
  Future<void> marcarTodasLidas();
}

class PbOsAtividadeRepository implements OsAtividadeRepository {
  PbOsAtividadeRepository(this._pb);

  final PocketBase _pb;

  RecordService get _ativ => _pb.collection(Collections.osAtividade);
  RecordService get _notif => _pb.collection(Collections.notificacoes);
  RecordService get _users => _pb.collection(Collections.users);

  @override
  Future<List<OsAtividade>> listByOs(String osId, {int perPage = 100}) async {
    final res = await _ativ.getList(
      page: 1,
      perPage: perPage,
      filter: _pb.filter('os = {:id}', {'id': osId}),
      sort: '-created',
      expand: 'autor',
    );
    return res.items.map(OsAtividade.fromRecord).toList();
  }

  @override
  Future<OsAtividade> addComentario({
    required String osId,
    required String texto,
    List<String> mentionIds = const [],
  }) async {
    final body = <String, dynamic>{
      'os': osId,
      'tipo': 'comentario',
      'texto': texto.trim(),
      if (mentionIds.isNotEmpty) 'mentions': mentionIds,
    };
    final rec = await _ativ.create(body: body, expand: 'autor');
    return OsAtividade.fromRecord(rec);
  }

  @override
  Future<List<User>> listMencionaveis() async {
    final recs = await _users.getFullList(
      filter: _pb.filter(
        'role = {:a} || role = {:g}',
        {'a': Role.admin.wire, 'g': Role.gerente.wire},
      ),
      sort: 'nome',
    );
    return recs.map(User.fromRecord).toList();
  }

  @override
  Future<List<NotificacaoInApp>> listNotificacoes({int perPage = 40}) async {
    final res = await _notif.getList(
      page: 1,
      perPage: perPage,
      sort: '-created',
    );
    return res.items.map(NotificacaoInApp.fromRecord).toList();
  }

  @override
  Future<int> countNaoLidas() async {
    final res = await _notif.getList(
      page: 1,
      perPage: 1,
      filter: _pb.filter('lida = false'),
    );
    return res.totalItems;
  }

  @override
  Future<void> marcarLida(String id) async {
    await _notif.update(id, body: {'lida': true});
  }

  @override
  Future<void> marcarTodasLidas() async {
    final list = await listNotificacoes(perPage: 100);
    for (final n in list.where((n) => !n.lida)) {
      try {
        await marcarLida(n.id);
      } catch (_) {}
    }
  }
}
