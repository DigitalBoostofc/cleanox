/// resumo_screen_test.dart — Dashboard Resumo: filtros + métricas.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/resumo/resumo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'fakes.dart';

const _user = User(id: 'p1', name: 'Pedro', role: Role.profissional);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  List<OrdemServico> ordens = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user),
        ordensRepositoryProvider.overrideWithValue(
          FakeOrdensRepository(listItems: ordens),
        ),
        // Coleção deslocamento: sem PB real → km 0 (catch no provider).
        pocketBaseProvider.overrideWithValue(PocketBase('http://127.0.0.1:9')),
      ],
      child: MaterialApp(
        theme: buildFintechLightTheme(),
        home: const Scaffold(body: ProfResumoScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

OrdemServico _os(String id, OSStatus status) => OrdemServico(
  id: id,
  status: status,
  profissional: 'p1',
  valorServico: 200,
);

void main() {
  testWidgets('mostra atendimentos e deslocamento (sem avaliação)', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(360, 800),
      ordens: [
        _os('1', OSStatus.agendada),
        _os('2', OSStatus.concluida),
        _os('3', OSStatus.cancelada),
      ],
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
    expect(find.text('Mês'), findsOneWidget);
    expect(find.text('Agendados'), findsOneWidget);
    expect(find.text('Canceladas'), findsOneWidget);
    expect(find.text('Realizados'), findsOneWidget);
    expect(find.text('Deslocamento'), findsOneWidget);
    expect(find.text('Avaliação'), findsNothing);
    expect(find.text('A receber'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem overflow a 320dp', (tester) async {
    await _pump(tester, size: const Size(320, 800));
    expect(tester.takeException(), isNull);
  });
}
