/// prof_pagamento.dart — Próximo pagamento + a receber (ciclo da equipe).
///
/// Regras de data (BRT, civil):
///  * diário     → amanhã
///  * semanal    → próxima sexta-feira (repassa o fechamento da semana)
///  * quinzenal  → próximo dia 1 ou 16 do mês
///  * mensal     → dia 1 do próximo mês civil
library;

import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';

/// Snapshot do que o profissional vê na carteira (ciclo + pendente).
class ProfPagamentoSnapshot {
  const ProfPagamentoSnapshot({
    required this.aReceber,
    required this.qtdPendentes,
    this.proximoPagamento,
    this.frequencia,
  });

  /// Soma de comissões com status pendente.
  final double aReceber;
  final int qtdPendentes;

  /// Próxima data de repasse (só data civil BRT, meia-noite UTC do dia).
  final DateTime? proximoPagamento;
  final PagamentoFrequencia? frequencia;

  bool get temCiclo => frequencia != null && proximoPagamento != null;
}

/// Relógio de parede BRT de [now] (UTC).
DateTime brtWallDate(DateTime now) {
  final brt = now.toUtc().subtract(kBrtOffset);
  return DateTime.utc(brt.year, brt.month, brt.day);
}

/// Próxima data de pagamento (meia-noite BRT como DateTime.utc “naive”).
DateTime? proximaDataPagamento(
  PagamentoFrequencia? freq, {
  DateTime? now,
}) {
  if (freq == null) return null;
  final hoje = brtWallDate(now ?? DateTime.now());

  switch (freq) {
    case PagamentoFrequencia.diario:
      return hoje.add(const Duration(days: 1));
    case PagamentoFrequencia.semanal:
      // Próxima sexta (weekday 5). Se hoje é sexta → próxima sexta (+7).
      final delta = (DateTime.friday - hoje.weekday + 7) % 7;
      return hoje.add(Duration(days: delta == 0 ? 7 : delta));
    case PagamentoFrequencia.quinzenal:
      // Dias 1 e 16 do mês civil.
      if (hoje.day < 1) {
        return DateTime.utc(hoje.year, hoje.month, 1);
      }
      if (hoje.day < 16) {
        return DateTime.utc(hoje.year, hoje.month, 16);
      }
      // Após o 16 → dia 1 do mês seguinte.
      final nextMonth = DateTime.utc(hoje.year, hoje.month + 1, 1);
      return nextMonth;
    case PagamentoFrequencia.mensal:
      return DateTime.utc(hoje.year, hoje.month + 1, 1);
  }
}

/// Formata data civil BRT do snapshot (dd/MM/yyyy).
String formatProximoPagamento(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}';
}

/// Monta o snapshot a partir do user + extrato de comissões.
ProfPagamentoSnapshot buildPagamentoSnapshot({
  required User me,
  required List<ProfComissao> comissoes,
  DateTime? now,
}) {
  var cents = 0;
  var qtd = 0;
  for (final c in comissoes) {
    if (c.status != ComissaoStatus.pendente) continue;
    cents += (c.valorComissao * 100).round();
    qtd += 1;
  }
  final freq = me.pagamentoFrequencia;
  return ProfPagamentoSnapshot(
    aReceber: cents / 100.0,
    qtdPendentes: qtd,
    frequencia: freq,
    proximoPagamento: proximaDataPagamento(freq, now: now),
  );
}
