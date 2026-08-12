import 'package:cleanos/vitrine/admin/vitrine_admin_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mídia do CMS da Vitrine é só global (sem vínculo a serviço)', (
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
            onSave:
                ({
                  required chave,
                  required titulo,
                  required urlExterna,
                  required ordem,
                  required ativo,
                  fileBytes,
                  filename,
                }) async {
                  captured = {
                    'chave': chave,
                    'titulo': titulo,
                    'ordem': ordem,
                    'ativo': ativo,
                  };
                },
          ),
        ),
      ),
    );

    expect(find.textContaining('Global: hero'), findsNothing);
    expect(find.text('Sofá 3 lugares'), findsNothing);
    expect(find.text('Papel visual'), findsNothing);
    expect(find.textContaining('Só mídia global'), findsOneWidget);
    expect(find.textContaining('Serviços → Editar'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Chave').first, 'hero');
    // Chave field already has hero default — set titulo
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Capa hero');
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(captured?['chave'], 'hero');
    expect(captured?['titulo'], 'Capa hero');
    expect(captured?['ativo'], isTrue);
  });
}
