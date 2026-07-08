/// usuarios_screen_test.dart — CRUD de Usuários + editor de Disponibilidade.
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/usuarios/disponibilidade_editor.dart';
import 'package:cleanos/painel/usuarios/usuario_form.dart';
import 'package:cleanos/painel/usuarios/usuarios_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda3.dart';
import 'painel_test_helpers.dart';

void main() {
  Finder formFieldAt(int i) => find
      .descendant(
        of: find.byType(UsuarioForm),
        matching: find.byType(TextField),
      )
      .at(i);

  group('UsuariosScreen', () {
    testWidgets('lista: renderiza usuários vindos do repositório', (
      tester,
    ) async {
      final repo = FakeUsuariosFull(
        seed: [
          fakeUser(id: 'a', name: 'Ana Admin', role: Role.admin),
          fakeUser(id: 'b', name: 'Bia Prof', role: Role.profissional),
        ],
      );
      await pumpPainel(
        tester,
        const UsuariosScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          usuariosRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Ana Admin'), findsOneWidget);
      expect(find.text('Bia Prof'), findsOneWidget);
    });

    testWidgets('vazio: estado sem usuários com ação', (tester) async {
      await pumpPainel(
        tester,
        const UsuariosScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          usuariosRepositoryProvider.overrideWithValue(FakeUsuariosFull()),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nenhum usuário cadastrado'), findsOneWidget);
    });

    testWidgets('erro: banner com retry', (tester) async {
      await pumpPainel(
        tester,
        const UsuariosScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          usuariosRepositoryProvider.overrideWithValue(
            FakeUsuariosFull(failList: true),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorBanner), findsOneWidget);
    });

    testWidgets(
      'excluir profissional: diálogo avisa que agenda será excluída',
      (tester) async {
        final prof = fakeUser(id: 'p1', name: 'Bia Prof', role: Role.profissional);
        final repo = FakeUsuariosFull(seed: [prof]);
        await pumpPainel(
          tester,
          const UsuariosScreen(),
          overrides: [
            ...painelOverrides(user: painelUser()),
            usuariosRepositoryProvider.overrideWithValue(repo),
          ],
        );
        await tester.pump();
        await tester.pump();

        // Toca no botão excluir do profissional.
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();

        // O diálogo deve mencionar a exclusão da agenda de disponibilidade.
        expect(
          find.textContaining('agenda de disponibilidade'),
          findsOneWidget,
        );

        // Confirma → delete é chamado no repositório.
        await tester.tap(find.widgetWithText(ClxButton, 'Excluir'));
        await tester.pump();
        await tester.pump();

        expect(repo.deleteCount, 1);
      },
    );

    testWidgets(
      'excluir profissional: bloqueado por OS em aberto → exibe mensagem real do PB',
      (tester) async {
        final prof = fakeUser(id: 'p2', name: 'Carlos Prof', role: Role.profissional);
        final repo = FakeUsuariosDeleteBlocked(seed: [prof]);
        await pumpPainel(
          tester,
          const UsuariosScreen(),
          overrides: [
            ...painelOverrides(user: painelUser()),
            usuariosRepositoryProvider.overrideWithValue(repo),
          ],
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();

        // Confirma no diálogo.
        await tester.tap(find.widgetWithText(ClxButton, 'Excluir'));
        await tester.pump();
        await tester.pump();

        // A mensagem real do backend deve aparecer no toast (SnackBar).
        expect(
          find.textContaining('ordem de serviço em aberto'),
          findsOneWidget,
        );
        // A mensagem genérica NÃO deve aparecer.
        expect(
          find.text('Não foi possível excluir o usuário.'),
          findsNothing,
        );
      },
    );

    testWidgets('cria: valida vazio e depois salva → create no repo', (
      tester,
    ) async {
      final repo = FakeUsuariosFull(
        seed: [fakeUser(id: 'a', name: 'Ana Admin', role: Role.admin)],
      );
      await pumpPainel(
        tester,
        const UsuariosScreen(),
        overrides: [
          ...painelOverrides(user: painelUser()),
          usuariosRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Novo usuário'));
      await tester.pumpAndSettle();
      expect(find.byType(UsuarioForm), findsOneWidget);

      // Salvar vazio → erros.
      await tester.tap(find.widgetWithText(ClxButton, 'Salvar'));
      await tester.pump();
      expect(find.text('Nome é obrigatório'), findsOneWidget);
      expect(repo.createCount, 0);

      // Preenche e salva. Ordem dos TextField: nome(0), email(1),
      // whatsapp(2, opcional), senha(3), confirma(4).
      await tester.enterText(formFieldAt(0), 'Pedro Santos'); // nome
      await tester.enterText(formFieldAt(1), 'pedro@empresa.com'); // email
      await tester.enterText(formFieldAt(2), '11999990000'); // whatsapp
      await tester.enterText(formFieldAt(3), 'senha1234'); // senha
      await tester.enterText(formFieldAt(4), 'senha1234'); // confirma
      await tester.pump();

      await tester.tap(find.widgetWithText(ClxButton, 'Salvar'));
      await tester.pump();
      await tester.pump();

      expect(repo.createCount, 1);
      expect(repo.lastCreate?['name'], 'Pedro Santos');
      expect(repo.lastCreate?['email'], 'pedro@empresa.com');
      expect(repo.lastCreate?['role'], 'profissional');
      expect(repo.lastCreate?['whatsapp'], '11999990000');
    });
  });

  group('DisponibilidadeEditor', () {
    testWidgets('cria disponibilidade quando não existe → create no repo', (
      tester,
    ) async {
      final repo = FakeDisponibilidade(); // vazio → cria no save
      await pumpPainel(
        tester,
        DisponibilidadeEditor(
          profissional: fakeUser(id: 'p1', name: 'Bia Prof'),
        ),
        overrides: [
          ...painelOverrides(user: painelUser()),
          disponibilidadeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump(); // dispara _load
      await tester.pump();

      expect(find.text('Segunda'), findsOneWidget);

      await tester.tap(find.widgetWithText(ClxButton, 'Salvar'));
      await tester.pump();
      await tester.pump();

      expect(repo.createCount, 1);
      expect(repo.lastCreate?['profissional'], 'p1');
      expect((repo.lastCreate?['dias'] as List).length, 7);
    });

    testWidgets('carrega e atualiza disponibilidade existente → update', (
      tester,
    ) async {
      final repo = FakeDisponibilidade(
        seed: [
          fakeDisponibilidade(id: 'd1', profissional: 'p1', duracaoMin: 90),
        ],
      );
      await pumpPainel(
        tester,
        DisponibilidadeEditor(
          profissional: fakeUser(id: 'p1', name: 'Bia Prof'),
        ),
        overrides: [
          ...painelOverrides(user: painelUser()),
          disponibilidadeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(ClxButton, 'Salvar'));
      await tester.pump();
      await tester.pump();

      expect(repo.updateCount, 1);
      expect(repo.createCount, 0);
    });
  });
}
