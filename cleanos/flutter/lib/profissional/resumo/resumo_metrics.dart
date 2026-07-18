/// resumo_metrics.dart — Indicadores do dashboard "Resumo" do profissional.
///
/// Função PURA: recebe as OS do período e o km planejado (soma dos dias) e
/// devolve contagens + deslocamento. Sem rede/Riverpod.
///
/// Definições:
///  * **Agendados** — total = realizados + canceladas + pendentes.
///  * **Pendentes** — ainda não encerradas (agendada / atribuída / em andamento).
///  * **Canceladas** — OS canceladas no período.
///  * **Realizados** — OS concluídas no período.
///  * **Km** — soma do deslocamento planejado dos dias do período.
library;

import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';

/// Filtro de período do dashboard Resumo.
enum ResumoPeriodo { hoje, semana, mes }

extension ResumoPeriodoX on ResumoPeriodo {
  String get label => switch (this) {
    ResumoPeriodo.hoje => 'Hoje',
    ResumoPeriodo.semana => 'Semana',
    ResumoPeriodo.mes => 'Mês',
  };

  /// Janela half-open [start, end) em string UTC do PB (BRT).
  DateRange bounds({DateTime? now}) {
    final n = now ?? DateTime.now();
    switch (this) {
      case ResumoPeriodo.hoje:
        final b = getBrtDayBounds(now: n);
        return DateRange(b.todayStart, b.tomorrowStart);
      case ResumoPeriodo.semana:
        return getBrtWeekBounds(now: n);
      case ResumoPeriodo.mes:
        return getBrtCurrentMonthRange(now: n);
    }
  }

  /// Chaves `YYYY-MM-DD` (BRT) half-open [start, end) para filtrar
  /// `prof_deslocamento_dia.dia`.
  ({String startDia, String endDiaExcl}) diaKeys({DateTime? now}) {
    final r = bounds(now: now);
    return (
      startDia: _pbUtcToBrtDia(r.start),
      endDiaExcl: _pbUtcToBrtDia(r.end),
    );
  }
}

String _pbUtcToBrtDia(String pbUtc) {
  final d = parsePbUtc(pbUtc);
  if (d == null) return '';
  final brt = d.subtract(kBrtOffset);
  String p(int n) => n.toString().padLeft(2, '0');
  return '${brt.year.toString().padLeft(4, '0')}-${p(brt.month)}-${p(brt.day)}';
}

/// Snapshot dos indicadores do dashboard.
class ProfResumo {
  const ProfResumo({
    required this.agendados,
    required this.pendentes,
    required this.canceladas,
    required this.realizados,
    required this.kmDeslocamento,
    this.periodo = ResumoPeriodo.hoje,
  });

  const ProfResumo.vazio({this.periodo = ResumoPeriodo.hoje})
    : agendados = 0,
      pendentes = 0,
      canceladas = 0,
      realizados = 0,
      kmDeslocamento = 0;

  /// Total do período (realizados + canceladas + pendentes).
  final int agendados;

  /// Ainda não encerradas.
  final int pendentes;

  final int canceladas;
  final int realizados;

  /// Km planejado somado no período (0 se sem partida/dias).
  final double kmDeslocamento;

  final ResumoPeriodo periodo;
}

/// Monta os indicadores a partir das OS do período e do km total.
///
/// **Agendados** = realizados + canceladas + pendentes.
ProfResumo buildResumo({
  required List<OrdemServico> ordens,
  double kmDeslocamento = 0,
  ResumoPeriodo periodo = ResumoPeriodo.hoje,
}) {
  var pendentes = 0;
  var canceladas = 0;
  var realizados = 0;

  for (final os in ordens) {
    switch (os.status) {
      case OSStatus.concluida:
        realizados++;
      case OSStatus.cancelada:
        canceladas++;
      case OSStatus.agendada:
      case OSStatus.atribuida:
      case OSStatus.emAndamento:
        pendentes++;
    }
  }

  final agendados = realizados + canceladas + pendentes;
  final km = (kmDeslocamento * 10).roundToDouble() / 10;

  return ProfResumo(
    agendados: agendados,
    pendentes: pendentes,
    canceladas: canceladas,
    realizados: realizados,
    kmDeslocamento: km,
    periodo: periodo,
  );
}
