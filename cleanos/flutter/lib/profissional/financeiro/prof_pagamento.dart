/// prof_pagamento.dart — Ciclo de pagamento + A receber + Perspectiva.
///
/// Regras (BRT, dia configurável pelo admin em `users.pagamento_dia`):
///  * diário     → amanhã
///  * semanal    → próximo [pagamento_dia] weekday (1=seg…7=dom; default sexta=5)
///  * quinzenal  → próximo entre [pagamento_dia] (default 15) e [pagamento_dia_2]
///                 (0 = último dia do mês; default 0)
///  * mensal     → próximo dia [pagamento_dia] (default 1)
///
/// **A receber** = comissões pendentes (já concluídas, não pagas).
/// **Perspectiva** = estimativa das OS em aberto com data até o próximo pagamento.
library;

import '../../core/formatters/formatters.dart';
import '../../core/models/collections.dart';
import '../../core/models/ordem_servico.dart';
import '../../core/models/prof_comissao.dart';
import '../../core/models/user.dart';
import 'prof_estimativa.dart';

/// Um pagamento já quitado (agrupa comissões pagas na mesma data).
class PagamentoHistorico {
  const PagamentoHistorico({
    required this.data,
    required this.total,
    required this.itens,
  });

  final String data; // YYYY-MM-DD ou texto de data da comissão
  final double total;
  final List<ProfComissao> itens;

  int get qtdOs => itens.length;
}

/// Snapshot da carteira do profissional.
class ProfPagamentoSnapshot {
  const ProfPagamentoSnapshot({
    required this.aReceber,
    required this.qtdPendentes,
    required this.perspectiva,
    required this.qtdAbertasCiclo,
    required this.pendentes,
    required this.historico,
    this.proximoPagamento,
    this.frequencia,
    this.cicloLabel = '',
  });

  /// Comissões pendentes (já garantidas).
  final double aReceber;
  final int qtdPendentes;
  final List<ProfComissao> pendentes;

  /// Estimativa de OS abertas até o próximo pagamento.
  final double perspectiva;
  final int qtdAbertasCiclo;

  /// Pagamentos já feitos (agrupados por data), mais recente primeiro.
  final List<PagamentoHistorico> historico;

  final DateTime? proximoPagamento;
  final PagamentoFrequencia? frequencia;
  final String cicloLabel;

  bool get temCiclo => frequencia != null && proximoPagamento != null;

  /// Perspectiva total do ciclo: já garantido + o que ainda pode entrar.
  double get totalCiclo =>
      ((aReceber + perspectiva) * 100).roundToDouble() / 100;
}

/// Relógio de parede BRT de [now] (UTC).
DateTime brtWallDate(DateTime now) {
  final brt = now.toUtc().subtract(kBrtOffset);
  return DateTime.utc(brt.year, brt.month, brt.day);
}

/// Último dia civil do mês (BRT naive como DateTime.utc).
DateTime lastDayOfMonth(int year, int month) {
  final firstNext = DateTime.utc(year, month + 1, 1);
  return firstNext.subtract(const Duration(days: 1));
}

/// Dia âncora normalizado conforme frequência (defaults do produto).
int pagamentoDiaEfetivo(User me) {
  final raw = me.pagamentoDia;
  switch (me.pagamentoFrequencia) {
    case PagamentoFrequencia.semanal:
      // 1–7 (seg…dom); default sexta = 5
      if (raw >= 1 && raw <= 7) return raw;
      return DateTime.friday; // 5
    case PagamentoFrequencia.mensal:
      if (raw >= 1 && raw <= 31) return raw;
      return 1;
    case PagamentoFrequencia.quinzenal:
      // 1º corte; default 15
      if (raw >= 1 && raw <= 31) return raw;
      return 15;
    case PagamentoFrequencia.diario:
    case null:
      return 0;
  }
}

/// 2º dia quinzenal; 0 = último dia do mês.
int pagamentoDia2Efetivo(User me) {
  final raw = me.pagamentoDia2;
  if (raw >= 1 && raw <= 31) return raw;
  return 0; // last day
}

/// Próxima data de pagamento (DateTime.utc naive = dia civil BRT).
DateTime? proximaDataPagamento(
  User me, {
  DateTime? now,
}) {
  final freq = me.pagamentoFrequencia;
  if (freq == null) return null;
  final hoje = brtWallDate(now ?? DateTime.now());
  final dia = pagamentoDiaEfetivo(me);

  switch (freq) {
    case PagamentoFrequencia.diario:
      return hoje.add(const Duration(days: 1));
    case PagamentoFrequencia.semanal:
      // weekday DateTime: 1=Mon … 7=Sun. Nosso dia: 1=seg … 7=dom.
      final target = dia.clamp(1, 7);
      final delta = (target - hoje.weekday + 7) % 7;
      // Se hoje é o dia de pagamento → próxima semana (já “fechou” o ciclo).
      return hoje.add(Duration(days: delta == 0 ? 7 : delta));
    case PagamentoFrequencia.quinzenal:
      final d1 = dia.clamp(1, 31);
      final d2raw = pagamentoDia2Efetivo(me);
      final d2 = d2raw == 0
          ? lastDayOfMonth(hoje.year, hoje.month).day
          : d2raw.clamp(1, 31);
      final candidates = <DateTime>[
        DateTime.utc(hoje.year, hoje.month, d1.clamp(1, lastDayOfMonth(hoje.year, hoje.month).day)),
        DateTime.utc(hoje.year, hoje.month, d2.clamp(1, lastDayOfMonth(hoje.year, hoje.month).day)),
        // próxima ocorrência no mês seguinte
        DateTime.utc(hoje.year, hoje.month + 1, d1.clamp(1, lastDayOfMonth(hoje.year, hoje.month + 1).day)),
        () {
          final lm = lastDayOfMonth(hoje.year, hoje.month + 1);
          final day = d2raw == 0 ? lm.day : d2raw.clamp(1, lm.day);
          return DateTime.utc(hoje.year, hoje.month + 1, day);
        }(),
      ];
      candidates.sort((a, b) => a.compareTo(b));
      for (final c in candidates) {
        if (c.isAfter(hoje)) return c;
      }
      return candidates.last;
    case PagamentoFrequencia.mensal:
      final target = dia.clamp(1, 31);
      final thisMonthLast = lastDayOfMonth(hoje.year, hoje.month).day;
      final thisDay = target.clamp(1, thisMonthLast);
      final thisPay = DateTime.utc(hoje.year, hoje.month, thisDay);
      if (thisPay.isAfter(hoje)) return thisPay;
      final nextLast = lastDayOfMonth(hoje.year, hoje.month + 1).day;
      return DateTime.utc(
        hoje.year,
        hoje.month + 1,
        target.clamp(1, nextLast),
      );
  }
}

/// Rótulo legível do ciclo (ex.: "Quinzenal · dias 15 e 31").
String cicloPagamentoLabel(User me) {
  final freq = me.pagamentoFrequencia;
  if (freq == null) return 'Sem ciclo';
  final d = pagamentoDiaEfetivo(me);
  switch (freq) {
    case PagamentoFrequencia.diario:
      return 'Diário';
    case PagamentoFrequencia.semanal:
      const names = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
      return 'Semanal · toda ${names[d.clamp(1, 7)]}';
    case PagamentoFrequencia.quinzenal:
      final d2 = pagamentoDia2Efetivo(me);
      final d2s = d2 == 0 ? 'último dia' : 'dia $d2';
      return 'Quinzenal · dia $d e $d2s';
    case PagamentoFrequencia.mensal:
      return 'Mensal · dia $d';
  }
}

String formatProximoPagamento(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}';
}

String _ymd(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${p(d.month)}-${p(d.day)}';
}

String _ymdBr(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}';
}

/// Janela do ciclo de pagamento **corrente** (datas de parede BRT).
///
/// Semanal com pagamento no sábado: **domingo → sábado** (7 dias).
/// No dia seguinte ao pagamento o contador recomeça do zero.
class CicloPagamentoWindow {
  const CicloPagamentoWindow({required this.inicio, required this.fim});

  /// Inclusivo (UTC naive = dia civil BRT).
  final DateTime inicio;
  final DateTime fim;

  String get inicioYmd => _ymd(inicio);
  String get fimYmd => _ymd(fim);

  /// Ex.: "20/07 a 26/07/2026"
  String get labelBr {
    if (inicioYmd == fimYmd) return _ymdBr(inicio);
    final sameYear = inicio.year == fim.year;
    final a = sameYear
        ? '${inicio.day.toString().padLeft(2, '0')}/${inicio.month.toString().padLeft(2, '0')}'
        : _ymdBr(inicio);
    return '$a a ${_ymdBr(fim)}';
  }

  bool contemYmd(String ymd) {
    final d = ymd.length >= 10 ? ymd.substring(0, 10) : ymd;
    if (d.length < 10) return false;
    return d.compareTo(inicioYmd) >= 0 && d.compareTo(fimYmd) <= 0;
  }
}

/// Ciclo corrente que contém [now] (ou o que fecha no próximo payday).
///
/// - **diário**: só o dia de hoje
/// - **semanal**: 7 dias terminando no weekday de pagamento (ex. sáb → dom…sáb)
/// - **quinzenal / mensal**: do dia seguinte ao corte anterior até o corte
CicloPagamentoWindow? cicloCorrente(User me, {DateTime? now}) {
  final freq = me.pagamentoFrequencia;
  if (freq == null) return null;
  final hoje = brtWallDate(now ?? DateTime.now());

  switch (freq) {
    case PagamentoFrequencia.diario:
      return CicloPagamentoWindow(inicio: hoje, fim: hoje);
    case PagamentoFrequencia.semanal:
      final target = pagamentoDiaEfetivo(me).clamp(1, 7);
      // Fim = próximo target **incluindo hoje** se já for o dia de pagamento.
      final delta = (target - hoje.weekday + 7) % 7;
      final fim = hoje.add(Duration(days: delta));
      final inicio = fim.subtract(const Duration(days: 6));
      return CicloPagamentoWindow(inicio: inicio, fim: fim);
    case PagamentoFrequencia.mensal:
      final target = pagamentoDiaEfetivo(me).clamp(1, 31);
      final thisLast = lastDayOfMonth(hoje.year, hoje.month).day;
      final thisPayDay = target.clamp(1, thisLast);
      final thisPay = DateTime.utc(hoje.year, hoje.month, thisPayDay);
      if (!hoje.isAfter(thisPay)) {
        // Ainda no ciclo que fecha este mês: início = dia após o corte do mês passado.
        final prevLast = lastDayOfMonth(hoje.year, hoje.month - 1).day;
        final prevPayDay = target.clamp(1, prevLast);
        final prevPay = DateTime.utc(hoje.year, hoje.month - 1, prevPayDay);
        return CicloPagamentoWindow(
          inicio: prevPay.add(const Duration(days: 1)),
          fim: thisPay,
        );
      }
      // Já passou o corte deste mês → ciclo até o próximo mês.
      final nextLast = lastDayOfMonth(hoje.year, hoje.month + 1).day;
      final nextPay = DateTime.utc(
        hoje.year,
        hoje.month + 1,
        target.clamp(1, nextLast),
      );
      return CicloPagamentoWindow(
        inicio: thisPay.add(const Duration(days: 1)),
        fim: nextPay,
      );
    case PagamentoFrequencia.quinzenal:
      final d1 = pagamentoDiaEfetivo(me).clamp(1, 31);
      final d2raw = pagamentoDia2Efetivo(me);
      final lm = lastDayOfMonth(hoje.year, hoje.month).day;
      final d2 = d2raw == 0 ? lm : d2raw.clamp(1, lm);
      final cuts = <DateTime>[
        DateTime.utc(hoje.year, hoje.month, d1.clamp(1, lm)),
        DateTime.utc(hoje.year, hoje.month, d2),
      ]..sort((a, b) => a.compareTo(b));
      // Próximo corte ≥ hoje (inclui hoje).
      DateTime? fim;
      for (final c in cuts) {
        if (!c.isBefore(hoje)) {
          fim = c;
          break;
        }
      }
      fim ??= () {
        final nlm = lastDayOfMonth(hoje.year, hoje.month + 1).day;
        final nd2 = d2raw == 0 ? nlm : d2raw.clamp(1, nlm);
        final nextCuts = <DateTime>[
          DateTime.utc(hoje.year, hoje.month + 1, d1.clamp(1, nlm)),
          DateTime.utc(hoje.year, hoje.month + 1, nd2),
        ]..sort((a, b) => a.compareTo(b));
        return nextCuts.first;
      }();
      // Início = dia após o corte anterior.
      final allPrev = <DateTime>[
        DateTime.utc(hoje.year, hoje.month - 1, d1.clamp(1, lastDayOfMonth(hoje.year, hoje.month - 1).day)),
        DateTime.utc(
          hoje.year,
          hoje.month - 1,
          d2raw == 0
              ? lastDayOfMonth(hoje.year, hoje.month - 1).day
              : d2raw.clamp(1, lastDayOfMonth(hoje.year, hoje.month - 1).day),
        ),
        ...cuts,
      ]..sort((a, b) => a.compareTo(b));
      DateTime inicio = fim.subtract(const Duration(days: 14));
      for (final c in allPrev.reversed) {
        if (c.isBefore(fim)) {
          inicio = c.add(const Duration(days: 1));
          break;
        }
      }
      return CicloPagamentoWindow(inicio: inicio, fim: fim);
  }
}

/// Parte-data YYYY-MM-DD da comissão (parede — sem fuso).
String comissaoYmd(ProfComissao c) {
  final raw = (c.data ?? c.created ?? '').trim();
  return raw.length >= 10 ? raw.substring(0, 10) : '';
}

/// Pendentes cuja data de OS cai no ciclo corrente.
List<ProfComissao> comissoesPendentesDoCiclo(
  User me,
  List<ProfComissao> comissoes, {
  DateTime? now,
}) {
  final w = cicloCorrente(me, now: now);
  if (w == null) {
    return [
      for (final c in comissoes)
        if (c.status == ComissaoStatus.pendente && c.valorComissao > 0) c,
    ];
  }
  return [
    for (final c in comissoes)
      if (c.status == ComissaoStatus.pendente && c.valorComissao > 0)
        // Sem data gravada (legado): entra no ciclo atual para não sumir
        // do "Fechar ciclo" / Equipe.
        if (comissaoYmd(c).isEmpty || w.contemYmd(comissaoYmd(c))) c,
  ];
}

/// String UTC PB meia-noite BRT do dia [d] (d é BRT naive utc).
String _pbStartOfDay(DateTime d) {
  // meia-noite BRT = 03:00 UTC
  final utc = DateTime.utc(d.year, d.month, d.day).add(kBrtOffset);
  String p(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${p(utc.month)}-${p(utc.day)} '
      '${p(utc.hour)}:${p(utc.minute)}:${p(utc.second)}';
}

/// Janela de OS abertas do ciclo: do mês anterior até o próximo pagamento
/// (inclui atrasadas ainda em aberto + futuras até o corte).
DateRange? cicloAbertoRange(User me, {DateTime? now}) {
  final next = proximaDataPagamento(me, now: now);
  if (next == null) return null;
  final hoje = brtWallDate(now ?? DateTime.now());
  // Começa 1 mês antes (atrasadas do ciclo atual ainda contam na perspectiva).
  final start = DateTime.utc(hoje.year, hoje.month - 1, 1);
  // end exclusive = day after payday (inclui OS no dia do pagamento)
  final end = next.add(const Duration(days: 1));
  return DateRange(_pbStartOfDay(start), _pbStartOfDay(end));
}

/// Agrupa comissões pagas por data (mais recente primeiro).
List<PagamentoHistorico> groupPagamentosHistorico(List<ProfComissao> comissoes) {
  final byDay = <String, List<ProfComissao>>{};
  for (final c in comissoes) {
    if (c.status != ComissaoStatus.paga) continue;
    final key = (c.data ?? '').trim();
    final day = key.length >= 10 ? key.substring(0, 10) : (key.isEmpty ? '—' : key);
    byDay.putIfAbsent(day, () => []).add(c);
  }
  final keys = byDay.keys.toList()
    ..sort((a, b) => b.compareTo(a)); // desc
  return [
    for (final k in keys)
      PagamentoHistorico(
        data: k,
        total: byDay[k]!
                .fold<int>(0, (s, c) => s + (c.valorComissao * 100).round()) /
            100.0,
        itens: byDay[k]!,
      ),
  ];
}

/// Monta o snapshot da carteira.
ProfPagamentoSnapshot buildPagamentoSnapshot({
  required User me,
  required List<ProfComissao> comissoes,
  List<OrdemServico> ordensAbertasCiclo = const [],
  DateTime? now,
}) {
  final pendentes = <ProfComissao>[];
  var centsPend = 0;
  for (final c in comissoes) {
    if (c.status != ComissaoStatus.pendente) continue;
    pendentes.add(c);
    centsPend += (c.valorComissao * 100).round();
  }

  // Perspectiva: OS abertas no ciclo (até próximo pagamento).
  var centsPrev = 0;
  var qtdAbertas = 0;
  for (final os in ordensAbertasCiclo) {
    if (os.status != OSStatus.atribuida &&
        os.status != OSStatus.emAndamento &&
        os.status != OSStatus.agendada) {
      continue;
    }
    // Diária: conta no máximo 1× por dia civil (simplifica perspectiva).
    final est = estimarComissaoOs(me, os);
    if (est <= 0 && me.comissaoTipo == ComissaoTipo.diaria) {
      // estima 1 diária se houver pelo menos 1 OS aberta no dia — feito abaixo
      continue;
    }
    if (est > 0) {
      centsPrev += (est * 100).round();
      qtdAbertas += 1;
    }
  }
  // Diária: nº de dias distintos com OS aberta no ciclo × valor diária.
  if (me.comissaoTipo == ComissaoTipo.diaria && me.comissaoValor > 0) {
    final days = <String>{};
    for (final os in ordensAbertasCiclo) {
      if (os.status == OSStatus.cancelada || os.status == OSStatus.concluida) {
        continue;
      }
      final dh = os.dataHora;
      if (dh.length >= 10) days.add(formatDate(dh)); // dd/MM/yyyy BRT
    }
    centsPrev = (days.length * me.comissaoValor * 100).round();
    qtdAbertas = days.length;
  }

  final next = proximaDataPagamento(me, now: now);
  return ProfPagamentoSnapshot(
    aReceber: centsPend / 100.0,
    qtdPendentes: pendentes.length,
    pendentes: pendentes,
    perspectiva: centsPrev / 100.0,
    qtdAbertasCiclo: qtdAbertas,
    historico: groupPagamentosHistorico(comissoes),
    frequencia: me.pagamentoFrequencia,
    proximoPagamento: next,
    cicloLabel: cicloPagamentoLabel(me),
  );
}
