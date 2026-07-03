/// config_atuacao_editor_test.dart — Editor de "Área de atuação" (config_atuacao),
/// Fase 3, Feature 2. Cobre: carregar (estado + cidades + bairros), editar/salvar
/// (upsert via `ConfigAtuacaoRepository`), validação (cidade vazia/duplicada) e o
/// gate por papel na toolbar de Clientes (admin/gerente vê; profissional não).
library;

import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/config_atuacao.dart';
import 'package:cleanos/core/repositories/config_atuacao_repository.dart';
import 'package:cleanos/painel/clientes/clientes_screen.dart';
import 'package:cleanos/painel/clientes/config_atuacao_editor.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'painel_test_helpers.dart';

/// Fake do singleton de área de atuação: registra create/update p/ asserção.
class FakeConfigAtuacao implements ConfigAtuacaoRepository {
  FakeConfigAtuacao({this.initial});
  ConfigAtuacao? initial;

  int createCount = 0;
  int updateCount = 0;
  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;

  @override
  Future<ConfigAtuacao?> get() async => initial;

  @override
  Future<ConfigAtuacao> create(Map<String, dynamic> data) async {
    createCount++;
    lastCreate = data;
    return ConfigAtuacao(id: 'novo', estado: (data['estado'] as String?) ?? '');
  }

  @override
  Future<ConfigAtuacao> update(String id, Map<String, dynamic> data) async {
    updateCount++;
    lastUpdate = data;
    return ConfigAtuacao(id: id, estado: (data['estado'] as String?) ?? '');
  }
}

ConfigAtuacao _cfg() => const ConfigAtuacao(
  id: 'c1',
  estado: 'SP',
  cidades: [
    ConfigAtuacaoCidade(
      nome: 'Fortaleza',
      principal: true,
      bairros: ['Centro'],
    ),
  ],
);

List<Override> _overrides(FakeConfigAtuacao cfg, {Role role = Role.admin}) => [
  ...painelOverrides(user: painelUser(role: role)),
  configAtuacaoRepositoryProvider.overrideWithValue(cfg),
  clientesRepositoryProvider.overrideWithValue(FakeClientes()),
];

void main() {
  group('ConfigAtuacaoEditor', () {
    testWidgets('carrega estado + cidades + bairros existentes', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const ConfigAtuacaoEditor(),
        overrides: _overrides(FakeConfigAtuacao(initial: _cfg())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Fortaleza'), findsOneWidget);
      expect(find.text('Centro'), findsOneWidget);
      final estado = tester.widget<TextField>(
        find.byKey(const ValueKey('atuacao-estado')),
      );
      expect(estado.controller?.text, 'SP');
    });

    testWidgets('vazio: nenhuma config → estado limpo + aviso', (tester) async {
      await pumpPainel(
        tester,
        const ConfigAtuacaoEditor(),
        overrides: _overrides(FakeConfigAtuacao()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nenhuma cidade cadastrada.'), findsOneWidget);
    });

    testWidgets('cria config quando não existia (upsert → create)', (
      tester,
    ) async {
      final fake = FakeConfigAtuacao();
      await pumpPainel(
        tester,
        const ConfigAtuacaoEditor(),
        overrides: _overrides(fake),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('atuacao-estado')),
        'ce',
      );
      await tester.enterText(
        find.byKey(const ValueKey('atuacao-nova-cidade')),
        'Fortaleza',
      );
      await tester.tap(find.text('Cidade'));
      await tester.pump();
      expect(find.text('Fortaleza'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump();

      expect(fake.createCount, 1);
      expect(fake.lastCreate?['estado'], 'CE');
      final cidades = fake.lastCreate?['cidades'] as List;
      expect(cidades.length, 1);
      expect((cidades.first as Map)['nome'], 'Fortaleza');
      expect((cidades.first as Map)['principal'], true);
    });

    testWidgets('edita existente (upsert → update com id)', (tester) async {
      final fake = FakeConfigAtuacao(initial: _cfg());
      await pumpPainel(
        tester,
        const ConfigAtuacaoEditor(),
        overrides: _overrides(fake),
      );
      await tester.pump();
      await tester.pump();

      // Adiciona um bairro à cidade existente.
      await tester.enterText(
        find.widgetWithText(TextField, 'Adicionar bairro…'),
        'Aldeota',
      );
      await tester.tap(find.byTooltip('Adicionar bairro'));
      await tester.pump();
      expect(find.text('Aldeota'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump();

      expect(fake.updateCount, 1);
      final cidades = fake.lastUpdate?['cidades'] as List;
      final bairros = (cidades.first as Map)['bairros'] as List;
      expect(bairros.contains('Centro'), isTrue);
      expect(bairros.contains('Aldeota'), isTrue);
    });

    testWidgets('UF vazia bloqueia o Salvar (só habilita com 2 letras)', (
      tester,
    ) async {
      final fake = FakeConfigAtuacao();
      await pumpPainel(
        tester,
        const ConfigAtuacaoEditor(),
        overrides: _overrides(fake),
      );
      await tester.pump();
      await tester.pump();

      // Sem UF: aviso visível e Salvar não dispara o repo.
      expect(find.text('UF obrigatória'), findsOneWidget);
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump();
      expect(fake.createCount, 0);

      // Com UF de 2 letras: some o aviso e o Salvar passa.
      await tester.enterText(
        find.byKey(const ValueKey('atuacao-estado')),
        'SP',
      );
      await tester.pump();
      expect(find.text('UF obrigatória'), findsNothing);
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump();
      expect(fake.createCount, 1);
      expect(fake.lastCreate?['estado'], 'SP');
    });

    testWidgets('validação: cidade duplicada mostra erro', (tester) async {
      await pumpPainel(
        tester,
        const ConfigAtuacaoEditor(),
        overrides: _overrides(FakeConfigAtuacao(initial: _cfg())),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('atuacao-nova-cidade')),
        'fortaleza', // mesmo nome, caixa diferente
      );
      await tester.tap(find.text('Cidade'));
      await tester.pump();

      expect(find.text('Cidade já adicionada.'), findsOneWidget);
    });
  });

  group('Clientes — gate da área de atuação', () {
    testWidgets('admin vê o botão de área de atuação', (tester) async {
      await pumpPainel(
        tester,
        const ClientesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          clientesRepositoryProvider.overrideWithValue(FakeClientes()),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('Área de atuação'), findsOneWidget);
    });

    testWidgets('profissional NÃO vê o botão', (tester) async {
      await pumpPainel(
        tester,
        const ClientesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser(role: Role.profissional)),
          clientesRepositoryProvider.overrideWithValue(FakeClientes()),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('Área de atuação'), findsNothing);
    });
  });
}
