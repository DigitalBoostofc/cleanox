/// os_execucao_offline_checklist_test.dart — Buffer offline do checklist (M3).
///
/// Offline, a edição do checklist só vivia em memória e morria com o app. Agora:
///  - falha de save → estado de erro + edição bufferizada em secure storage,
///  - recriar o provider (restart/reconnect) → a edição é recuperada e REENVIADA.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/data/prof_providers.dart';
import 'package:cleanos/profissional/os_execucao/os_execucao_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _user = User(id: 'p1', name: 'Pedro', role: Role.profissional);
const _bufKey = 'cleanos_checklist_exec_os1';

OrdemServico _execOS() => OrdemServico(
  id: 'os1',
  nomeCurto: 'Carlos S.',
  status: OSStatus.emAndamento,
  profissional: 'p1',
  dataHora: '2026-07-01 10:00:00Z',
  valorServico: 150,
  serviceSnapshot: const ServiceSnapshot(
    serviceId: 's1',
    nome: 'Higienização',
    valorBase: 150,
  ),
  checklistExec: const [
    ChecklistExecItem(id: 'c1', titulo: 'Aspirar'),
    ChecklistExecItem(id: 'c2', titulo: 'Enxaguar'),
  ],
);

ProviderContainer _container({
  required FakeOrdensRepository ordens,
  required FakeSecureStorage storage,
}) {
  final c = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(_user),
      ordensRepositoryProvider.overrideWithValue(ordens),
      evidenciasRepositoryProvider.overrideWithValue(
        FakeEvidenciasRepository(),
      ),
      secureStorageProvider.overrideWithValue(storage),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

List<ChecklistExecItem> _marcarPrimeiro(List<ChecklistExecItem> src) => [
  src[0].copyWith(
    status: ChecklistExecStatus.concluido,
    concluidoEm: '2026-07-01 10:05:00Z',
  ),
  src[1],
];

void main() {
  testWidgets('save offline falha → erro e bufferiza em secure storage', (
    tester,
  ) async {
    final storage = FakeSecureStorage();
    final ordens = FakeOrdensRepository(execOS: _execOS())
      ..patchError = Exception('offline');
    final c = _container(ordens: ordens, storage: storage);
    c.listen(osExecucaoProvider('os1'), (_, __) {});
    final ctrl = c.read(osExecucaoProvider('os1').notifier);

    await tester.pump(const Duration(milliseconds: 50)); // load
    expect(c.read(osExecucaoProvider('os1')).checklist, hasLength(2));

    ctrl.setChecklist(
      _marcarPrimeiro(c.read(osExecucaoProvider('os1')).checklist),
    );
    await tester.pump(const Duration(milliseconds: 50)); // grava o buffer já
    expect(
      storage.store.containsKey(_bufKey),
      isTrue,
      reason: 'edição precisa persistir antes mesmo do debounce',
    );

    await tester.pump(const Duration(milliseconds: 850)); // debounce → _doSave
    expect(c.read(osExecucaoProvider('os1')).saveState, SaveState.error);
    // Buffer permanece (não foi confirmado no servidor).
    expect(storage.store.containsKey(_bufKey), isTrue);
  });

  testWidgets('recriar o provider recupera a edição e reenvia', (tester) async {
    final storage = FakeSecureStorage();

    // 1ª sessão: offline → edita e bufferiza.
    final ordens1 = FakeOrdensRepository(execOS: _execOS())
      ..patchError = Exception('offline');
    final c1 = _container(ordens: ordens1, storage: storage);
    c1.listen(osExecucaoProvider('os1'), (_, __) {});
    final ctrl1 = c1.read(osExecucaoProvider('os1').notifier);
    await tester.pump(const Duration(milliseconds: 50));
    ctrl1.setChecklist(
      _marcarPrimeiro(c1.read(osExecucaoProvider('os1')).checklist),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(storage.store.containsKey(_bufKey), isTrue);
    c1.dispose();

    // 2ª sessão (restart/reconnect): online, MESMO storage.
    final ordens2 = FakeOrdensRepository(execOS: _execOS());
    final c2 = _container(ordens: ordens2, storage: storage);
    c2.listen(osExecucaoProvider('os1'), (_, __) {});
    await tester.pump(
      const Duration(milliseconds: 100),
    ); // load + restore + resend

    final state = c2.read(osExecucaoProvider('os1'));
    // A edição foi recuperada…
    expect(state.checklist[0].concluido, isTrue);
    // …e REENVIADA (patch com checklist_exec).
    expect(ordens2.patchCalls, isNotEmpty);
    expect(ordens2.patchCalls.last.keys, contains('checklist_exec'));
    // Confirmado → buffer limpo.
    expect(storage.store.containsKey(_bufKey), isFalse);

    // Drena o timer "salvo → idle" (2s) do _doSave bem-sucedido.
    await tester.pump(const Duration(seconds: 3));
  });
}
