/// servicos_screen_test.dart — Lista + editor + checklist do catálogo de Serviços.
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/servicos/checklist_editor.dart';
import 'package:cleanos/painel/servicos/servico_editor.dart';
import 'package:cleanos/painel/servicos/servicos_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda3.dart';
import 'painel_test_helpers.dart';

void main() {
  group('ServicosListScreen', () {
    testWidgets('lista: renderiza serviços vindos do repositório', (
      tester,
    ) async {
      final repo = FakeServicosFull(
        seed: [
          fakeServico(id: 'a', nome: 'Sofá 3 lugares'),
          fakeServico(id: 'b', nome: 'Colchão casal'),
        ],
      );
      await pumpPainel(
        tester,
        const ServicosListScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          servicosRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Sofá 3 lugares'), findsOneWidget);
      expect(find.text('Colchão casal'), findsOneWidget);
    });

    testWidgets('vazio: estado sem serviços com ação', (tester) async {
      await pumpPainel(
        tester,
        const ServicosListScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          servicosRepositoryProvider.overrideWithValue(FakeServicosFull()),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nenhum serviço cadastrado'), findsOneWidget);
    });

    testWidgets('erro: banner com retry', (tester) async {
      await pumpPainel(
        tester,
        const ServicosListScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          servicosRepositoryProvider.overrideWithValue(
            FakeServicosFull(failList: true),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorBanner), findsOneWidget);
    });
  });

  group('ServicoEditorScreen', () {
    testWidgets('valida: salvar sem nome mostra erro de campo', (tester) async {
      final repo = FakeServicosFull();
      await pumpPainel(
        tester,
        const ServicoEditorScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          servicosRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Nome é obrigatório.'), findsOneWidget);
      expect(repo.createCount, 0);
    });

    testWidgets('checklist: adiciona item e salva → create com checklist', (
      tester,
    ) async {
      final repo = FakeServicosFull();
      await pumpPainel(
        tester,
        const ServicoEditorScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          servicosRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();

      // Nome (primeiro TextField do formulário).
      await tester.enterText(find.byType(TextField).first, 'Sofá Premium');

      // Adiciona um item de checklist e o preenche (rola até o botão primeiro).
      await tester.ensureVisible(find.text('Adicionar item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar item'));
      await tester.pumpAndSettle();
      final chkField = find
          .descendant(
            of: find.byType(ChecklistEditor),
            matching: find.byType(TextField),
          )
          .first;
      expect(chkField, findsOneWidget);
      await tester.ensureVisible(chkField);
      await tester.pumpAndSettle();
      await tester.enterText(chkField, 'Aspirar estofado');
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump();

      expect(repo.createCount, 1);
      expect(repo.lastCreate?['nome'], 'Sofá Premium');
      final checklist = repo.lastCreate?['checklist_padrao'] as List<dynamic>?;
      expect(checklist, isNotNull);
      expect(checklist!.length, 1);
      expect((checklist.first as Map)['titulo'], 'Aspirar estofado');
    });

    testWidgets('edita: carrega serviço e prefila o nome', (tester) async {
      final repo = FakeServicosFull(
        seed: [
          fakeServico(
            id: 'x',
            nome: 'Higienização Deluxe',
            checklist: const [
              ChecklistTemplateItem(
                id: 'c1',
                titulo: 'Passo 1',
                ordem: 1,
                obrigatorio: true,
              ),
            ],
          ),
        ],
      );
      await pumpPainel(
        tester,
        const ServicoEditorScreen(servicoId: 'x'),
        overrides: [
          ...painelOverrides(user: painelUser()),
          servicosRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump(); // dispara _load
      await tester.pump();

      expect(find.text('Editar serviço'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Higienização Deluxe'),
        findsOneWidget,
      );
      // Item de checklist carregado.
      expect(find.widgetWithText(TextField, 'Passo 1'), findsOneWidget);
    });
  });
}
