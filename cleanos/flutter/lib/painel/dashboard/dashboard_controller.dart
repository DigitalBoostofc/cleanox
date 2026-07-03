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

/// Payload completo do Dashboard: KPIs + próximos atendimentos.
class DashboardData {
  const DashboardData({required this.kpis, required this.upcoming});

  final DashboardKpis kpis;
  final List<OrdemServico> upcoming;

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
  final bounds = getBrtDayBounds();

  // B1: filtros montados com `pbStringLiteral` (mesmo escaping do `pb.filter`),
  // por consistência com o resto do Painel. Os valores são bounds BRT/enums
  // internos (sem entrada do usuário), mas seguimos a convenção anti-injeção.
  final todayStart = pbStringLiteral(bounds.todayStart);
  final tomorrowStart = pbStringLiteral(bounds.tomorrowStart);
  final concluida = pbStringLiteral(OSStatus.concluida.wire);
  final cancelada = pbStringLiteral(OSStatus.cancelada.wire);

  // Duas queries em paralelo (espelha o Promise.all do React).
  // ⚠️ `perPage: 200` é o teto dos KPIs do dia: se algum dia houver > 200 OS num
  // único dia BRT, a contagem subcontaria (a página 2 não é lida). O volume real
  // documentado (< ~50 OS/dia) cobre folgadamente; se estourar, paginar aqui.
  final results = await Future.wait([
    // OS de HOJE (qualquer status) — base dos KPIs.
    repo.list(
      perPage: 200,
      sort: 'data_hora',
      filter: 'data_hora >= $todayStart && data_hora < $tomorrowStart',
    ),
    // Próximos atendimentos: em aberto a partir de hoje, com o profissional.
    repo.list(
      perPage: 20,
      sort: 'data_hora',
      expand: 'profissional',
      filter:
          'status != $concluida && status != $cancelada '
          '&& data_hora >= $todayStart',
    ),
  ]);

  final todayOS = results[0].items;
  final upcoming = results[1].items;

  int countBy(OSStatus s) => todayOS.where((o) => o.status == s).length;
  final faturamento = todayOS
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
  );
});
