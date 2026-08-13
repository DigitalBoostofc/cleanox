import 'package:cleanos/vitrine/widgets/vitrine_catalogo_personalizavel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('busca por palavras no nome, ordem livre e sem acento', () {
    expect(
      vitrineMatchesBuscaNome(
        nome: 'Sofá 3 lugares',
        tituloComercial: '',
        query: 'sofa 3',
      ),
      isTrue,
    );
    expect(
      vitrineMatchesBuscaNome(
        nome: 'Sofá 3 lugares',
        tituloComercial: '',
        query: '3 sofa',
      ),
      isTrue,
    );
    expect(
      vitrineMatchesBuscaNome(
        nome: 'Higienização de bancos frente e trás',
        tituloComercial: '',
        query: 'bancos frente',
      ),
      isTrue,
    );
    expect(
      vitrineMatchesBuscaNome(
        nome: 'Colchão queen',
        tituloComercial: '',
        query: 'king',
      ),
      isFalse,
    );
    expect(
      vitrineMatchesBuscaNome(
        nome: 'Cleanox Premium - Promoção',
        tituloComercial: 'Pacote Premium',
        query: 'premium',
      ),
      isTrue,
    );
    expect(
      vitrineMatchesBuscaNome(
        nome: 'x',
        tituloComercial: '',
        query: '',
      ),
      isTrue,
    );
  });

  test('fold remove acentos', () {
    expect(vitrineFoldBusca('Sofá'), 'sofa');
    expect(vitrineFoldBusca('Colchão'), 'colchao');
  });
}
