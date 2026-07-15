/// agenda_drag_test.dart — Núcleo PURO do arraste (Fase 2, spec §7/§11).
///
/// Trava a aritmética do drag em minutos-BRT inteiros: snap de 15, duração
/// mínima, teto na meia-noite, cross-day por largura de coluna, piso amplo do
/// dia de destino (2020) e o **ida-e-volta BRT** completo
/// (pixel → minuto → `localInputToPBDate` → PATCH → `parsePbUtc` → pixel),
/// incluindo o caso noturno (23h BRT = 02h UTC do dia seguinte).
library;

import 'package:cleanos/core/agenda/agenda_drag.dart';
import 'package:cleanos/core/agenda/agenda_layout.dart';
import 'package:cleanos/core/formatters/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Escala da grade do desktop (56 px por hora) — mesma do `day_column.dart`.
const double _px = 56 / 60;

void main() {
  group('minutosDoDeltaY', () {
    test('converte px → minutos na escala da grade', () {
      expect(minutosDoDeltaY(56, _px), 60); // 1 hora
      expect(minutosDoDeltaY(-28, _px), -30);
      expect(minutosDoDeltaY(0, _px), 0);
    });

    test('escala inválida não explode', () {
      expect(minutosDoDeltaY(100, 0), 0);
    });
  });

  group('novoInicioMovendo (snap 15)', () {
    test('arraste pequeno gruda no múltiplo de 15 mais próximo', () {
      // 08:00 + 5px (~5 min) → 08:00 (arredonda pra baixo).
      expect(novoInicioMovendo(startMin: 480, dyPx: 5, pxPorMin: _px), 480);
      // 08:00 + 12px (~13 min) → 08:15.
      expect(novoInicioMovendo(startMin: 480, dyPx: 12, pxPorMin: _px), 495);
    });

    test('mover pra cima (mais cedo) é permitido', () {
      expect(novoInicioMovendo(startMin: 480, dyPx: -56, pxPorMin: _px), 420);
    });

    test('não passa da meia-noite nem fica negativo', () {
      expect(novoInicioMovendo(startMin: 60, dyPx: -1000, pxPorMin: _px), 0);
      expect(
        novoInicioMovendo(startMin: 1380, dyPx: 1000, pxPorMin: _px),
        kMinutosNoDia - 15,
      );
    });
  });

  group('novaDuracaoRedimensionando', () {
    test('estica 1h → 2h', () {
      expect(
        novaDuracaoRedimensionando(
          startMin: 480,
          duracaoMin: 60,
          dyPx: 56,
          pxPorMin: _px,
        ),
        120,
      );
    });

    test('encolhe com snap de 15', () {
      expect(
        novaDuracaoRedimensionando(
          startMin: 480,
          duracaoMin: 60,
          dyPx: -28,
          pxPorMin: _px,
        ),
        30,
      );
    });

    test('duração mínima de 15 min (encolher demais não zera)', () {
      expect(
        novaDuracaoRedimensionando(
          startMin: 480,
          duracaoMin: 60,
          dyPx: -500,
          pxPorMin: _px,
        ),
        kDuracaoMinimaMin,
      );
    });

    test('teto na meia-noite do dia de início', () {
      // 23:00 + esticar 5h → só sobram 60 min até 24:00.
      expect(
        novaDuracaoRedimensionando(
          startMin: 23 * 60,
          duracaoMin: 60,
          dyPx: 5 * 56,
          pxPorMin: _px,
        ),
        60,
      );
    });
  });

  group('deltaDiasDoDrag (cross-day — D8)', () {
    test('coluna destino = deslocamento / largura da coluna', () {
      expect(deltaDiasDoDrag(0, 120), 0);
      expect(deltaDiasDoDrag(130, 120), 1);
      expect(deltaDiasDoDrag(-250, 120), -2);
      expect(deltaDiasDoDrag(50, 120), 0); // menos de meia coluna: fica
    });

    test('largura inválida não explode', () {
      expect(deltaDiasDoDrag(500, 0), 0);
    });
  });

  group('clampDiaDestino (piso 2020 — permite passado)', () {
    final hoje = DateTime(2026, 7, 13);

    test('pode voltar de hoje/futuro para um dia passado', () {
      final os = DateTime(2026, 7, 15);
      expect(
        clampDiaDestino(DateTime(2026, 7, 14), diaOriginal: os, hoje: hoje),
        DateTime(2026, 7, 14),
      );
      expect(
        clampDiaDestino(DateTime(2026, 7, 11), diaOriginal: os, hoje: hoje),
        DateTime(2026, 7, 11),
      );
    });

    test('avançar é sempre permitido', () {
      final os = DateTime(2026, 7, 13);
      expect(
        clampDiaDestino(DateTime(2026, 7, 20), diaOriginal: os, hoje: hoje),
        DateTime(2026, 7, 20),
      );
    });

    test('piso absoluto em 2020-01-01', () {
      final os = DateTime(2026, 7, 10);
      expect(
        clampDiaDestino(DateTime(2019, 12, 31), diaOriginal: os, hoje: hoje),
        DateTime(2020),
      );
      expect(
        clampDiaDestino(DateTime(2026, 7, 8), diaOriginal: os, hoje: hoje),
        DateTime(2026, 7, 8),
      );
    });
  });

  group('propostaDeMover', () {
    final hoje = DateTime(2026, 7, 13);

    test('semana: arrastar 1 coluna à direita e 1h pra baixo', () {
      final p = propostaDeMover(
        diaOriginal: DateTime(2026, 7, 14),
        hoje: hoje,
        startMin: 480,
        duracaoMin: 90,
        dxPx: 120,
        dyPx: 56,
        pxPorMin: _px,
        larguraColunaPx: 120,
        permiteCrossDay: true,
      );
      expect(p.dia, DateTime(2026, 7, 15));
      expect(p.deltaDias, 1);
      expect(p.startMin, 540);
      expect(p.duracaoMin, 90); // mover não mexe na duração
      expect(p.inerte, isFalse);
    });

    test('visão dia: deslocamento horizontal é ignorado (sem cross-day)', () {
      final p = propostaDeMover(
        diaOriginal: DateTime(2026, 7, 14),
        hoje: hoje,
        startMin: 480,
        duracaoMin: 60,
        dxPx: 900,
        dyPx: 0,
        pxPorMin: _px,
        larguraColunaPx: 300,
        permiteCrossDay: false,
      );
      expect(p.deltaDias, 0);
      expect(p.dia, DateTime(2026, 7, 14));
      expect(p.inerte, isTrue); // nada mudou → drop é no-op
    });

    test('arrastar pro passado aplica o delta (15 → 10, não recorta em hoje)', () {
      final p = propostaDeMover(
        diaOriginal: DateTime(2026, 7, 15),
        hoje: hoje,
        startMin: 480,
        duracaoMin: 60,
        dxPx: -600, // 5 colunas pra esquerda
        dyPx: 0,
        pxPorMin: _px,
        larguraColunaPx: 120,
        permiteCrossDay: true,
      );
      expect(p.dia, DateTime(2026, 7, 10));
      expect(p.deltaDias, -5); // 15 → 10
    });
  });

  test('propostaDeRedimensionar muda só a duração', () {
    final p = propostaDeRedimensionar(
      diaOriginal: DateTime(2026, 7, 14, 9, 30),
      startMin: 480,
      duracaoMin: 60,
      dyPx: 28,
      pxPorMin: _px,
    );
    expect(p.dia, DateTime(2026, 7, 14));
    expect(p.startMin, 480);
    expect(p.duracaoMin, 90);
    expect(p.deltaDias, 0);
    expect(p.fimMin, 570);
  });

  /* ─────────────────── ida-e-volta BRT (gate G-8, spec §11) ─────────────────
     pixel → minutos → localInputToPBDate → (PATCH) → parsePbUtc → pixel.
     Nenhum passo usa DateTime.now(); tudo em minutos-BRT inteiros.            */
  group('ida-e-volta BRT do drop', () {
    /// Volta do PB para o minuto-BRT do dia (o que a grade desenha).
    ({DateTime dia, int startMin}) voltaDoPb(String pb) {
      final utc = parsePbUtc(pb)!;
      final brt = utc.subtract(kBrtOffset);
      return (
        dia: DateTime(brt.year, brt.month, brt.day),
        startMin: brt.hour * 60 + brt.minute,
      );
    }

    test('diurno: 08:00 arrastado +1h30 volta em 09:30 no mesmo dia', () {
      final dia = DateTime(2026, 7, 14);
      final start = novoInicioMovendo(
        startMin: 480,
        dyPx: 1.5 * 56,
        pxPorMin: _px,
      );
      expect(start, 570);

      final pb = dataHoraPbDe(dia, start);
      expect(pb, startsWith('2026-07-14 12:30')); // 09:30 BRT = 12:30 UTC

      final volta = voltaDoPb(pb);
      expect(volta.dia, dia);
      expect(volta.startMin, start);
      // …e a mesma altura em pixels que o bloco tinha.
      expect(volta.startMin * _px, closeTo(start * _px, 0.001));
    });

    test('NOTURNO: 23:00 BRT = 02:00 UTC do dia seguinte (round-trip fiel)', () {
      final dia = DateTime(2026, 7, 14);
      // Bloco às 22:00, arrastado 1h pra baixo → 23:00.
      final start = novoInicioMovendo(
        startMin: 22 * 60,
        dyPx: 56,
        pxPorMin: _px,
      );
      expect(start, 23 * 60);

      final pb = dataHoraPbDe(dia, start);
      expect(pb, startsWith('2026-07-15 02:00')); // vira o dia em UTC

      final volta = voltaDoPb(pb);
      expect(volta.dia, dia, reason: 'a coluna continua sendo a do dia 14 (BRT)');
      expect(volta.startMin, 23 * 60);
    });

    test('cross-day noturno: drop na coluna seguinte às 23:45', () {
      final origem = DateTime(2026, 7, 14);
      final p = propostaDeMover(
        diaOriginal: origem,
        hoje: DateTime(2026, 7, 13),
        startMin: 23 * 60,
        duracaoMin: 60,
        dxPx: 120,
        dyPx: 45 * _px, // +45 min
        pxPorMin: _px,
        larguraColunaPx: 120,
        permiteCrossDay: true,
      );
      expect(p.dia, DateTime(2026, 7, 15));
      expect(p.startMin, 23 * 60 + 45);

      final pb = dataHoraPbDe(p.dia, p.startMin);
      expect(pb, startsWith('2026-07-16 02:45'));
      final volta = voltaDoPb(pb);
      expect(volta.dia, DateTime(2026, 7, 15));
      expect(volta.startMin, 23 * 60 + 45);
    });

    test('meia-noite: startMin nunca chega a 24:00', () {
      final pb = dataHoraPbDe(DateTime(2026, 7, 14), kMinutosNoDia - 15);
      expect(pb, startsWith('2026-07-15 02:45'));
      expect(voltaDoPb(pb).startMin, 23 * 60 + 45);
    });
  });
}
