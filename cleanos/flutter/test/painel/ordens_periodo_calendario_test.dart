import 'package:cleanos/painel/ordens/ordens_periodo_calendario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final d10 = DateTime(2026, 7, 10);
  final d12 = DateTime(2026, 7, 12);

  test('primeiro toque marca o início; segundo fecha o intervalo', () {
    final s = const PeriodoSelecao().toque(d10).toque(d12);
    expect(s.start, d10);
    expect(s.end, d12);
    expect(s.contem(DateTime(2026, 7, 11)), isTrue);
    expect(s.contem(DateTime(2026, 7, 13)), isFalse);
  });

  test('toque no mesmo dia = um dia', () {
    final s = const PeriodoSelecao().toque(d10).toque(d10);
    expect(s.start, d10);
    expect(s.end, d10);
  });

  test('toque depois de intervalo fechado recomeça', () {
    final s = const PeriodoSelecao().toque(d10).toque(d12).toque(d10);
    expect(s.inicio, d10);
    expect(s.fim, isNull);
  });

  test('segundo toque antes do início inverte', () {
    final s = const PeriodoSelecao().toque(d12).toque(d10);
    expect(s.start, d10);
    expect(s.end, d12);
  });
}
