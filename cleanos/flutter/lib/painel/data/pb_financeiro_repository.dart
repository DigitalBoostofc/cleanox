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
import '../financeiro/fin_derivations.dart';
import '../financeiro/fin_recorrencia.dart';
import 'painel_filters.dart';

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

  /// Copia um lançamento como NOVO idêntico (anti-desvio: via_os vira manual).
  Future<FinLancamento> duplicateLancamento(FinLancamento base);

  /// Alias de [duplicateLancamento] (botão legado "Repetir" no detalhe).
  Future<FinLancamento> repeatLancamento(FinLancamento base);

  /// Materializa no [periodo] as ocorrências mensais faltantes de despesas/
  /// receitas `fixa`/`recorrente` (status `previsto`). Idempotente.
  /// Retorna quantas ocorrências novas foram criadas.
  Future<int> ensureRecorrenciasNoPeriodo(Periodo periodo);

  /// Ao criar um lançamento fixo/recorrente: grava as próximas
  /// [kRecorrenciaMesesAFrente] ocorrências mensais como `previsto`.
  Future<int> materializarRecorrenciaAFrente(FinLancamento template);

  /// Metas de caixa (`fin_objetivos`).
  Future<List<FinObjetivo>> listObjetivos();
  Future<FinObjetivo> createObjetivo(Map<String, dynamic> data);
  Future<FinObjetivo> updateObjetivo(String id, Map<String, dynamic> data);
  Future<void> deleteObjetivo(String id);
}

class PbFinanceiroRepository implements FinanceiroPanelRepository {
  PbFinanceiroRepository(this._pb);

  final PocketBase _pb;

  /// Dedup de ensure concorrente (controller + period provider no mesmo mês).
  final Map<String, Future<int>> _ensureLocks = {};

  RecordService get _contas => _pb.collection(FinCollections.contas);
  RecordService get _categorias => _pb.collection(FinCollections.categorias);
  RecordService get _lancamentos => _pb.collection(FinCollections.lancamentos);
  RecordService get _limites => _pb.collection(FinCollections.limites);
  RecordService get _objetivos => _pb.collection(FinCollections.objetivos);

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

  /// Body PB (snake_case) de um lançamento de domínio, JÁ desvinculado da OS
  /// quando origem `via_os` (anti-desvio — espelha `desvincularOsSeViaOs`): a
  /// cópia nasce 'manual' e sem `os_*`. Sem `id`/`created`/`updated` (novo registro).
  Map<String, dynamic> _bodyDesvinculado(FinLancamento l) {
    final viaOs = l.origem == OrigemLancamento.viaOs;
    return <String, dynamic>{
      'tipo': l.tipo.wire,
      'descricao': l.descricao,
      'categoria_id': l.categoriaId,
      'subcategoria_id': l.subcategoriaId,
      'valor': l.valor,
      'conta_id': l.contaId,
      'data': l.data,
      'vencimento': l.vencimento,
      'status': l.status.wire,
      'recorrencia': l.recorrencia.wire,
      'parcela_atual': l.parcelaAtual,
      'parcelas_total': l.parcelasTotal,
      'origem': OrigemLancamento.manual.wire,
      'os_id': viaOs ? null : l.osId,
      'os_numero': viaOs ? null : l.osNumero,
      'cliente_nome': viaOs ? null : l.clienteNome,
      'servico_nome': viaOs ? null : l.servicoNome,
      'forma_pagamento': l.formaPagamento,
      'observacao': l.observacao,
      'tags': l.tags,
      'anexos': l.anexos.map((a) => a.toJson()).toList(),
    };
  }

  /// Duplica o lançamento **idêntico** (mesma descrição, valor, status, datas…).
  /// Só tira o vínculo com OS (`via_os` → manual). Não acrescenta " (cópia)".
  @override
  Future<FinLancamento> duplicateLancamento(FinLancamento base) {
    return createLancamento(_bodyDesvinculado(base));
  }

  /// Alias de [duplicateLancamento] — o botão "Repetir" do detalhe era confuso:
  /// o dono espera outra movimentação **igual**, não a "próxima parcela prevista".
  @override
  Future<FinLancamento> repeatLancamento(FinLancamento base) =>
      duplicateLancamento(base);

  /// Lista todas as fixas/recorrentes com data < [antesDe] (paginado).
  Future<List<FinLancamento>> _listRecorrenciasAtivas({
    required String antesDe,
  }) async {
    final filter =
        '(recorrencia = ${pbStringLiteral(RecorrenciaTipo.fixa.wire)} '
        '|| recorrencia = ${pbStringLiteral(RecorrenciaTipo.recorrente.wire)}) '
        '&& data < ${pbStringLiteral(antesDe)}';
    final out = <FinLancamento>[];
    var page = 1;
    const perPage = 200;
    while (true) {
      final res = await listLancamentos(
        page: page,
        perPage: perPage,
        filter: filter,
        sort: 'data',
      );
      out.addAll(res.items);
      if (page >= res.totalPages || res.items.isEmpty) break;
      page++;
    }
    return out;
  }

  @override
  Future<int> ensureRecorrenciasNoPeriodo(Periodo periodo) {
    final key = '${periodo.start}|${periodo.end}';
    return _ensureLocks.putIfAbsent(key, () async {
      try {
        return await _ensureRecorrenciasImpl(periodo);
      } finally {
        _ensureLocks.remove(key);
      }
    });
  }

  Future<int> _ensureRecorrenciasImpl(Periodo periodo) async {
    // Templates e ocorrências até o fim do período (+ 1 ano p/ semanal).
    final horizonte = parseYmdLocal(periodo.end) ?? DateTime.now();
    final ativos = await _listRecorrenciasAtivas(
      antesDe: formatYmdLocal(addMonthsClamped(horizonte, 1)),
    );
    if (ativos.isEmpty) return 0;

    final bySerie = <String, List<FinLancamento>>{};
    for (final l in ativos) {
      if (!isRecorrenciaAtiva(l.recorrencia)) continue;
      bySerie.putIfAbsent(serieRecorrenciaKey(l), () => []).add(l);
    }

    var created = 0;
    for (final members in bySerie.values) {
      members.sort((a, b) => a.data.compareTo(b.data));
      final template = members.first;
      final baseDate = parseYmdLocal(template.data);
      if (baseDate == null) continue;

      // Existentes: YMD (10 chars) + year-month (mensal). PB date pode vir com hora.
      final existentes = <String>{
        for (final m in members) ...[
          m.data.length >= 10 ? m.data.substring(0, 10) : m.data,
          yearMonthOf(m.data),
        ],
      };
      final faltantes = datasRecorrenciaFaltantes(
        baseDate: baseDate,
        frequencia: template.frequenciaEfetiva,
        periodo: periodo,
        datasExistentes: existentes,
      );
      for (final dataYmd in faltantes) {
        String? venc;
        if (template.vencimento != null &&
            template.vencimento!.isNotEmpty) {
          final v0 = parseYmdLocal(template.vencimento!);
          final d0 = parseYmdLocal(dataYmd);
          if (v0 != null && d0 != null) {
            final deltaDays = v0.difference(baseDate).inDays;
            venc = formatYmdLocal(d0.add(Duration(days: deltaDays)));
          }
        }
        await createLancamento(
          bodyOcorrenciaPrevista(template, dataYmd, vencimentoYmd: venc),
        );
        created++;
      }
    }
    return created;
  }

  @override
  Future<int> materializarRecorrenciaAFrente(FinLancamento template) async {
    if (!isRecorrenciaAtiva(template.recorrencia)) return 0;
    final baseDate = parseYmdLocal(template.data);
    if (baseDate == null) return 0;
    final freq = template.frequenciaEfetiva;

    final ultimo = addFrequencia(
      baseDate,
      freq,
      horizontePassos(freq) + 1,
    );
    final ativos = await _listRecorrenciasAtivas(
      antesDe: formatYmdLocal(ultimo),
    );
    final key = serieRecorrenciaKey(template);
    final existentes = <String>{
      for (final l in ativos)
        if (serieRecorrenciaKey(l) == key) ...[
          l.data.length >= 10 ? l.data.substring(0, 10) : l.data,
          yearMonthOf(l.data),
        ],
    };

    var created = 0;
    for (final dataYmd in datasRecorrenciaAFrente(
      baseDate: baseDate,
      frequencia: freq,
    )) {
      final ym = yearMonthOf(dataYmd);
      if (existentes.contains(dataYmd) || existentes.contains(ym)) continue;
      String? venc;
      if (template.vencimento != null && template.vencimento!.isNotEmpty) {
        final v0 = parseYmdLocal(template.vencimento!);
        final d0 = parseYmdLocal(dataYmd);
        if (v0 != null && d0 != null) {
          final deltaDays = v0.difference(baseDate).inDays;
          venc = formatYmdLocal(d0.add(Duration(days: deltaDays)));
        }
      }
      await createLancamento(
        bodyOcorrenciaPrevista(template, dataYmd, vencimentoYmd: venc),
      );
      existentes
        ..add(dataYmd)
        ..add(ym);
      created++;
    }
    return created;
  }

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

  /* ─────────────────────── Objetivos ─────────────────────── */

  @override
  Future<List<FinObjetivo>> listObjetivos() async {
    final recs = await _objetivos.getFullList(sort: '-created');
    return recs.map(FinObjetivo.fromRecord).toList();
  }

  @override
  Future<FinObjetivo> createObjetivo(Map<String, dynamic> data) async {
    final rec = await _objetivos.create(body: data);
    return FinObjetivo.fromRecord(rec);
  }

  @override
  Future<FinObjetivo> updateObjetivo(String id, Map<String, dynamic> data) async {
    final rec = await _objetivos.update(id, body: data);
    return FinObjetivo.fromRecord(rec);
  }

  @override
  Future<void> deleteObjetivo(String id) => _objetivos.delete(id);
}
