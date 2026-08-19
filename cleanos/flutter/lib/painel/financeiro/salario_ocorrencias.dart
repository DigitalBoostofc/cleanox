/// Datas e status das parcelas de salário fixo.
library;

import '../../core/models/collections.dart';
import '../../core/models/user.dart';
import '../../profissional/financeiro/prof_pagamento.dart';

class SalarioOcorrenciaPlano {
  const SalarioOcorrenciaPlano({
    required this.ymd,
    required this.status,
  });

  final String ymd;
  final ComissaoStatus status;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String salarioDescricaoDia(String ymd) {
  final p = ymd.split('-');
  if (p.length != 3) return ymd;
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// Quinzena/mês: cortes do mês + último dia dos meses seguintes.
List<SalarioOcorrenciaPlano> planejarOcorrenciasSalario(
  User me, {
  required DateTime now,
  int mesesHorizon = 2,
}) {
  if (!me.hasRemuneracaoAtiva || me.remuneracaoValor <= 0) return const [];
  final hoje = DateTime.utc(now.year, now.month, now.day);
  final seen = <String>{};
  final out = <SalarioOcorrenciaPlano>[];

  void addDay(int year, int month, int day) {
    final last = lastDayOfMonth(year, month).day;
    final d = DateTime.utc(year, month, day.clamp(1, last));
    final ymd = _ymd(d);
    if (!seen.add(ymd)) return;
    out.add(
      SalarioOcorrenciaPlano(
        ymd: ymd,
        status: !d.isAfter(hoje) ? ComissaoStatus.paga : ComissaoStatus.pendente,
      ),
    );
  }

  final freq = me.pagamentoFrequencia;
  for (var i = 0; i < mesesHorizon; i++) {
    final cursor = DateTime.utc(hoje.year, hoje.month + i, 1);
    final y = cursor.year;
    final m = cursor.month;
    if (freq == PagamentoFrequencia.quinzenal) {
      addDay(y, m, pagamentoDiaEfetivo(me));
      final d2 = pagamentoDia2Efetivo(me);
      addDay(y, m, d2 == 0 ? lastDayOfMonth(y, m).day : d2);
    } else if (freq == PagamentoFrequencia.mensal) {
      final d = pagamentoDiaEfetivo(me);
      addDay(y, m, d <= 0 ? lastDayOfMonth(y, m).day : d);
    } else if (freq == PagamentoFrequencia.semanal) {
      // Semanal não gera série mensal aqui; só o corte do mês corrente
      // já coberto pelo próximo pagamento da UI.
    }
  }
  out.sort((a, b) => a.ymd.compareTo(b.ymd));
  return out;
}
