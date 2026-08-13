import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula o cálculo de índices do ReorderableListView + renumeração 0..n.
List<int> reorderIds(List<int> ids, int oldIndex, int newIndex) {
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  final moved = [...ids];
  final item = moved.removeAt(oldIndex);
  moved.insert(target, item);
  return moved;
}

void main() {
  test('reorder renumber: move item para baixo', () {
    // A B C D → move A (0) para depois de C → B C A D
    final ids = [10, 20, 30, 40];
    // ReorderableListView: old=0, new=3 (insert before index 3 after remove adjust)
    final out = reorderIds(ids, 0, 3);
    expect(out, [20, 30, 10, 40]);
    final ordens = {for (var i = 0; i < out.length; i++) out[i]: i};
    expect(ordens[20], 0);
    expect(ordens[10], 2);
  });

  test('reorder renumber: move item para cima', () {
    final ids = [10, 20, 30, 40];
    // move D (3) to start: newIndex 0
    final out = reorderIds(ids, 3, 0);
    expect(out, [40, 10, 20, 30]);
  });

  test('copyWith vitrineOrdem', () {
    final s = VitrineAdminServico(
      id: '1',
      nome: 'x',
      grupo: 'sofa',
      categoria: 'residencial',
      valorBase: 1,
      vitrine: true,
      vitrineDestaque: false,
      ativo: true,
      vitrineOrdem: 5,
    );
    expect(s.copyWith(vitrineOrdem: 0).vitrineOrdem, 0);
    expect(s.copyWith(vitrineOrdem: 0).nome, 'x');
  });
}
