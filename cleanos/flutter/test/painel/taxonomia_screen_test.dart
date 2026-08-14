/// taxonomia_screen_test.dart — Engrenagem Categoria → Grupo → Serviço.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/servicos/servico_editor.dart';
import 'package:cleanos/painel/servicos/taxonomia/servicos_taxonomia_screen.dart';
import 'package:cleanos/painel/servicos/taxonomia/taxonomia_models.dart';
import 'package:cleanos/painel/servicos/taxonomia/taxonomia_providers.dart';
import 'package:cleanos/painel/servicos/taxonomia/taxonomia_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'fakes_onda3.dart';
import 'painel_test_helpers.dart';

TaxonomiaArvore _arvoreProduto() => TaxonomiaArvore(const [
      TaxonomiaNo(
        id: 'c1',
        tipo: TaxonomiaTipo.categoria,
        slug: 'residencial',
        nome: 'Residencial',
        parent: '',
        ordem: 1,
        ativo: true,
      ),
      TaxonomiaNo(
        id: 'g1',
        tipo: TaxonomiaTipo.grupo,
        slug: 'sofa',
        nome: 'Sofá',
        parent: 'c1',
        ordem: 1,
        ativo: true,
      ),
      TaxonomiaNo(
        id: 'g3',
        tipo: TaxonomiaTipo.grupo,
        slug: 'colchao',
        nome: 'Colchão',
        parent: 'c1',
        ordem: 2,
        ativo: true,
      ),
      TaxonomiaNo(
        id: 'c2',
        tipo: TaxonomiaTipo.categoria,
        slug: 'veicular',
        nome: 'Veicular',
        parent: '',
        ordem: 2,
        ativo: true,
      ),
      TaxonomiaNo(
        id: 'g2',
        tipo: TaxonomiaTipo.grupo,
        slug: 'plano',
        nome: 'Plano',
        parent: 'c2',
        ordem: 1,
        ativo: true,
      ),
      TaxonomiaNo(
        id: 'sg1',
        tipo: TaxonomiaTipo.subgrupo,
        slug: 'premium',
        nome: 'Premium legado',
        parent: 'g1',
        ordem: 1,
        ativo: true,
      ),
    ]);

class _FakeTaxonomiaRepository extends TaxonomiaRepository {
  _FakeTaxonomiaRepository() : super(PocketBase('http://127.0.0.1:9'));

  final Map<String, int> ordensSalvas = {};
  final List<({String kind, List<String> ids})> reorders = [];

  @override
  Future<void> reorderCatalog({
    required String kind,
    required List<String> ids,
  }) async {
    reorders.add((kind: kind, ids: [...ids]));
  }

  @override
  Future<TaxonomiaNo> update(
    String id, {
    String? nome,
    String? slug,
    int? ordem,
    bool? ativo,
    String? parent,
  }) async {
    if (ordem != null) ordensSalvas[id] = ordem;
    return _arvoreProduto().byId(id)!;
  }
}

List<Override> _overrides(
  FakeServicosFull repo, {
  TaxonomiaRepository? taxonomiaRepo,
}) => [
      ...painelOverrides(user: painelUser()),
      pocketBaseProvider.overrideWithValue(PocketBase('http://127.0.0.1:9')),
      servicosRepositoryProvider.overrideWithValue(repo),
      if (taxonomiaRepo != null)
        taxonomiaRepositoryProvider.overrideWithValue(taxonomiaRepo),
      taxonomiaArvoreProvider.overrideWith((ref) async => _arvoreProduto()),
    ];

void main() {
  group('ServicosTaxonomiaScreen', () {
    testWidgets('arrastar categoria persiste a nova sequência', (tester) async {
      final servicos = FakeServicosFull();
      final taxonomia = _FakeTaxonomiaRepository();
      await pumpPainel(
        tester,
        const ServicosTaxonomiaScreen(),
        size: const Size(1800, 1000),
        overrides: _overrides(servicos, taxonomiaRepo: taxonomia),
      );
      await tester.pumpAndSettle();

      final lista = find.descendant(
        of: find.byKey(const Key('taxonomia-col-categorias')),
        matching: find.byType(ReorderableListView),
      );
      expect(lista, findsOneWidget);
      expect(
        find.descendant(
          of: lista,
          matching: find.byType(ReorderableDelayedDragStartListener),
        ),
        findsNWidgets(2),
      );

      tester.widget<ReorderableListView>(lista).onReorder(1, 0);
      await tester.pumpAndSettle();

      expect(taxonomia.reorders.single.kind, 'taxonomia');
      expect(taxonomia.reorders.single.ids, ['c2', 'c1']);
    });

    testWidgets('arrastar grupo persiste uma sequência atômica do pai',
        (tester) async {
      final servicos = FakeServicosFull();
      final taxonomia = _FakeTaxonomiaRepository();
      await pumpPainel(
        tester,
        const ServicosTaxonomiaScreen(),
        size: const Size(1800, 1000),
        overrides: _overrides(servicos, taxonomiaRepo: taxonomia),
      );
      await tester.pumpAndSettle();

      final lista = find.descendant(
        of: find.byKey(const Key('taxonomia-col-grupos')),
        matching: find.byType(ReorderableListView),
      );
      expect(lista, findsOneWidget);

      tester.widget<ReorderableListView>(lista).onReorder(1, 0);
      await tester.pumpAndSettle();

      expect(taxonomia.reorders.single.kind, 'taxonomia');
      expect(taxonomia.reorders.single.ids, ['g3', 'g1']);
    });

    testWidgets('arrastar serviço persiste a nova sequência do grupo',
        (tester) async {
      final servicos = FakeServicosFull(
        seed: [
          fakeServico(id: 'svc1', nome: 'Primeiro', ordem: 10),
          fakeServico(id: 'svc2', nome: 'Segundo', ordem: 20),
        ],
      );
      final taxonomia = _FakeTaxonomiaRepository();
      await pumpPainel(
        tester,
        const ServicosTaxonomiaScreen(),
        size: const Size(1800, 1000),
        overrides: _overrides(servicos, taxonomiaRepo: taxonomia),
      );
      await tester.pumpAndSettle();

      final lista = find.descendant(
        of: find.byKey(const Key('taxonomia-col-servicos')),
        matching: find.byType(ReorderableListView),
      );
      expect(lista, findsOneWidget);

      tester.widget<ReorderableListView>(lista).onReorder(1, 0);
      await tester.pumpAndSettle();

      expect(taxonomia.reorders.single.kind, 'servicos');
      expect(taxonomia.reorders.single.ids, ['svc2', 'svc1']);
    });

    testWidgets('mobile empilha as três áreas em cards, sem tabela',
        (tester) async {
      final repo = FakeServicosFull(
        seed: [
          fakeServico(
            id: 'svc1',
            nome: 'Sofá 3 lugares',
            categoria: 'residencial',
            grupo: 'sofa',
          ),
        ],
      );
      await pumpPainel(
        tester,
        const ServicosTaxonomiaScreen(),
        size: const Size(390, 844),
        overrides: _overrides(repo),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(DataTable), findsNothing);
      expect(find.byKey(const Key('taxonomia-col-servicos')), findsOneWidget);
      expect(find.text('Editar serviço'), findsOneWidget);
      expect(find.text('Subgrupos'), findsNothing);
    });

    testWidgets('terceira coluna lista serviços do grupo, sem CRUD de subgrupo',
        (tester) async {
      final repo = FakeServicosFull(
        seed: [
          fakeServico(
            id: 'svc1',
            nome: 'Sofá 3 lugares',
            categoria: 'residencial',
            grupo: 'sofa',
          ),
          fakeServico(
            id: 'svc2',
            nome: 'Plano Completo',
            categoria: 'veicular',
            grupo: 'plano',
          ),
        ],
      );
      await pumpPainel(
        tester,
        const ServicosTaxonomiaScreen(),
        overrides: _overrides(repo),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Categorias, grupos e serviços'), findsOneWidget);
      expect(find.text('Categorias'), findsOneWidget);
      expect(find.text('Grupos'), findsOneWidget);
      expect(find.text('Serviços'), findsOneWidget);
      expect(find.text('Subgrupos'), findsNothing);
      expect(find.text('Novo subgrupo'), findsNothing);
      expect(find.text('Premium legado'), findsNothing);
      expect(find.byKey(const Key('taxonomia-col-servicos')), findsOneWidget);
      expect(find.text('Sofá 3 lugares'), findsOneWidget);
      expect(find.text('Plano Completo'), findsNothing);
      expect(find.text('Editar serviço'), findsOneWidget);
    });

    testWidgets('Editar serviço abre o editor e atualiza a lista ao voltar',
        (tester) async {
      final repo = FakeServicosFull(
        seed: [
          fakeServico(
            id: 'svc1',
            nome: 'Sofá 3 lugares',
            categoria: 'residencial',
            grupo: 'sofa',
          ),
        ],
      );
      await pumpPainel(
        tester,
        const ServicosTaxonomiaScreen(),
        size: const Size(1800, 1000),
        overrides: _overrides(repo),
      );
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('taxonomia-servico-editar-svc1')),
      );
      await tester.tap(find.byKey(const Key('taxonomia-servico-editar-svc1')));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ServicoEditorScreen), findsOneWidget);
      expect(find.text('Subgrupo'), findsNothing);

      final nomeField = find.widgetWithText(TextField, 'Sofá 3 lugares');
      expect(nomeField, findsOneWidget);
      await tester.enterText(nomeField, 'Sofá 4 lugares');
      await tester.pump();
      final salvar = tester.widget<ClxButton>(
        find.byWidgetPredicate(
          (w) => w is ClxButton && w.label == 'Salvar',
        ),
      );
      salvar.onPressed?.call();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(ServicoEditorScreen), findsNothing);
      expect(find.text('Sofá 4 lugares'), findsOneWidget);
      expect(find.text('Sofá 3 lugares'), findsNothing);
      expect(find.text('Residencial'), findsOneWidget);
      expect(find.text('Sofá'), findsOneWidget);
      expect(find.byKey(const Key('taxonomia-col-servicos')), findsOneWidget);
    });

    testWidgets(
        'Adicionar serviço abre criação com categoria e grupo selecionados',
        (tester) async {
      final repo = FakeServicosFull();
      await pumpPainel(
        tester,
        const ServicosTaxonomiaScreen(),
        size: const Size(1800, 1200),
        overrides: _overrides(repo),
      );
      await tester.pump();
      await tester.pump();

      final adicionar = find.byKey(
        const Key('taxonomia-servico-adicionar'),
      );
      expect(adicionar, findsOneWidget);
      await tester.tap(adicionar);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ServicoEditorScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Sofá novo');
      final salvar = tester.widget<ClxButton>(
        find.byWidgetPredicate(
          (w) => w is ClxButton && w.label == 'Salvar',
        ),
      );
      salvar.onPressed?.call();
      await tester.pump();
      await tester.pump();

      expect(repo.createCount, 1);
      expect(repo.lastCreate?['nome'], 'Sofá novo');
      expect(repo.lastCreate?['categoria'], 'residencial');
      expect(repo.lastCreate?['grupo'], 'sofa');
    });
  });
}
