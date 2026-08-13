/// Formatação de rua/cidade no detalhe da OS (Agenda / Ordens).
library;

import 'package:cleanos/core/models/cliente.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/ponto_fisico.dart';
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

  group('formatOs*DaOs ponto físico', () {
    OrdemServico osPonto() {
      return OrdemServico(
        id: 'os1',
        cliente: 'c1',
        bairro: 'Meireles',
        localTipo: 'ponto_fisico',
        pontoFisico: 'p1',
        expand: OSExpand(
          pontoFisico: const PontoFisico(
            id: 'p1',
            nome: 'Galpão Centro',
            enderecoRua: 'Rua A',
            enderecoNumero: '10',
            enderecoBairro: 'Meireles',
            enderecoCidade: 'Fortaleza',
            enderecoEstado: 'CE',
          ),
          cliente: Cliente(
            id: 'c1',
            nome: 'Cliente',
            enderecoRua: 'Rua do Cliente',
            enderecoNumero: '99',
            enderecoBairro: 'Aldeota',
            enderecoCidade: 'Fortaleza',
            enderecoEstado: 'CE',
          ),
        ),
      );
    }

    test('rua vem do ponto, não do cliente', () {
      final os = osPonto();
      expect(formatOsRuaDaOs(os), contains('Galpão Centro'));
      expect(formatOsRuaDaOs(os), contains('Rua A, 10'));
      expect(formatOsRuaDaOs(os), isNot(contains('Rua do Cliente')));
    });

    test('cidade do ponto', () {
      expect(formatOsCidadeDaOs(osPonto()), 'Fortaleza — CE');
    });

    test('bairro do ponto', () {
      expect(formatOsBairroDaOs(osPonto()), 'Meireles');
    });

    test('cliente normal usa cofre', () {
      final os = OrdemServico(
        id: 'os2',
        cliente: 'c1',
        bairro: 'Aldeota',
        localTipo: 'cliente',
        expand: OSExpand(
          cliente: Cliente(
            id: 'c1',
            nome: 'Cliente',
            enderecoRua: 'Rua do Cliente',
            enderecoNumero: '99',
            enderecoBairro: 'Aldeota',
            enderecoCidade: 'Fortaleza',
            enderecoEstado: 'CE',
          ),
        ),
      );
      expect(formatOsRuaDaOs(os), 'Rua do Cliente, 99');
      expect(formatOsBairroDaOs(os), 'Aldeota');
    });
  });
}
