/// pb_comissao_repository.dart — Impl PB de [ComissaoRepository].
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import '../../core/repositories/comissao_repository.dart';

Map<String, dynamic> comissaoUserUpdateBody({
  required ComissaoTipo tipo,
  required double valor,
  RemuneracaoTipo remuneracaoTipo = RemuneracaoTipo.nenhuma,
  double remuneracaoValor = 0,
  PagamentoFrequencia? pagamentoFrequencia,
  int pagamentoDia = 0,
  int pagamentoDia2 = 0,
}) {
  final keepCycle = tipo != ComissaoTipo.nenhuma ||
      remuneracaoTipo == RemuneracaoTipo.salarioFixo;
  return {
    'comissao_tipo': tipo.wire,
    'comissao_valor': tipo == ComissaoTipo.nenhuma ? 0 : valor,
    'remuneracao_tipo': remuneracaoTipo.wire,
    'remuneracao_valor': remuneracaoTipo == RemuneracaoTipo.salarioFixo
        ? remuneracaoValor
        : 0,
    // R2: select vazio = "" no PB. Salário fixo também precisa do ciclo.
    'pagamento_frequencia': keepCycle ? (pagamentoFrequencia?.wire ?? '') : '',
    'pagamento_dia': keepCycle ? pagamentoDia : 0,
    'pagamento_dia_2': keepCycle ? pagamentoDia2 : 0,
  };
}

class PbComissaoRepository implements ComissaoRepository {
  PbComissaoRepository(this._pb);

  final PocketBase _pb;

  @override
  Future<List<User>> listProfissionais({bool incluirInativos = false}) async {
    final recs = await _pb
        .collection(Collections.users)
        .getFullList(
          sort: 'nome',
        );
    return recs
        .map(User.fromRecord)
        .where((u) => u.hasRole(Role.profissional))
        .where((u) => incluirInativos || u.ativo)
        .toList();
  }

  @override
  Future<User> setComissao({
    required String profissionalId,
    required ComissaoTipo tipo,
    required double valor,
    RemuneracaoTipo remuneracaoTipo = RemuneracaoTipo.nenhuma,
    double remuneracaoValor = 0,
    PagamentoFrequencia? pagamentoFrequencia,
    int pagamentoDia = 0,
    int pagamentoDia2 = 0,
  }) async {
    final rec = await _pb
        .collection(Collections.users)
        .update(
          profissionalId,
          body: comissaoUserUpdateBody(
            tipo: tipo,
            valor: valor,
            remuneracaoTipo: remuneracaoTipo,
            remuneracaoValor: remuneracaoValor,
            pagamentoFrequencia: pagamentoFrequencia,
            pagamentoDia: pagamentoDia,
            pagamentoDia2: pagamentoDia2,
          ),
        );
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
    final body = <String, dynamic>{'status': status.wire};
    // Paga: manda pago_em no mesmo update (BRT yyyy-MM-dd) para o hook não
    // precisar de 2º save e para o repasse upsertar 1 despesa por dia.
    if (status == ComissaoStatus.paga) {
      final now = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      body['pago_em'] = '$y-$m-$d';
    } else if (status == ComissaoStatus.pendente) {
      body['pago_em'] = '';
    }
    final rec = await _pb
        .collection(Collections.profComissoes)
        .update(id, body: body);
    return ProfComissao.fromRecord(rec);
  }

  @override
  Future<void> marcarLotePagas(List<String> ids) async {
    for (final id in ids) {
      if (id.isEmpty) continue;
      await setStatus(id, ComissaoStatus.paga);
    }
  }

  @override
  Future<void> excluirBonificacao(String id) async {
    await _pb.collection(Collections.profComissoes).delete(id);
  }

  @override
  Future<ProfComissao> criarBonificacao({
    required String profissionalId,
    required double valor,
    String descricao = '',
    String? osId,
  }) async {
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final body = <String, dynamic>{
      'profissional': profissionalId,
      'valor_os': 0,
      'valor_comissao': valor,
      'tipo_aplicado': ProfComissaoTipo.bonificacao.wire,
      'base_valor': valor,
      'status': ComissaoStatus.pendente.wire,
      'data': '$y-$m-$d 00:00:00.000Z',
      'descricao': descricao.trim(),
    };
    if (osId != null && osId.isNotEmpty) body['os'] = osId;
    final rec = await _pb
        .collection(Collections.profComissoes)
        .create(body: body);
    return ProfComissao.fromRecord(rec);
  }
}
