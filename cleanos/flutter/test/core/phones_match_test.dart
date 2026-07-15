/// phones_match_test.dart — unicidade de celular (espelha os_logic.phonesMatch).
library;

import 'package:cleanos/core/formatters/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phonesMatch', () {
    test('mesmo número com máscaras diferentes casa', () {
      expect(phonesMatch('(85) 98690-3728', '85986903728'), isTrue);
      expect(phonesMatch('85 98690-3728', '+55 85 98690-3728'), isTrue);
      expect(phonesMatch('5585986903728', '(85) 98690-3728'), isTrue);
    });

    test('9º dígito opcional (celular) casa com mesma base', () {
      // 11 dígitos com 9 vs 10 sem 9 (mesmo DDD + 8 finais)
      expect(phonesMatch('85986903728', '8586903728'), isTrue);
      expect(phonesMatch('(85) 98690-3728', '85 8690-3728'), isTrue);
    });

    test('números distintos não casam', () {
      expect(phonesMatch('(85) 98690-3728', '(85) 98690-3729'), isFalse);
      expect(phonesMatch('(85) 98690-3728', '(88) 98690-3728'), isFalse);
      expect(phonesMatch('', '(85) 98690-3728'), isFalse);
    });

    test('phoneCanonBR remove DDI 55', () {
      expect(phoneCanonBR('+55 (85) 98690-3728'), '85986903728');
      expect(phoneCanonBR('85986903728'), '85986903728');
    });
  });
}
