/// servicos_repository.dart — Contrato do catálogo RICO de serviços.
library;

import '../models/servico.dart';
import 'repo_types.dart';

abstract class ServicosRepository {
  /// Só serviços ativos (para dropdowns de Nova OS).
  Future<List<ServicoPB>> listAtivos();
  Future<PageResult<ServicoPB>> list({
    int page,
    int perPage,
    String? filter,
    String sort,
  });
  Future<ServicoPB> getOne(String id);
  Future<ServicoPB> create(Map<String, dynamic> data);
  Future<ServicoPB> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}

/// Stub congelado (Fase 1). Impl real na Fase 2 (Time A / Painel).
class UnimplementedServicosRepository implements ServicosRepository {
  const UnimplementedServicosRepository();

  Never _todo() =>
      throw UnimplementedError('TODO Fase 2 (Painel): ServicosRepository');

  @override
  Future<List<ServicoPB>> listAtivos() => _todo();

  @override
  Future<PageResult<ServicoPB>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'nome',
  }) => _todo();

  @override
  Future<ServicoPB> getOne(String id) => _todo();

  @override
  Future<ServicoPB> create(Map<String, dynamic> data) => _todo();

  @override
  Future<ServicoPB> update(String id, Map<String, dynamic> data) => _todo();

  @override
  Future<void> delete(String id) => _todo();
}
