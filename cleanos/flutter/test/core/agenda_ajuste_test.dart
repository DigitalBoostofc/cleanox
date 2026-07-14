/// agenda_ajuste_test.dart — Núcleo PURO do ajuste por sheet (Fase 3, D3/D6/D7).
///
/// O sheet do APK só mexe em DOIS números (início e duração), em passos de 15
/// min. Toda a regra mora aqui (minutos-BRT inteiros, gate G-8):
/// - snap de 15 e piso de 00:00 — adiantar NUNCA rola pro dia anterior (D7);
/// - duração mínima de 15 min e teto na meia-noite;
/// - só `agendada`/`atribuida` são ajustáveis (D6).
library;

import 'package:cleanos/core/agenda/agenda_ajuste.dart';
import 'package:cleanos/core/agenda/agenda_drag.dart';
import 'package:cleanos/core/agenda/agenda_layout.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:flutter_test/flutter_test.dart';

OrdemServico _os(OSStatus status) =>
    OrdemServico(id: 'x', nomeCurto: 'Ana', status: status, dataHora: '');

void main() {
  group('inicioComPasso', () {
    test('anda de 15 em 15 min', () {
      expect(inicioComPasso(14 * 60, 1), 14 * 60 + 15);
      expect(inicioComPasso(14 * 60, -1), 13 * 60 + 45);
      expect(inicioComPasso(14 * 60, 4), 15 * 60);
    });

    test('normaliza um horário fora da grade (08:07 → 08:15 / 07:45)', () {
      expect(inicioComPasso(8 * 60 + 7, 1), 8 * 60 + 15);
      expect(inicioComPasso(8 * 60 + 7, -1), 7 * 60 + 45);
    });

    test('à meia-noite, adiantar NÃO rola pro dia anterior (D7)', () {
      expect(inicioComPasso(0, -1), 0);
      expect(inicioComPasso(0, -10), 0);
      expect(inicioComPasso(10, -1), 0);
    });

    test('não passa de 23:45', () {
      expect(inicioComPasso(23 * 60 + 45, 1), 23 * 60 + 45);
      expect(inicioComPasso(23 * 60 + 30, 5), 23 * 60 + 45);
    });
  });

  group('duracaoComPasso', () {
    test('anda de 15 em 15 min', () {
      expect(duracaoComPasso(60, 1, startMin: 9 * 60), 75);
      expect(duracaoComPasso(60, -1, startMin: 9 * 60), 45);
      expect(duracaoComPasso(30, 6, startMin: 9 * 60), 120);
    });

    test('piso de 15 min (não encolhe até sumir)', () {
      expect(duracaoComPasso(30, -1, startMin: 9 * 60), kDuracaoMinimaMin);
      expect(duracaoComPasso(15, -1, startMin: 9 * 60), kDuracaoMinimaMin);
      expect(duracaoComPasso(15, -8, startMin: 9 * 60), kDuracaoMinimaMin);
    });

    test('teto na meia-noite do dia de início', () {
      // 23:00 + 60 = meia-noite exata; esticar mais não vaza pro dia seguinte.
      expect(duracaoComPasso(60, 1, startMin: 23 * 60), 60);
      expect(duracaoComPasso(30, 10, startMin: 23 * 60 + 30), 30);
    });

    test('duração inválida (0 / negativa) sobe pro mínimo', () {
      expect(duracaoComPasso(0, 0, startMin: 8 * 60), kDuracaoMinimaMin);
    });
  });

  group('reancorar a duração ao mudar o início', () {
    test('empurrar o início encolhe a duração até a meia-noite', () {
      // 23:00–00:00 (60 min) → +15 no início: 23:15 só cabe 45 min.
      final start = inicioComPasso(23 * 60, 1);
      expect(start, 23 * 60 + 15);
      expect(duracaoComPasso(60, 0, startMin: start), 45);
    });
  });

  group('osAjustavel (D6)', () {
    test('só agendada e atribuida', () {
      expect(osAjustavel(_os(OSStatus.agendada)), isTrue);
      expect(osAjustavel(_os(OSStatus.atribuida)), isTrue);
      expect(osAjustavel(_os(OSStatus.emAndamento)), isFalse);
      expect(osAjustavel(_os(OSStatus.concluida)), isFalse);
      expect(osAjustavel(_os(OSStatus.cancelada)), isFalse);
    });
  });

  group('dia do ajuste (D7)', () {
    test('o sheet nunca cai num dia anterior a hoje', () {
      final hoje = DateTime(2026, 7, 13);
      final amanha = DateTime(2026, 7, 14);
      // O sheet não muda de dia: o destino é sempre o dia da própria OS.
      expect(
        clampDiaDestino(amanha, diaOriginal: amanha, hoje: hoje),
        amanha,
      );
      // OS atrasada (ontem): o piso é o dia dela — o ajuste não a empurra.
      final ontem = DateTime(2026, 7, 12);
      expect(clampDiaDestino(ontem, diaOriginal: ontem, hoje: hoje), ontem);
    });
  });

  group('faixaHoraria (rótulo único de faixa)', () {
    test('formata início–fim a partir de minutos', () {
      expect(faixaHoraria(14 * 60, 45), '14:00–14:45');
      expect(faixaHoraria(8 * 60, 120), '08:00–10:00');
    });
  });
}
