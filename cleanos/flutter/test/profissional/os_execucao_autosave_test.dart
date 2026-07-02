/// os_execucao_autosave_test.dart — Auto-save DEBOUNCED do checklist:
///  - alterar o checklist agenda um patchExec após ~800ms,
///  - o body enviado contém SÓ `checklist_exec` (nunca campos travados → sem 403).
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

final _execOS = OrdemServico(
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

void main() {
  testWidgets('checklist auto-save envia só checklist_exec após debounce', (
    tester,
  ) async {
    final ordens = FakeOrdensRepository(execOS: _execOS);
    final evid = FakeEvidenciasRepository();

    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(_user),
        ordensRepositoryProvider.overrideWithValue(ordens),
        evidenciasRepositoryProvider.overrideWithValue(evid),
        ordensRealtimeProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(osExecucaoProvider('os1'), (_, __) {});

    final ctrl = container.read(osExecucaoProvider('os1').notifier);

    // Aguarda o load (getExec + evidências) concluir.
    await tester.pump(const Duration(milliseconds: 50));
    var state = container.read(osExecucaoProvider('os1'));
    expect(state.loading, isFalse);
    expect(state.checklist, hasLength(2));

    // Marca o 1º item como concluído.
    final novo = [
      state.checklist[0].copyWith(
        status: ChecklistExecStatus.concluido,
        concluidoEm: '2026-07-01 10:05:00Z',
      ),
      state.checklist[1],
    ];
    ctrl.setChecklist(novo);

    // Antes do debounce (800ms), NADA foi salvo.
    await tester.pump(const Duration(milliseconds: 300));
    expect(ordens.patchCalls, isEmpty);

    // Depois do debounce, salva UMA vez com só checklist_exec.
    await tester.pump(const Duration(milliseconds: 700));
    expect(ordens.patchCalls, hasLength(1));
    expect(ordens.patchCalls.single.keys.toSet(), {'checklist_exec'});

    state = container.read(osExecucaoProvider('os1'));
    expect(state.saveState, SaveState.saved);

    // Drena o timer de reset "salvo → idle" (2s) para não deixar Timer pendente.
    await tester.pump(const Duration(seconds: 3));
  });
}
