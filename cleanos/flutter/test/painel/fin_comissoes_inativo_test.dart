import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/models/prof_comissao.dart';
import 'package:cleanos/painel/financeiro/charts/fin_charts.dart';
import 'package:cleanos/painel/financeiro/fin_comissoes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

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

    test('gráfico usa a mesma cor configurada no usuário/agenda', () {
      const prof = User(
        id: 'prof-cor',
        nome: 'Breno Fixo',
        role: Role.profissional,
        corAgenda: '#EF4444',
      );

      expect(corGraficoComissaoProfissional(prof), const Color(0xFFEF4444));
    });
  });

  group('bonificação manual em comissões', () {
    test('modelo aceita tipo aplicado bonificacao', () {
      final c = ProfComissao.fromJson(const {
        'id': 'bonus-1',
        'profissional': 'prof-breno',
        'os': '',
        'valor_os': 0,
        'valor_comissao': 40,
        'tipo_aplicado': 'bonificacao',
        'base_valor': 40,
        'status': 'pendente',
        'descricao': 'Bonificação · meta do dia',
      });

      expect(c.tipoAplicado, ProfComissaoTipo.bonificacao);
      expect(c.os, isEmpty);
      expect(c.valorComissao, 40);
    });

    test('fromRecord normaliza relação os vazia/null para string vazia', () {
      final c = ProfComissao.fromRecord(
        RecordModel({
          'id': 'bonus-null-os',
          'profissional': 'prof-breno',
          'os': null,
          'valor_os': 0,
          'valor_comissao': 40,
          'tipo_aplicado': 'bonificacao',
          'base_valor': 40,
          'status': 'pendente',
          'descricao': 'Bonificação · meta do dia',
        }),
      );

      expect(c.tipoAplicado, ProfComissaoTipo.bonificacao);
      expect(c.os, isEmpty);
    });
  });
}
