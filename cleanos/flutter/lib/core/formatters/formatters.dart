/// formatters.dart — Utilitários puros portados de `web/src/lib/collections.ts`.
///
/// ⭐ TODA a lógica de fuso BRT (UTC-3) vive AQUI (gate G-8). Nenhuma feature faz
/// conta de fuso sozinha. Ao contrário do web (que confia no fuso LOCAL do device),
/// o core fixa o offset **UTC-3** explicitamente — assim os bounds são corretos e
/// TESTÁVEIS em qualquer máquina/CI, espelhando `assertServiceIsToday` do hook
/// (`new Date(Date.now() - 3*3600*1000)`).
library;

import 'package:intl/intl.dart';

/// Offset fixo do horário de Brasília (sem horário de verão desde 2019).
const Duration kBrtOffset = Duration(hours: 3);

/// Limites de um dia [todayStart, tomorrowStart) já em string UTC do PocketBase.
class PbDayBounds {
  const PbDayBounds(this.todayStart, this.tomorrowStart);
  final String todayStart;
  final String tomorrowStart;
}

/// Janela half-open [start, end) em string UTC do PocketBase.
class DateRange {
  const DateRange(this.start, this.end);
  final String start;
  final String end;
}

/* ─────────────────────── datas / fuso BRT ─────────────────────── */

String _fmtPb(DateTime utc) {
  final d = utc.toUtc();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${p(d.month)}-${p(d.day)} '
      '${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
}

/// "BRT naive" = relógio de parede BRT representado como DateTime.utc (offset já
/// removido). Converter de volta para UTC real é somar [kBrtOffset].
DateTime _brtWallClock(DateTime nowUtc) => nowUtc.toUtc().subtract(kBrtOffset);

/// Limites do dia corrente em BRT, como string UTC do PB.
/// Espelha `getBrtDayBounds` (mas com offset BRT explícito, não o fuso do device).
PbDayBounds getBrtDayBounds({DateTime? now}) {
  final brt = _brtWallClock(now ?? DateTime.now());
  final brtMidnight = DateTime.utc(brt.year, brt.month, brt.day);
  final todayStart = brtMidnight.add(kBrtOffset);
  final tomorrowStart = brtMidnight
      .add(const Duration(days: 1))
      .add(kBrtOffset);
  return PbDayBounds(_fmtPb(todayStart), _fmtPb(tomorrowStart));
}

/// Limites de um mês (1-based) em BRT, como string UTC do PB.
/// Espelha `getBrtMonthBounds` (o web usa month 0-based; aqui é 1-based Dart).
DateRange getBrtMonthBounds(int year, int month) {
  final startNaive = DateTime.utc(year, month, 1);
  final endNaive = DateTime.utc(year, month + 1, 1);
  return DateRange(
    _fmtPb(startNaive.add(kBrtOffset)),
    _fmtPb(endNaive.add(kBrtOffset)),
  );
}

/// Janela half-open em BRT a partir da meia-noite de hoje, por [days] dias
/// (1 = só hoje, 7 = hoje + próximos 6 dias).
DateRange getBrtForwardDaysRange(int days, {DateTime? now}) {
  assert(days >= 1);
  final brt = _brtWallClock(now ?? DateTime.now());
  final brtMidnight = DateTime.utc(brt.year, brt.month, brt.day);
  final start = brtMidnight.add(kBrtOffset);
  final end = brtMidnight.add(Duration(days: days)).add(kBrtOffset);
  return DateRange(_fmtPb(start), _fmtPb(end));
}

/// Mês civil corrente em BRT (1º 00:00 → 1º do mês seguinte).
DateRange getBrtCurrentMonthRange({DateTime? now}) {
  final brt = _brtWallClock(now ?? DateTime.now());
  return getBrtMonthBounds(brt.year, brt.month);
}

/// Offset explícito no fim do datetime: `+03:00`, `-0300`, `+0300`… (A-07:
/// `.contains('+')` não reconhecia offset NEGATIVO e concatenava um 'Z' num
/// string que já tinha `-03:00`, quebrando o parse). Não casa a data em si
/// (`…-07-02`): exige [+-] seguido de exatamente 2+2 dígitos no FIM.
final RegExp _explicitOffsetRe = RegExp(r'[+-]\d{2}:?\d{2}$');

/// Parseia um datetime do PB (UTC, separador espaço ou 'T', com/sem 'Z' ou
/// offset explícito ±HH:MM) → DateTime UTC.
DateTime? parsePbUtc(String iso) {
  if (iso.isEmpty) return null;
  var s = iso.trim().replaceFirst(' ', 'T');
  if (!s.endsWith('Z') && !_explicitOffsetRe.hasMatch(s)) s = '${s}Z';
  return DateTime.tryParse(s)?.toUtc();
}

/// Converte value do `<input type="datetime-local">` (relógio BRT) → string UTC do PB.
/// Espelha `localInputToPBDate`.
String localInputToPBDate(String value) {
  if (value.isEmpty) return '';
  final p = DateTime.tryParse(value);
  if (p == null) return '';
  final naive = DateTime.utc(
    p.year,
    p.month,
    p.day,
    p.hour,
    p.minute,
    p.second,
  );
  return _fmtPb(naive.add(kBrtOffset));
}

/// Converte datetime UTC do PB → value do `<input type="datetime-local">` (BRT).
/// Espelha `pbDateToLocalInput`. Formato 'yyyy-MM-ddTHH:mm'.
String pbDateToLocalInput(String iso) {
  final utc = parsePbUtc(iso);
  if (utc == null) return '';
  final brt = utc.subtract(kBrtOffset);
  String p(int n) => n.toString().padLeft(2, '0');
  return '${brt.year.toString().padLeft(4, '0')}-${p(brt.month)}-${p(brt.day)}'
      'T${p(brt.hour)}:${p(brt.minute)}';
}

/// Extrai YYYY-MM-DD de um ISO (espelha `toDateInputValue`).
String toDateInputValue(String iso) => iso.isEmpty ? '' : iso.substring(0, 10);

/// Data de hoje em BRT como 'YYYY-MM-DD' (espelha `todayLocalDate`, mas em BRT).
String todayLocalDate({DateTime? now}) {
  final brt = _brtWallClock(now ?? DateTime.now());
  String p(int n) => n.toString().padLeft(2, '0');
  return '${brt.year.toString().padLeft(4, '0')}-${p(brt.month)}-${p(brt.day)}';
}

/* ─────────────────────── exibição ─────────────────────── */

final NumberFormat _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// Moeda R$ pt-BR (espelha `formatCurrency`).
String formatCurrency(num value) => _brl.format(value);

/// dd/MM/yyyy em BRT (espelha `formatDate`).
String formatDate(String iso) {
  final utc = parsePbUtc(iso);
  if (utc == null) return '—';
  return DateFormat('dd/MM/yyyy').format(utc.subtract(kBrtOffset));
}

/// dd/MM/yyyy HH:mm em BRT (espelha `formatDateTime`).
String formatDateTime(String iso) {
  final utc = parsePbUtc(iso);
  if (utc == null) return '—';
  return DateFormat('dd/MM/yyyy HH:mm').format(utc.subtract(kBrtOffset));
}

/// HH:mm em BRT (espelha `formatTime`).
String formatTime(String iso) {
  final utc = parsePbUtc(iso);
  if (utc == null) return '—';
  return DateFormat('HH:mm').format(utc.subtract(kBrtOffset));
}

/// HH:mm em BRT com placeholder '--:--' (espelha `formatHour`).
String formatHour(String iso) {
  final utc = parsePbUtc(iso);
  if (utc == null) return '--:--';
  return DateFormat('HH:mm').format(utc.subtract(kBrtOffset));
}

/* ─────────────────────── máscaras BR ─────────────────────── */

/// Máscara progressiva BR: (DD) NNNNN-NNNN / (DD) NNNN-NNNN (espelha `maskPhoneBR`).
String maskPhoneBR(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final d = digits.length > 11 ? digits.substring(0, 11) : digits;
  final n = d.length;
  if (n == 0) return '';
  if (n <= 2) return '($d';
  if (n <= 6) return '(${d.substring(0, 2)}) ${d.substring(2)}';
  if (n <= 10) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  }
  return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
}

/// Só os dígitos de um telefone (espelha `onlyDigitsPhone`).
String onlyDigitsPhone(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Máscara de CEP: NNNNN-NNN (espelha `maskCEP`).
String maskCEP(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final d = digits.length > 8 ? digits.substring(0, 8) : digits;
  if (d.length <= 5) return d;
  return '${d.substring(0, 5)}-${d.substring(5)}';
}

/// Divide nome completo no primeiro espaço (espelha `splitNome`).
({String nome, String sobrenome}) splitNome(String nomeCompleto) {
  final trimmed = nomeCompleto.trim();
  if (trimmed.isEmpty) return (nome: '', sobrenome: '');
  final idx = trimmed.indexOf(' ');
  if (idx == -1) return (nome: trimmed, sobrenome: '');
  return (
    nome: trimmed.substring(0, idx),
    sobrenome: trimmed.substring(idx + 1).trim(),
  );
}

/* ─────────────────────── slots de disponibilidade ─────────────────────── */

/// Config de um dia da semana (espelha `DisponibilidadeDia`).
class DisponibilidadeDia {
  const DisponibilidadeDia({
    required this.ativo,
    required this.inicio,
    required this.fim,
  });
  final bool ativo;

  /// 'HH:MM'
  final String inicio;

  /// 'HH:MM'
  final String fim;
}

/// Gera horários disponíveis 'HH:MM' (espelha `gerarSlotsDisponiveis`).
List<String> gerarSlotsDisponiveis(
  DisponibilidadeDia dia,
  int duracaoMin,
  List<String> horariosOcupados,
) {
  if (!dia.ativo || duracaoMin <= 0) return [];
  int toMin(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  final inicioMin = toMin(dia.inicio);
  final fimMin = toMin(dia.fim);
  if (inicioMin >= fimMin) return [];
  final ocupadosMin = horariosOcupados.map(toMin).toList();
  final slots = <String>[];
  var cur = inicioMin;
  while (cur + duracaoMin <= fimMin) {
    final colide = ocupadosMin.any(
      (o) => cur < o + duracaoMin && o < cur + duracaoMin,
    );
    if (!colide) {
      final h = cur ~/ 60;
      final m = cur % 60;
      slots.add(
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
      );
    }
    cur += 15;
  }
  return slots;
}
