/// fin_comissoes_percent_test.dart — F-230: o extrato de comissões renderizava o
/// `double` cru do PocketBase ("10.0%" em vez de "10%").
library;

import 'package:cleanos/painel/financeiro/fin_comissoes_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPercent', () {
    test('percentual redondo não mostra casa decimal (F-230)', () {
      expect(formatPercent(10), '10%');
      expect(formatPercent(10.0), '10%');
      expect(formatPercent(5), '5%');
      expect(formatPercent(100), '100%');
      expect(formatPercent(0), '0%');
    });

    test('percentual quebrado mantém a casa, com vírgula (pt-BR)', () {
      expect(formatPercent(12.5), '12,5%');
      expect(formatPercent(7.25), '7,25%');
    });
  });
}
