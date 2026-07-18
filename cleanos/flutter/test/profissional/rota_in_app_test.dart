/// Formatação e haversine da rota in-app.
library;

import 'package:cleanos/profissional/mapa/rota_in_app_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDistancia', () {
    test('metros', () {
      expect(formatDistancia(350), '350 m');
    });
    test('km', () {
      expect(formatDistancia(1200), '1,2 km');
      expect(formatDistancia(15000), '15 km');
    });
  });

  group('formatDuracao', () {
    test('minutos', () {
      expect(formatDuracao(90), '2 min'); // ceil
      expect(formatDuracao(600), '10 min');
    });
    test('horas', () {
      expect(formatDuracao(3600), '1 h');
      expect(formatDuracao(3900), '1 h 05 min');
    });
  });

  group('haversineM', () {
    test('mesma coordenada ≈ 0', () {
      expect(haversineM(-3.7, -38.5, -3.7, -38.5), closeTo(0, 1));
    });
    test('~1 km na mesma latitude', () {
      // ~0.009 deg lon ≈ 1 km no equador; em -3.7 ≈ 1 km
      final m = haversineM(-3.7, -38.5, -3.7, -38.491);
      expect(m, greaterThan(800));
      expect(m, lessThan(1200));
    });
  });

  group('RotaDestino.fromJson', () {
    test('parse', () {
      final d = RotaDestino.fromJson({
        'osId': 'x',
        'nome': 'Cli',
        'endereco': 'Rua A',
        'lat': -3.7,
        'lng': -38.5,
      });
      expect(d.hasCoords, isTrue);
      expect(d.nome, 'Cli');
    });
  });
}
