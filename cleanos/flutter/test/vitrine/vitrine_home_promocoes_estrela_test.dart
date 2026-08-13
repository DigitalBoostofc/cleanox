import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:flutter_test/flutter_test.dart';

VitrineServico s(String id, {bool destaque = false, int ordem = 0}) =>
    VitrineServico(
      id: id,
      nome: id,
      descricao: '',
      categoria: 'veicular',
      grupo: 'plano',
      valorBase: 100,
      valorBaseMax: 0,
      tempoMedioMin: 0,
      tempoMedioLabel: '',
      orientacoesPre: '',
      vitrineDestaque: destaque,
      vitrineOrdem: ordem,
    );

List<VitrineServico> promocoesHome(List<VitrineServico> catalog) {
  final pkgs = catalog.where((e) => e.vitrineDestaque).toList()
    ..sort((a, b) {
      final o = a.vitrineOrdem.compareTo(b.vitrineOrdem);
      if (o != 0) return o;
      return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    });
  return pkgs;
}

void main() {
  test('Promoções da Semana só inclui estrela ativa', () {
    final catalog = [
      s('a', destaque: false, ordem: 0),
      s('b', destaque: true, ordem: 2),
      s('c', destaque: true, ordem: 1),
      s('d', destaque: false, ordem: 0),
    ];
    final pkgs = promocoesHome(catalog);
    expect(pkgs.map((e) => e.id).toList(), ['c', 'b']);
  });

  test('sem estrela → lista vazia (some seção na home)', () {
    expect(promocoesHome([s('x'), s('y')]), isEmpty);
  });
}
