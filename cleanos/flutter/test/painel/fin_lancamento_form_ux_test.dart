/// UX do form de lançamento: data única, pago/não pago na 1ª tela.
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/lancamentos/lancamento_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  List<Override> withFin(FakeFinanceiro fake) => [
        ...painelOverrides(user: painelUser()),
        financeiroRepositoryProvider.overrideWithValue(fake),
      ];

  testWidgets(
    'form mostra data única e status pago/não pago na 1ª tela',
    (tester) async {
      await pumpPainel(
        tester,
        const LancamentoForm(initialTipo: TipoLancamento.despesa),
        overrides: withFin(
          FakeFinanceiro(
            contas: [fakeConta(id: 'c', nome: 'Caixa')],
            categorias: [
              fakeCategoria(id: 'cat', nome: 'Material'),
            ],
          ),
        ),
      );
      await settle(tester);

      // Label required → Text.rich "Data (vencimento) *"
      expect(find.textContaining('Data (vencimento)'), findsOneWidget);
      expect(find.text('Pago'), findsWidgets);
      expect(find.text('Não pago'), findsOneWidget);
      // Só 1 rótulo com "vencimento" (o da data unificada).
      expect(find.textContaining('vencimento'), findsOneWidget);

      await tester.tap(find.text('Mais'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Forma de pagamento'), findsOneWidget);
      // Em Mais não surge segundo campo de vencimento.
      expect(find.textContaining('vencimento'), findsOneWidget);
    },
  );

  testWidgets(
    'salvar grava data=vencimento e respeita Não pago',
    (tester) async {
      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'c1', nome: 'Caixa')],
        categorias: [fakeCategoria(id: 'cat1', nome: 'Material')],
      );
      await pumpPainel(
        tester,
        const LancamentoForm(initialTipo: TipoLancamento.despesa),
        overrides: withFin(fake),
      );
      await settle(tester);
      await tester.pump(); // post-frame auto-conta
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Teste QA local');
      await tester.enterText(fields.at(1), '50,00');
      await settle(tester);

      // Picker de categoria: toca no hint / campo
      final catPicker = find.textContaining('Selecione');
      if (catPicker.evaluate().isNotEmpty) {
        await tester.tap(catPicker.first);
        await tester.pumpAndSettle();
      }
      final material = find.text('Material');
      if (material.evaluate().isNotEmpty) {
        await tester.tap(material.last);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Não pago'));
      await settle(tester);

      final saveTooltip = find.byTooltip('Salvar');
      expect(saveTooltip, findsOneWidget);
      await tester.tap(saveTooltip);
      await tester.pumpAndSettle();

      expect(fake.createLancCount, greaterThan(0),
          reason: 'save deve chamar createLancamento');
      final body = fake.lastCreateLanc!;
      expect(body['data'], body['vencimento']);
      expect(body['status'], 'pendente');
      expect(body['descricao'], 'Teste QA local');
    },
  );
}
