/// fin_dash_layout_test.dart — modelo freeform do Dashboard (grade 12).
library;

import 'package:cleanos/painel/financeiro/dashboard/fin_dash_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinDashLayout.defaultLayout', () {
    test('tem todos os cards canônicos', () {
      final d = FinDashLayout.defaultLayout();
      expect(
        d.items.map((e) => e.id).toSet(),
        FinDashCardId.all.toSet(),
      );
      expect(d.items.every((e) => e.visible), isTrue);
    });

    test('KPIs ocupam linha inteira no topo', () {
      final kpis = FinDashLayout.defaultLayout().byId(FinDashCardId.kpis)!;
      expect(kpis.x, 0);
      expect(kpis.y, 0);
      expect(kpis.w, kFinDashCols);
    });
  });

  group('fromJson / clamp', () {
    test('rejeita id desconhecido e completa cards novos', () {
      final layout = FinDashLayout.fromJson({
        'v': 1,
        'items': [
          {'id': 'kpis', 'x': 0, 'y': 0, 'w': 12, 'h': 2, 'visible': true},
          {'id': 'hacker', 'x': 0, 'y': 0, 'w': 4, 'h': 4, 'visible': true},
        ],
      });
      expect(layout.byId('hacker'), isNull);
      expect(layout.byId(FinDashCardId.kpis)!.visible, isTrue);
      // Cards ausentes entram ocultos.
      expect(layout.byId(FinDashCardId.calendario)!.visible, isFalse);
    });

    test('clamp impede w > 12 e x+w overflow', () {
      final p = FinDashLayout.clampPlacement(
        const FinDashPlacement(
          id: FinDashCardId.freq,
          x: 10,
          y: 0,
          w: 8,
          h: 1,
        ),
      );
      expect(p.w + p.x, lessThanOrEqualTo(kFinDashCols));
      expect(p.h, greaterThanOrEqualTo(FinDashCardId.minSize(p.id).$2));
    });

    test('round-trip JSON', () {
      final a = FinDashLayout.defaultLayout().upsert(
        const FinDashPlacement(
          id: FinDashCardId.objetivos,
          x: 2,
          y: 4,
          w: 4,
          h: 5,
          visible: false,
        ),
      );
      final b = FinDashLayout.fromJson(a.toJson());
      final o = b.byId(FinDashCardId.objetivos)!;
      expect(o.x, 2);
      expect(o.y, 4);
      expect(o.w, 4);
      expect(o.h, 5);
      expect(o.visible, isFalse);
    });
  });
}
