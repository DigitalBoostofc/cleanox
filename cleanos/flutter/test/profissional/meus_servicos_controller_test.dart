/// meus_servicos_controller_test.dart — Regras da conclusão da OS:
///  - checklist obrigatório pendente BLOQUEIA a conclusão (abre a execução),
///  - sem pendências, conclui e chama updateStatus(concluida).
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/os_execucao.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/profissional/data/prof_providers.dart';
import 'package:cleanos/profissional/meus_servicos/meus_servicos_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _user = User(id: 'p1', name: 'Pedro', role: Role.profissional);

OrdemServico _execComChecklist({required bool obrigatorioPendente}) =>
    OrdemServico(
      id: 'os1',
      nomeCurto: 'Carlos S.',
      status: OSStatus.emAndamento,
      profissional: 'p1',
      dataHora: '2026-07-01 10:00:00Z',
      valorServico: 150,
      valorPago: 150,
      formaPagamento: FormaPagamento.debito,
      checklistExec: [
        ChecklistExecItem(
          id: 'c1',
          titulo: 'Aspirar',
          obrigatorio: true,
          status: obrigatorioPendente
              ? ChecklistExecStatus.pendente
              : ChecklistExecStatus.concluido,
        ),
      ],
    );

ProviderContainer _container(FakeOrdensRepository repo) {
  final c = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(_user),
      ordensRepositoryProvider.overrideWithValue(repo),
      ordensRealtimeProvider.overrideWith((ref) => const Stream.empty()),
    ],
  );
  addTearDown(c.dispose);
  // Mantém o provider autoDispose vivo durante o teste.
  c.listen(meusServicosProvider, (_, __) {});
  return c;
}

void main() {
  test('conclusão BLOQUEIA quando há item obrigatório pendente', () async {
    final repo = FakeOrdensRepository(
      execOS: _execComChecklist(obrigatorioPendente: true),
    );
    final c = _container(repo);
    final ctrl = c.read(meusServicosProvider.notifier);

    final os = repo.execOS!;
    final res = await ctrl.concluir(os);

    expect(res, ConcluirResultado.checklistPendente);
    expect(repo.statusCalls, isEmpty, reason: 'não pode concluir no servidor');
  });

  test('conclusão prossegue quando não há obrigatório pendente', () async {
    final repo = FakeOrdensRepository(
      execOS: _execComChecklist(obrigatorioPendente: false),
    );
    final c = _container(repo);
    final ctrl = c.read(meusServicosProvider.notifier);

    final res = await ctrl.concluir(repo.execOS!);

    expect(res, ConcluirResultado.concluida);
    expect(repo.statusCalls, [OSStatus.concluida]);
  });

  test('A-03: falha do getExec NÃO conclui às cegas — erro propaga', () async {
    final repo = FakeOrdensRepository(
      execOS: _execComChecklist(obrigatorioPendente: true),
    )..getExecError = Exception('offline');
    final c = _container(repo);
    final ctrl = c.read(meusServicosProvider.notifier);

    await expectLater(
      ctrl.concluir(repo.execOS!),
      throwsA(isA<Exception>()),
    );
    expect(
      repo.statusCalls,
      isEmpty,
      reason: 'sem validar o checklist, a OS não pode ser concluída',
    );
  });
}
