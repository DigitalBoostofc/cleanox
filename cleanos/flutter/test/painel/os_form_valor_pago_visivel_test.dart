/// Nova OS não pede Valor pago — isso é da conclusão.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/disponibilidade.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/core/repositories/disponibilidade_repository.dart';
import 'package:cleanos/core/repositories/repo_types.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/ordens/os_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'fakes_painel.dart';
import 'painel_test_helpers.dart';

class _FakeDispVazia implements DisponibilidadeRepository {
  @override
  Future<PageResult<Disponibilidade>> list({
    int page = 1,
    int perPage = 30,
    String? filter,
    String sort = 'profissional',
  }) async => const PageResult<Disponibilidade>(
    items: [],
    page: 1,
    perPage: 30,
    totalItems: 0,
    totalPages: 1,
  );

  Never _u() => throw UnimplementedError();
  @override
  Future<Disponibilidade> getOne(String id) => _u();
  @override
  Future<Disponibilidade> create(Map<String, dynamic> data) => _u();
  @override
  Future<Disponibilidade> update(String id, Map<String, dynamic> data) => _u();
  @override
  Future<void> delete(String id) => _u();
}

List<Override> _overrides() => [
  ...painelOverrides(user: painelUser()),
  ordensRepositoryProvider.overrideWithValue(FakeOrdens()),
  clientesRepositoryProvider.overrideWithValue(FakeClientes()),
  servicosRepositoryProvider.overrideWithValue(FakeServicos()),
  usuariosRepositoryProvider.overrideWithValue(
    FakeUsuarios(
      profissionais: const [
        User(id: 'p1', name: 'Pedro', role: Role.profissional),
      ],
    ),
  ),
  disponibilidadeRepositoryProvider.overrideWithValue(_FakeDispVazia()),
];

Future<void> _pump(WidgetTester tester, Widget child) async {
  await pumpPainel(tester, child, overrides: _overrides());
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('Nova OS não mostra Valor pago', (tester) async {
    await _pump(tester, const OSForm());

    expect(find.textContaining('Valor do serviço principal'), findsOneWidget);
    expect(find.textContaining('Valor pago'), findsNothing);
    expect(find.textContaining('caixa real'), findsNothing);
  });

  testWidgets('OS em andamento mostra Valor pago para concluir', (tester) async {
    await _pump(
      tester,
      OSForm(editing: painelOS(id: 'os1', status: OSStatus.emAndamento)),
    );

    expect(find.textContaining('Valor pago'), findsWidgets);
  });
}
