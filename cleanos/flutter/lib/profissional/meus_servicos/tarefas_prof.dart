/// Lista de tarefas do profissional em Meus serviços.
library;

import '../../core/formatters/formatters.dart';
import '../../core/models/agenda_compromisso.dart';

/// Pendentes (qualquer dia) + concluídas de hoje. Ordena por horário.
List<AgendaCompromisso> tarefasParaMeusServicos(
  Iterable<AgendaCompromisso> todas, {
  required DateTime hojeBrt,
}) {
  final dia = DateTime(hojeBrt.year, hojeBrt.month, hojeBrt.day);
  final out = <AgendaCompromisso>[];
  for (final t in todas) {
    final brt = _brt(t);
    if (brt == null) continue;
    final mesmoDia =
        brt.year == dia.year && brt.month == dia.month && brt.day == dia.day;
    if (!t.concluida || mesmoDia) out.add(t);
  }
  out.sort((a, b) {
    final ca = a.concluida ? 1 : 0;
    final cb = b.concluida ? 1 : 0;
    if (ca != cb) return ca - cb;
    return a.dataHora.compareTo(b.dataHora);
  });
  return out;
}

String horarioTarefa(AgendaCompromisso t) {
  final brt = _brt(t);
  if (brt == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(brt.hour)}:${p(brt.minute)}';
}

DateTime? _brt(AgendaCompromisso t) {
  final utc = parsePbUtc(t.dataHora);
  return utc?.subtract(kBrtOffset);
}
