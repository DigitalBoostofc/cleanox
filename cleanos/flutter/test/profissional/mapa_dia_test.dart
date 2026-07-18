/// Testes puros do mapa do dia (URL multi-parada + parse de pins).
library;

import 'package:cleanos/profissional/mapa/mapa_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapsDirUrl', () {
    test('vazio → maps genérico', () {
      expect(mapsDirUrl(const []), 'https://www.google.com/maps');
    });

    test('1 pin → search query', () {
      const p = MapaDiaPin(
        seq: 1,
        osId: 'a',
        nome: 'A',
        hora: '08:00',
        endereco: 'Rua Um, 1',
        status: 'atribuida',
      );
      final url = mapsDirUrl([p]);
      expect(url, contains('maps/search'));
      expect(url, contains(Uri.encodeComponent('Rua Um, 1')));
    });

    test('N pins → dir com waypoints e destination', () {
      final pins = [
        const MapaDiaPin(
          seq: 1,
          osId: 'a',
          nome: 'A',
          hora: '08:00',
          endereco: 'Rua Um',
          status: 'atribuida',
        ),
        const MapaDiaPin(
          seq: 2,
          osId: 'b',
          nome: 'B',
          hora: '10:00',
          endereco: 'Rua Dois',
          status: 'atribuida',
        ),
        const MapaDiaPin(
          seq: 3,
          osId: 'c',
          nome: 'C',
          hora: '14:00',
          endereco: 'Rua Tres',
          status: 'em_andamento',
        ),
      ];
      final url = mapsDirUrl(pins);
      expect(url, contains('maps/dir'));
      expect(url, contains('waypoints='));
      expect(url, contains(Uri.encodeComponent('Rua Tres')));
      expect(url, contains(Uri.encodeComponent('Rua Um')));
    });
  });

  group('MapaDiaPin.fromJson', () {
    test('parse com coords', () {
      final p = MapaDiaPin.fromJson({
        'seq': 1,
        'osId': 'x',
        'nome': 'Cli',
        'hora': '09:00',
        'endereco': 'Rua Z',
        'status': 'atribuida',
        'lat': -3.7,
        'lng': -38.5,
      });
      expect(p.seq, 1);
      expect(p.hasCoords, isTrue);
      expect(p.lat, -3.7);
    });

    test('lat/lng 0 → sem coords', () {
      final p = MapaDiaPin.fromJson({
        'seq': 1,
        'osId': 'x',
        'nome': 'Cli',
        'hora': '09:00',
        'endereco': 'Rua Z',
        'status': 'atribuida',
        'lat': 0,
        'lng': 0,
      });
      expect(p.hasCoords, isFalse);
    });
  });

  group('pinColorForSeq', () {
    test('1 e 2 são cores diferentes', () {
      expect(pinColorForSeq(1), isNot(equals(pinColorForSeq(2))));
    });

    test('cicla após 8', () {
      expect(pinColorForSeq(1), pinColorForSeq(9));
      expect(pinColorForSeq(2), pinColorForSeq(10));
    });
  });
}
