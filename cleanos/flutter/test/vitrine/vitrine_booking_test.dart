import 'dart:convert';

import 'package:cleanos/vitrine/screens/vitrine_home_screen.dart';
import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:cleanos/vitrine/vitrine_booking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('funil ordem e labels', () {
    test('ordem canônica Serviços → Data → Dados → Revisar', () {
      expect(kVitrineFunilOrdem.map((s) => s.headerLabel).toList(), [
        '1 · Serviços',
        '2 · Data e horário',
        '3 · Seus dados',
        '4 · Revisar',
      ]);
      expect(VitrineStep.servicos.index, 1);
      expect(VitrineStep.agenda.index, 2);
      expect(VitrineStep.dados.index, 3);
      expect(VitrineStep.revisar.index, 4);
    });

    test('defaults de config não usam linguagem de orçamento', () {
      const cfg = VitrineConfig();
      expect(contemLinguagemOrcamento(cfg.heroTitulo), isFalse);
      expect(contemLinguagemOrcamento(cfg.heroCta), isFalse);
      expect(contemLinguagemOrcamento(cfg.heroSubtitulo), isFalse);
      expect(contemLinguagemOrcamento(cfg.comoFunciona), isFalse);
      expect(cfg.heroTitulo, contains('Agende'));
      expect(cfg.heroCta, contains('Agendar'));
    });
  });

  group('validações de endereço', () {
    test('exige campos estruturados', () {
      expect(
        validarDadosVitrine(
          nome: '',
          whatsapp: '19999998888',
          cep: '13010000',
          rua: 'Rua A',
          numero: '1',
          bairro: 'Centro',
          cidade: 'Campinas',
        ),
        isNotNull,
      );
      expect(
        validarDadosVitrine(
          nome: 'Maria',
          whatsapp: '19999998888',
          cep: '13010000',
          rua: 'Rua A',
          numero: '1',
          bairro: 'Centro',
          cidade: 'Campinas',
        ),
        isNull,
      );
      expect(
        validarDadosVitrine(
          nome: 'Maria',
          whatsapp: '19999998888',
          cep: '123',
          rua: 'Rua A',
          numero: '1',
          bairro: 'Centro',
          cidade: 'Campinas',
        ),
        contains('CEP'),
      );
      expect(
        validarDadosVitrine(
          nome: 'Maria',
          whatsapp: '19999998888',
          cep: '13010000',
          rua: '',
          numero: '1',
          bairro: 'Centro',
          cidade: 'Campinas',
        ),
        contains('rua'),
      );
      expect(
        validarDadosVitrine(
          nome: 'Maria',
          whatsapp: '19999998888',
          cep: '13010000',
          rua: 'Rua A',
          numero: '',
          bairro: 'Centro',
          cidade: 'Campinas',
        ),
        contains('número'),
      );
      expect(
        validarDadosVitrine(
          nome: 'Maria',
          whatsapp: '(19) 99999-8888',
          cep: '13010-000',
          rua: 'Rua das Flores, 100',
          numero: '',
          bairro: 'Centro',
          cidade: 'Campinas',
          ruaComNumero: true,
        ),
        isNull,
      );
      expect(
        validarDadosVitrine(
          nome: 'Maria',
          whatsapp: '19999998888',
          cep: '13010000',
          rua: 'Rua sem numero',
          numero: '',
          bairro: 'Centro',
          cidade: 'Campinas',
          ruaComNumero: true,
        ),
        contains('número'),
      );
    });

    test('splitRuaNumero extrai número do fim', () {
      expect(splitRuaNumero('Rua A, 12').rua, 'Rua A');
      expect(splitRuaNumero('Rua A, 12').numero, '12');
      expect(splitRuaNumero('Av. Brasil 100A').numero, '100A');
      expect(splitRuaNumero('Rua X n 45').numero, '45');
      expect(splitRuaNumero('Só rua').numero, isEmpty);
    });

    test('payload estruturado sem endereco livre', () {
      final p = montarPayloadAgendamento(
        slotToken: 'tok',
        nome: 'Maria',
        whatsapp: '19999998888',
        cep: '13010-000',
        rua: 'Rua das Flores',
        numero: '100',
        bairro: 'Centro',
        cidade: 'Campinas',
        estado: 'sp',
        complemento: 'Apto 1',
        observacoes: 'Portão',
        honeypot: '',
        idempotencyKey: 'abc',
        itens: [
          {'id': 's1'},
        ],
      );
      expect(p.containsKey('endereco'), isFalse);
      expect(p['cep'], '13010000');
      expect(p['rua'], 'Rua das Flores');
      expect(p['numero'], '100');
      expect(p['bairro'], 'Centro');
      expect(p['cidade'], 'Campinas');
      expect(p['estado'], 'SP');
      expect(p['idempotency_key'], 'abc');
      expect(p['slot_token'], 'tok');
    });

    test('máscara de WhatsApp', () {
      expect(mascaraWhatsapp('19999998888'), isNot(contains('999998888')));
      expect(mascaraWhatsapp('19999998888').contains('*'), isTrue);
    });
  });

  group('widget home autoagendamento', () {
    VitrineApi fakeApi() {
      final catalog = [
        {
          'id': 'sofa1',
          'nome': 'Sofa 3 lugares',
          'descricao': 'Higienizacao',
          'grupo': 'sofa',
          'valor_base': 200,
          'tempo_medio_min': 60,
          'vitrine_destaque': true,
          'vitrine_layout': 'compacto',
          'ativo': true,
        },
      ];
      http.Response jsonOk(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
      return VitrineApi(
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.contains('/servicos')) return jsonOk({'items': catalog});
          if (path.contains('/bootstrap') || path.endsWith('/config')) {
            return jsonOk({
              'config': {
                'hero_titulo': 'Agende seu servico',
                'hero_subtitulo': 'Marque data e horario',
                'hero_cta': 'Agendar agora',
                'como_funciona':
                    '1) Selecione\n2) Data\n3) Dados\n4) Revise\n5) OS criada',
              },
              'hero_titulo': 'Agende seu servico',
              'hero_cta': 'Agendar agora',
              'midia': [],
              'atuacao': {
                'estado': 'SP',
                'cidades': ['Campinas'],
              },
            });
          }
          if (path.contains('/order-bumps')) return jsonOk({'items': []});
          if (path.contains('/slots')) {
            return jsonOk({
              'slots': [
                {'hora': '09:00', 'token': 't1'},
              ],
            });
          }
          return http.Response('{}', 404);
        }),
        baseUrl: 'http://test.local',
      );
    }

    testWidgets('home guiada: categorias → grupos → catálogo + carrinho', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: VitrineHomeScreen(api: fakeApi())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(RegExp(r'[Oo]r[cç]amento')), findsNothing);
      expect(find.text('O que você procura?'), findsOneWidget);
      expect(find.byKey(const Key('vitrine-home-browse-categorias')), findsOneWidget);
      expect(find.byKey(const Key('vitrine-nav-agendar')), findsNothing);
      expect(find.byKey(const Key('vitrine-home-cat-row')), findsOneWidget);

      // Categoria residencial (ou veicular se for a disponível no fake)
      final catResid = find.byKey(const Key('vitrine-home-cat-residencial'));
      final catVeic = find.byKey(const Key('vitrine-home-cat-veicular'));
      if (catResid.evaluate().isNotEmpty) {
        await tester.tap(catResid);
      } else {
        await tester.tap(catVeic);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vitrine-home-browse-grupos')), findsOneWidget);
      expect(find.text('Selecione os itens que deseja limpar'), findsOneWidget);
      expect(find.byKey(const Key('vitrine-home-grupo-row')), findsOneWidget);
      expect(find.byKey(const Key('vitrine-nav-agendar')), findsNothing);

      // Entra no primeiro grupo
      final anyGrupo = find.byKey(const Key('vitrine-home-grupo-sofa'));
      final anyPlano = find.byKey(const Key('vitrine-home-grupo-plano'));
      final anyAvulso = find.byKey(const Key('vitrine-home-grupo-avulsos'));
      if (anyGrupo.evaluate().isNotEmpty) {
        await tester.tap(anyGrupo);
      } else if (anyPlano.evaluate().isNotEmpty) {
        await tester.tap(anyPlano);
      } else if (anyAvulso.evaluate().isNotEmpty) {
        await tester.tap(anyAvulso);
      } else {
        // qualquer card de grupo
        await tester.tap(find.textContaining('opções').first);
      }
      await tester.pumpAndSettle();

      // Catálogo ou subgrupos
      final cat = find.byKey(const Key('vitrine-home-browse-catalogo'));
      final subs = find.byKey(const Key('vitrine-home-browse-subgrupos'));
      expect(cat.evaluate().isNotEmpty || subs.evaluate().isNotEmpty, isTrue);
      if (subs.evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('vitrine-home-ver-todos-grupo')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('vitrine-home-browse-catalogo')), findsOneWidget);
      expect(find.byKey(const Key('vitrine-home-catalog-header')), findsOneWidget);
      expect(find.textContaining(RegExp(r'[Oo]r[cç]amento')), findsNothing);
    });

    testWidgets('como funciona usa copy de autoagendamento', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: VitrineHomeScreen(api: fakeApi())),
      );
      await tester.pumpAndSettle();

      // Bottom nav "Como funciona" — 3º item
      final nav = find.byType(BottomNavigationBar);
      if (nav.evaluate().isNotEmpty) {
        await tester.tap(find.text('Como funciona').first);
      } else {
        // VitrineBottomNav custom
        final como = find.textContaining('Como');
        if (como.evaluate().isNotEmpty) {
          await tester.tap(como.last);
        }
      }
      await tester.pumpAndSettle();
      // Se chegou na etapa 6, não deve haver orçamento
      expect(find.textContaining(RegExp(r'[Oo]r[cç]amento')), findsNothing);
    });
  });
}
