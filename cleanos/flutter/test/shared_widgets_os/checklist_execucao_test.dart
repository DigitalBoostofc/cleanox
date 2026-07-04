/// checklist_execucao_test.dart — Widget compartilhado ChecklistExecucao:
/// marcar um item alterna para concluído e grava concluidoEm/concluidoPor.
library;

import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/shared_widgets_os/checklist_execucao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('marcar um item o conclui com carimbo de data/autor', (
    tester,
  ) async {
    var items = const [
      ChecklistExecItem(id: 'c1', titulo: 'Aspirar'),
      ChecklistExecItem(id: 'c2', titulo: 'Enxaguar'),
    ];
    List<ChecklistExecItem>? emitido;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ChecklistExecucao(
            items: items,
            concluidoPor: 'Pedro',
            nowIso: () => '2026-07-01 10:00:00Z',
            onChange: (v) => emitido = v,
          ),
        ),
      ),
    );

    expect(find.text('0 de 2 concluídos'), findsOneWidget);

    // Marca o primeiro item (reskin Fintech Clean trocou o `Checkbox` do
    // Material por uma caixa de marcação custom — o alvo de toque agora é
    // achado pela `Key` do item, não mais por tipo).
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
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ChecklistExecucao(items: const [], onChange: (_) {}),
        ),
      ),
    );
    expect(find.text('Checklist vazio'), findsOneWidget);
  });
}
