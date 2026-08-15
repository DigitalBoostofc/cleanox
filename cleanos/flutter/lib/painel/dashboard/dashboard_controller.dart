/// dashboard_controller.dart — Estado/dados do Dashboard do Painel.
///
/// Espelha `Dashboard.tsx`: KPIs do dia (agendadas/atribuídas/em andamento/
/// concluídas + faturamento) e a lista de "próximos atendimentos" (OS em aberto
/// a partir de hoje). Consome só o contrato congelado `OrdensRepository`
/// (injetado por Riverpod) — nunca o PocketBase direto.
///
/// Toda a lógica de fuso BRT vem de `formatters.dart` (gate G-8): nada de conta
/// de fuso aqui.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../data/painel_filters.dart' show pbStringLiteral;
import '../ordens/ordens_controller.dart';

/// Período do Dashboard — mesmo contrato da lista de OS.
class DashboardPeriodo {
  const DashboardPeriodo({
    this.periodo = OrdensPeriodo.hoje,
    this.personalizadoInicio,
    this.personalizadoFim,
  });

  final OrdensPeriodo periodo;
  final DateTime? personalizadoInicio;
  final DateTime? personalizadoFim;

  OrdensFilter get asFilter => OrdensFilter(
    periodo: periodo,
    personalizadoInicio: personalizadoInicio,
    personalizadoFim: personalizadoFim,
  );

  DateRange? range({DateTime? now}) => ordensPeriodoRange(
    periodo,
    now: now,
    personalizadoInicio: personalizadoInicio,
    personalizadoFim: personalizadoFim,
  );

  DashboardPeriodo copyWith({
    OrdensPeriodo? periodo,
    DateTime? personalizadoInicio,
    DateTime? personalizadoFim,
    bool limparPersonalizado = false,
  }) => DashboardPeriodo(
    periodo: periodo ?? this.periodo,
    personalizadoInicio: limparPersonalizado
        ? null
        : (personalizadoInicio ?? this.personalizadoInicio),
    personalizadoFim: limparPersonalizado
        ? null
        : (personalizadoFim ?? this.personalizadoFim),
  );
}

String dashboardTitulo(DashboardPeriodo p) => ordensPeriodoRotulo(p.asFilter);

String dashboardFaturamentoLabel(DashboardPeriodo p) =>
    p.periodo == OrdensPeriodo.hoje ? 'Faturamento hoje' : 'Faturamento';

String dashboardAnaliseTitulo(DashboardPeriodo p) =>
    p.periodo == OrdensPeriodo.hoje ? 'Análise de hoje' : 'Análise';

String? dashboardPeriodoFilter(DashboardPeriodo p, {DateTime? now}) {
  final range = p.range(now: now);
  if (range == null) return null;
  return 'data_hora >= ${pbStringLiteral(range.start)} '
      '&& data_hora < ${pbStringLiteral(range.end)}';
}

final dashboardPeriodoProvider = StateProvider.autoDispose<DashboardPeriodo>(
  (ref) => const DashboardPeriodo(),
);

/// KPIs do dia (espelha a interface `KPIs` do React).
class DashboardKpis {
  const DashboardKpis({
    this.agendada = 0,
    this.atribuida = 0,
    this.emAndamento = 0,
    this.concluida = 0,
    this.faturamentoDia = 0,
  });

  final int agendada;
  final int atribuida;
  final int emAndamento;
  final int concluida;
  final double faturamentoDia;
}

/// Quem atendeu no dia (OS do profissional principal ou do 2º).
class DashboardProfRanking {
  const DashboardProfRanking({
    required this.id,
    required this.nome,
    required this.osCount,
  });

  final String id;
  final String nome;
  final int osCount;
}

/// Domicílio vs ponto físico no dia (ignora canceladas).
class DashboardLocalSplit {
  const DashboardLocalSplit({this.domicilio = 0, this.pontoFisico = 0});

  final int domicilio;
  final int pontoFisico;
  int get total => domicilio + pontoFisico;
}

List<DashboardProfRanking> dashboardRankingProfissionais(
  List<OrdemServico> ordens,
) {
  final counts = <String, ({String nome, int n})>{};
  void add(String? id, String? nome) {
    final key = (id ?? '').trim();
    if (key.isEmpty) return;
    final label = (nome ?? '').trim();
    final prev = counts[key];
    counts[key] = (
      nome: prev?.nome.isNotEmpty == true
          ? prev!.nome
          : (label.isEmpty ? 'Profissional' : label),
      n: (prev?.n ?? 0) + 1,
    );
  }

  for (final o in ordens) {
    if (o.status == OSStatus.cancelada) continue;
    add(o.profissional, o.expand?.profissional?.displayName);
    add(o.profissional2, o.expand?.profissional2?.displayName);
  }

  final list = [
    for (final e in counts.entries)
      DashboardProfRanking(id: e.key, nome: e.value.nome, osCount: e.value.n),
  ]..sort((a, b) {
    final byCount = b.osCount.compareTo(a.osCount);
    if (byCount != 0) return byCount;
    return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
  });
  return list;
}

DashboardLocalSplit dashboardLocalSplit(List<OrdemServico> ordens) {
  var domicilio = 0;
  var ponto = 0;
  for (final o in ordens) {
    if (o.status == OSStatus.cancelada) continue;
    if (o.localTipo.trim().toLowerCase() == 'ponto_fisico') {
      ponto += 1;
    } else {
      domicilio += 1;
    }
  }
  return DashboardLocalSplit(domicilio: domicilio, pontoFisico: ponto);
}

/// Payload completo do Dashboard: KPIs + próximos + análise do dia.
class DashboardData {
  const DashboardData({
    required this.kpis,
    required this.upcoming,
    this.ranking = const [],
    this.local = const DashboardLocalSplit(),
  });

  final DashboardKpis kpis;
  final List<OrdemServico> upcoming;
  final List<DashboardProfRanking> ranking;
  final DashboardLocalSplit local;

  bool get isEmpty => upcoming.isEmpty;
}

/// Carrega KPIs + próximos atendimentos numa única passada.
///
/// `autoDispose`: some da memória quando o Dashboard sai de tela; um novo acesso
/// refaz o fetch (dados do dia mudam). `ref.invalidateSelf` (via retry na UI)
/// reexecuta. Realtime é opcional nesta onda — o refresh manual cobre o MVP.
final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final repo = ref.watch(ordensRepositoryProvider);
  final periodo = ref.watch(dashboardPeriodoProvider);
  final dateFilter = dashboardPeriodoFilter(periodo);
  final concluida = pbStringLiteral(OSStatus.concluida.wire);
  final cancelada = pbStringLiteral(OSStatus.cancelada.wire);

  final kpisFilter = dateFilter;
  final upcomingFilter = [
    'status != $concluida',
    'status != $cancelada',
    if (dateFilter != null) dateFilter,
  ].join(' && ');

  final results = await Future.wait([
    repo.list(
      perPage: 200,
      sort: 'data_hora',
      expand: 'profissional,profissional2',
      filter: kpisFilter,
    ),
    repo.list(
      perPage: 20,
      sort: 'data_hora',
      expand: 'profissional,cliente',
      filter: upcomingFilter,
    ),
  ]);

  var periodOS = results[0].items;
  if (results[0].totalPages > 1) {
    for (var page = 2; page <= results[0].totalPages && page <= 5; page++) {
      final extra = await repo.list(
        page: page,
        perPage: 200,
        sort: 'data_hora',
        expand: 'profissional,profissional2',
        filter: kpisFilter,
      );
      periodOS = [...periodOS, ...extra.items];
    }
  }
  final upcoming = results[1].items;

  int countBy(OSStatus s) => periodOS.where((o) => o.status == s).length;
  final faturamento = periodOS
      .where((o) => o.status == OSStatus.concluida)
      .fold<double>(0, (sum, o) => sum + (o.valorPago ?? 0));

  return DashboardData(
    kpis: DashboardKpis(
      agendada: countBy(OSStatus.agendada),
      atribuida: countBy(OSStatus.atribuida),
      emAndamento: countBy(OSStatus.emAndamento),
      concluida: countBy(OSStatus.concluida),
      faturamentoDia: faturamento,
    ),
    upcoming: upcoming,
    ranking: dashboardRankingProfissionais(periodOS),
    local: dashboardLocalSplit(periodOS),
  );
});
