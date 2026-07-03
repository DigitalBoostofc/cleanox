/// financeiro_repository.dart — Contrato do módulo Financeiro (admin/gerente).
library;

import '../models/financeiro.dart';
import 'repo_types.dart';

abstract class FinanceiroRepository {
  Future<List<FinConta>> listContas();
  Future<FinConta> createConta(Map<String, dynamic> data);
  Future<FinConta> updateConta(String id, Map<String, dynamic> data);
  Future<void> deleteConta(String id);

  Future<List<FinCategoria>> listCategorias();
  Future<FinCategoria> createCategoria(Map<String, dynamic> data);
  Future<FinCategoria> updateCategoria(String id, Map<String, dynamic> data);
  Future<void> deleteCategoria(String id);

  Future<PageResult<FinLancamento>> listLancamentos({
    int page,
    int perPage,
    String? filter,
    String sort,
  });
  Future<FinLancamento> createLancamento(Map<String, dynamic> data);
  Future<FinLancamento> updateLancamento(String id, Map<String, dynamic> data);
  Future<void> deleteLancamento(String id);

  Future<List<FinLimite>> listLimites();
  Future<FinLimite> upsertLimite(Map<String, dynamic> data);
  Future<void> deleteLimite(String id);
}

/// Stub congelado (Fase 1). Impl real na Fase 2 (Time A / Painel — Slice A4).
class UnimplementedFinanceiroRepository implements FinanceiroRepository {
  const UnimplementedFinanceiroRepository();

  Never _todo() =>
      throw UnimplementedError('TODO Fase 2 (Painel): FinanceiroRepository');

  @override
  Future<List<FinConta>> listContas() => _todo();
  @override
  Future<FinConta> createConta(Map<String, dynamic> data) => _todo();
  @override
  Future<FinConta> updateConta(String id, Map<String, dynamic> data) => _todo();
  @override
  Future<void> deleteConta(String id) => _todo();

  @override
  Future<List<FinCategoria>> listCategorias() => _todo();
  @override
  Future<FinCategoria> createCategoria(Map<String, dynamic> data) => _todo();
  @override
  Future<FinCategoria> updateCategoria(String id, Map<String, dynamic> data) =>
      _todo();
  @override
  Future<void> deleteCategoria(String id) => _todo();

  @override
  Future<PageResult<FinLancamento>> listLancamentos({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data',
  }) => _todo();
  @override
  Future<FinLancamento> createLancamento(Map<String, dynamic> data) => _todo();
  @override
  Future<FinLancamento> updateLancamento(
    String id,
    Map<String, dynamic> data,
  ) => _todo();
  @override
  Future<void> deleteLancamento(String id) => _todo();

  @override
  Future<List<FinLimite>> listLimites() => _todo();
  @override
  Future<FinLimite> upsertLimite(Map<String, dynamic> data) => _todo();
  @override
  Future<void> deleteLimite(String id) => _todo();
}
