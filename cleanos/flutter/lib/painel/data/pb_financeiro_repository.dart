/// pb_financeiro_repository.dart — Impl PB da interface congelada
/// `FinanceiroRepository` do core, na camada de dados do PAINEL.
///
/// Espelha `web/src/lib/financeiro/store.ts`:
///   • CRUD de `fin_contas`, `fin_categorias`, `fin_lancamentos`, `fin_limites`;
///   • mapeamento `RecordModel` → tipo de domínio (`FinConta.fromRecord`, etc.);
///   • Lançamentos com paginação SERVER-SIDE (`getList`) — nunca `getFullList`
///     numa lista de UI grande. Contas/categorias/limites são conjuntos pequenos
///     e fechados → `getFullList` é aceitável (dropdowns/árvores).
///
/// ⭐ SALDO SERVER-SIDE (fin-saldo-serverside): a fonte ÚNICA e ATÔMICA do
/// `saldo_atual` é o backend. Este repositório NÃO muta mais `saldo_atual` no
/// cliente:
///   • CRUD de lançamentos só cria/edita/apaga o registro — o hook de modelo
///     `fin_lancamentos` (fin_saldo.pb.js) credita/debita o saldo server-side
///     (inclui pendente↔pago e troca de conta), sem read-then-write nem
///     lost-update no cliente.
///   • [ajustarSaldo]/[transferir] batem nas rotas transacionais
///     (`/api/cleanos/fin/...`) que fazem incremento atômico em SQL.
///   • [updateConta] NUNCA envia `saldo_atual` (o guard de request ignora, mas
///     removemos por limpeza).
///
/// ⚠️ REALTIME: as mutações de saldo (hook de modelo + rotas) usam SQL direto e
/// NÃO emitem evento realtime de `fin_contas`. Por isso os controllers/telas
/// devem REFETCHAR as contas (`finContasProvider`) após qualquer CRUD de
/// lançamento OU ajuste/transferência — não confiar em subscribe.
///
/// Convenções: nomes de coleção de `FinCollections`, filtros via `pb.filter`
/// (anti-injeção), `RecordModel` → domínio, rotas custom via `pb.send`, erros
/// propagados como `ClientException` (a UI traduz por código).
library;

import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/financeiro.dart';
import '../../core/repositories/financeiro_repository.dart';
import '../../core/repositories/repo_types.dart';

/// Contrato do repositório do Financeiro NA CAMADA DO PAINEL: a interface
/// congelada do core ([FinanceiroRepository]) + os extras que o Painel precisa
/// (ajuste de saldo e transferência entre contas — ambos server-side). Manter
/// esta fronteira permite injetar um fake nos testes sem instanciar PocketBase.
abstract class FinanceiroPanelRepository implements FinanceiroRepository {
  /// Ajuste manual de saldo de uma conta via rota transacional (incremento
  /// atômico server-side). O cliente NÃO grava `saldo_atual`. Use quando o valor
  /// é um INCREMENTO já conhecido (ex.: correção somada). Para "setar o saldo
  /// para X" (campo "Saldo atual = X" do form), use [definirSaldo] — que evita a
  /// janela de lost-update de calcular delta sobre um saldo já defasado.
  Future<void> ajustarSaldo(String contaId, double delta);

  /// Define o saldo de uma conta para um valor ABSOLUTO via rota transacional.
  /// O servidor converte para delta lendo o saldo FRESCO DENTRO da transação —
  /// sem a janela em que o cliente calcula `delta = novo − saldo_carregado` sobre
  /// um `saldo_carregado` já defasado (outra OS/gerente pode ter mexido desde que
  /// o form abriu). Esta é a semântica correta de "Saldo atual = X". O cliente
  /// NÃO grava `saldo_atual`.
  Future<void> definirSaldo(String contaId, double novoSaldo);

  /// Transferência entre contas via rota transacional (débito+crédito na MESMA
  /// transação server-side — sem rollback client-side).
  Future<void> transferir(String fromId, String toId, double valor);
}

class PbFinanceiroRepository implements FinanceiroPanelRepository {
  PbFinanceiroRepository(this._pb);

  final PocketBase _pb;

  RecordService get _contas => _pb.collection(FinCollections.contas);
  RecordService get _categorias => _pb.collection(FinCollections.categorias);
  RecordService get _lancamentos => _pb.collection(FinCollections.lancamentos);
  RecordService get _limites => _pb.collection(FinCollections.limites);

  /* ─────────────────────── Contas / Carteiras ─────────────────────── */

  @override
  Future<List<FinConta>> listContas() async {
    // Conjunto pequeno e fechado (carteiras) → getFullList OK.
    final recs = await _contas.getFullList(sort: 'nome');
    return recs.map(FinConta.fromRecord).toList();
  }

  @override
  Future<FinConta> createConta(Map<String, dynamic> data) async {
    // Abertura de conta com saldo inicial é legítima (não sofre lost-update) —
    // o backend só bloqueia a MUTAÇÃO de `saldo_atual` no update.
    final rec = await _contas.create(body: data);
    return FinConta.fromRecord(rec);
  }

  @override
  Future<FinConta> updateConta(String id, Map<String, dynamic> data) async {
    // Nunca enviamos `saldo_atual` no update: o saldo é server-side (o guard de
    // request ignoraria, mas removemos por limpeza). Ajuste de saldo é feito
    // pela rota transacional [ajustarSaldo].
    final body = Map<String, dynamic>.from(data)..remove('saldo_atual');
    final rec = await _contas.update(id, body: body);
    return FinConta.fromRecord(rec);
  }

  @override
  Future<void> deleteConta(String id) => _contas.delete(id);

  /// Ajuste manual de saldo do painel via rota transacional
  /// `POST /api/cleanos/fin/conta/{id}/ajuste` com `{ "delta": <double> }`.
  /// O servidor aplica um INCREMENTO ATÔMICO em SQL (sem read-then-write nem
  /// lost-update). Só admin/gerente (401/403); 400 se a conta não existir (via
  /// delta) ou o valor for inválido.
  ///
  /// ⚠️ Não emite realtime de `fin_contas`: quem chama deve REFETCHAR as contas
  /// (`finContasProvider`) para refletir o novo saldo.
  @override
  Future<void> ajustarSaldo(String contaId, double delta) async {
    if (delta == 0 || contaId.isEmpty) return; // no-op: evita chamada inútil
    await _pb.send<dynamic>(
      '/api/cleanos/fin/conta/$contaId/ajuste',
      method: 'POST',
      body: {'delta': delta},
    );
  }

  /// Define o saldo do painel para um valor ABSOLUTO via a mesma rota
  /// `POST /api/cleanos/fin/conta/{id}/ajuste`, mas com `{ "novoSaldo": <double> }`.
  /// O servidor lê o saldo FRESCO dentro da transação e aplica o delta necessário
  /// — sem a janela de lost-update de calcular delta no cliente sobre um saldo já
  /// defasado. Resposta 200 `{ok,conta_id,saldo_atual}`; erros 401/403/400/404
  /// sobem como `ClientException` para a UI traduzir (`finErrorMessage`).
  ///
  /// ⚠️ Não emite realtime de `fin_contas`: quem chama deve REFETCHAR as contas
  /// (`finContasProvider`) para refletir o novo saldo.
  @override
  Future<void> definirSaldo(String contaId, double novoSaldo) async {
    if (contaId.isEmpty) return; // no-op defensivo (o caller sempre passa id)
    await _pb.send<dynamic>(
      '/api/cleanos/fin/conta/$contaId/ajuste',
      method: 'POST',
      body: {'novoSaldo': novoSaldo},
    );
  }

  /// Transferência entre contas via rota transacional
  /// `POST /api/cleanos/fin/transferencia` com `{ "from", "to", "valor" }`.
  /// Débito na origem + crédito no destino na MESMA transação server-side — sem
  /// a janela do rollback client-side (o backend é transacional). Erros do
  /// backend (from==to, valor<=0, conta inexistente, sem permissão) sobem como
  /// `ClientException` para a UI traduzir por código.
  ///
  /// ⚠️ Não emite realtime de `fin_contas`: quem chama deve REFETCHAR as contas.
  @override
  Future<void> transferir(String fromId, String toId, double valor) async {
    await _pb.send<dynamic>(
      '/api/cleanos/fin/transferencia',
      method: 'POST',
      body: {'from': fromId, 'to': toId, 'valor': valor},
    );
  }

  /* ─────────────────────── Categorias ─────────────────────── */

  @override
  Future<List<FinCategoria>> listCategorias() async {
    // Árvore de categorias/subcategorias (conjunto pequeno) → getFullList OK.
    final recs = await _categorias.getFullList(sort: 'nome');
    return recs.map(FinCategoria.fromRecord).toList();
  }

  @override
  Future<FinCategoria> createCategoria(Map<String, dynamic> data) async {
    final rec = await _categorias.create(body: data);
    return FinCategoria.fromRecord(rec);
  }

  @override
  Future<FinCategoria> updateCategoria(
    String id,
    Map<String, dynamic> data,
  ) async {
    final rec = await _categorias.update(id, body: data);
    return FinCategoria.fromRecord(rec);
  }

  @override
  Future<void> deleteCategoria(String id) => _categorias.delete(id);

  /* ─────────────────────── Lançamentos ─────────────────────── */

  @override
  Future<PageResult<FinLancamento>> listLancamentos({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data',
  }) async {
    final res = await _lancamentos.getList(
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort,
    );
    return PageResult<FinLancamento>(
      items: res.items.map(FinLancamento.fromRecord).toList(),
      page: res.page,
      perPage: res.perPage,
      totalItems: res.totalItems,
      totalPages: res.totalPages,
    );
  }

  /// Cria o lançamento. NÃO ajusta o saldo no cliente: o hook de modelo
  /// server-side (`fin_saldo.pb.js`) credita/debita `saldo_atual` (se pago).
  /// Quem chama deve REFETCHAR as contas depois (sem realtime).
  @override
  Future<FinLancamento> createLancamento(Map<String, dynamic> data) async {
    final rec = await _lancamentos.create(body: data);
    return FinLancamento.fromRecord(rec);
  }

  /// Edita o lançamento. NÃO ajusta o saldo no cliente: o hook de modelo
  /// server-side estorna o efeito antigo e aplica o novo (trata pendente↔pago e
  /// troca de conta atomicamente). Quem chama deve REFETCHAR as contas depois.
  @override
  Future<FinLancamento> updateLancamento(
    String id,
    Map<String, dynamic> data,
  ) async {
    final rec = await _lancamentos.update(id, body: data);
    return FinLancamento.fromRecord(rec);
  }

  /// Apaga o lançamento. NÃO ajusta o saldo no cliente: o hook de modelo
  /// server-side estorna o efeito. Quem chama deve REFETCHAR as contas depois.
  @override
  Future<void> deleteLancamento(String id) => _lancamentos.delete(id);

  /* ─────────────────────── Limites de gasto ─────────────────────── */

  @override
  Future<List<FinLimite>> listLimites() async {
    final recs = await _limites.getFullList(sort: 'categoria_id');
    return recs.map(FinLimite.fromRecord).toList();
  }

  @override
  Future<FinLimite> upsertLimite(Map<String, dynamic> data) async {
    // Upsert por `id` quando fornecido; senão cria. Espelha o padrão de limites
    // do web (um limite por categoria; a tela resolve o id existente).
    final id = data['id'] as String?;
    final body = Map<String, dynamic>.from(data)..remove('id');
    final rec = (id != null && id.isNotEmpty)
        ? await _limites.update(id, body: body)
        : await _limites.create(body: body);
    return FinLimite.fromRecord(rec);
  }

  @override
  Future<void> deleteLimite(String id) => _limites.delete(id);
}
