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
import '../../core/formatters/formatters.dart' show todayLocalDate;
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
  /// Só gera para séries **ativas** (ou legado sem série ainda ativo por chave).
  Future<int> ensureRecorrenciasNoPeriodo(Periodo periodo);

  /// Ao criar um lançamento fixo/recorrente: grava as próximas
  /// ocorrências como `previsto` (respeita série se [template.serieId] setado).
  Future<int> materializarRecorrenciaAFrente(FinLancamento template);

  /// Materializa à frente a partir da regra [serie] (só se ativa).
  Future<int> materializarSerieAFrente(FinSerie serie);

  /// CRUD de regras fixas (`fin_series`).
  Future<List<FinSerie>> listSeries();
  Future<FinSerie> createSerie(Map<String, dynamic> data);
  Future<FinSerie> updateSerie(String id, Map<String, dynamic> data);
  Future<void> deleteSerie(String id);

  /// Atualiza a regra e propaga para ocorrências futuras não pagas:
  /// - valor/descrição/conta/categoria nos previstos/pendentes
  /// - se [data_fim] setada, remove não-pagos depois do fim
  /// - se ativa, completa o horizonte materializado
  Future<FinSerie> updateSeriePropagando(String id, Map<String, dynamic> data);

  /// Pausa a série (não gera mais) e apaga ocorrências futuras não pagas.
  Future<FinSerie> pausarSerie(String serieId, {String? aPartirDeYmd});

  /// Retoma série pausada e materializa horizonte à frente.
  Future<FinSerie> retomarSerie(String serieId);

  /// Encerra a série: status encerrada + data_fim + apaga futuros não pagos
  /// **depois** de [dataFimYmd] (o dia do fim ainda pode existir se não pago).
  Future<FinSerie> encerrarSerie(String serieId, {String? dataFimYmd});

  /// Exclui lançamentos da série conforme [escopo].
  /// Retorna quantos registros foram apagados.
  Future<int> excluirOcorrenciasSerie({
    required String serieId,
    required SerieExclusaoEscopo escopo,
    FinLancamento? referencia,
  });

  /// Garante que um lançamento fixo legado tenha `serie_id` (cria série se preciso).
  Future<FinSerie> ensureSerieForLancamento(FinLancamento l);

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
  RecordService get _series => _pb.collection(FinCollections.series);

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
      'frequencia': l.frequencia?.wire,
      'serie_id': l.serieId,
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
    return _listLancamentosAll(filter: filter, sort: 'data');
  }

  Future<List<FinLancamento>> _listLancamentosAll({
    required String filter,
    String sort = 'data',
  }) async {
    final out = <FinLancamento>[];
    var page = 1;
    const perPage = 200;
    while (true) {
      final res = await listLancamentos(
        page: page,
        perPage: perPage,
        filter: filter,
        sort: sort,
      );
      out.addAll(res.items);
      if (page >= res.totalPages || res.items.isEmpty) break;
      page++;
    }
    return out;
  }

  Future<List<FinLancamento>> _listBySerieId(String serieId) {
    return _listLancamentosAll(
      filter: 'serie_id = ${pbStringLiteral(serieId)}',
      sort: 'data',
    );
  }

  String _ymdOf(String raw) =>
      raw.length >= 10 ? raw.substring(0, 10) : raw.trim();

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
    var created = 0;
    // Chaves soft já cobertas por fin_series (evita duplicar no path legado).
    final seriesKeys = <String>{};
    // 1) Séries com ID (caminho canônico).
    try {
      final series = await listSeries();
      for (final s in series) {
        seriesKeys.add(_serieBusinessKey(s));
        if (!s.isAtiva) continue;
        created += await _materializarSerieNoPeriodo(s, periodo);
      }
    } catch (_) {
      // Collection pode não existir ainda (pré-migrate) — cai no legado.
    }

    // 2) Legado: fixa/recorrente SEM serie_id e SEM série já cadastrada.
    final horizonte = parseYmdLocal(periodo.end) ?? DateTime.now();
    final ativos = await _listRecorrenciasAtivas(
      antesDe: formatYmdLocal(addMonthsClamped(horizonte, 1)),
    );
    final bySerie = <String, List<FinLancamento>>{};
    for (final l in ativos) {
      if (!isRecorrenciaAtiva(l.recorrencia)) continue;
      // Já coberto pelo caminho de série.
      if (l.serieId != null && l.serieId!.isNotEmpty) continue;
      final key = serieRecorrenciaKey(l);
      // Já existe fin_series com essa chave → não materializar por soft-key
      // (evita duplicata se só parte dos membros tem serie_id).
      if (seriesKeys.contains(key)) continue;
      bySerie.putIfAbsent(key, () => []).add(l);
    }

    for (final members in bySerie.values) {
      members.sort((a, b) => a.data.compareTo(b.data));
      final template = members.first;
      final baseDate = parseYmdLocal(template.data);
      if (baseDate == null) continue;

      final freq = template.frequenciaEfetiva;
      final existentes = chavesExistentesSerie(
        members.map((m) => m.data),
        frequencia: freq,
      );
      final faltantes = datasRecorrenciaFaltantes(
        baseDate: baseDate,
        frequencia: freq,
        periodo: periodo,
        datasExistentes: existentes,
      );
      for (final dataYmd in faltantes) {
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
        created++;
      }
    }
    return created;
  }

  /// Chave de negócio alinhada a [serieRecorrenciaKey] para uma [FinSerie].
  String _serieBusinessKey(FinSerie s) => serieRecorrenciaKey(
        FinLancamento(
          id: s.id,
          tipo: s.tipo,
          descricao: s.descricao,
          categoriaId: s.categoriaId,
          subcategoriaId: s.subcategoriaId,
          valor: s.valor,
          contaId: s.contaId,
          data: s.dataInicio,
          recorrencia: s.recorrencia,
          frequencia: s.frequencia,
        ),
      );

  Future<int> _materializarSerieNoPeriodo(
    FinSerie serie,
    Periodo periodo,
  ) async {
    if (!serie.isAtiva) return 0;
    final baseDate = parseYmdLocal(serie.dataInicio);
    if (baseDate == null) return 0;
    final fimSerie = (serie.dataFim != null && serie.dataFim!.isNotEmpty)
        ? parseYmdLocal(serie.dataFim!)
        : null;

    // Periodo efetivo: corta em data_fim da série (fim exclusivo = dia seguinte).
    var end = periodo.end;
    if (fimSerie != null) {
      final endSerieExcl = formatYmdLocal(fimSerie.add(const Duration(days: 1)));
      if (endSerieExcl.compareTo(periodo.start) <= 0) return 0;
      if (endSerieExcl.compareTo(end) < 0) end = endSerieExcl;
    }
    final periodoEfetivo = Periodo(periodo.start, end);

    final members = await _listBySerieId(serie.id);
    final freq = serie.frequenciaEfetiva;
    final existentes = chavesExistentesSerie(
      members.map((m) => m.data),
      frequencia: freq,
    );
    final faltantes = datasRecorrenciaFaltantes(
      baseDate: baseDate,
      frequencia: freq,
      periodo: periodoEfetivo,
      datasExistentes: existentes,
    );
    var created = 0;
    for (final dataYmd in faltantes) {
      try {
        await createLancamento(bodyOcorrenciaDaSerie(serie, dataYmd));
        created++;
      } catch (_) {
        // Race com outra aba — segue.
      }
    }
    return created;
  }

  @override
  Future<int> materializarRecorrenciaAFrente(FinLancamento template) async {
    if (!isRecorrenciaAtiva(template.recorrencia)) return 0;
    // Preferir série se existir.
    final sid = (template.serieId ?? '').trim();
    if (sid.isNotEmpty) {
      try {
        final serie = await _getSerie(sid);
        if (serie != null) return materializarSerieAFrente(serie);
      } catch (_) {}
    }

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
    final existentes = chavesExistentesSerie(
      [
        for (final l in ativos)
          if ((sid.isNotEmpty && l.serieId == sid) ||
              (sid.isEmpty && serieRecorrenciaKey(l) == key))
            l.data,
      ],
      frequencia: freq,
    );

    var created = 0;
    for (final dataYmd in datasRecorrenciaAFrente(
      baseDate: baseDate,
      frequencia: freq,
    )) {
      if (serieJaTemData(existentes, dataYmd, frequencia: freq)) continue;
      String? venc;
      if (template.vencimento != null && template.vencimento!.isNotEmpty) {
        final v0 = parseYmdLocal(template.vencimento!);
        final d0 = parseYmdLocal(dataYmd);
        if (v0 != null && d0 != null) {
          final deltaDays = v0.difference(baseDate).inDays;
          venc = formatYmdLocal(d0.add(Duration(days: deltaDays)));
        }
      }
      try {
        await createLancamento(
          bodyOcorrenciaPrevista(
            template,
            dataYmd,
            vencimentoYmd: venc,
            serieId: sid.isEmpty ? null : sid,
          ),
        );
        existentes.addAll(
          chavesExistentesSerie([dataYmd], frequencia: freq),
        );
        created++;
      } catch (_) {
        existentes.addAll(
          chavesExistentesSerie([dataYmd], frequencia: freq),
        );
      }
    }
    return created;
  }

  @override
  Future<int> materializarSerieAFrente(FinSerie serie) async {
    if (!serie.isAtiva) return 0;
    final baseDate = parseYmdLocal(serie.dataInicio);
    if (baseDate == null) return 0;
    final freq = serie.frequenciaEfetiva;
    final fimSerie = (serie.dataFim != null && serie.dataFim!.isNotEmpty)
        ? parseYmdLocal(serie.dataFim!)
        : null;

    final members = await _listBySerieId(serie.id);
    final existentes = chavesExistentesSerie(
      members.map((m) => m.data),
      frequencia: freq,
    );

    var created = 0;
    for (final dataYmd in datasRecorrenciaAFrente(
      baseDate: baseDate,
      frequencia: freq,
    )) {
      if (fimSerie != null) {
        final d = parseYmdLocal(dataYmd);
        if (d != null && d.isAfter(fimSerie)) break;
      }
      if (serieJaTemData(existentes, dataYmd, frequencia: freq)) continue;
      try {
        await createLancamento(bodyOcorrenciaDaSerie(serie, dataYmd));
        existentes.addAll(
          chavesExistentesSerie([dataYmd], frequencia: freq),
        );
        created++;
      } catch (_) {
        existentes.addAll(
          chavesExistentesSerie([dataYmd], frequencia: freq),
        );
      }
    }
    return created;
  }

  /* ─────────────────────── Séries (fin_series) ─────────────────────── */

  @override
  Future<List<FinSerie>> listSeries() async {
    final recs = await _series.getFullList(sort: 'descricao');
    return recs.map(FinSerie.fromRecord).toList();
  }

  Future<FinSerie?> _getSerie(String id) async {
    if (id.isEmpty) return null;
    try {
      final rec = await _series.getOne(id);
      return FinSerie.fromRecord(rec);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FinSerie> createSerie(Map<String, dynamic> data) async {
    final rec = await _series.create(body: data);
    return FinSerie.fromRecord(rec);
  }

  @override
  Future<FinSerie> updateSerie(String id, Map<String, dynamic> data) async {
    final rec = await _series.update(id, body: data);
    return FinSerie.fromRecord(rec);
  }

  @override
  Future<void> deleteSerie(String id) => _series.delete(id);

  /// Primeiro dia **após** [dataFimYmd] (não-pagos a partir daqui saem).
  /// [dataFimYmd] é o último dia válido da série (inclusive).
  String _diaApos(String dataFimYmd) {
    final d = parseYmdLocal(dataFimYmd);
    if (d == null) return dataFimYmd;
    return formatYmdLocal(d.add(const Duration(days: 1)));
  }

  String _hojeBrt() => todayLocalDate();

  /// Apaga lançamentos da série com data >= [fromYmd] e status ≠ pago
  /// (previsto/pendente/em_atraso). Pagos nunca são tocados aqui.
  Future<int> _deleteFuturosNaoPagos(String serieId, String fromYmd) async {
    final members = await _listBySerieId(serieId);
    var n = 0;
    for (final l in members) {
      final d = _ymdOf(l.data);
      if (d.compareTo(fromYmd) < 0) continue;
      if (l.status == LancamentoStatus.pago) continue;
      try {
        await deleteLancamento(l.id);
        n++;
      } catch (_) {}
    }
    return n;
  }

  /// Propaga template da série para ocorrências não pagas + poda por data_fim.
  Future<void> _propagarSerieParaOcorrencias(FinSerie serie) async {
    // 1) data_fim: remove não-pagos depois do último dia válido.
    final fim = (serie.dataFim ?? '').trim();
    if (fim.isNotEmpty) {
      await _deleteFuturosNaoPagos(serie.id, _diaApos(fim));
    }

    // 2) Atualiza template nos restantes não pagos.
    final members = await _listBySerieId(serie.id);
    final patch = <String, dynamic>{
      'descricao': serie.descricao,
      'valor': serie.valor,
      'conta_id': serie.contaId,
      'categoria_id': serie.categoriaId,
      'subcategoria_id': (serie.subcategoriaId ?? '').trim(),
      'frequencia': serie.frequenciaEfetiva.wire,
      'recorrencia': serie.recorrencia == RecorrenciaTipo.recorrente
          ? RecorrenciaTipo.recorrente.wire
          : RecorrenciaTipo.fixa.wire,
      'forma_pagamento': serie.formaPagamento ?? '',
      'observacao': serie.observacao ?? '',
      'tags': serie.tags,
    };
    for (final l in members) {
      if (l.status == LancamentoStatus.pago) continue;
      try {
        await updateLancamento(l.id, patch);
      } catch (_) {}
    }

    // 3) Completa horizonte se ainda ativa.
    if (serie.isAtiva) {
      await materializarSerieAFrente(serie);
    }
  }

  @override
  Future<FinSerie> updateSeriePropagando(
    String id,
    Map<String, dynamic> data,
  ) async {
    final serie = await updateSerie(id, data);
    await _propagarSerieParaOcorrencias(serie);
    return serie;
  }

  @override
  Future<FinSerie> pausarSerie(String serieId, {String? aPartirDeYmd}) async {
    final from = aPartirDeYmd ?? _hojeBrt();
    // Mantém o dia de [from] em diante limpo (não pagos).
    await _deleteFuturosNaoPagos(serieId, from);
    return updateSerie(serieId, {
      'status': FinSerieStatus.pausada.wire,
    });
  }

  @override
  Future<FinSerie> retomarSerie(String serieId) async {
    final serie = await updateSerie(serieId, {
      'status': FinSerieStatus.ativa.wire,
      'data_fim': '',
    });
    await materializarSerieAFrente(serie);
    return serie;
  }

  @override
  Future<FinSerie> encerrarSerie(String serieId, {String? dataFimYmd}) async {
    // data_fim = último dia válido (default: hoje BRT). Não-pagos depois saem.
    final fim = dataFimYmd ?? _hojeBrt();
    await _deleteFuturosNaoPagos(serieId, _diaApos(fim));
    return updateSerie(serieId, {
      'status': FinSerieStatus.encerrada.wire,
      'data_fim': fim,
    });
  }

  @override
  Future<int> excluirOcorrenciasSerie({
    required String serieId,
    required SerieExclusaoEscopo escopo,
    FinLancamento? referencia,
  }) async {
    switch (escopo) {
      case SerieExclusaoEscopo.somenteEste:
        if (referencia == null) return 0;
        await deleteLancamento(referencia.id);
        return 1;
      case SerieExclusaoEscopo.esteEFuturos:
        final from = referencia != null
            ? _ymdOf(referencia.data)
            : _hojeBrt();
        final refId = referencia?.id;
        final members = await _listBySerieId(serieId);
        var n = 0;
        for (final l in members) {
          if (_ymdOf(l.data).compareTo(from) < 0) continue;
          // Mantém históricos pagos, exceto o lançamento que o usuário abriu.
          final isRef = refId != null && l.id == refId;
          if (l.status == LancamentoStatus.pago && !isRef) continue;
          try {
            await deleteLancamento(l.id);
            n++;
          } catch (_) {}
        }
        return n;
      case SerieExclusaoEscopo.futurosEEncerrar:
      case SerieExclusaoEscopo.encerrarMantendoPagos:
        // Mesma regra de [encerrarSerie]: data_fim=hoje; poda a partir de amanhã.
        final fim = _hojeBrt();
        final n = await _deleteFuturosNaoPagos(serieId, _diaApos(fim));
        await updateSerie(serieId, {
          'status': FinSerieStatus.encerrada.wire,
          'data_fim': fim,
        });
        return n;
    }
  }

  @override
  Future<FinSerie> ensureSerieForLancamento(FinLancamento l) async {
    final sid = (l.serieId ?? '').trim();
    if (sid.isNotEmpty) {
      final existing = await _getSerie(sid);
      if (existing != null) return existing;
    }
    final all = await listSeries();
    final key = serieRecorrenciaKey(l);
    FinSerie? matchAtiva;
    FinSerie? matchQualquer;
    for (final s in all) {
      if (_serieBusinessKey(s) != key) continue;
      matchQualquer ??= s;
      if (s.isAtiva) {
        matchAtiva = s;
        break;
      }
    }
    final chosen = matchAtiva ?? matchQualquer;
    if (chosen != null) {
      await _linkSoftKeySiblings(key, chosen.id, preferId: l.id);
      return chosen;
    }
    final created = await createSerie(bodySerieFromLancamento(l));
    await _linkSoftKeySiblings(key, created.id, preferId: l.id);
    return created;
  }

  /// Liga lançamentos da soft-key sem serie_id à série [serieId].
  Future<void> _linkSoftKeySiblings(
    String key,
    String serieId, {
    String? preferId,
  }) async {
    if (preferId != null && preferId.isNotEmpty) {
      try {
        await updateLancamento(preferId, {'serie_id': serieId});
      } catch (_) {}
    }
    final siblings = await _listRecorrenciasAtivas(
      antesDe: formatYmdLocal(addMonthsClamped(DateTime.now(), 36)),
    );
    for (final m in siblings) {
      if ((m.serieId ?? '').isNotEmpty) continue;
      if (serieRecorrenciaKey(m) != key) continue;
      if (preferId != null && m.id == preferId) continue;
      try {
        await updateLancamento(m.id, {'serie_id': serieId});
      } catch (_) {}
    }
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
