/// prof_estimativa.dart — Estimativa de comissão a partir das OS do profissional.
///
/// Funções puras (testáveis): base do serviço × regra de comissão do user.
library;

import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/user.dart';

/// Filtro de período da estimativa de ganho.
enum EstimativaPeriodo {
  dia(1, 'Dia'),
  semana(7, 'Semana'),
  dias15(15, '15 dias'),
  mes(0, 'Mês'); // 0 = mês civil (não N dias)

  const EstimativaPeriodo(this.days, this.label);
  final int days;
  final String label;

  DateRange toRange({DateTime? now}) {
    if (this == EstimativaPeriodo.mes) {
      return getBrtCurrentMonthRange(now: now);
    }
    return getBrtForwardDaysRange(days, now: now);
  }
}

/// Linha da estimativa (uma OS).
class EstimativaOsLinha {
  const EstimativaOsLinha({
    required this.os,
    required this.base,
    required this.comissaoEstimada,
  });

  final OrdemServico os;
  final double base;
  final double comissaoEstimada;

  bool get isConcluida => os.status == OSStatus.concluida;
  bool get isAberta =>
      os.status == OSStatus.agendada ||
      os.status == OSStatus.atribuida ||
      os.status == OSStatus.emAndamento;
}

/// Resumo da perspectiva no período.
class EstimativaGanho {
  const EstimativaGanho({
    required this.periodo,
    required this.linhas,
    required this.totalEstimado,
    required this.totalAberto,
    required this.totalConcluido,
  });

  final EstimativaPeriodo periodo;
  final List<EstimativaOsLinha> linhas;
  final double totalEstimado;
  final double totalAberto;
  final double totalConcluido;

  int get qtdOs => linhas.length;
  int get qtdAbertas => linhas.where((l) => l.isAberta).length;
  int get qtdConcluidas => linhas.where((l) => l.isConcluida).length;
}

/// Base de cálculo: valor pago se > 0, senão valor do serviço.
double baseValorOs(OrdemServico os) {
  final pago = os.valorPago ?? 0;
  if (pago > 0) return pago;
  return os.valorServico ?? 0;
}

/// Comissão estimada para [os] com a regra de [me]. Canceladas = 0.
double estimarComissaoOs(User me, OrdemServico os) {
  if (os.status == OSStatus.cancelada) return 0;
  if (!me.comissaoTipo.isAtiva || me.comissaoValor <= 0) return 0;

  if (me.comissaoTipo == ComissaoTipo.fixo) {
    return (me.comissaoValor * 100).roundToDouble() / 100;
  }

  final base = baseValorOs(os);
  if (base <= 0) return 0;
  // percentual
  return ((base * me.comissaoValor / 100) * 100).roundToDouble() / 100;
}

/// Monta a estimativa a partir da lista de OS (já filtrada por janela/prof).
EstimativaGanho buildEstimativa({
  required User me,
  required List<OrdemServico> ordens,
  required EstimativaPeriodo periodo,
}) {
  final linhas = <EstimativaOsLinha>[];
  var total = 0.0;
  var aberto = 0.0;
  var concluido = 0.0;

  for (final os in ordens) {
    if (os.status == OSStatus.cancelada) continue;
    final base = baseValorOs(os);
    final com = estimarComissaoOs(me, os);
    if (com <= 0 && base <= 0) continue;
    final linha = EstimativaOsLinha(
      os: os,
      base: base,
      comissaoEstimada: com,
    );
    linhas.add(linha);
    total += com;
    if (linha.isConcluida) {
      concluido += com;
    } else if (linha.isAberta) {
      aberto += com;
    }
  }

  // Arredonda totais
  double r(double v) => (v * 100).roundToDouble() / 100;

  return EstimativaGanho(
    periodo: periodo,
    linhas: linhas,
    totalEstimado: r(total),
    totalAberto: r(aberto),
    totalConcluido: r(concluido),
  );
}
