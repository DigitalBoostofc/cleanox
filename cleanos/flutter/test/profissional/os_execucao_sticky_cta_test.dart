/// os_execucao_sticky_cta_test.dart — CTA fixo "Concluir serviço" (espec tela
/// 3, doc 12 Onda 2): desabilitado sem pagamento/com obrigatórios pendentes,
/// habilitado quando as duas condições da lógica de negócio já existente são
/// satisfeitas. Tema fintech, 360x800 e 320x800 (sem overflow).
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/design.dart';
import 'package:cleanos/core/design/theme_fintech.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/data/prof_providers.dart';
import 'package:cleanos/profissional/os_execucao/os_execucao_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _prof = User(id: 'p1', name: 'Pedro', role: Role.profissional);

OrdemServico _os({
  double? valorPago,
  FormaPagamento? forma,
  bool obrigatorioPendente = false,
}) => OrdemServico(
  id: 'os1',
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  status: OSStatus.emAndamento,
  profissional: 'p1',
  dataHora: '2026-07-01 10:00:00Z',
  valorServico: 150,
  valorPago: valorPago,
  formaPagamento: forma,
  serviceSnapshot: const ServiceSnapshot(
    serviceId: 's1',
    nome: 'Higienização',
    valorBase: 150,
  ),
  checklistExec: [
    ChecklistExecItem(
      id: 'c1',
      titulo: 'Higienização completa',
      obrigatorio: true,
      status: obrigatorioPendente
          ? ChecklistExecStatus.pendente
          : ChecklistExecStatus.concluido,
    ),
  ],
);

Future<void> _pump(WidgetTester tester, OrdemServico os, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_prof),
        ordensRepositoryProvider.overrideWithValue(
          FakeOrdensRepository(execOS: os),
        ),
        evidenciasRepositoryProvider.overrideWithValue(
          FakeEvidenciasRepository(),
        ),
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
      ],
      child: MaterialApp(
        theme: buildFintechLightTheme(),
        home: const OSExecucaoScreen(osId: 'os1'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

ClxButton _cta(WidgetTester tester) => tester
    .widgetList<ClxButton>(find.byType(ClxButton))
    .firstWhere((b) => b.label == 'Concluir serviço');

void main() {
  testWidgets('sem pagamento e sem obrigatórios: CTA desabilitado (360x800)', (
    tester,
  ) async {
    await _pump(tester, _os(), const Size(360, 800));

    expect(find.text('Concluir serviço'), findsOneWidget);
    expect(_cta(tester).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('obrigatório pendente MESMO com pagamento: CTA desabilitado', (
    tester,
  ) async {
    await _pump(
      tester,
      _os(
        valorPago: 150,
        forma: FormaPagamento.pixMaquininha,
        obrigatorioPendente: true,
      ),
      const Size(360, 800),
    );

    expect(_cta(tester).onPressed, isNull);
  });

  testWidgets('pagamento registrado e checklist ok: CTA habilitado', (
    tester,
  ) async {
    await _pump(
      tester,
      _os(valorPago: 150, forma: FormaPagamento.pixMaquininha),
      const Size(360, 800),
    );

    expect(_cta(tester).onPressed, isNotNull);
  });

  testWidgets('320x800: sem overflow com o CTA fixo no rodapé', (
    tester,
  ) async {
    await _pump(
      tester,
      _os(valorPago: 150, forma: FormaPagamento.pixMaquininha),
      const Size(320, 800),
    );

    expect(tester.takeException(), isNull);
  });
}
