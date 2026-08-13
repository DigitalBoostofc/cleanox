import 'package:cleanos/vitrine/admin/vitrine_admin_screens.dart';
import 'package:cleanos/vitrine/admin/vitrine_midia_repository.dart';
import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

class _FakeMidiaRepo extends VitrineMidiaRepository {
  _FakeMidiaRepo() : super(PocketBase('http://127.0.0.1'));

  @override
  Future<List<VitrineMidiaItem>> listByServico(String servicoId) async =>
      const [];
}

void main() {
  const servico = VitrineAdminServico(
    id: 'svc1',
    nome: 'Sofá 3 lugares',
    grupo: 'sofa',
    categoria: 'residencial',
    valorBase: 180,
    vitrine: true,
    vitrineDestaque: false,
    ativo: true,
  );

  testWidgets('editor exibe controles e preview do catálogo', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VitrineServicoEditorDialog(
            servico: servico,
            midiaRepo: _FakeMidiaRepo(),
            onSave: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Personalizar serviço'), findsOneWidget);
    expect(find.text('Formato visual'), findsOneWidget);
    expect(find.text('Preço na vitrine'), findsOneWidget);
    expect(find.byKey(const Key('vitrine-servico-titulo')), findsOneWidget);
    expect(find.byKey(const Key('vitrine-servico-descricao')), findsOneWidget);
    expect(find.byKey(const Key('vitrine-servico-badge')), findsOneWidget);
    expect(find.byKey(const Key('vitrine-servico-cta')), findsOneWidget);
    expect(find.byKey(const Key('vitrine-servico-ordem')), findsOneWidget);
    expect(find.byKey(const Key('vitrine-servico-preview')), findsOneWidget);
  });

  testWidgets('editor salva rascunho comercial e não estoura no mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    Map<String, dynamic>? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VitrineServicoEditorDialog(
            servico: servico,
            midiaRepo: _FakeMidiaRepo(),
            onSave: (draft) async => captured = draft,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('vitrine-servico-titulo')),
      'Sofá renovado',
    );
    await tester.enterText(
      find.byKey(const Key('vitrine-servico-badge')),
      'Mais escolhido',
    );
    await tester.ensureVisible(find.text('Salvar personalização'));
    await tester.tap(find.text('Salvar personalização'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(captured?['vitrine_titulo'], 'Sofá renovado');
    expect(captured?['vitrine_badge'], 'Mais escolhido');
    expect(captured?['vitrine_layout'], 'fotografico');
    expect(captured?['vitrine_preco_modo'], 'a_partir_de');
  });
}
