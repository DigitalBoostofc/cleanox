/// fin_repetir_form_test.dart — Painel "Repetir" estilo Organizze no form.
library;

import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/lancamentos/lancamento_form.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  List<Override> withFin(FakeFinanceiro fake) => [
        ...painelOverrides(user: painelUser()),
        financeiroRepositoryProvider.overrideWithValue(fake),
      ];

  testWidgets(
    'tocar Repetir revela opções fixa e parcelado (Organizze)',
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

      // Painel fechado por padrão.
      expect(find.textContaining('é uma despesa fixa'), findsNothing);
      expect(find.textContaining('parcelado'), findsNothing);

      await tester.tap(find.text('Repetir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('é uma despesa fixa'), findsOneWidget);
      expect(
        find.textContaining('é um lançamento parcelado em'),
        findsOneWidget,
      );
      // Default: fixa → dropdown de frequência singular (Mensal).
      expect(find.text('Mensal'), findsOneWidget);

      // Alterna para parcelado.
      await tester.tap(find.textContaining('é um lançamento parcelado em'));
      await tester.pumpAndSettle();

      expect(find.text('Meses'), findsOneWidget);
      // Contador default 2.
      expect(find.text('2'), findsWidgets);
    },
  );

  testWidgets(
    'em Nova receita o rótulo diz "é uma receita fixa"',
    (tester) async {
      await pumpPainel(
        tester,
        const LancamentoForm(initialTipo: TipoLancamento.receita),
        overrides: withFin(
          FakeFinanceiro(
            contas: [fakeConta(id: 'c', nome: 'Caixa')],
            categorias: [
              fakeCategoria(
                id: 'r',
                nome: 'Vendas',
                tipo: TipoLancamento.receita,
              ),
            ],
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Repetir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('é uma receita fixa'), findsOneWidget);
    },
  );
}
