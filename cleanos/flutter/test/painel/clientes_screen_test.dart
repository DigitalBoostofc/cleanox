/// clientes_screen_test.dart — Lista / criar / validar do cofre de Clientes.
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/painel/clientes/cliente_form.dart';
import 'package:cleanos/painel/clientes/clientes_screen.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'painel_test_helpers.dart';

void main() {
  Finder formTextFieldAt(int i) => find
      .descendant(
        of: find.byType(ClienteForm),
        matching: find.byType(TextField),
      )
      .at(i);

  group('ClientesScreen', () {
    testWidgets('lista: renderiza clientes vindos do repositório', (
      tester,
    ) async {
      final repo = FakeClientes(
        seed: [
          fakeCliente(id: 'a', nome: 'Ana', sobrenome: 'Souza'),
          fakeCliente(id: 'b', nome: 'Bruno', sobrenome: 'Lima'),
        ],
      );
      await pumpPainel(
        tester,
        const ClientesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          clientesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('Bruno Lima'), findsOneWidget);
    });

    testWidgets('vazio: estado sem clientes com ação', (tester) async {
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

      expect(find.text('Nenhum cliente cadastrado'), findsOneWidget);
    });

    testWidgets('erro: banner com retry', (tester) async {
      await pumpPainel(
        tester,
        const ClientesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          clientesRepositoryProvider.overrideWithValue(
            FakeClientes(failList: true),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorBanner), findsOneWidget);
    });

    testWidgets('valida: salvar vazio mostra erros de campo', (tester) async {
      final repo = FakeClientes(
        seed: [fakeCliente(id: 'a', nome: 'Ana')],
      );
      await pumpPainel(
        tester,
        const ClientesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          clientesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Novo cliente'));
      await tester.pumpAndSettle();
      expect(find.byType(ClienteForm), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Nome é obrigatório'), findsOneWidget);
      expect(find.text('Bairro é obrigatório'), findsOneWidget);
      expect(repo.createCount, 0);
    });

    testWidgets('cria: preenche obrigatórios e salva → create no repo', (
      tester,
    ) async {
      final repo = FakeClientes(
        seed: [fakeCliente(id: 'a', nome: 'Ana')],
      );
      await pumpPainel(
        tester,
        const ClientesScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          clientesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Novo cliente'));
      await tester.pumpAndSettle();

      await tester.enterText(formTextFieldAt(0), 'Carlos Silva'); // nome
      await tester.enterText(formTextFieldAt(1), '85999998888'); // telefone
      await tester.enterText(formTextFieldAt(6), 'Centro'); // bairro
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump();

      expect(repo.createCount, 1);
      expect(repo.lastCreate?['nome'], 'Carlos');
      expect(repo.lastCreate?['sobrenome'], 'Silva');
      expect(repo.lastCreate?['endereco_bairro'], 'Centro');
    });
  });
}
