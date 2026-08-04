/// fakes_onda4.dart — Fake do repositório do Financeiro (Onda 4) para os testes
/// do Painel, sem rede. Implementa `FinanceiroPanelRepository` (interface do
/// core + extras do painel). `listLancamentos` devolve os seeds numa página só
/// (o filtro/paginação real é do PB; aqui só provamos a UI/derivações).
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/data/pb_financeiro_repository.dart';
import 'package:cleanos/painel/financeiro/fin_derivations.dart';
import 'package:cleanos/painel/financeiro/fin_recorrencia.dart';

FinConta fakeConta({
  required String id,
  String nome = 'Caixa',
  ContaTipo tipo = ContaTipo.caixa,
  double saldoInicial = 0,
  double saldoAtual = 0,
  bool ativo = true,
}) => FinConta(
  id: id,
  nome: nome,
  tipo: tipo,
  saldoInicial: saldoInicial,
  saldoAtual: saldoAtual,
  ativo: ativo,
);

FinCategoria fakeCategoria({
  required String id,
  String nome = 'Categoria',
  TipoLancamento tipo = TipoLancamento.despesa,
  String? parentId,
  String icone = 'tag',
  String? cor,
}) => FinCategoria(
  id: id,
  nome: nome,
  tipo: tipo,
  parentId: parentId,
  icone: icone,
  cor: cor,
);

FinLancamento fakeLanc({
  required String id,
  TipoLancamento tipo = TipoLancamento.despesa,
  String descricao = 'Lançamento',
  double valor = 100,
  String categoriaId = 'cat',
  String contaId = 'conta',
  String data = '2026-07-10',
  String? vencimento,
  LancamentoStatus status = LancamentoStatus.pago,
  OrigemLancamento origem = OrigemLancamento.manual,
  RecorrenciaTipo recorrencia = RecorrenciaTipo.unica,
  String? observacao,
}) => FinLancamento(
  id: id,
  tipo: tipo,
  descricao: descricao,
  valor: valor,
  categoriaId: categoriaId,
  contaId: contaId,
  data: data,
  vencimento: vencimento,
  status: status,
  origem: origem,
  recorrencia: recorrencia,
  observacao: observacao,
);

FinLimite fakeLimite({
  required String id,
  String categoriaId = 'cat',
  double limite = 500,
  String? anoMes,
}) {
  // Default: mês BRT corrente (casa com o seletor da tela de Limites).
  final am = anoMes ??
      (() {
        final h = DateTime.now().toUtc().subtract(const Duration(hours: 3));
        final m = h.month.toString().padLeft(2, '0');
        return '${h.year}-$m';
      })();
  return FinLimite(
    id: id,
    categoriaId: categoriaId,
    limite: limite,
    anoMes: am,
  );
}

class FakeFinanceiro implements FinanceiroPanelRepository {
  FakeFinanceiro({
    List<FinConta>? contas,
    List<FinCategoria>? categorias,
    List<FinLancamento>? lancamentos,
    List<FinLimite>? limites,
    this.fail = false,
  }) : contas = contas ?? const [],
       categorias = categorias ?? const [],
       lancamentos = lancamentos ?? const [],
       limites = limites ?? const [];

  List<FinConta> contas;
  List<FinCategoria> categorias;
  List<FinLancamento> lancamentos;
  List<FinLimite> limites;

  /// Se true, toda leitura lança (estado de erro).
  final bool fail;

  int createLancCount = 0;
  int updateLancCount = 0;
  int deleteLancCount = 0;
  int createContaCount = 0;
  int createCategoriaCount = 0;
  int upsertLimiteCount = 0;
  int ajusteCount = 0;
  int definirSaldoCount = 0;
  int transferirCount = 0;

  /// Quantas vezes as contas foram (re)carregadas — prova o REFETCH após uma
  /// mutação (o saldo server-side não emite realtime).
  int listContasCount = 0;

  Map<String, dynamic>? lastCreateLanc;
  Map<String, dynamic>? lastUpdateLanc;
  Map<String, dynamic>? lastCreateCategoria;
  Map<String, dynamic>? lastUpdateCategoria;
  Map<String, dynamic>? lastUpsertLimiteData;
  String? lastAjusteContaId;
  double? lastAjusteDelta;
  String? lastDefinirContaId;
  double? lastDefinirNovoSaldo;
  Map<String, dynamic>? lastUpdateConta;
  ({String from, String to, double valor})? lastTransfer;

  PageResult<FinLancamento> _page(List<FinLancamento> items) => PageResult(
    items: items,
    page: 1,
    perPage: items.length,
    totalItems: items.length,
    totalPages: 1,
  );

  @override
  Future<List<FinConta>> listContas() async {
    listContasCount++;
    if (fail) throw Exception('falha');
    return contas;
  }

  @override
  Future<FinConta> createConta(Map<String, dynamic> data) async {
    createContaCount++;
    return fakeConta(id: 'nova', nome: (data['nome'] as String?) ?? 'Nova');
  }

  @override
  Future<FinConta> updateConta(String id, Map<String, dynamic> data) async {
    lastUpdateConta = data;
    return fakeConta(id: id, nome: (data['nome'] as String?) ?? 'Conta');
  }

  @override
  Future<void> deleteConta(String id) async {}

  @override
  Future<List<FinCategoria>> listCategorias() async {
    if (fail) throw Exception('falha');
    return categorias;
  }

  @override
  Future<FinCategoria> createCategoria(Map<String, dynamic> data) async {
    createCategoriaCount++;
    lastCreateCategoria = data;
    // Espelha o PocketBase real: o novo registro passa a existir e deve
    // aparecer num listCategorias() subsequente (prova reload/invalidate).
    final nova = fakeCategoria(
      id: 'nova_$createCategoriaCount',
      nome: (data['nome'] as String?) ?? 'Nova',
      tipo: TipoLancamento.values.byName(
        (data['tipo'] as String?) ?? TipoLancamento.despesa.wire,
      ),
      parentId: data['parent_id'] as String?,
      icone: (data['icone'] as String?) ?? 'tag',
      cor: data['cor'] as String?,
    );
    categorias = [...categorias, nova];
    return nova;
  }

  @override
  Future<FinCategoria> updateCategoria(
    String id,
    Map<String, dynamic> data,
  ) async {
    lastUpdateCategoria = data;
    return fakeCategoria(id: id, nome: (data['nome'] as String?) ?? 'Cat');
  }

  @override
  Future<void> deleteCategoria(String id) async {}

  @override
  Future<PageResult<FinLancamento>> listLancamentos({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = '-data',
  }) async {
    if (fail) throw Exception('falha');
    return _page(lancamentos);
  }

  @override
  Future<FinLancamento> createLancamento(Map<String, dynamic> data) async {
    createLancCount++;
    lastCreateLanc = data;
    // Espelha o PocketBase real: o novo registro passa a existir e deve
    // aparecer num listLancamentos() subsequente (prova reload/invalidate).
    final novo = fakeLanc(
      id: 'novo_$createLancCount',
      descricao: (data['descricao'] as String?) ?? '',
      tipo: TipoLancamento.values.byName(
        (data['tipo'] as String?) ?? TipoLancamento.despesa.wire,
      ),
      valor: (data['valor'] as num?)?.toDouble() ?? 100,
      categoriaId: (data['categoria_id'] as String?) ?? 'cat',
      contaId: (data['conta_id'] as String?) ?? 'conta',
      data: (data['data'] as String?) ?? '2026-07-10',
    );
    lancamentos = [...lancamentos, novo];
    return novo;
  }

  @override
  Future<FinLancamento> updateLancamento(
    String id,
    Map<String, dynamic> data,
  ) async {
    updateLancCount++;
    lastUpdateLanc = data;
    return fakeLanc(id: id);
  }

  @override
  Future<void> deleteLancamento(String id) async {
    deleteLancCount++;
  }

  int duplicateLancCount = 0;
  int repeatLancCount = 0;
  FinLancamento? lastDuplicateBase;
  FinLancamento? lastRepeatBase;

  @override
  Future<FinLancamento> duplicateLancamento(FinLancamento base) async {
    duplicateLancCount++;
    lastDuplicateBase = base;
    createLancCount++;
    return fakeLanc(id: 'dup', descricao: base.descricao);
  }

  @override
  Future<FinLancamento> repeatLancamento(FinLancamento base) async {
    repeatLancCount++;
    lastRepeatBase = base;
    return duplicateLancamento(base);
  }

  @override
  Future<int> ensureRecorrenciasNoPeriodo(Periodo periodo) async => 0;

  @override
  Future<int> materializarRecorrenciaAFrente(FinLancamento template) async => 0;

  @override
  Future<int> materializarSerieAFrente(FinSerie serie) async => 0;

  List<FinSerie> series = const [];

  @override
  Future<List<FinSerie>> listSeries() async {
    if (fail) throw Exception('falha');
    return series;
  }

  @override
  Future<FinSerie> createSerie(Map<String, dynamic> data) async {
    final s = FinSerie(
      id: 'serie_${series.length + 1}',
      tipo: TipoLancamento.values.byName(
        (data['tipo'] as String?) ?? TipoLancamento.despesa.wire,
      ),
      descricao: (data['descricao'] as String?) ?? '',
      categoriaId: (data['categoria_id'] as String?) ?? '',
      valor: (data['valor'] as num?)?.toDouble() ?? 0,
      contaId: (data['conta_id'] as String?) ?? '',
      dataInicio: (data['data_inicio'] as String?) ?? '',
    );
    series = [...series, s];
    return s;
  }

  @override
  Future<FinSerie> updateSerie(String id, Map<String, dynamic> data) async {
    final i = series.indexWhere((s) => s.id == id);
    if (i < 0) {
      return FinSerie(id: id, descricao: (data['descricao'] as String?) ?? '');
    }
    final cur = series[i];
    final next = cur.copyWith(
      descricao: (data['descricao'] as String?) ?? cur.descricao,
      valor: (data['valor'] as num?)?.toDouble() ?? cur.valor,
      status: data['status'] != null
          ? FinSerieStatus.values.byName(data['status'] as String)
          : cur.status,
      dataFim: data.containsKey('data_fim')
          ? (data['data_fim'] as String?)
          : cur.dataFim,
    );
    series = [...series]..[i] = next;
    return next;
  }

  @override
  Future<FinSerie> updateSeriePropagando(
    String id,
    Map<String, dynamic> data,
  ) =>
      updateSerie(id, data);

  @override
  Future<void> deleteSerie(String id) async {
    series = series.where((s) => s.id != id).toList();
  }

  @override
  Future<FinSerie> pausarSerie(String serieId, {String? aPartirDeYmd}) =>
      updateSerie(serieId, {'status': FinSerieStatus.pausada.wire});

  @override
  Future<FinSerie> retomarSerie(String serieId) =>
      updateSerie(serieId, {'status': FinSerieStatus.ativa.wire, 'data_fim': ''});

  @override
  Future<FinSerie> encerrarSerie(String serieId, {String? dataFimYmd}) =>
      updateSerie(serieId, {
        'status': FinSerieStatus.encerrada.wire,
        'data_fim': dataFimYmd ?? '2026-01-01',
      });

  @override
  Future<int> excluirOcorrenciasSerie({
    required String serieId,
    required SerieExclusaoEscopo escopo,
    FinLancamento? referencia,
  }) async =>
      0;

  @override
  Future<FinSerie> ensureSerieForLancamento(FinLancamento l) async {
    if ((l.serieId ?? '').isNotEmpty) {
      final found = series.where((s) => s.id == l.serieId).toList();
      if (found.isNotEmpty) return found.first;
    }
    return createSerie({
      'tipo': l.tipo.wire,
      'descricao': l.descricao,
      'categoria_id': l.categoriaId,
      'valor': l.valor,
      'conta_id': l.contaId,
      'data_inicio': l.data,
    });
  }

  @override
  Future<List<FinLimite>> listLimites() async {
    if (fail) throw Exception('falha');
    return limites;
  }

  @override
  Future<FinLimite> upsertLimite(Map<String, dynamic> data) async {
    upsertLimiteCount++;
    lastUpsertLimiteData = data;
    return fakeLimite(
      id: (data['id'] as String?) ?? 'novo',
      categoriaId: (data['categoria_id'] as String?) ?? 'cat',
      limite: (data['limite'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<void> deleteLimite(String id) async {}

  @override
  Future<void> ajustarSaldo(String contaId, double delta) async {
    ajusteCount++;
    lastAjusteContaId = contaId;
    lastAjusteDelta = delta;
  }

  @override
  Future<void> definirSaldo(String contaId, double novoSaldo) async {
    definirSaldoCount++;
    lastDefinirContaId = contaId;
    lastDefinirNovoSaldo = novoSaldo;
  }

  @override
  Future<void> transferir(String fromId, String toId, double valor) async {
    transferirCount++;
    lastTransfer = (from: fromId, to: toId, valor: valor);
  }

  List<FinObjetivo> objetivos = const [];

  @override
  Future<List<FinObjetivo>> listObjetivos() async {
    if (fail) throw Exception('falha');
    return objetivos;
  }

  @override
  Future<FinObjetivo> createObjetivo(Map<String, dynamic> data) async {
    final o = FinObjetivo(
      id: 'obj_${objetivos.length + 1}',
      nome: (data['nome'] as String?) ?? 'Meta',
      metaValor: (data['meta_valor'] as num?)?.toDouble() ?? 0,
      valorAtual: (data['valor_atual'] as num?)?.toDouble() ?? 0,
      ativo: data['ativo'] as bool? ?? true,
    );
    objetivos = [...objetivos, o];
    return o;
  }

  @override
  Future<FinObjetivo> updateObjetivo(String id, Map<String, dynamic> data) async {
    final i = objetivos.indexWhere((o) => o.id == id);
    if (i < 0) {
      return FinObjetivo(id: id, nome: (data['nome'] as String?) ?? 'Meta');
    }
    final cur = objetivos[i];
    final next = cur.copyWith(
      nome: (data['nome'] as String?) ?? cur.nome,
      metaValor: (data['meta_valor'] as num?)?.toDouble() ?? cur.metaValor,
      valorAtual: (data['valor_atual'] as num?)?.toDouble() ?? cur.valorAtual,
      ativo: data['ativo'] as bool? ?? cur.ativo,
    );
    objetivos = [...objetivos]..[i] = next;
    return next;
  }

  @override
  Future<void> deleteObjetivo(String id) async {
    objetivos = objetivos.where((o) => o.id != id).toList();
  }
}
