import 'package:cleanos/vitrine/vitrine_api.dart';
import 'package:cleanos/vitrine/widgets/vitrine_servico_detalhes_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('popup detalhes mostra capa título texto e Adicionar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var toggled = false;
    const servico = VitrineServico(
      id: 'svc1',
      nome: 'Sofá 3 lugares',
      descricao: 'fallback',
      categoria: 'residencial',
      grupo: 'sofa',
      valorBase: 250,
      valorBaseMax: 0,
      tempoMedioMin: 120,
      tempoMedioLabel: '2h',
      orientacoesPre: '',
      vitrineDescricao: 'Inclui higienização completa dos assentos e encosto.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open'),
              onPressed: () => showVitrineServicoDetalhes(
                context,
                servico: servico,
                media: const [],
                onToggle: () => toggled = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vitrine-detalhes-titulo-svc1')), findsOneWidget);
    expect(find.text('Sofá 3 lugares'), findsOneWidget);
    expect(find.text('Detalhes'), findsOneWidget);
    expect(
      find.text('Inclui higienização completa dos assentos e encosto.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('vitrine-detalhes-adicionar-svc1')),
      findsOneWidget,
    );
    expect(find.text('+ Adicionar'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vitrine-detalhes-adicionar-svc1')));
    await tester.pumpAndSettle();
    expect(toggled, isTrue);
  });
}
