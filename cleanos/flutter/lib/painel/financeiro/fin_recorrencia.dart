/// fin_recorrencia.dart — Expansão de lançamentos fixos/recorrentes.
///
/// Série `fixa`/`recorrente` com [FrequenciaRecorrencia]:
/// - **semanal**: a cada 7 dias a partir da data-base (ex.: toda segunda)
/// - **diario / quinzenal**: passo em dias
/// - **mensal+**: mesmo dia do mês (com clamp)
///
/// Ao abrir o período ou criar o fixo, materializamos as faltantes como `previsto`.
library;

import '../../core/models/financeiro.dart';
import 'fin_derivations.dart';

/// Fixa e recorrente geram série; parcelada já materializa na criação.
bool isRecorrenciaAtiva(RecorrenciaTipo r) =>
    r == RecorrenciaTipo.fixa || r == RecorrenciaTipo.recorrente;

/// Chave de série: mesma despesa/receita + frequência.
String serieRecorrenciaKey(FinLancamento l) =>
    '${l.tipo.wire}|${l.descricao.trim()}|'
    '${l.valor}|${l.contaId}|${l.categoriaId}|${l.subcategoriaId ?? ''}|'
    '${l.frequenciaEfetiva.wire}';

DateTime? parseYmdLocal(String s) {
  if (s.length < 10) return null;
  final y = int.tryParse(s.substring(0, 4));
  final m = int.tryParse(s.substring(5, 7));
  final d = int.tryParse(s.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String formatYmdLocal(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${p(d.month)}-${p(d.day)}';
}

/// Soma meses mantendo o dia (31/jan → 28/29 fev).
DateTime addMonthsClamped(DateTime d, int months) {
  final total = d.month - 1 + months;
  final y = d.year + total ~/ 12;
  final mo = total % 12 + 1;
  final lastDay = DateTime(y, mo + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(y, mo, day);
}

String yearMonthOf(String ymd) =>
    ymd.length >= 7 ? ymd.substring(0, 7) : ymd;

/// Avança [steps] unidades de [freq] a partir de [base].
DateTime addFrequencia(DateTime base, FrequenciaRecorrencia freq, int steps) {
  if (steps == 0) return base;
  return switch (freq) {
    FrequenciaRecorrencia.diario => base.add(Duration(days: steps)),
    FrequenciaRecorrencia.semanal => base.add(Duration(days: 7 * steps)),
    FrequenciaRecorrencia.quinzenal => base.add(Duration(days: 15 * steps)),
    FrequenciaRecorrencia.mensal => addMonthsClamped(base, steps),
    FrequenciaRecorrencia.bimestral => addMonthsClamped(base, steps * 2),
    FrequenciaRecorrencia.trimestral => addMonthsClamped(base, steps * 3),
    FrequenciaRecorrencia.semestral => addMonthsClamped(base, steps * 6),
    FrequenciaRecorrencia.anual => addMonthsClamped(base, steps * 12),
  };
}

bool _isMensalLike(FrequenciaRecorrencia f) =>
    f == FrequenciaRecorrencia.mensal ||
    f == FrequenciaRecorrencia.bimestral ||
    f == FrequenciaRecorrencia.trimestral ||
    f == FrequenciaRecorrencia.semestral ||
    f == FrequenciaRecorrencia.anual;

/// Datas (YYYY-MM-DD) faltantes no [periodo] para a série.
///
/// [datasExistentes]: datas YMD já gravadas na série (ou year-month `YYYY-MM`
/// para frequências mensais — ambos aceitos).
List<String> datasRecorrenciaFaltantes({
  required DateTime baseDate,
  required FrequenciaRecorrencia frequencia,
  required Periodo periodo,
  required Set<String> datasExistentes,
}) {
  final start = parseYmdLocal(periodo.start);
  final endExcl = parseYmdLocal(periodo.end);
  if (start == null || endExcl == null) return outEmpty;

  if (_isMensalLike(frequencia)) {
    return _faltantesMensal(
      baseDate: baseDate,
      frequencia: frequencia,
      start: start,
      endExcl: endExcl,
      existentes: datasExistentes,
    );
  }
  return _faltantesPorPassoDias(
    baseDate: baseDate,
    frequencia: frequencia,
    start: start,
    endExcl: endExcl,
    existentes: datasExistentes,
  );
}

const List<String> outEmpty = [];

List<String> _faltantesMensal({
  required DateTime baseDate,
  required FrequenciaRecorrencia frequencia,
  required DateTime start,
  required DateTime endExcl,
  required Set<String> existentes,
}) {
  final out = <String>[];
  final monthStep = switch (frequencia) {
    FrequenciaRecorrencia.mensal => 1,
    FrequenciaRecorrencia.bimestral => 2,
    FrequenciaRecorrencia.trimestral => 3,
    FrequenciaRecorrencia.semestral => 6,
    FrequenciaRecorrencia.anual => 12,
    _ => 1,
  };
  for (var step = 0; step < 120; step += monthStep) {
    final occ = addMonthsClamped(baseDate, step);
    if (occ.isBefore(start)) continue;
    if (!occ.isBefore(endExcl)) break;
    final ymd = formatYmdLocal(occ);
    final ym = yearMonthOf(ymd);
    if (existentes.contains(ymd) || existentes.contains(ym)) continue;
    out.add(ymd);
  }
  return out;
}

List<String> _faltantesPorPassoDias({
  required DateTime baseDate,
  required FrequenciaRecorrencia frequencia,
  required DateTime start,
  required DateTime endExcl,
  required Set<String> existentes,
}) {
  final stepDays = switch (frequencia) {
    FrequenciaRecorrencia.diario => 1,
    FrequenciaRecorrencia.semanal => 7,
    FrequenciaRecorrencia.quinzenal => 15,
    _ => 7,
  };
  final out = <String>[];
  // Alinha cursor na primeira ocorrência >= max(base, start).
  var cursor = baseDate;
  final limite = start.isBefore(baseDate) ? baseDate : start;
  // Avança em passos até alcançar o início do período (sem passar do fim).
  if (cursor.isBefore(limite)) {
    final diff = limite.difference(cursor).inDays;
    final steps = (diff / stepDays).ceil();
    cursor = cursor.add(Duration(days: steps * stepDays));
  }
  // Segurança: no máximo ~2 anos de diários.
  // Semanal/quinzenal/diário: só YMD (NUNCA year-month — senão 1x/mês).
  for (var guard = 0; guard < 800; guard++) {
    if (!cursor.isBefore(endExcl)) break;
    if (!cursor.isBefore(baseDate) && !cursor.isBefore(start)) {
      final ymd = formatYmdLocal(cursor);
      if (!existentes.contains(ymd)) {
        out.add(ymd);
      }
    }
    cursor = cursor.add(Duration(days: stepDays));
  }
  return out;
}

/// Chaves já existentes na série: YMD sempre; year-month só em mensal+.
Set<String> chavesExistentesSerie(
  Iterable<String> datasYmd, {
  required FrequenciaRecorrencia frequencia,
}) {
  final out = <String>{};
  for (final raw in datasYmd) {
    final ymd = raw.length >= 10 ? raw.substring(0, 10) : raw;
    if (ymd.isEmpty) continue;
    out.add(ymd);
    if (_isMensalLike(frequencia)) {
      out.add(yearMonthOf(ymd));
    }
  }
  return out;
}

/// Já existe ocorrência nesta data (mensal: mesmo mês conta como ocupado).
bool serieJaTemData(
  Set<String> existentes,
  String dataYmd, {
  required FrequenciaRecorrencia frequencia,
}) {
  final ymd = dataYmd.length >= 10 ? dataYmd.substring(0, 10) : dataYmd;
  if (existentes.contains(ymd)) return true;
  if (_isMensalLike(frequencia) && existentes.contains(yearMonthOf(ymd))) {
    return true;
  }
  return false;
}

/// Datas futuras após a base (horizonte por frequência).
List<String> datasRecorrenciaAFrente({
  required DateTime baseDate,
  required FrequenciaRecorrencia frequencia,
  int? passos,
}) {
  final n = passos ?? horizontePassos(frequencia);
  return [
    for (var i = 1; i <= n; i++)
      formatYmdLocal(addFrequencia(baseDate, frequencia, i)),
  ];
}

/// Quantas ocorrências criar à frente ao salvar um fixo.
int horizontePassos(FrequenciaRecorrencia f) => switch (f) {
      FrequenciaRecorrencia.diario => 90,
      FrequenciaRecorrencia.semanal => 52,
      FrequenciaRecorrencia.quinzenal => 26,
      FrequenciaRecorrencia.mensal => 12,
      FrequenciaRecorrencia.bimestral => 12,
      FrequenciaRecorrencia.trimestral => 8,
      FrequenciaRecorrencia.semestral => 6,
      FrequenciaRecorrencia.anual => 5,
    };

/// Alias legado (testes/antigos).
const int kRecorrenciaMesesAFrente = 12;

/// Body PB para materializar uma ocorrência prevista a partir do template.
Map<String, dynamic> bodyOcorrenciaPrevista(
  FinLancamento template,
  String dataYmd, {
  String? vencimentoYmd,
}) =>
    <String, dynamic>{
      'tipo': template.tipo.wire,
      'descricao': template.descricao,
      'categoria_id': template.categoriaId,
      'subcategoria_id': template.subcategoriaId,
      'valor': template.valor,
      'conta_id': template.contaId,
      'data': dataYmd,
      'vencimento': vencimentoYmd,
      'status': LancamentoStatus.previsto.wire,
      'recorrencia': template.recorrencia.wire,
      'frequencia': template.frequenciaEfetiva.wire,
      'parcela_atual': null,
      'parcelas_total': null,
      'origem': OrigemLancamento.manual.wire,
      'os_id': null,
      'os_numero': null,
      'cliente_nome': null,
      'servico_nome': null,
      'forma_pagamento': template.formaPagamento,
      'observacao': template.observacao,
      'tags': template.tags,
      'anexos': template.anexos.map((a) => a.toJson()).toList(),
    };
