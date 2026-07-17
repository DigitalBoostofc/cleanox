/// prof_estimativa.dart — Carteira do profissional: o que ele JÁ GANHOU e o
/// que ele AINDA PODE ganhar.
///
/// Regra de ouro (F-226): são duas coisas diferentes e nunca se misturam.
///
///  * OS **concluída** → o dinheiro dele já foi CONGELADO em `prof_comissoes`
///    no momento em que a OS fechou (hook `prof_comissao_lib.js`). Esse valor é
///    o único que pode aparecer. Recalcular pela config ATUAL do user é MENTIR:
///    o admin muda a comissão amanhã e o valor de um serviço já concluído E
///    PAGO muda retroativamente na cara de quem vai receber.
///  * OS **ainda aberta** → não existe valor congelado (o hook ainda não rodou).
///    Aí sim é uma ESTIMATIVA, calculada pela config atual, e é rotulada como
///    tal na UI.
///
/// Por isso [buildEstimativa] exige a lista de comissões congeladas: sem ela
/// não há como exibir OS concluída honestamente, e o parâmetro obrigatório
/// impede que um call site futuro volte a "estimar" dinheiro já realizado.
library;

import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/prof_comissao.dart';
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

/// De onde saiu o valor exibido para a OS.
enum ComissaoOrigem {
  /// `prof_comissoes.valor_comissao` — valor final, imutável. Dinheiro real.
  congelada,

  /// Calculado agora pela config do user — a OS ainda não fechou.
  estimativa,
}

/// Linha da carteira (uma OS).
class EstimativaOsLinha {
  const EstimativaOsLinha({
    required this.os,
    required this.base,
    required this.valorComissao,
    required this.origem,
  });

  final OrdemServico os;
  final double base;

  /// Congelado (`prof_comissoes`) se [origem] é [ComissaoOrigem.congelada];
  /// senão, estimativa pela config atual.
  final double valorComissao;
  final ComissaoOrigem origem;

  /// Valor final, já garantido ao profissional — não muda mais.
  bool get isCongelada => origem == ComissaoOrigem.congelada;

  bool get isConcluida => os.status == OSStatus.concluida;
  bool get isAberta =>
      os.status == OSStatus.agendada ||
      os.status == OSStatus.atribuida ||
      os.status == OSStatus.emAndamento;

  /// OS fechou mas a comissão não foi gerada (ex.: concluída sem `valor_pago`).
  /// Não há valor congelado, então o que se mostra é estimativa — e a UI precisa
  /// dizer isso, nunca chamar de "realizada".
  bool get isConcluidaSemComissao => isConcluida && !isCongelada;
}

/// Resumo da carteira no período.
class EstimativaGanho {
  const EstimativaGanho({
    required this.periodo,
    required this.linhas,
    required this.totalRealizado,
    required this.totalPrevisto,
    required this.totalPago,
  });

  const EstimativaGanho.vazia(this.periodo)
    : linhas = const [],
      totalRealizado = 0,
      totalPrevisto = 0,
      totalPago = 0;

  final EstimativaPeriodo periodo;
  final List<EstimativaOsLinha> linhas;

  /// Soma dos valores CONGELADOS (OS concluídas). Dinheiro garantido —
  /// inclui o que já foi pago e o que ainda está a receber.
  final double totalRealizado;

  /// Soma das ESTIMATIVAS (OS ainda não fechadas). Pode mudar.
  final double totalPrevisto;

  /// Subconjunto do [totalRealizado] cuja comissão o admin já marcou como
  /// PAGA (`prof_comissoes.status == paga`). Nunca maior que o garantido.
  final double totalPago;

  /// Perspectiva do período: realizado + previsto.
  double get totalGeral =>
      ((totalRealizado + totalPrevisto) * 100).roundToDouble() / 100;

  int get qtdOs => linhas.length;
  int get qtdAbertas => linhas.where((l) => l.isAberta).length;
  int get qtdConcluidas => linhas.where((l) => l.isConcluida).length;
}

/// Base de cálculo da ESTIMATIVA: valor pago se > 0, senão valor do serviço.
double baseValorOs(OrdemServico os) {
  final pago = os.valorPago ?? 0;
  if (pago > 0) return pago;
  return os.valorServico ?? 0;
}

/// Comissão ESTIMADA para [os] com a config ATUAL de [me]. Canceladas = 0.
///
/// Só vale para OS que ainda NÃO fecharam. Para OS concluída existe valor
/// congelado em `prof_comissoes` — use-o (ver [buildEstimativa]).
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

/// Monta a carteira a partir das OS do período e das comissões CONGELADAS.
///
/// [comissoes] é obrigatório de propósito: é a única fonte válida do valor de
/// uma OS concluída (F-226).
EstimativaGanho buildEstimativa({
  required User me,
  required List<OrdemServico> ordens,
  required List<ProfComissao> comissoes,
  required EstimativaPeriodo periodo,
}) {
  final congeladaPorOs = <String, ProfComissao>{
    for (final c in comissoes) c.os: c,
  };

  final linhas = <EstimativaOsLinha>[];
  var realizado = 0.0;
  var previsto = 0.0;
  var pago = 0.0;

  for (final os in ordens) {
    if (os.status == OSStatus.cancelada) continue;

    final base = baseValorOs(os);
    final congelada = os.status == OSStatus.concluida
        ? congeladaPorOs[os.id]
        : null;

    final double valor;
    final ComissaoOrigem origem;
    if (congelada != null) {
      valor = congelada.valorComissao;
      origem = ComissaoOrigem.congelada;
    } else {
      valor = estimarComissaoOs(me, os);
      origem = ComissaoOrigem.estimativa;
    }

    if (valor <= 0 && base <= 0) continue;

    linhas.add(
      EstimativaOsLinha(
        os: os,
        base: base,
        valorComissao: valor,
        origem: origem,
      ),
    );

    if (origem == ComissaoOrigem.congelada) {
      realizado += valor;
      // "Pago" é o subconjunto do garantido que o admin já quitou.
      if (congelada!.status == ComissaoStatus.paga) pago += valor;
    } else {
      previsto += valor;
    }
  }

  double r(double v) => (v * 100).roundToDouble() / 100;

  return EstimativaGanho(
    periodo: periodo,
    linhas: linhas,
    totalRealizado: r(realizado),
    totalPrevisto: r(previsto),
    totalPago: r(pago),
  );
}
