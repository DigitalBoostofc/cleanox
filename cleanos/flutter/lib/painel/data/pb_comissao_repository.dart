/// pb_comissao_repository.dart — Impl PB de [ComissaoRepository].
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import '../../core/repositories/comissao_repository.dart';

class PbComissaoRepository implements ComissaoRepository {
  PbComissaoRepository(this._pb);

  final PocketBase _pb;

  @override
  Future<List<User>> listProfissionais() async {
    final recs = await _pb
        .collection(Collections.users)
        .getFullList(
          filter: _pb.filter('role = {:r}', {'r': Role.profissional.wire}),
          sort: 'nome',
        );
    return recs.map(User.fromRecord).toList();
  }

  @override
  Future<User> setComissao({
    required String profissionalId,
    required ComissaoTipo tipo,
    required double valor,
    PagamentoFrequencia? pagamentoFrequencia,
    int pagamentoDia = 0,
    int pagamentoDia2 = 0,
  }) async {
    final body = <String, dynamic>{
      'comissao_tipo': tipo.wire,
      'comissao_valor': tipo == ComissaoTipo.nenhuma ? 0 : valor,
      // R2: select vazio = "" no PB.
      'pagamento_frequencia': tipo == ComissaoTipo.nenhuma
          ? ''
          : (pagamentoFrequencia?.wire ?? ''),
      'pagamento_dia': tipo == ComissaoTipo.nenhuma ? 0 : pagamentoDia,
      'pagamento_dia_2': tipo == ComissaoTipo.nenhuma ? 0 : pagamentoDia2,
    };
    final rec = await _pb
        .collection(Collections.users)
        .update(profissionalId, body: body);
    return User.fromRecord(rec);
  }

  @override
  Future<List<ProfComissao>> listComissoes({
    String? profissionalId,
    String sort = '-data',
  }) async {
    String? filter;
    if (profissionalId != null && profissionalId.isNotEmpty) {
      filter = _pb.filter('profissional = {:id}', {'id': profissionalId});
    }
    final recs = await _pb
        .collection(Collections.profComissoes)
        .getFullList(filter: filter, sort: sort);
    return recs.map(ProfComissao.fromRecord).toList();
  }

  @override
  Future<ProfComissao> marcarPaga(String id) =>
      setStatus(id, ComissaoStatus.paga);

  @override
  Future<ProfComissao> setStatus(String id, ComissaoStatus status) async {
    final rec = await _pb
        .collection(Collections.profComissoes)
        .update(id, body: {'status': status.wire});
    return ProfComissao.fromRecord(rec);
  }
}
