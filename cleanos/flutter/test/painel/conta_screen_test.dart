/// conta_screen_test.dart — "Minha Conta": dados do usuário + validação da senha.
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/painel/conta/conta_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painel_test_helpers.dart';

void main() {
  group('ContaScreen', () {
    testWidgets('mostra nome, e-mail e papel do usuário', (tester) async {
      await pumpPainel(
        tester,
        const ContaScreen(),
        overrides: painelOverrides(
          user: painelUser(role: Role.gerente, nome: 'Gil Gerente'),
        ),
        size: const Size(900, 1200),
      );

      expect(find.text('Gil Gerente'), findsOneWidget);
      expect(find.text('gerente@cleanos.app'), findsOneWidget);
      expect(find.text('Gerente'), findsOneWidget); // chip do papel
    });

    testWidgets('validação: campos vazios bloqueiam e mostram erros', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const ContaScreen(),
        overrides: painelOverrides(user: painelUser()),
        size: const Size(900, 1200),
      );

      // Submete sem preencher nada.
      await tester.tap(find.byType(ClxButton));
      await tester.pump();

      expect(find.text('Informe a senha atual'), findsOneWidget);
      expect(find.text('Informe a nova senha'), findsOneWidget);
    });

    testWidgets('validação: senhas divergentes → "As senhas não coincidem"', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const ContaScreen(),
        overrides: painelOverrides(user: painelUser()),
        size: const Size(900, 1200),
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'senhaAntiga1');
      await tester.enterText(fields.at(1), 'novaSenha123');
      await tester.enterText(fields.at(2), 'outraCoisa999');
      await tester.tap(find.byType(ClxButton));
      await tester.pump();

      expect(find.text('As senhas não coincidem'), findsOneWidget);
    });

    testWidgets('validação: nova senha curta → "Mínimo 8 caracteres"', (
      tester,
    ) async {
      await pumpPainel(
        tester,
        const ContaScreen(),
        overrides: painelOverrides(user: painelUser()),
        size: const Size(900, 1200),
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'senhaAntiga1');
      await tester.enterText(fields.at(1), '123');
      await tester.enterText(fields.at(2), '123');
      await tester.tap(find.byType(ClxButton));
      await tester.pump();

      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    });
  });
}
