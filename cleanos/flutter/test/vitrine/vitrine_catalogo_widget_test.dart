import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:cleanos/vitrine/widgets/vitrine_catalogo_personalizavel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

VitrineServico service(
  String id,
  String nome,
  VitrineServicoLayout layout, {
  String grupo = 'sofa',
  String cta = '',
  String? descricao,
}) => VitrineServico(
  id: id,
  nome: nome,
  descricao: descricao ?? 'Descrição de $nome',
  categoria: '',
  grupo: grupo,
  valorBase: 180,
  valorBaseMax: 0,
  tempoMedioMin: 90,
  tempoMedioLabel: '1h30',
  orientacoesPre: '',
  layout: layout,
  vitrineCta: cta,
  vitrineBadge: layout == VitrineServicoLayout.destaque ? 'Mais escolhido' : '',
);

void main() {
  final servicos = [
    service('hero', 'Sofá premium', VitrineServicoLayout.destaque),
    service(
      'photo',
      'Colchão casal',
      VitrineServicoLayout.fotografico,
      grupo: 'colchao',
    ),
    service(
      'compare',
      'Poltrona renovada',
      VitrineServicoLayout.antesDepois,
      grupo: 'poltrona',
    ),
    service(
      'compact',
      'Cadeira',
      VitrineServicoLayout.compacto,
      grupo: 'cadeira',
    ),
  ];
  final bootstrap = VitrineBootstrap(
    config: const VitrineConfig(),
    midia: [
      VitrineMidia.fromJson({
        'id': 'cover',
        'servico': 'hero',
        'papel': 'capa',
        'url': 'https://images.example/cover.webp',
      }),
      VitrineMidia.fromJson({
        'id': 'before',
        'servico': 'compare',
        'papel': 'antes',
        'par_id': 'pair-1',
        'url': 'https://images.example/before.webp',
      }),
      VitrineMidia.fromJson({
        'id': 'after',
        'servico': 'compare',
        'papel': 'depois',
        'par_id': 'pair-1',
        'url': 'https://images.example/after.webp',
      }),
    ],
  );

  Future<void> pumpCatalog(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
    ValueChanged<VitrineServico>? onToggle,
    List<VitrineServico>? items,
    String? initialGroup,
    bool carousel = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VitrineCatalogoPersonalizavel(
              servicos: items ?? servicos,
              bootstrap: bootstrap,
              selectedIds: const {},
              onToggle: onToggle ?? (_) {},
              initialGroup: initialGroup,
              carousel: carousel,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renderiza os quatro formatos editoriais', (tester) async {
    await pumpCatalog(tester);

    expect(
      find.byKey(const Key('vitrine-layout-destaque-hero')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('vitrine-layout-fotografico-photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('vitrine-layout-antes_depois-compare')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('vitrine-layout-compacto-compact')),
      findsOneWidget,
    );
    expect(find.text('ANTES'), findsOneWidget);
    expect(find.text('DEPOIS'), findsOneWidget);
  });

  testWidgets('busca filtra sem alterar o fluxo de seleção', (tester) async {
    VitrineServico? selected;
    await pumpCatalog(tester, onToggle: (value) => selected = value);

    await tester.enterText(
      find.byKey(const Key('vitrine-catalogo-busca')),
      'colchão',
    );
    await tester.pump();

    expect(find.text('Colchão casal'), findsOneWidget);
    expect(find.text('Sofá premium'), findsNothing);
    await tester.tap(find.byKey(const Key('vitrine-add-photo')));
    expect(selected?.id, 'photo');
  });

  testWidgets('atalhos casam prefixo e não deixam catálogo vazio', (
    tester,
  ) async {
    final shortcuts = [
      service(
        'auto',
        'Interior automotivo',
        VitrineServicoLayout.fotografico,
        grupo: 'automotivo',
      ),
      service(
        'imper',
        'Impermeabilização',
        VitrineServicoLayout.compacto,
        grupo: 'adicional',
      ),
    ];

    await pumpCatalog(tester, items: shortcuts, initialGroup: 'auto');
    expect(find.text('Interior automotivo'), findsOneWidget);
    expect(find.text('Impermeabilização'), findsNothing);

    await pumpCatalog(tester, items: shortcuts, initialGroup: 'imper');
    expect(find.text('Interior automotivo'), findsNothing);
    expect(find.text('Impermeabilização'), findsOneWidget);

    await pumpCatalog(
      tester,
      items: shortcuts,
      initialGroup: 'sem-correspondencia',
    );
    expect(find.text('Interior automotivo'), findsOneWidget);
    expect(find.text('Impermeabilização'), findsOneWidget);
  });

  testWidgets('abre galeria com todas as fotos do serviço', (tester) async {
    await pumpCatalog(tester);

    final action = find.byKey(const Key('vitrine-gallery-compare'));
    tester.widget<FilledButton>(action).onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Galeria · Poltrona renovada'), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.byKey(const Key('vitrine-gallery-next')), findsOneWidget);
  });

  testWidgets('catálogo não estoura em 390 px', (tester) async {
    await pumpCatalog(tester, size: const Size(390, 844));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Encontre o cuidado certo'), findsOneWidget);
    expect(
      find.byKey(const Key('vitrine-layout-destaque-hero')),
      findsOneWidget,
    );
  });

  testWidgets('CTA longo e texto 2x não estouram no mobile', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpCatalog(
      tester,
      size: const Size(390, 844),
      items: [
        service(
          'cta-longo',
          'Higienização automotiva',
          VitrineServicoLayout.fotografico,
          grupo: 'automotivo',
          cta: 'Quero solicitar uma avaliação personalizada agora',
        ),
      ],
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('destaque e antes/depois suportam conteúdo máximo a 2x', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final title = List.filled(16, 'Título').join(' ').substring(0, 100);
    final description = List.filled(
      55,
      'descrição',
    ).join(' ').substring(0, 480);
    final cta = List.filled(8, 'solicitar').join(' ').substring(0, 60);
    await pumpCatalog(
      tester,
      items: [
        service(
          'hero-longo',
          title,
          VitrineServicoLayout.destaque,
          cta: cta,
          descricao: description,
        ),
        service(
          'compare-longo',
          title,
          VitrineServicoLayout.antesDepois,
          cta: cta,
          descricao: description,
        ),
      ],
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('variante carrossel é horizontal e não estoura no mobile', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpCatalog(tester, size: const Size(390, 844), carousel: true);
    await tester.pump();

    expect(find.byKey(const Key('vitrine-catalogo-carrossel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
