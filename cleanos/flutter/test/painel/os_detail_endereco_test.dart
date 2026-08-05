/// Formatação de rua/cidade no detalhe da OS (Agenda / Ordens).
library;

import 'package:cleanos/core/models/cliente.dart';
import 'package:cleanos/painel/ordens/os_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatOsRuaExibicao', () {
    test('null → traço', () {
      expect(formatOsRuaExibicao(null), '—');
    });

    test('rua + número', () {
      final c = Cliente(
        id: '1',
        nome: 'A',
        enderecoRua: 'Rua Doutor José',
        enderecoNumero: '79',
      );
      expect(formatOsRuaExibicao(c), 'Rua Doutor José, 79');
    });

    test('só rua', () {
      final c = Cliente(id: '1', nome: 'A', enderecoRua: 'Av. Brasil');
      expect(formatOsRuaExibicao(c), 'Av. Brasil');
    });

    test('vazio → traço', () {
      final c = Cliente(id: '1', nome: 'A');
      expect(formatOsRuaExibicao(c), '—');
    });
  });

  group('formatOsCidadeExibicao', () {
    test('cidade + UF', () {
      final c = Cliente(
        id: '1',
        nome: 'A',
        enderecoCidade: 'Fortaleza',
        enderecoEstado: 'CE',
      );
      expect(formatOsCidadeExibicao(c), 'Fortaleza — CE');
    });

    test('só cidade', () {
      final c = Cliente(id: '1', nome: 'A', enderecoCidade: 'Fortaleza');
      expect(formatOsCidadeExibicao(c), 'Fortaleza');
    });

    test('null → traço', () {
      expect(formatOsCidadeExibicao(null), '—');
    });
  });
}
