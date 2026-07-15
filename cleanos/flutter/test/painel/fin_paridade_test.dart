/// fin_paridade_test.dart — Testes de paridade para:
/// • CategoriaForm: seletor mãe, alocação automática de ícone/cor,
///   herança de subcategoria.
/// • FinLimitesScreen: aceita 0, rejeita negativo/vazio, card sem limite.
library;

import 'dart:math' show Random;

import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/models/financeiro.dart';
import 'package:cleanos/painel/financeiro/categorias/categoria_form.dart';
import 'package:cleanos/painel/financeiro/fin_labels.dart';
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
          find.text(
            'A subcategoria herda o tipo, o símbolo e a cor da categoria-mãe.',
          ),
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

  // ─── Alocação automática de ícone/cor ────────────────────────────────────

  group('alocarIconeCorCategoria', () {
    test('raiz nova evita ícone e cor já usados', () {
      final existentes = [
        fakeCategoria(id: 'a', nome: 'A', icone: 'tag', cor: '#EF4444'),
        fakeCategoria(id: 'b', nome: 'B', icone: 'cash', cor: '#F97316'),
      ];
      final aloc = alocarIconeCorCategoria(
        existentes: existentes,
        random: Random(42),
      );
      expect(aloc.icone, isNot(anyOf('tag', 'cash')));
      expect(aloc.cor.toUpperCase(), isNot(anyOf('#EF4444', '#F97316')));
      expect(kFinCategoriaIcons.containsKey(aloc.icone), isTrue);
      expect(
        kFinCategoriaCoresPool.map((c) => c.toUpperCase()),
        contains(aloc.cor.toUpperCase()),
      );
    });

    test('subcategoria herda ícone e cor da mãe', () {
      final mae = fakeCategoria(
        id: 'mae',
        nome: 'Mãe',
        icone: 'truck',
        cor: '#3B82F6',
      );
      final aloc = alocarIconeCorCategoria(
        existentes: [mae],
        parentId: 'mae',
      );
      expect(aloc.icone, 'truck');
      expect(aloc.cor, '#3B82F6');
    });

    test('subs não contam para unicidade de raiz', () {
      final mae = fakeCategoria(
        id: 'mae',
        nome: 'Mãe',
        icone: 'tag',
        cor: '#EF4444',
      );
      final sub = fakeCategoria(
        id: 'sub',
        nome: 'Sub',
        parentId: 'mae',
        icone: 'tag',
        cor: '#EF4444',
      );
      // Única raiz usa tag/#EF4444; sub não bloqueia outros slots além da raiz.
      final aloc = alocarIconeCorCategoria(
        existentes: [mae, sub],
        random: Random(1),
      );
      expect(aloc.icone, isNot('tag'));
      expect(aloc.cor.toUpperCase(), isNot('#EF4444'));
    });
  });

  group('CategoriaForm — ícone/cor automáticos', () {
    testWidgets(
      'edição preserva ícone e cor da raiz',
      (tester) async {
        final cat = fakeCategoria(
          id: 'x',
          nome: 'Cat',
          icone: 'spray-can',
          cor: '#AABBCC',
        );
        final fake = FakeFinanceiro(categorias: [cat]);

        await _pumpForm(tester, fake: fake, editing: cat);

        await tester.tap(find.text('Salvar'));
        await tester.pump();

        expect(fake.lastUpdateCategoria?['icone'], 'spray-can');
        expect(fake.lastUpdateCategoria?['cor'], '#AABBCC');
      },
    );

    testWidgets('criar raiz grava ícone e cor do pool', (tester) async {
      final fake = FakeFinanceiro();

      await _pumpForm(tester, fake: fake);

      final nomeField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ex.: Marketing, Salários, Vendas',
      );
      await tester.enterText(nomeField, 'Nova');
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      final icone = fake.lastCreateCategoria?['icone'] as String?;
      final cor = fake.lastCreateCategoria?['cor'] as String?;
      expect(icone, isNotNull);
      expect(icone, isNotEmpty);
      expect(kFinCategoriaIcons.containsKey(icone), isTrue);
      expect(cor, isNotNull);
      expect(cor!.startsWith('#'), isTrue);
      expect(find.textContaining('Gerado automaticamente'), findsOneWidget);
    });

    testWidgets('criar sub herda ícone e cor da mãe', (tester) async {
      final mae = fakeCategoria(
        id: 'mae',
        nome: 'Marketing',
        icone: 'megaphone',
        cor: '#8B5CF6',
      );
      final fake = FakeFinanceiro(categorias: [mae]);

      await _pumpForm(tester, fake: fake, parent: mae, parents: [mae]);

      final nomeField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ex.: Marketing, Salários, Vendas',
      );
      await tester.enterText(nomeField, 'Meta Ads');
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(fake.lastCreateCategoria?['icone'], 'megaphone');
      expect(fake.lastCreateCategoria?['cor'], '#8B5CF6');
      expect(fake.lastCreateCategoria?['parent_id'], 'mae');
      expect(find.textContaining('Mesmo símbolo e cor da mãe'), findsOneWidget);
    });
  });

  // ─── Limites: empty do mês + popover ───────────────────────────────────────

  group('Limites — Organizze', () {
    List<Override> withFin(FakeFinanceiro fake) => [
      ...painelOverrides(user: painelUser()),
      financeiroRepositoryProvider.overrideWithValue(fake),
    ];

    testWidgets('mês vazio mostra Definir e Copiar', (tester) async {
      final cat = fakeCategoria(id: 'cat', nome: 'Material');
      final fake = FakeFinanceiro(categorias: [cat]);

      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(fake),
      );
      await _settle(tester);

      expect(find.textContaining('Nenhum limite de gasto definido'), findsOneWidget);
      expect(find.text('Definir limite de gastos'), findsOneWidget);
      expect(find.text('Copiar os últimos definidos'), findsOneWidget);
    });

    testWidgets('Definir abre árvore; + e Ok gravam limite 0', (tester) async {
      final cat = fakeCategoria(id: 'cat', nome: 'Material');
      final fake = FakeFinanceiro(categorias: [cat]);

      await pumpPainel(
        tester,
        const FinLimitesScreen(),
        overrides: withFin(fake),
      );
      await _settle(tester);

      await tester.tap(find.text('Definir limite de gastos'));
      await tester.pumpAndSettle();

      expect(find.text('Material'), findsOneWidget);
      expect(find.text('despesas'), findsOneWidget);

      // Abre popover no + da linha.
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      final valorField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0,00',
      );
      expect(valorField, findsOneWidget);
      await tester.enterText(valorField, '0');
      await tester.pump();

      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();

      expect(fake.upsertLimiteCount, 1);
      expect(
        (fake.lastUpsertLimiteData?['limite'] as num?)?.toDouble(),
        0.0,
      );
      expect(fake.lastUpsertLimiteData?['categoria_id'], 'cat');
      expect(fake.lastUpsertLimiteData?['ano_mes'], isNotEmpty);
    });

    testWidgets('limite 0 não mostra "X de Y" (sem teto visual)', (tester) async {
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

      expect(find.text('Material'), findsOneWidget);
      // Totais globais: "0,00 de 0,00"; linha da cat sem teto não repete "R$ 0,00 de R$ 0,00".
      expect(find.textContaining('0,00 de 0,00'), findsOneWidget);
      expect(find.textContaining('R\$ 0,00 de R\$ 0,00'), findsNothing);
    });
  });
}

