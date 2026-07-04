/// checklist_execucao_test.dart — Widget compartilhado ChecklistExecucao:
/// marcar um item alterna para concluído e grava concluidoEm/concluidoPor.
///
/// QA-F5: a caixa de marcação custom (commit caf2ed1) só pode aparecer no APK
/// fintech — a Web precisa continuar com o `Checkbox` Material de sempre
/// (mesmo padrão de gate do `EmptyState`: `Consumer` + `isFintechCleanProvider`,
/// default `false`).
library;

import 'package:cleanos/app.dart';
import 'package:cleanos/core/design/app_surface_provider.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/shared_widgets_os/checklist_execucao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<ChecklistExecItem> items,
  required ValueChanged<List<ChecklistExecItem>> onChange,
  bool fintech = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (fintech) appSurfaceProvider.overrideWithValue(AppSurface.android),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ChecklistExecucao(
            items: items,
            concluidoPor: 'Pedro',
            nowIso: () => '2026-07-01 10:00:00Z',
            onChange: onChange,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('marcar um item o conclui com carimbo de data/autor', (
    tester,
  ) async {
    var items = const [
      ChecklistExecItem(id: 'c1', titulo: 'Aspirar'),
      ChecklistExecItem(id: 'c2', titulo: 'Enxaguar'),
    ];
    List<ChecklistExecItem>? emitido;

    await _pump(tester, items: items, onChange: (v) => emitido = v);

    expect(find.text('0 de 2 concluídos'), findsOneWidget);

    // O alvo de toque é achado pela `Key` do item — estável nos dois ramos
    // (Web/Checkbox Material e APK fintech/caixa custom).
    await tester.tap(find.byKey(const ValueKey('checklist-toggle-c1')));
    await tester.pump();

    expect(emitido, isNotNull);
    final c1 = emitido!.firstWhere((i) => i.id == 'c1');
    expect(c1.concluido, isTrue);
    expect(c1.concluidoEm, '2026-07-01 10:00:00Z');
    expect(c1.concluidoPor, 'Pedro');
    // O outro item não muda.
    expect(emitido!.firstWhere((i) => i.id == 'c2').concluido, isFalse);
  });

  testWidgets('checklist vazio mostra estado vazio', (tester) async {
    await _pump(tester, items: const [], onChange: (_) {});
    expect(find.text('Checklist vazio'), findsOneWidget);
  });

  testWidgets(
    'Web (sem override): caixa de marcação é o Checkbox Material de sempre',
    (tester) async {
      const items = [ChecklistExecItem(id: 'c1', titulo: 'Aspirar')];
      await _pump(tester, items: items, onChange: (_) {});

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byKey(const ValueKey('checklist-toggle-c1')), findsOneWidget);
    },
  );

  testWidgets(
    'Fintech Clean (APK): caixa de marcação custom substitui o Checkbox',
    (tester) async {
      const items = [ChecklistExecItem(id: 'c1', titulo: 'Aspirar')];
      await _pump(tester, items: items, onChange: (_) {}, fintech: true);

      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const ValueKey('checklist-toggle-c1')), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsOneWidget);
    },
  );
}
