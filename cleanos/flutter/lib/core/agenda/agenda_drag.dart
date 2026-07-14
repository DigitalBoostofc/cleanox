/// agenda_drag.dart — Núcleo PURO do ARRASTE na grade (Fase 2, desktop web).
///
/// Sem Flutter: só aritmética em **minutos-BRT inteiros** (gate G-8). A camada de
/// gestos (`painel/agenda/day_column.dart`) traduz pixels → minutos por AQUI, e
/// nada mais no caminho do arraste chama `DateTime.now()` — o resultado de um
/// arraste depende só do bloco arrastado e do deslocamento do ponteiro, então é
/// determinístico no teste.
///
/// Regras que moram aqui (spec §7):
/// - snap de 15 min e duração mínima de 15 min;
/// - resize pela borda inferior nunca cruza a meia-noite do dia de início;
/// - cross-day na semana: coluna destino = deslocamento horizontal / largura (D8);
/// - **nunca para um dia anterior** (D7) — mover mais cedo DENTRO do dia é ok.
library;

import '../formatters/formatters.dart';
import 'agenda_layout.dart';

/// Passo do snap (min). O mesmo do formulário — grade e form não divergem.
const int kSnapMin = 15;

/// Minutos correspondentes a um deslocamento vertical de [dyPx] na escala
/// [pxPorMin] (px por minuto da grade).
int minutosDoDeltaY(double dyPx, double pxPorMin) {
  if (pxPorMin <= 0) return 0;
  return (dyPx / pxPorMin).round();
}

/// Novo início (minutos-BRT) ao **mover** um bloco que começa em [startMin] por
/// [dyPx] px. Snap de 15 min, sempre dentro do relógio do dia.
int novoInicioMovendo({
  required int startMin,
  required double dyPx,
  required double pxPorMin,
}) => snap15(startMin + minutosDoDeltaY(dyPx, pxPorMin));

/// Nova duração ao **redimensionar** pela borda inferior (arrastar [dyPx] px).
///
/// Snap de 15, mínimo [kDuracaoMinimaMin] e teto na meia-noite do dia de início
/// (esticar sem fim viraria um bloco maior que a grade).
int novaDuracaoRedimensionando({
  required int startMin,
  required int duracaoMin,
  required double dyPx,
  required double pxPorMin,
}) {
  final bruto = duracaoMin + minutosDoDeltaY(dyPx, pxPorMin);
  var snap = (bruto / kSnapMin).round() * kSnapMin;
  if (snap < kDuracaoMinimaMin) snap = kDuracaoMinimaMin;
  final teto = kMinutosNoDia - startMin;
  if (snap > teto) snap = teto;
  return snap;
}

/// Quantos DIAS o arraste horizontal atravessou (visão semana — D8):
/// coluna destino = deslocamento / largura da coluna.
int deltaDiasDoDrag(double dxPx, double larguraColunaPx) {
  if (larguraColunaPx <= 0) return 0;
  return (dxPx / larguraColunaPx).round();
}

/// Data (date-only) de um [DateTime] — descarta a hora, imune a fuso.
DateTime diaDe(DateTime d) => DateTime(d.year, d.month, d.day);

/// Recorta o dia de destino do arraste (D7): **nunca antes de hoje**. Se a OS já
/// está no passado, o piso é o próprio dia dela (arrastar não a empurra pra
/// frente sozinha nem a joga mais pra trás).
DateTime clampDiaDestino(
  DateTime destino, {
  required DateTime diaOriginal,
  required DateTime hoje,
}) {
  final d = diaDe(destino);
  final original = diaDe(diaOriginal);
  final h = diaDe(hoje);
  final piso = h.isBefore(original) ? h : original;
  return d.isBefore(piso) ? piso : d;
}

/// `data_hora` do PB (string UTC) para o dia BRT [dia] às [startMin] minutos.
///
/// Fecha o ida-e-volta do arraste: pixel → minuto → AQUI → PATCH → `parsePbUtc`
/// → pixel. Caso noturno: 23:00 BRT vira 02:00 UTC do dia seguinte.
String dataHoraPbDe(DateTime dia, int startMin) {
  final m = startMin.clamp(0, kMinutosNoDia - 1);
  String p(int n) => n.toString().padLeft(2, '0');
  return localInputToPBDate(
    '${dia.year.toString().padLeft(4, '0')}-${p(dia.month)}-${p(dia.day)}'
    'T${hhmmDeMinutos(m)}',
  );
}

/// Proposta de um arraste em curso: onde o bloco CAI se o ponteiro soltar agora.
///
/// É o que o preview desenha (estado local do widget) e o que o drop persiste —
/// mesma conta, então preview e gravação nunca divergem.
class DragProposta {
  const DragProposta({
    required this.dia,
    required this.startMin,
    required this.duracaoMin,
    required this.deltaDias,
    required this.origemStartMin,
    required this.origemDuracaoMin,
  });

  /// Dia de destino (date-only, já recortado por [clampDiaDestino]).
  final DateTime dia;

  /// Início (minutos-BRT) e duração (min) propostos, já com snap.
  final int startMin;
  final int duracaoMin;

  /// Quantos dias o bloco andou de fato (0 = mesma coluna).
  final int deltaDias;

  /// De onde o bloco saiu (para saber se o drop mudou alguma coisa).
  final int origemStartMin;
  final int origemDuracaoMin;

  int get fimMin => startMin + duracaoMin;

  /// Nada mudou → o drop é um no-op (não gasta PATCH).
  bool get inerte =>
      deltaDias == 0 &&
      startMin == origemStartMin &&
      duracaoMin == origemDuracaoMin;

  @override
  String toString() =>
      'DragProposta(${dia.toIso8601String().substring(0, 10)}, '
      '$startMin+$duracaoMin, dias:$deltaDias)';
}

/// Proposta de **mover** o bloco (corpo): muda dia e/ou início; duração intacta.
DragProposta propostaDeMover({
  required DateTime diaOriginal,
  required DateTime hoje,
  required int startMin,
  required int duracaoMin,
  required double dxPx,
  required double dyPx,
  required double pxPorMin,
  required double larguraColunaPx,
  required bool permiteCrossDay,
}) {
  final passos = permiteCrossDay ? deltaDiasDoDrag(dxPx, larguraColunaPx) : 0;
  final destino = clampDiaDestino(
    diaDe(diaOriginal).add(Duration(days: passos)),
    diaOriginal: diaOriginal,
    hoje: hoje,
  );
  return DragProposta(
    dia: destino,
    startMin: novoInicioMovendo(
      startMin: startMin,
      dyPx: dyPx,
      pxPorMin: pxPorMin,
    ),
    duracaoMin: duracaoMin,
    // `difference` em dias date-only: imune a fuso (ambos são meia-noite local).
    deltaDias: destino.difference(diaDe(diaOriginal)).inDays,
    origemStartMin: startMin,
    origemDuracaoMin: duracaoMin,
  );
}

/// Proposta de **redimensionar** (borda inferior): muda só a duração.
DragProposta propostaDeRedimensionar({
  required DateTime diaOriginal,
  required int startMin,
  required int duracaoMin,
  required double dyPx,
  required double pxPorMin,
}) => DragProposta(
  dia: diaDe(diaOriginal),
  startMin: startMin,
  duracaoMin: novaDuracaoRedimensionando(
    startMin: startMin,
    duracaoMin: duracaoMin,
    dyPx: dyPx,
    pxPorMin: pxPorMin,
  ),
  deltaDias: 0,
  origemStartMin: startMin,
  origemDuracaoMin: duracaoMin,
);
