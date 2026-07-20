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
  bool readOnly = false,
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
            readOnly: readOnly,
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
      // Escopado ao alvo de toque: o casco (ClxCard com press-scale) também
      // usa AnimatedContainer, então o byType global seria ambíguo.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('checklist-toggle-c1')),
          matching: find.byType(AnimatedContainer),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tocar no NOME do item também alterna (pedido do dono 16/07 — antes só a caixinha)',
    (tester) async {
      const items = [ChecklistExecItem(id: 'c1', titulo: 'Aspirar')];
      List<ChecklistExecItem>? emitido;

      await _pump(tester, items: items, onChange: (v) => emitido = v);

      await tester.tap(find.text('Aspirar'));
      await tester.pump();

      expect(emitido, isNotNull);
      expect(emitido!.single.concluido, isTrue);
      expect(emitido!.single.concluidoPor, 'Pedro');
    },
  );

  testWidgets(
    'readOnly (OS concluída): nem caixinha nem nome alternam, sem botão de observação',
    (tester) async {
      const items = [ChecklistExecItem(id: 'c1', titulo: 'Aspirar')];
      List<ChecklistExecItem>? emitido;

      await _pump(
        tester,
        items: items,
        onChange: (v) => emitido = v,
        readOnly: true,
      );

      await tester.tap(find.byKey(const ValueKey('checklist-toggle-c1')));
      await tester.tap(find.text('Aspirar'), warnIfMissed: false);
      await tester.pump();

      expect(emitido, isNull);
      expect(find.byTooltip('Adicionar observação'), findsNothing);
    },
  );

  group('faseFotoExigida / checklistItemPodeConcluir', () {
    test('detecta fotos de antes e depois pelo título', () {
      expect(
        faseFotoExigida(const ChecklistExecItem(id: '1', titulo: 'Fotos de antes')),
        FaseFoto.antes,
      );
      expect(
        faseFotoExigida(
          const ChecklistExecItem(id: '2', titulo: 'Sofá 2 lugares: Fotos de depois'),
        ),
        FaseFoto.depois,
      );
      expect(
        faseFotoExigida(const ChecklistExecItem(id: '3', titulo: 'Aspirar')),
        isNull,
      );
    });

    test('só libera check com foto vinculada ao item', () {
      const item = ChecklistExecItem(id: 'cke1', titulo: 'Fotos de antes');
      expect(checklistItemPodeConcluir(item, const []), isFalse);
      expect(
        checklistItemPodeConcluir(item, const [
          EvidenciaFoto(
            id: 'f1',
            fase: FaseFoto.antes,
            checklistItemId: 'cke1',
          ),
        ]),
        isTrue,
      );
      // foto de outra fase/item não conta
      expect(
        checklistItemPodeConcluir(item, const [
          EvidenciaFoto(
            id: 'f2',
            fase: FaseFoto.antes,
            checklistItemId: 'outro',
          ),
        ]),
        isFalse,
      );
    });
  });

  group('agruparChecklistSecoes', () {
    test('principal e extra ficam em seções distintas', () {
      const principal = [
        ChecklistExecItem(id: 'p1', titulo: 'Aspirar'),
        ChecklistExecItem(id: 'p2', titulo: 'Enxaguar'),
      ];
      const extra = [
        ChecklistExecItem(
          id: 'e1',
          titulo: 'Fotos de antes',
          adicionalId: 'add1',
        ),
        ChecklistExecItem(
          id: 'e2',
          titulo: 'Higienização',
          adicionalId: 'add1',
        ),
      ];
      const adicionais = [
        ServicoAdicionalOS(id: 'add1', nome: 'Sofá 2 lugares', valor: 300),
      ];
      final secoes = agruparChecklistSecoes(
        [...principal, ...extra],
        adicionais: adicionais,
      );
      expect(secoes, hasLength(2));
      expect(secoes[0].key, 'principal');
      expect(secoes[0].items.map((e) => e.id), ['p1', 'p2']);
      expect(secoes[1].extra, isTrue);
      expect(secoes[1].titulo, 'Sofá 2 lugares');
      expect(secoes[1].items.map((e) => e.id), ['e1', 'e2']);
    });

    test('legado "Nome: item" agrupa pelo nome do adicional', () {
      const items = [
        ChecklistExecItem(id: 'p1', titulo: 'Aspirar'),
        ChecklistExecItem(
          id: 'e1',
          titulo: 'Sofá 2 lugares: Fotos de antes',
        ),
      ];
      const adicionais = [
        ServicoAdicionalOS(id: 'add1', nome: 'Sofá 2 lugares'),
      ];
      final secoes = agruparChecklistSecoes(items, adicionais: adicionais);
      expect(secoes, hasLength(2));
      expect(secoes[1].items.single.id, 'e1');
      expect(
        tituloChecklistExibicao(secoes[1].items.single, secaoTitulo: 'Sofá 2 lugares'),
        'Fotos de antes',
      );
    });
  });

  testWidgets('UI mostra cabeçalho de serviço extra separado', (tester) async {
    await _pump(
      tester,
      items: const [
        ChecklistExecItem(id: 'p1', titulo: 'Aspirar'),
        ChecklistExecItem(
          id: 'e1',
          titulo: 'Fotos de antes',
          adicionalId: 'add1',
        ),
      ],
      onChange: (_) {},
    );
    // _pump doesn't pass adicionais — re-pump with them.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ChecklistExecucao(
              items: const [
                ChecklistExecItem(id: 'p1', titulo: 'Aspirar'),
                ChecklistExecItem(
                  id: 'e1',
                  titulo: 'Fotos de antes',
                  adicionalId: 'add1',
                ),
              ],
              adicionais: const [
                ServicoAdicionalOS(id: 'add1', nome: 'Sofá 2 lugares'),
              ],
              onChange: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Serviço principal'), findsOneWidget);
    expect(find.text('Sofá 2 lugares'), findsOneWidget);
    expect(find.text('Serviço extra'), findsWidgets);
    expect(find.text('Fotos de antes'), findsOneWidget);
    expect(find.text('Aspirar'), findsOneWidget);
  });
}
