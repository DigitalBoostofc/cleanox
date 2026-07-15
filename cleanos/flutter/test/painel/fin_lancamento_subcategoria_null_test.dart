/// fin_lancamento_subcategoria_null_test.dart — Regressão (review, 04/07): mesmo
/// bug "" vs null do `parent_id` de `FinCategoria` (05e2388), aqui em
/// `subcategoria_id` de `FinLancamento`. `subcategoria_id` é um RelationField
/// OPCIONAL (migration 14) — o PocketBase grava relação vazia como `""`, nunca
/// `null`. O form usa [FinCategoriaTreePicker] unificado; sem normalizar no
/// `fromRecord`, a seleção falha ao editar lançamento sem subcategoria.
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:cleanos/painel/financeiro/lancamentos/lancamento_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

void main() {
  testWidgets(
    'editar lançamento sem subcategoria (subcategoria_id="" do PocketBase) '
    'não crasha o picker unificado',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // O shape exato que o PocketBase devolve: subcategoria_id vazio como
      // "" (RelationField opcional), nunca null. Passa pelo `fromRecord` de
      // verdade — é o boundary que precisa normalizar.
      final lanc = FinLancamento.fromRecord(
        RecordModel.fromJson({
          'id': 'l1',
          'tipo': 'despesa',
          'descricao': 'Combustível',
          'categoria_id': 'cat1',
          'subcategoria_id': '',
          'valor': 100,
          'conta_id': 'conta1',
          'data': '2026-07-01 12:00:00.000Z',
          'status': 'pago',
          'recorrencia': 'unica',
          'origem': 'manual',
        }),
      );

      final fake = FakeFinanceiro(
        contas: [fakeConta(id: 'conta1', nome: 'Caixa')],
        categorias: [
          fakeCategoria(id: 'cat1', nome: 'Transporte'),
          fakeCategoria(
            id: 'sub1',
            nome: 'Combustível',
            parentId: 'cat1',
          ),
        ],
        lancamentos: [lanc],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...painelOverrides(user: painelUser()),
            financeiroRepositoryProvider.overrideWithValue(fake),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: Dialog(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 620,
                    maxHeight: 780,
                  ),
                  child: LancamentoForm(editing: lanc),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(LancamentoForm), findsOneWidget);
      // Picker unificado mostra a categoria-raiz (sem "— Nenhuma").
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.byKey(const ValueKey('fin-categoria-tree-picker')), findsOneWidget);
    },
  );
}
