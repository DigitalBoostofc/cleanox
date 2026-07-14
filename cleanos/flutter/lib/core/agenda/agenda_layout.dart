/// agenda_layout.dart — Núcleo PURO do calendário (agenda estilo Google).
///
/// Sem `dart:ui`, sem Flutter: só aritmética em **minutos-BRT inteiros**. É a
/// fonte única de verdade de "quanto dura", "o que sobrepõe o quê" e "onde cada
/// bloco fica" — assim o AVISO do formulário e o DESENHO da grade nunca se
/// contradizem (mesma função `sobreposicoes`).
///
/// ⭐ Fuso BRT centralizado (gate G-8): o relógio de parede sai de
/// `parsePbUtc(...).subtract(kBrtOffset)` (core/formatters). Nenhuma conta de
/// fuso solta aqui, e **nenhum `DateTime.now()`** no meio do cálculo — o layout
/// de um dia depende só dos eventos daquele dia, então é determinístico no teste.
library;

import '../formatters/formatters.dart';
import '../models/disponibilidade.dart';
import '../models/ordem_servico.dart';

/* ─────────────────────────── tokens do domínio ─────────────────────────── */

/// Fallback final de duração quando nem a OS nem o profissional definem uma (D9).
const int kDuracaoPadraoMin = 60;

/// Duração MÍNIMA de layout. Intervalo `[x, x)` (duração 0) não sobrepõe nada e
/// desenharia um bloco de altura zero — todo evento ocupa ao menos 15 min.
const int kDuracaoMinimaMin = 15;

/// Janela padrão da grade (6h–22h). É só o PISO: [layoutDayEvents] EXPANDE a
/// janela para caber eventos fora dela (nada some, nada estoura o Stack).
const int kDiaInicioPadraoMin = 6 * 60;
const int kDiaFimPadraoMin = 22 * 60;

/// Minutos num dia — teto do relógio de parede.
const int kMinutosNoDia = 24 * 60;

/// Máximo de colunas lado a lado num aglomerado de sobrepostas. O excedente vira
/// um chip "+N" (R4: em telas estreitas, lista — nunca colunas ilegíveis).
const int kMaxColunasMobile = 3;
const int kMaxColunasDesktop = 5;

/* ─────────────────────────── tipos ─────────────────────────── */

/// Um intervalo de agenda em minutos-BRT (half-open: `[startMin, endMin)`).
class Intervalo {
  const Intervalo({
    required this.id,
    required this.startMin,
    required this.endMin,
    this.label = '',
  });

  final String id;
  final int startMin;
  final int endMin;

  /// Rótulo humano (ex.: nome curto do cliente) — usado no aviso do formulário.
  final String label;

  int get duracaoMin => endMin - startMin;

  @override
  String toString() => 'Intervalo($id, $startMin→$endMin)';
}

/// Um evento já POSICIONADO na coluna de um dia.
class EventoPosicionado {
  const EventoPosicionado({
    required this.evento,
    required this.startMin,
    required this.endMin,
    required this.column,
    required this.columnCount,
    required this.truncTop,
    required this.truncBottom,
  });

  final Intervalo evento;

  /// Início/fim JÁ recortados ao dia da coluna (cruzando meia-noite, a fração do
  /// outro dia aparece na coluna daquele dia).
  final int startMin;
  final int endMin;

  /// Coluna ocupada (0-based) e quantas colunas o aglomerado tem no total —
  /// a largura do bloco é `1 / columnCount`. É o máximo FINAL do aglomerado,
  /// não o máximo corrente (senão a 1ª OS de uma cadeia ficaria larga demais).
  final int column;
  final int columnCount;

  /// O evento começa antes / termina depois da janela desenhada.
  final bool truncTop;
  final bool truncBottom;

  String get id => evento.id;
  int get duracaoMin => endMin - startMin;
}

/// Excedente de um aglomerado que passou do teto de colunas → chip "+N".
class ExcedenteAglomerado {
  const ExcedenteAglomerado({
    required this.startMin,
    required this.endMin,
    required this.eventos,
  });

  final int startMin;
  final int endMin;
  final List<Intervalo> eventos;

  int get count => eventos.length;
}

/// Resultado do layout de um dia.
class DayLayout {
  const DayLayout({
    required this.dayStart,
    required this.dayEnd,
    required this.eventos,
    required this.excedentes,
  });

  /// Janela EFETIVA desenhada (já expandida para caber tudo).
  final int dayStart;
  final int dayEnd;

  final List<EventoPosicionado> eventos;
  final List<ExcedenteAglomerado> excedentes;

  static const DayLayout vazio = DayLayout(
    dayStart: kDiaInicioPadraoMin,
    dayEnd: kDiaFimPadraoMin,
    eventos: [],
    excedentes: [],
  );

  int get duracaoJanelaMin => dayEnd - dayStart;
}

/* ─────────────────────────── duração ─────────────────────────── */

/// Duração efetiva de uma OS, em minutos (D9): **OS > profissional > 60**.
///
/// Só valores `> 0` contam — `duracao_min` do PB volta `0` quando vazio (R2
/// numérica), e `disponibilidade.duracao_min` também pode vir 0.
int duracaoEfetivaMin(OrdemServico os, [Disponibilidade? dispProf]) {
  final daOs = os.duracaoMin ?? 0;
  if (daOs > 0) return daOs;
  final doProf = dispProf?.duracaoMin ?? 0;
  if (doProf > 0) return doProf;
  return kDuracaoPadraoMin;
}

/// Intervalo `[início, fim)` de uma OS no relógio de parede BRT, em minutos
/// contados a partir da meia-noite do dia de INÍCIO.
///
/// `endMin` pode passar de [kMinutosNoDia] quando o serviço cruza a meia-noite —
/// o recorte por dia é responsabilidade do layout, não desta função.
({int startMin, int endMin}) intervaloBrtMin(
  OrdemServico os, [
  Disponibilidade? dispProf,
]) {
  final utc = parsePbUtc(os.dataHora);
  if (utc == null) return (startMin: 0, endMin: kDuracaoPadraoMin);
  final brt = utc.subtract(kBrtOffset);
  final start = brt.hour * 60 + brt.minute;
  return (startMin: start, endMin: start + duracaoEfetivaMin(os, dispProf));
}

/// [Intervalo] pronto de uma OS (id + rótulo do cliente), para o aviso e a grade.
Intervalo intervaloDaOs(OrdemServico os, [Disponibilidade? dispProf]) {
  final i = intervaloBrtMin(os, dispProf);
  return Intervalo(
    id: os.id,
    startMin: i.startMin,
    endMin: i.endMin,
    label: os.nomeCurto,
  );
}

/* ─────────────────────────── sobreposição ─────────────────────────── */

/// Quais [ocupados] colidem com o intervalo `[start, start + dur)`.
///
/// Half-open: encostar (`08:00–09:00` e `09:00–10:00`) **não** é sobrepor.
/// [dur] abaixo do mínimo de layout é elevado a [kDuracaoMinimaMin] — o mesmo
/// que a grade desenha, para aviso e desenho não divergirem.
List<Intervalo> sobreposicoes(List<Intervalo> ocupados, int start, int dur) {
  final end = start + (dur < kDuracaoMinimaMin ? kDuracaoMinimaMin : dur);
  return [
    for (final o in ocupados)
      if (o.startMin < end && start < o.endMin) o,
  ];
}

/* ─────────────────────────── layout do dia ─────────────────────────── */

/// Posiciona os [eventos] de UM dia em colunas estilo Google Calendar.
///
/// - **Aglomerados** (clusters) conectados por sobreposição; dentro de cada um,
///   o evento vai para a 1ª coluna livre e a largura é `1 / columnCount` — o
///   número FINAL de colunas do aglomerado (não o máximo corrente).
/// - **Teto de colunas** [maxColunas]: o excedente não é desenhado, vira
///   [ExcedenteAglomerado] ("+N", que a UI abre como lista).
/// - **Duração mínima** de 15 min aplicada ANTES do algoritmo.
/// - **Ordenação estável**: início ↑, fim ↓, id ↑ (determinístico nos testes).
/// - **Janela dinâmica**: `dayStart = min(padrão, chão da hora do 1º início)` e
///   `dayEnd = max(padrão, teto da hora do último fim)` — evento fora de 6h–22h
///   não some nem estoura o Stack. `truncTop/truncBottom` só marcam o que ainda
///   assim ficou de fora (a fração de quem cruza a meia-noite).
DayLayout layoutDayEvents(
  List<Intervalo> eventos, {
  int dayStart = kDiaInicioPadraoMin,
  int dayEnd = kDiaFimPadraoMin,
  int maxColunas = kMaxColunasDesktop,
}) {
  if (eventos.isEmpty) {
    return DayLayout(
      dayStart: dayStart,
      dayEnd: dayEnd,
      eventos: const [],
      excedentes: const [],
    );
  }

  // 1) Normaliza: recorta ao dia [0, 1440) e aplica a duração mínima de layout.
  final normalizados = <_Normalizado>[];
  for (final e in eventos) {
    final rawStart = e.startMin;
    final rawEnd = rawStart + (e.duracaoMin < kDuracaoMinimaMin
        ? kDuracaoMinimaMin
        : e.duracaoMin);
    final start = rawStart < 0 ? 0 : rawStart;
    final end = rawEnd > kMinutosNoDia ? kMinutosNoDia : rawEnd;
    // Evento inteiramente fora do dia (defensivo) — ignorado.
    if (start >= kMinutosNoDia || end <= start) continue;
    normalizados.add(
      _Normalizado(
        evento: e,
        startMin: start,
        endMin: end,
        truncTop: rawStart < 0,
        truncBottom: rawEnd > kMinutosNoDia,
      ),
    );
  }
  if (normalizados.isEmpty) {
    return DayLayout(
      dayStart: dayStart,
      dayEnd: dayEnd,
      eventos: const [],
      excedentes: const [],
    );
  }

  // 2) Ordenação estável: início ↑, fim ↓, id ↑.
  normalizados.sort((a, b) {
    final s = a.startMin.compareTo(b.startMin);
    if (s != 0) return s;
    final e = b.endMin.compareTo(a.endMin);
    if (e != 0) return e;
    return a.evento.id.compareTo(b.evento.id);
  });

  // 3) Janela dinâmica: só EXPANDE (o padrão 6h–22h é o piso).
  var minStart = normalizados.first.startMin;
  var maxEnd = normalizados.first.endMin;
  for (final n in normalizados) {
    if (n.startMin < minStart) minStart = n.startMin;
    if (n.endMin > maxEnd) maxEnd = n.endMin;
  }
  final inicioJanela = _min(dayStart, (minStart ~/ 60) * 60);
  final fimJanela = _min(
    kMinutosNoDia,
    _max(dayEnd, ((maxEnd + 59) ~/ 60) * 60),
  );

  // 4) Aglomerados + colunas.
  final posicionados = <EventoPosicionado>[];
  final excedentes = <ExcedenteAglomerado>[];
  var i = 0;
  while (i < normalizados.length) {
    // Fecha o aglomerado: cresce enquanto o próximo começar antes do fim corrente.
    final cluster = <_Normalizado>[normalizados[i]];
    var clusterEnd = normalizados[i].endMin;
    var j = i + 1;
    while (j < normalizados.length && normalizados[j].startMin < clusterEnd) {
      cluster.add(normalizados[j]);
      if (normalizados[j].endMin > clusterEnd) clusterEnd = normalizados[j].endMin;
      j++;
    }
    i = j;

    // Empacota: 1ª coluna cujo último evento já terminou.
    final fimPorColuna = <int>[];
    final colunaDe = <int>[]; // índice de coluna por evento do aglomerado
    for (final n in cluster) {
      var col = -1;
      for (var c = 0; c < fimPorColuna.length; c++) {
        if (fimPorColuna[c] <= n.startMin) {
          col = c;
          break;
        }
      }
      if (col == -1) {
        fimPorColuna.add(n.endMin);
        col = fimPorColuna.length - 1;
      } else {
        fimPorColuna[col] = n.endMin;
      }
      colunaDe.add(col);
    }

    // Largura = 1 / colunas FINAIS do aglomerado, respeitando o teto.
    final colunasUsadas = fimPorColuna.length;
    final columnCount = colunasUsadas > maxColunas ? maxColunas : colunasUsadas;

    final sobrando = <Intervalo>[];
    for (var k = 0; k < cluster.length; k++) {
      final n = cluster[k];
      final col = colunaDe[k];
      if (col >= maxColunas) {
        sobrando.add(n.evento);
        continue;
      }
      posicionados.add(
        EventoPosicionado(
          evento: n.evento,
          startMin: n.startMin,
          endMin: n.endMin,
          column: col,
          columnCount: columnCount,
          truncTop: n.truncTop || n.startMin < inicioJanela,
          truncBottom: n.truncBottom || n.endMin > fimJanela,
        ),
      );
    }
    if (sobrando.isNotEmpty) {
      excedentes.add(
        ExcedenteAglomerado(
          startMin: cluster.first.startMin,
          endMin: clusterEnd,
          eventos: sobrando,
        ),
      );
    }
  }

  return DayLayout(
    dayStart: inicioJanela,
    dayEnd: fimJanela,
    eventos: posicionados,
    excedentes: excedentes,
  );
}

/// Janela COMPARTILHADA por vários dias — na visão semana as 7 colunas precisam
/// alinhar as linhas de hora, então a janela é a união das janelas de cada dia.
({int inicio, int fim}) janelaCompartilhada(
  List<List<Intervalo>> dias, {
  int dayStart = kDiaInicioPadraoMin,
  int dayEnd = kDiaFimPadraoMin,
}) {
  var inicio = dayStart;
  var fim = dayEnd;
  for (final dia in dias) {
    final l = layoutDayEvents(dia, dayStart: dayStart, dayEnd: dayEnd);
    if (l.dayStart < inicio) inicio = l.dayStart;
    if (l.dayEnd > fim) fim = l.dayEnd;
  }
  return (inicio: inicio, fim: fim);
}

/// Entrada LIVRE de horário: 'HH:MM' → minutos do dia, ou `null` se inválido.
/// Tolerante ao que o usuário digita: '8:5' → 08:05, '0930' não (precisa do ':').
int? parseHoraLivre(String raw) {
  final m = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(raw.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// Arredonda ao múltiplo de 15 min mais próximo, sem passar de 23:45.
int snap15(int min) {
  final s = ((min / 15).round()) * 15;
  if (s < 0) return 0;
  return s >= kMinutosNoDia ? kMinutosNoDia - 15 : s;
}

/// 'HH:MM' de um minuto-BRT do dia (aceita >= 24h, recortando ao relógio).
String hhmmDeMinutos(int min) {
  final m = min < 0 ? 0 : min;
  final h = (m ~/ 60) % 24;
  final mm = m % 60;
  return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

/// Rótulo humano de uma duração: 45 → "45 min", 60 → "1h", 90 → "1h30".
String labelDuracao(int min) {
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = min % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

/// Faixa "08:00–10:00" de uma OS (cards do APK / web estreita — R4).
String faixaHorariaDaOs(OrdemServico os, [Disponibilidade? dispProf]) {
  final i = intervaloBrtMin(os, dispProf);
  return '${hhmmDeMinutos(i.startMin)}–${hhmmDeMinutos(i.endMin)}';
}

class _Normalizado {
  const _Normalizado({
    required this.evento,
    required this.startMin,
    required this.endMin,
    required this.truncTop,
    required this.truncBottom,
  });
  final Intervalo evento;
  final int startMin;
  final int endMin;
  final bool truncTop;
  final bool truncBottom;
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
