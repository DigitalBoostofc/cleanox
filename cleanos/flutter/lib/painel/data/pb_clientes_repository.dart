/// pb_clientes_repository.dart — 🔒 COFRE. Impl PB da interface congelada
/// `ClientesRepository` do core, na camada de dados do PAINEL (Time A).
///
/// ANTI-DESVIO: SÓ o Painel (admin/gerente) injeta/consome — a coleção `clientes`
/// carrega PII (telefone/e-mail/endereço) e é negada ao profissional por regra de
/// servidor. Esta impl NUNCA é registrada no app do profissional.
///
/// Padrão idêntico a `profissional/data/*` e ao core `PbOrdensRepository`:
///   • nomes de coleção sempre de `Collections` (nunca string solta);
///   • filtros sempre via `pb.filter(expr, params)` (binding anti-injeção);
///   • lista de UI paginada com `getList` (NUNCA `getFullList`);
///   • mapeia `RecordModel` → `Cliente` (nunca vaza o record para a UI).
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/formatters/formatters.dart';
import '../../core/models/cliente.dart';
import '../../core/models/collections.dart';
import '../../core/pb/pb_filters.dart';
import '../../core/repositories/clientes_repository.dart';
import '../../core/repositories/repo_types.dart';

class PbClientesRepository implements ClientesRepository {
  PbClientesRepository(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.clientes);

  @override
  Future<PageResult<Cliente>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'nome,sobrenome',
  }) async {
    final res = await _col.getList(
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort,
    );
    return PageResult<Cliente>(
      items: res.items.map(Cliente.fromRecord).toList(),
      page: res.page,
      perPage: res.perPage,
      totalItems: res.totalItems,
      totalPages: res.totalPages,
    );
  }

  @override
  Future<Cliente> getOne(String id) async {
    final rec = await _col.getOne(id);
    return Cliente.fromRecord(rec);
  }

  @override
  Future<Cliente> create(Map<String, dynamic> data) async {
    final rec = await _col.create(body: data);
    return Cliente.fromRecord(rec);
  }

  @override
  Future<Cliente> update(String id, Map<String, dynamic> data) async {
    final rec = await _col.update(id, body: data);
    return Cliente.fromRecord(rec);
  }

  @override
  Future<void> delete(String id) => _col.delete(id);

  @override
  Future<Cliente?> findByTelefone(String telefone, {String? excludeId}) async {
    final digits = onlyDigitsPhone(telefone);
    if (digits.length < 10) return null;

    // Pré-filtro frouxo pelos 4 dígitos finais (máscaras com hífen quebram
    // match contíguo de 8+). Refine com phonesMatch no cliente.
    final tail = digits.substring(digits.length - 4);
    final filter = 'telefone ~ ${pbStringLiteral(tail)}';
    final res = await _col.getList(
      page: 1,
      perPage: 50,
      filter: filter,
      sort: '-created',
    );
    for (final rec in res.items) {
      if (excludeId != null && rec.id == excludeId) continue;
      final c = Cliente.fromRecord(rec);
      if (phonesMatch(c.telefone, telefone)) return c;
    }
    return null;
  }
}
