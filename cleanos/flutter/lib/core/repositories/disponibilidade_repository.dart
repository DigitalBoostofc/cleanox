/// disponibilidade_repository.dart — Contrato de `disponibilidade` (agenda por
/// profissional).
///
/// SÓ o Painel (admin/gerente) injeta/consome (Fase 2 — agenda). Espelha o CRUD
/// genérico dos demais repos do Painel. Stub congelado na Fase 1.
library;

import '../models/disponibilidade.dart';
import 'repo_types.dart';

abstract class DisponibilidadeRepository {
  Future<PageResult<Disponibilidade>> list({
    int page,
    int perPage,
    String? filter,
    String sort,
  });
  Future<Disponibilidade> getOne(String id);
  Future<Disponibilidade> create(Map<String, dynamic> data);
  Future<Disponibilidade> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}

/// Stub congelado (Fase 1). Impl real é entregue na Fase 2 (Time A / Painel).
class UnimplementedDisponibilidadeRepository
    implements DisponibilidadeRepository {
  const UnimplementedDisponibilidadeRepository();

  Never _todo() => throw UnimplementedError(
    'TODO Fase 2 (Painel): DisponibilidadeRepository',
  );

  @override
  Future<PageResult<Disponibilidade>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'profissional',
  }) => _todo();

  @override
  Future<Disponibilidade> getOne(String id) => _todo();

  @override
  Future<Disponibilidade> create(Map<String, dynamic> data) => _todo();

  @override
  Future<Disponibilidade> update(String id, Map<String, dynamic> data) =>
      _todo();

  @override
  Future<void> delete(String id) => _todo();
}
