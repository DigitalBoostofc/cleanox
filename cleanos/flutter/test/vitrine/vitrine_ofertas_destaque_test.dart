import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:cleanos/vitrine/widgets/vitrine_ofertas_destaque.dart';
import 'package:flutter_test/flutter_test.dart';

VitrineServico _s({
  required String id,
  String cat = 'veicular',
  String grupo = 'plano',
  bool destaque = false,
  int ordem = 0,
}) => VitrineServico(
  id: id,
  nome: id,
  descricao: '',
  categoria: cat,
  grupo: grupo,
  valorBase: 100,
  valorBaseMax: 0,
  tempoMedioMin: 0,
  tempoMedioLabel: '',
  orientacoesPre: '',
  vitrineDestaque: destaque,
  vitrineOrdem: ordem,
);

void main() {
  test('ofertas priorizam estrela da categoria', () {
    final list = ofertasDestaqueDaCategoria(
      catalogo: [
        _s(id: 'x', destaque: false),
        _s(id: 'a', destaque: true, ordem: 2),
        _s(id: 'c', destaque: true, ordem: 1),
        _s(id: 'r', cat: 'residencial', destaque: true),
      ],
      categoria: 'veicular',
    );
    expect(list.map((e) => e.id), ['c', 'a']);
  });

  test('sem estrela a faixa fica vazia', () {
    final list = ofertasDestaqueDaCategoria(
      catalogo: [
        _s(id: 'x'),
        _s(id: 'p', grupo: 'promocao'),
      ],
      categoria: 'veicular',
    );
    expect(list, isEmpty);
  });
}
