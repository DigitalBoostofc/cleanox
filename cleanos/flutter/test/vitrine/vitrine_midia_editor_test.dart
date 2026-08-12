import 'package:cleanos/vitrine/admin/vitrine_admin_screens.dart';
import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mídia pode ser vinculada a serviço como par antes/depois', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    Map<String, dynamic>? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VitrineMidiaEditorDialog(
            existing: null,
            servicos: const [
              VitrineAdminServico(
                id: 'svc1',
                nome: 'Sofá 3 lugares',
                grupo: 'sofa',
                valorBase: 180,
                vitrine: true,
                vitrineDestaque: false,
                ativo: true,
              ),
            ],
            onSave:
                ({
                  required chave,
                  required titulo,
                  required urlExterna,
                  required ordem,
                  required ativo,
                  required servicoId,
                  required papel,
                  required parId,
                  required legenda,
                  required focoX,
                  required focoY,
                  fileBytes,
                  filename,
                }) async {
                  captured = {
                    'chave': chave,
                    'servico': servicoId,
                    'papel': papel,
                    'par_id': parId,
                    'legenda': legenda,
                    'foco_x': focoX,
                    'foco_y': focoY,
                  };
                },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Global: hero, categoria ou oferta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sofá 3 lugares').last);
    await tester.pumpAndSettle();

    expect(find.text('Papel visual'), findsOneWidget);
    expect(find.byKey(const Key('vitrine-midia-legenda')), findsOneWidget);
    expect(find.text('Foco horizontal'), findsOneWidget);
    expect(find.text('Foco vertical'), findsOneWidget);

    await tester.tap(find.text('Capa principal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antes').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vitrine-midia-par')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('vitrine-midia-par')),
      'sofa-sala-1',
    );
    await tester.enterText(
      find.byKey(const Key('vitrine-midia-legenda')),
      'Manchas no assento',
    );
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(captured?['chave'], 'servico_svc1_antes');
    expect(captured?['servico'], 'svc1');
    expect(captured?['papel'], 'antes');
    expect(captured?['par_id'], 'sofa-sala-1');
    expect(captured?['legenda'], 'Manchas no assento');
  });
}
