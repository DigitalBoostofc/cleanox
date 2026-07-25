/// fin_dash_layout_test.dart — modelo freeform do Dashboard (grade 24 v2).
library;

import 'package:cleanos/painel/financeiro/dashboard/fin_dash_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinDashLayout.defaultLayout', () {
    test('tem todos os cards canônicos na grade 24', () {
      final d = FinDashLayout.defaultLayout();
      expect(
        d.items.map((e) => e.id).toSet(),
        FinDashCardId.all.toSet(),
      );
      expect(d.items.every((e) => e.visible), isTrue);
      expect(kFinDashCols, 24);
    });

    test('KPIs ocupam linha inteira no topo', () {
      final kpis = FinDashLayout.defaultLayout().byId(FinDashCardId.kpis)!;
      expect(kpis.x, 0);
      expect(kpis.y, 0);
      expect(kpis.w, kFinDashCols);
    });
  });

  group('fromJson / clamp / migração v1→v2', () {
    test('rejeita id desconhecido e completa cards novos', () {
      final layout = FinDashLayout.fromJson({
        'v': 2,
        'items': [
          {'id': 'kpis', 'x': 0, 'y': 0, 'w': 24, 'h': 4, 'visible': true},
          {'id': 'hacker', 'x': 0, 'y': 0, 'w': 4, 'h': 4, 'visible': true},
        ],
      });
      expect(layout.byId('hacker'), isNull);
      expect(layout.byId(FinDashCardId.kpis)!.visible, isTrue);
      expect(layout.byId(FinDashCardId.calendario)!.visible, isFalse);
    });

    test('v1 (12 cols) escala ×2 para v2', () {
      final layout = FinDashLayout.fromJson({
        'v': 1,
        'items': [
          {
            'id': 'receitas_cat',
            'x': 0,
            'y': 2,
            'w': 6,
            'h': 5,
            'visible': true,
          },
        ],
      });
      final r = layout.byId(FinDashCardId.receitasCat)!;
      expect(r.x, 0);
      expect(r.y, 4);
      expect(r.w, 12);
      expect(r.h, 10);
    });

    test('clamp impede w > 24 e x+w overflow', () {
      final p = FinDashLayout.clampPlacement(
        const FinDashPlacement(
          id: FinDashCardId.freq,
          x: 20,
          y: 0,
          w: 16,
          h: 1,
        ),
      );
      expect(p.w + p.x, lessThanOrEqualTo(kFinDashCols));
      expect(p.h, greaterThanOrEqualTo(FinDashCardId.minSize(p.id).$2));
    });

    test('round-trip JSON grava v2', () {
      final a = FinDashLayout.defaultLayout().upsert(
        const FinDashPlacement(
          id: FinDashCardId.objetivos,
          x: 4,
          y: 8,
          w: 8,
          h: 10,
          visible: false,
        ),
      );
      final json = a.toJson();
      expect(json['v'], kFinDashLayoutVersion);
      final b = FinDashLayout.fromJson(json);
      final o = b.byId(FinDashCardId.objetivos)!;
      expect(o.x, 4);
      expect(o.y, 8);
      expect(o.w, 8);
      expect(o.h, 10);
      expect(o.visible, isFalse);
    });
  });

  group('placeWithReflow', () {
    test('aumentar altura empurra o card de baixo', () {
      final layout = const FinDashLayout([
        FinDashPlacement(id: FinDashCardId.freq, x: 0, y: 0, w: 12, h: 6),
        FinDashPlacement(id: FinDashCardId.balanco, x: 0, y: 6, w: 12, h: 6),
      ]);
      final next = layout.placeWithReflow(
        const FinDashPlacement(id: FinDashCardId.freq, x: 0, y: 0, w: 12, h: 10),
      );
      final a = next.byId(FinDashCardId.freq)!;
      final b = next.byId(FinDashCardId.balanco)!;
      expect(a.h, 10);
      expect(b.y, greaterThanOrEqualTo(a.y + a.h));
      expect(FinDashLayout.overlaps(a, b), isFalse);
    });

    test('aumentar largura empurra vizinho que colide', () {
      final layout = const FinDashLayout([
        FinDashPlacement(
          id: FinDashCardId.receitasCat,
          x: 0,
          y: 0,
          w: 12,
          h: 8,
        ),
        FinDashPlacement(
          id: FinDashCardId.despesasCat,
          x: 12,
          y: 0,
          w: 12,
          h: 8,
        ),
      ]);
      final next = layout.placeWithReflow(
        const FinDashPlacement(
          id: FinDashCardId.receitasCat,
          x: 0,
          y: 0,
          w: 16,
          h: 8,
        ),
      );
      final a = next.byId(FinDashCardId.receitasCat)!;
      final b = next.byId(FinDashCardId.despesasCat)!;
      expect(a.w, 16);
      expect(FinDashLayout.overlaps(a, b), isFalse);
      expect(b.y, greaterThanOrEqualTo(a.y + a.h));
    });

    test('mínimos livres permitem card 2×2', () {
      final p = FinDashLayout.clampPlacement(
        const FinDashPlacement(
          id: FinDashCardId.economia,
          x: 0,
          y: 0,
          w: 2,
          h: 2,
        ),
      );
      expect(p.w, 2);
      expect(p.h, 2);
    });

    test('card pinned não é empurrado no reflow', () {
      final layout = const FinDashLayout([
        FinDashPlacement(
          id: FinDashCardId.freq,
          x: 0,
          y: 0,
          w: 12,
          h: 6,
        ),
        FinDashPlacement(
          id: FinDashCardId.balanco,
          x: 0,
          y: 4,
          w: 12,
          h: 6,
          pinned: true,
        ),
      ]);
      // Aumenta freq invadindo o balanço pinned → o ativo (freq) cede.
      final next = layout.placeWithReflow(
        const FinDashPlacement(
          id: FinDashCardId.freq,
          x: 0,
          y: 0,
          w: 12,
          h: 10,
        ),
      );
      final pinned = next.byId(FinDashCardId.balanco)!;
      final freq = next.byId(FinDashCardId.freq)!;
      expect(pinned.y, 4);
      expect(pinned.pinned, isTrue);
      expect(FinDashLayout.overlaps(freq, pinned), isFalse);
    });

    test('persistência de pin e align', () {
      final a = FinDashLayout.defaultLayout().upsert(
        const FinDashPlacement(
          id: FinDashCardId.economia,
          x: 2,
          y: 2,
          w: 8,
          h: 6,
          pinned: true,
          align: FinDashAlign.center,
        ),
      );
      final b = FinDashLayout.fromJson(a.toJson());
      final e = b.byId(FinDashCardId.economia)!;
      expect(e.pinned, isTrue);
      expect(e.align, FinDashAlign.center);
      expect(a.toJson()['v'], kFinDashLayoutVersion);
    });
  });
}
