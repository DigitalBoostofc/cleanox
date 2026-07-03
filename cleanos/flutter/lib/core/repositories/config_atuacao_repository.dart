/// config_atuacao_repository.dart — Contrato de `config_atuacao` (singleton de
/// área de atuação).
///
/// SÓ o Painel (admin/gerente) injeta/consome (Fase 2 — config). Stub congelado
/// na Fase 1.
library;

import '../models/config_atuacao.dart';

abstract class ConfigAtuacaoRepository {
  /// Config singleton atual, ou `null` se ainda não existir.
  Future<ConfigAtuacao?> get();
  Future<ConfigAtuacao> create(Map<String, dynamic> data);
  Future<ConfigAtuacao> update(String id, Map<String, dynamic> data);
}

/// Stub congelado (Fase 1). Impl real é entregue na Fase 2 (Time A / Painel).
class UnimplementedConfigAtuacaoRepository implements ConfigAtuacaoRepository {
  const UnimplementedConfigAtuacaoRepository();

  Never _todo() =>
      throw UnimplementedError('TODO Fase 2 (Painel): ConfigAtuacaoRepository');

  @override
  Future<ConfigAtuacao?> get() => _todo();

  @override
  Future<ConfigAtuacao> create(Map<String, dynamic> data) => _todo();

  @override
  Future<ConfigAtuacao> update(String id, Map<String, dynamic> data) => _todo();
}
