/// empty_state_test.dart — F-opcional (Onda 4, item 8): círculo `bg3` atrás
/// do ícone só quando `isFintechCleanProvider` é true (fiel ao mock); a Web
/// (sem override, default false) não pode ganhar o círculo por acidente.
library;

import 'package:cleanos/app.dart';
import 'package:cleanos/core/design/app_surface_provider.dart';
import 'package:cleanos/core/design/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required bool fintech}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (fintech)
          appSurfaceProvider.overrideWithValue(AppSurface.android),
      ],
      child: const MaterialApp(
        home: Scaffold(body: EmptyState(title: 'Nada por aqui')),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Web (sem override): ícone sem círculo atrás', (tester) async {
    await _pump(tester, fintech: false);

    expect(find.byType(Icon), findsOneWidget);
    expect(
      find.ancestor(of: find.byType(Icon), matching: find.byType(Container)),
      findsNothing,
    );
  });

  testWidgets('Fintech Clean (APK): ícone ganha círculo bg3 atrás', (
    tester,
  ) async {
    await _pump(tester, fintech: true);

    final containerFinder = find.ancestor(
      of: find.byType(Icon),
      matching: find.byType(Container),
    );
    expect(containerFinder, findsOneWidget);

    final decoration =
        tester.widget<Container>(containerFinder).decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
  });
}
