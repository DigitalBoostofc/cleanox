/// os_execucao_screen_test.dart — ANTI-DESVIO na tela de execução (P2).
///
///  - endereço liberado só aparece em `em_andamento` (oculto p/ outros status),
///  - visão-de-job: nome_curto aparece; id do cliente / telefone NUNCA.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/design/theme.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/data/prof_providers.dart';
import 'package:cleanos/profissional/os_execucao/os_execucao_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _user = User(id: 'p1', name: 'Pedro', role: Role.profissional);

OrdemServico _os(OSStatus status) => OrdemServico(
  id: 'os1',
  cliente: 'cliente_secreto_id',
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  status: status,
  profissional: 'p1',
  dataHora: '2026-07-01 10:00:00Z',
  valorServico: 150,
  enderecoLiberado: 'Rua Secreta, 123',
  serviceSnapshot: const ServiceSnapshot(
    serviceId: 's1',
    nome: 'Higienização',
    valorBase: 150,
  ),
);

Future<void> _pump(WidgetTester tester, OSStatus status) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user),
        ordensRepositoryProvider.overrideWithValue(
          FakeOrdensRepository(execOS: _os(status)),
        ),
        evidenciasRepositoryProvider.overrideWithValue(
          FakeEvidenciasRepository(),
        ),
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const OSExecucaoScreen(osId: 'os1'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100)); // load + fotos
}

void main() {
  testWidgets('endereço OCULTO fora de em_andamento (atribuida)', (
    tester,
  ) async {
    await _pump(tester, OSStatus.atribuida);

    expect(find.textContaining('Rua Secreta'), findsNothing);
    // Visão-de-job: nome_curto aparece; id do cliente nunca.
    expect(find.text('Carlos S.'), findsOneWidget);
    expect(find.textContaining('cliente_secreto_id'), findsNothing);
  });

  testWidgets('endereço LIBERADO em em_andamento', (tester) async {
    await _pump(tester, OSStatus.emAndamento);
    expect(find.textContaining('Rua Secreta, 123'), findsWidgets);
  });
}
