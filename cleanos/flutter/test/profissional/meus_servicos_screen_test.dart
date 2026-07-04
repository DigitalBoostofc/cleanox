/// meus_servicos_screen_test.dart — Reskin "Fintech Clean" (doc 12, Onda 2):
/// seções Em aberto/Hoje/Próximos, badges por status e estado vazio, no tema
/// fintech (`AppSurface.android`) em 360x800 e 320x800 (sem overflow).
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/data/prof_providers.dart';
import 'package:cleanos/profissional/meus_servicos/meus_servicos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _user = User(id: 'p1', name: 'Pedro', role: Role.profissional);

OrdemServico _os(
  String id, {
  required OSStatus status,
  required String dataHora,
  String nome = 'Carlos S.',
}) => OrdemServico(
  id: id,
  nomeCurto: nome,
  bairro: 'Centro',
  tipoServicoNome: 'Higienização',
  status: status,
  profissional: 'p1',
  dataHora: dataHora,
  valorServico: 150,
);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  List<OrdemServico> Function(int index)? listByIndex,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = FakeOrdensRepository()..listByIndex = listByIndex;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user),
        ordensRepositoryProvider.overrideWithValue(repo),
        ordensRealtimeProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: MaterialApp(
        theme: buildFintechLightTheme(),
        home: const Scaffold(body: MeusServicosScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('seções Em aberto/Hoje/Próximos + badges por status (360x800)', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(360, 800),
      // índice 0=hoje, 1=próximas, 2=atrasadas (mesma ordem de Future.wait
      // no MeusServicosController.refresh).
      listByIndex: (i) => switch (i) {
        0 => [_os('hoje1', status: OSStatus.emAndamento, dataHora: '2026-07-03 09:00:00Z')],
        1 => [_os('prox1', status: OSStatus.atribuida, dataHora: '2026-07-10 09:00:00Z')],
        2 => [_os('atraso1', status: OSStatus.atribuida, dataHora: '2020-01-01 09:00:00Z')],
        _ => [],
      },
    );

    expect(find.text('Em aberto (atrasado)'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    // Badges de status com as cores semânticas do tema fintech (via StatusBadge
    // + CleanoxColors.fintechLight — atribuída=violeta, em andamento=warning).
    expect(find.text('Atribuída'), findsWidgets);
    expect(find.text('Em andamento'), findsOneWidget);

    // "Próximos agendamentos" fica mais abaixo na lista — rola até ele.
    await tester.scrollUntilVisible(find.text('Próximos agendamentos'), 300);
    expect(find.text('Próximos agendamentos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('estado vazio quando não há serviço nenhuma janela (360x800)', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(360, 800),
      listByIndex: (_) => const [],
    );

    expect(find.text('Nenhum serviço hoje'), findsOneWidget);
  });

  testWidgets('320x800: sem overflow com as 3 seções povoadas', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(320, 800),
      listByIndex: (i) => switch (i) {
        0 => [_os('hoje1', status: OSStatus.concluida, dataHora: '2026-07-03 09:00:00Z')],
        1 => [_os('prox1', status: OSStatus.atribuida, dataHora: '2026-07-10 09:00:00Z')],
        2 => [_os('atraso1', status: OSStatus.atribuida, dataHora: '2020-01-01 09:00:00Z')],
        _ => [],
      },
    );

    expect(tester.takeException(), isNull);
  });
}
