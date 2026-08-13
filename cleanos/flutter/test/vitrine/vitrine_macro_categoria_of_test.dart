import 'package:cleanos/vitrine/widgets/vitrine_catalogo_personalizavel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macro categoria a partir do serviço', () {
    expect(
      vitrineMacroCategoriaOf(
        categoria: 'veicular',
        grupo: 'promocao',
        nome: 'Cleanox Premium - Promoção',
      ),
      'veicular',
    );
    expect(
      vitrineMacroCategoriaOf(
        categoria: 'residencial',
        grupo: 'sofa',
        nome: 'Sofá 3 lugares',
      ),
      'residencial',
    );
    expect(
      vitrineMacroCategoriaOf(
        categoria: '',
        grupo: 'plano',
        nome: 'Cleanox Basic',
      ),
      'veicular',
    );
  });
}
