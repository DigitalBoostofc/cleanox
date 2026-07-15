/// Divisão de parcelas (estilo Organizze): sobra na 1ª.
library;

import 'package:flutter_test/flutter_test.dart';

// Espelha a lógica de `_dividirParcelas` do form (privada no lib).
List<double> dividirParcelas(double total, int n) {
  if (n < 1) return [total];
  final cents = (total * 100).round();
  final base = cents ~/ n;
  final resto = cents - base * n;
  return [
    for (var i = 0; i < n; i++) (base + (i == 0 ? resto : 0)) / 100.0,
  ];
}

void main() {
  test('100 em 3 parcelas: 33,34 + 33,33 + 33,33', () {
    final v = dividirParcelas(100, 3);
    expect(v.length, 3);
    expect(v[0] + v[1] + v[2], closeTo(100, 0.001));
    expect(v[0], greaterThanOrEqualTo(v[1]));
    expect(v[1], v[2]);
  });

  test('36,68 em 2: 18,34 + 18,34', () {
    final v = dividirParcelas(36.68, 2);
    expect(v[0] + v[1], closeTo(36.68, 0.001));
  });
}
