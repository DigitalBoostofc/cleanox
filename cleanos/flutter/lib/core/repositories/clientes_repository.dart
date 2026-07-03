/// clientes_repository.dart — 🔒 COFRE. Contrato do CRUD de `clientes`.
///
/// ANTI-DESVIO: SÓ o Painel (admin/gerente) injeta/consome. O app do profissional
/// NUNCA registra este repositório — a coleção é negada por regra de servidor.
library;

import '../models/cliente.dart';
import 'repo_types.dart';

abstract class ClientesRepository {
  Future<PageResult<Cliente>> list({
    int page,
    int perPage,
    String? filter,
    String sort,
  });
  Future<Cliente> getOne(String id);
  Future<Cliente> create(Map<String, dynamic> data);
  Future<Cliente> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}

/// Stub congelado (Fase 1). Impl real é entregue na Fase 2 (Time A / Painel).
class UnimplementedClientesRepository implements ClientesRepository {
  const UnimplementedClientesRepository();

  Never _todo() =>
      throw UnimplementedError('TODO Fase 2 (Painel): ClientesRepository');

  @override
  Future<PageResult<Cliente>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'nome',
  }) => _todo();

  @override
  Future<Cliente> getOne(String id) => _todo();

  @override
  Future<Cliente> create(Map<String, dynamic> data) => _todo();

  @override
  Future<Cliente> update(String id, Map<String, dynamic> data) => _todo();

  @override
  Future<void> delete(String id) => _todo();
}
