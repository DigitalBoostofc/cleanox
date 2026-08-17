import 'package:flutter_test/flutter_test.dart';

import 'package:cleanos/vitrine/widgets/vitrine_hero_catalogo.dart';

void main() {
  test('hero parse e encode', () {
    const h = VitrineHeroCatalogo(titulo: 'Lava o carro hoje', destaque: 'carro', x: 10, y: 20);
    final again = VitrineHeroCatalogo.parse(h.encode());
    expect(again.titulo, 'Lava o carro hoje');
    expect(again.destaque, 'carro');
    expect(again.x, 10);
    expect(again.y, 20);
  });

  test('hero vazio vira default', () {
    final h = VitrineHeroCatalogo.parse('');
    expect(h.titulo, VitrineHeroCatalogo.defaultTitulo);
    expect(h.destaque, VitrineHeroCatalogo.defaultDestaque);
  });
}
