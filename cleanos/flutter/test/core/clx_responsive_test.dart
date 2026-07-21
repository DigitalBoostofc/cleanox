/// Testes da escala responsiva (telefone pequeno → grande).
library;

import 'package:cleanos/core/design/clx_responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computeLayoutScale: ref 390×844 ≈ 1.0', () {
    final s = ClxResponsive.computeLayoutScale(const Size(390, 844));
    expect(s, closeTo(1.0, 0.02));
  });

  test('computeLayoutScale: celular estreito &lt; 1', () {
    final s = ClxResponsive.computeLayoutScale(const Size(320, 568));
    expect(s, lessThan(1.0));
    expect(s, greaterThanOrEqualTo(kClxScaleMin));
  });

  test('computeLayoutScale: celular largo &gt; 1 e clampado', () {
    final s = ClxResponsive.computeLayoutScale(const Size(430, 932));
    expect(s, greaterThan(1.0));
    expect(s, lessThanOrEqualTo(kClxScaleMax));
  });

  test('computeLayoutScale: tamanho zero não quebra', () {
    expect(ClxResponsive.computeLayoutScale(Size.zero), 1.0);
  });

  testWidgets('ClxResponsiveScope define TextScaler combinado', (tester) async {
    late TextScaler scaler;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 640)),
        child: ClxResponsiveScope(
          child: Builder(
            builder: (context) {
              scaler = MediaQuery.textScalerOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    // Em 320dp a escala deve ser &lt; 1 (referência 390).
    expect(scaler.scale(10), lessThan(10));
    expect(scaler.scale(10), greaterThan(8));
  });
}
