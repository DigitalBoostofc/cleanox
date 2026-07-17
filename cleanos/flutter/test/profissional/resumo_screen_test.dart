/// resumo_screen_test.dart — Aba Resumo do profissional: renderiza os 5
/// indicadores no tema fintech, sem overflow em 320/360dp.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/prof_comissao.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/comissao_repository.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/profissional/resumo/resumo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _user = User(id: 'p1', name: 'Pedro', role: Role.profissional);

/// Fake mínimo: só `listComissoes` é exercido pela tela.
class _FakeComissaoRepo implements ComissaoRepository {
  _FakeComissaoRepo(this.items);
  final List<ProfComissao> items;

  @override
  Future<List<ProfComissao>> listComissoes({
    String? profissionalId,
    String sort = '-created',
  }) async => items;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

ProfComissao _com(String id, double v, ComissaoStatus s) => ProfComissao(
  id: id,
  profissional: 'p1',
  os: 'os-$id',
  valorComissao: v,
  valorOs: 200,
  status: s,
);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  List<OrdemServico> ordens = const [],
  List<ProfComissao> comissoes = const [],
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
        comissaoRepositoryProvider.overrideWithValue(
          _FakeComissaoRepo(comissoes),
        ),
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

OrdemServico _os(String id, OSStatus status, {double? nota}) => OrdemServico(
  id: id,
  status: status,
  profissional: 'p1',
  valorServico: 200,
  avaliacaoNota: nota,
);

void main() {
  testWidgets('mostra os cinco indicadores', (tester) async {
    await _pump(
      tester,
      size: const Size(360, 800),
      ordens: [
        _os('1', OSStatus.agendada),
        _os('2', OSStatus.concluida, nota: 5),
      ],
      comissoes: [
        _com('a', 30, ComissaoStatus.pendente),
        _com('b', 50, ComissaoStatus.paga),
      ],
    );

    expect(find.text('Agendados'), findsOneWidget);
    expect(find.text('Realizados'), findsOneWidget);
    expect(find.text('A receber'), findsOneWidget);
    expect(find.text('Recebidos'), findsOneWidget);
    expect(find.text('Avaliação'), findsOneWidget);
    // Sem exceções de layout (overflow etc).
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem dados: zeros e aviso de avaliação, sem overflow a 320dp', (
    tester,
  ) async {
    await _pump(tester, size: const Size(320, 800));

    expect(find.textContaining('Sem avaliações ainda'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
