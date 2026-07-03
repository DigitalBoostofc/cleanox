/// pb_config_atuacao_repository.dart — Impl PB da interface congelada
/// `ConfigAtuacaoRepository` do core (coleção `config_atuacao`), camada do PAINEL.
///
/// Singleton de área de atuação (estado + cidades/bairros). `get()` devolve o
/// primeiro (e único) registro, ou `null` se ainda não existir — o editor decide
/// entre `create`/`update`.
///
/// Convenções (skill pocketbase-cleanos): `Collections.configAtuacao`, sem string
/// de coleção solta, tratamento gracioso do 404 (coleção vazia).
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/config_atuacao.dart';
import '../../core/repositories/config_atuacao_repository.dart';

class PbConfigAtuacaoRepository implements ConfigAtuacaoRepository {
  PbConfigAtuacaoRepository(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.configAtuacao);

  @override
  Future<ConfigAtuacao?> get() async {
    // Conjunto singleton (1 registro): getList perPage=1 é suficiente e barato.
    final res = await _col.getList(page: 1, perPage: 1, sort: '-created');
    if (res.items.isEmpty) return null;
    return ConfigAtuacao.fromRecord(res.items.first);
  }

  @override
  Future<ConfigAtuacao> create(Map<String, dynamic> data) async {
    final rec = await _col.create(body: data);
    return ConfigAtuacao.fromRecord(rec);
  }

  @override
  Future<ConfigAtuacao> update(String id, Map<String, dynamic> data) async {
    final rec = await _col.update(id, body: data);
    return ConfigAtuacao.fromRecord(rec);
  }
}
