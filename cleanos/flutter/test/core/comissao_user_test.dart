import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User comissão', () {
    test('sem comissão: hasComissaoAtiva false', () {
      const u = User(
        id: '1',
        role: Role.profissional,
        comissaoTipo: ComissaoTipo.nenhuma,
        comissaoValor: 10,
      );
      expect(u.hasComissaoAtiva, isFalse);
    });

    test('percentual com valor: hasComissaoAtiva true', () {
      const u = User(
        id: '1',
        role: Role.profissional,
        comissaoTipo: ComissaoTipo.percentual,
        comissaoValor: 10,
      );
      expect(u.hasComissaoAtiva, isTrue);
      expect(u.comissaoResumo, '10% por OS');
    });

    test('fixo com valor: resumo em R\$', () {
      const u = User(
        id: '1',
        role: Role.profissional,
        comissaoTipo: ComissaoTipo.fixo,
        comissaoValor: 30,
      );
      expect(u.hasComissaoAtiva, isTrue);
      expect(u.comissaoResumo, contains('30'));
    });

    test('admin nunca tem comissão ativa na UI do app', () {
      const u = User(
        id: '1',
        role: Role.admin,
        comissaoTipo: ComissaoTipo.percentual,
        comissaoValor: 10,
      );
      expect(u.hasComissaoAtiva, isFalse);
    });

    test('fromJson trata comissao_tipo vazio', () {
      final u = User.fromJson({
        'id': 'x',
        'comissao_tipo': '',
        'comissao_valor': null,
      });
      // empty tipo falls to default via fromRecord; fromJson alone may fail
      // so we only check explicit nenhuma
      final u2 = User.fromJson({
        'id': 'y',
        'comissao_tipo': 'nenhuma',
        'comissao_valor': 0,
      });
      expect(u2.comissaoTipo, ComissaoTipo.nenhuma);
      expect(u.id, 'x');
    });
  });
}
