import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/financeiro/charts/fin_charts.dart';
import 'package:cleanos/painel/financeiro/fin_comissoes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('profissional inativo no histórico de comissões', () {
    const ativo = User(
      id: 'prof-ativo',
      nome: 'Hendrio Piter',
      role: Role.profissional,
    );
    const inativo = User(
      id: 'prof-inativo',
      nome: 'João Pedro',
      role: Role.profissional,
      ativo: false,
    );

    test('mantém o nome e acrescenta a marcação inativo', () {
      expect(nomeProfissionalNoHistorico(ativo), 'Hendrio Piter');
      expect(nomeProfissionalNoHistorico(inativo), 'João Pedro (inativo)');
    });

    test('reduz somente a opacidade da identidade do inativo', () {
      expect(opacidadeProfissionalNoHistorico(ativo), 1);
      expect(opacidadeProfissionalNoHistorico(inativo), lessThan(1));
      expect(
        opacidadeProfissionalNoHistorico(inativo),
        greaterThanOrEqualTo(0.6),
      );
    });

    test('legenda abrevia o nome sem mutilar a marcação inativo', () {
      expect(nomeCurtoProfissionalNoHistorico(inativo), 'João P. (inativo)');
    });

    test('navegação usa o id mesmo quando legendas abreviadas colidem', () {
      const joaoPedro = FinSlice(
        id: 'prof-joao-pedro',
        label: 'João P. (inativo)',
        value: 474,
        color: Colors.blue,
      );
      const joaoPaulo = FinSlice(
        id: 'prof-joao-paulo',
        label: 'João P. (inativo)',
        value: 100,
        color: Colors.grey,
      );

      expect(profissionalIdDaFatia(joaoPedro), 'prof-joao-pedro');
      expect(profissionalIdDaFatia(joaoPaulo), 'prof-joao-paulo');
    });
  });
}
