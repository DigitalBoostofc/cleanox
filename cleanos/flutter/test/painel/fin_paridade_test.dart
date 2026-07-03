/// fin_paridade_test.dart — Testes de paridade Flutter↔React para:
/// • CategoriaForm: seletor mãe (reparent/promote/herança de tipo), ícone
///   texto livre (round-trip desconhecido, vazio→'tag'), cor hex + presets.
/// • FinLimitesScreen: aceita 0, rejeita negativo/vazio, card "Limite zerado".
library;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/categorias/categoria_form.dart';
import 'package:cleanos/painel/financeiro/fin_limites_screen.dart';
import 'package:cleanos/painel/financeiro/fin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda4.dart';
import 'painel_test_helpers.dart';

// ─── helpers ────────────────────────────────────────────────────────────────

List<Override> _withFin(FakeFinanceiro fake) => [
  ...painelOverrides(user: painelUser()),
  financeiroRepositoryProvider.overrideWithValue(fake),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Monta o CategoriaForm diretamente dentro de um Dialog.
Future<void> _pumpForm(
  WidgetTester tester, {
  required FakeFinanceiro fake,
  FinCategoria? editing,
  FinCategoria? parent,
  List<FinCategoria> parents = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _withFin(fake),
      child: MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
              child: CategoriaForm(
                editing: editing,
                parent: parent,
                parents: parents,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// ─── main ────────────────────────────────────────────────────────────────────

void main() {
  // ─── CategoriaForm: seletor de mãe ────────────────────────────────────────

  group('CategoriaForm — seletor de mãe', () {
    final catA = fakeCategoria(
      id: 'a',
      nome: 'Alimentos',
      tipo: TipoLancamento.despesa,
    );
    final catB = fakeCategoria(
      id: 'b',
      nome: 'Beleza',
      tipo: TipoLancamento.despesa,
    );
    final catC = fakeCategoria(
      id: 'c',
      nome: 'Clientes',
      tipo: TipoLancamento.receita,
    );

    testWidgets(
      'mães elegíveis: B despesa aparece; A (self) e C (tipo errado) não',
      (tester) async {
        final fake = FakeFinanceiro(categorias: [catA, catB, catC]);
        // Editando catA (despesa raiz) → elegível = catB apenas.
        await _pumpForm(
          tester,
          fake: fake,
          editing: catA,
          parents: [catA, catB, catC],
        );

        // Abre o dropdown de mãe.
        await tester.tap(find.text('Nenhuma (categoria principal)'));
        await tester.pumpAndSettle();

        // 'Beleza' deve aparecer como opção.
        expect(find.text('Beleza'), findsWidgets);
        // 'Alimentos' (self) e 'Clientes' (receita) não devem aparecer no menu.
        final menuItems = find.descendant(
          of: find.byType(Material).last,
          matching: find.byType(DropdownMenuItem<String>),
        );
        expect(
          find.descendant(
            of: menuItems,
            matching: find.text('Alimentos'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: menuItems,
            matching: find.text('Clientes'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'herda tipo ao selecionar mãe + dropdown Natureza desabilitado',
      (tester) async {
        final fake = FakeFinanceiro(categorias: [catA, catB, catC]);
        await _pumpForm(
          tester,
          fake: fake,
          parents: [catA, catB, catC],
        );

        // Seleciona catB (despesa) como mãe.
        await tester.tap(find.text('Nenhuma (categoria principal)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beleza'));
        await tester.pumpAndSettle();

        // Hint de herança deve aparecer.
        expect(
          find.text('A subcategoria herda o tipo da categoria-mãe.'),
          findsOneWidget,
        );

        // Dropdown de Natureza deve estar desabilitado.
        final tipoDropdown =
            tester.widget<DropdownButtonFormField<TipoLancamento>>(
          find.byType(DropdownButtonFormField<TipoLancamento>),
        );
        expect(tipoDropdown.onChanged, isNull);
      },
    );

    testWidgets('reparent: editar sub de A → salva com parent_id = B', (
      tester,
    ) async {
      final sub = fakeCategoria(
        id: 'sub',
        nome: 'Sub',
        parentId: 'a',
        tipo: TipoLancamento.despesa,
      );
      final fake = FakeFinanceiro(categorias: [catA, catB, catC, sub]);

      await _pumpForm(
        tester,
        fake: fake,
        editing: sub,
        parents: [catA, catB, catC],
      );

      // Muda pai de A → B.
      await tester.tap(find.text('Alimentos')); // valor atual
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beleza'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(fake.lastUpdateCategoria?['parent_id'], 'b');
    });

    testWidgets('promote: sub → Nenhuma → parent_id null no save', (
      tester,
    ) async {
      final sub = fakeCategoria(
        id: 'sub',
        nome: 'Sub',
        parentId: 'a',
        tipo: TipoLancamento.despesa,
      );
      final fake = FakeFinanceiro(categorias: [catA, catB, catC, sub]);

      await _pumpForm(
        tester,
        fake: fake,
        editing: sub,
        parents: [catA, catB, catC],
      );

      // Abre dropdown (mostra 'Alimentos' — pai atual) e seleciona "Nenhuma".
      await tester.tap(find.text('Alimentos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nenhuma (categoria principal)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(fake.lastUpdateCategoria?['parent_id'], isNull);
    });
  });

  // ─── CategoriaForm: ícone texto livre ─────────────────────────────────────

  group('CategoriaForm — ícone', () {
    testWidgets(
      'ícone desconhecido "spray-can" é preservado no save sem tocar',
      (tester) async {
        final cat = fakeCategoria(id: 'x', nome: 'Cat').copyWith(icone: 'spray-can');
        final fake = FakeFinanceiro(categorias: [cat]);

        await _pumpForm(tester, fake: fake, editing: cat);

        await tester.tap(find.text('Salvar'));
        await tester.pump();

        expect(fake.lastUpdateCategoria?['icone'], 'spray-can');
      },
    );

    testWidgets('ícone vazio → "tag" no save', (tester) async {
      final fake = FakeFinanceiro();

      await _pumpForm(tester, fake: fake);

      // Limpa o campo de ícone.
      final iconeField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ex.: spray-can, truck, home',
      );
      await tester.enterText(iconeField, '');
      await tester.pump();

      // Preenche nome obrigatório.
      final nomeField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ex.: Marketing, Salários, Vendas',
      );
      await tester.enterText(nomeField, 'Nova');
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(fake.lastCreateCategoria?['icone'], 'tag');
    });

    testWidgets('clicar tile de preset preenche campo de ícone', (tester) async {
      final fake = FakeFinanceiro();

      await _pumpForm(tester, fake: fake);

      // Toca no tile de 'cash' (ícone payments_outlined).
      await tester.tap(find.byIcon(Icons.payments_outlined));
      await tester.pump();

      final iconeField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ex.: spray-can, truck, home',
      );
      expect(tester.widget<TextField>(iconeField).controller?.text, 'cash');
    });
  });

  // ─── CategoriaForm: cor hex + presets ─────────────────────────────────────

  group('CategoriaForm — cor', () {
    testWidgets(
      'cor desconhecida "#AABBCC" é preservada no save sem tocar',
      (tester) async {
        final cat = fakeCategoria(id: 'x', nome: 'Cat').copyWith(cor: '#AABBCC');
        final fake = FakeFinanceiro(categorias: [cat]);

        await _pumpForm(tester, fake: fake, editing: cat);

        await tester.tap(find.text('Salvar'));
        await tester.pump();

        expect(fake.lastUpdateCategoria?['cor'], '#AABBCC');
      },
    );

    testWidgets('digitar "#FF0000" no campo atualiza cor no save', (
      tester,
    ) async {
      final fake = FakeFinanceiro();

      await _pumpForm(tester, fake: fake);

      final corField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '#0E9F9C',
      );
      await tester.enterText(corField, '#FF0000');
      await tester.pump();

      final nomeField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ex.: Marketing, Salários, Vendas',
      );
      await tester.enterText(nomeField, 'Nova');
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(fake.lastCreateCategoria?['cor'], '#FF0000');
    });

    testWidgets('clicar preset "#22C55E" atualiza campo hex', (tester) async {
      final fake = FakeFinanceiro();

      await _pumpForm(tester, fake: fake);

      final corField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '#0E9F9C',
      );

      // kPresetCores[3] == '#22C55E' — achamos todos os swatches (círculos) e pegamos o índice 3.
      final swatches = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      await tester.ensureVisible(swatches.at(3));
      await tester.tap(swatches.at(3));
      await tester.pump();

      expect(
        tester.widget<TextField>(corField).controller?.text,
        '#22C55E',
      );
    });
  });

  // ─── Limites: validação e card ─────────────────────────────────────────────

  group('Limites — validação e card', () {
    List<Override> withFin(FakeFinanceiro fake) => [
      ...painelOverrides(user: painelUser()),
      financeiroRepositoryProvider.overrideWithValue(fake),
    ];

    testWidgets('aceita valor 0: upsert chamado sem erro', (tester) async {
      final cat = fakeCategoria(id: 'cat', nome: 'Material');
      final fake = FakeFinanceiro(categorias: [cat]);

      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(fake),
      );
      await _settle(tester);

      await tester.tap(find.text('Novo limite').first);
      await tester.pumpAndSettle();

      // Seleciona categoria.
      await tester.tap(find.text('Selecione…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Material'));
      await tester.pumpAndSettle();

      // Digita 0.
      final valorField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0,00',
      );
      await tester.enterText(valorField, '0');
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Informe um teto válido'), findsNothing);
      expect(fake.upsertLimiteCount, 1);
      expect(
        (fake.lastUpsertLimiteData?['limite'] as num?)?.toDouble(),
        0.0,
      );
    });

    testWidgets('rejeita valor negativo', (tester) async {
      final cat = fakeCategoria(id: 'cat', nome: 'Material');
      final fake = FakeFinanceiro(categorias: [cat]);

      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(fake),
      );
      await _settle(tester);

      await tester.tap(find.text('Novo limite').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Selecione…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Material'));
      await tester.pumpAndSettle();

      final valorField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0,00',
      );
      await tester.enterText(valorField, '-10');
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Informe um teto válido'), findsOneWidget);
      expect(fake.upsertLimiteCount, 0);
    });

    testWidgets('rejeita campo de valor vazio', (tester) async {
      final cat = fakeCategoria(id: 'cat', nome: 'Material');
      final fake = FakeFinanceiro(categorias: [cat]);

      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(fake),
      );
      await _settle(tester);

      await tester.tap(find.text('Novo limite').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Selecione…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Material'));
      await tester.pumpAndSettle();

      // Não digita nada → campo vazio.
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Informe um teto válido'), findsOneWidget);
      expect(fake.upsertLimiteCount, 0);
    });

    testWidgets(
      'card com limite 0 exibe "Limite zerado" e sem LinearProgressIndicator',
      (tester) async {
        final cat = fakeCategoria(id: 'cat', nome: 'Material');
        final fake = FakeFinanceiro(
          categorias: [cat],
          limites: [fakeLimite(id: 'l', categoriaId: 'cat', limite: 0)],
        );

        await pumpPainel(
          tester,
          const FinLimitesScreen(),
          overrides: withFin(fake),
        );
        await _settle(tester);

        expect(find.text('Limite zerado'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );
  });
}
