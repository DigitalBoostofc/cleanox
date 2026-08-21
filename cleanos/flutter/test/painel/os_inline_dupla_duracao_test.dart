/// os_inline_dupla_duracao_test.dart — Gerar OS no cadastro de cliente.
///
/// Dois sintomas do dono:
///   1) duração parava em 4h;
///   2) não dava para colocar o 2º profissional na hora de registrar a OS.
library;

import 'package:cleanos/core/auth/auth_providers.dart';
import 'package:cleanos/core/models/collections.dart';
import 'package:cleanos/core/models/ordem_servico.dart';
import 'package:cleanos/core/models/servico.dart';
import 'package:cleanos/core/models/user.dart';
import 'package:cleanos/painel/clientes/cliente_form.dart';
import 'package:cleanos/painel/clientes/os_inline_section.dart';
import 'package:cleanos/painel/data/painel_providers.dart';
import 'package:cleanos/painel/ordens/ordens_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_onda2.dart';
import 'painel_test_helpers.dart';

const _servico = ServicoPB(
  id: 's1',
  nome: 'Higienização Sofá',
  categoria: 'residencial',
  grupo: 'sofa',
  valorBase: 200,
);

const _profs = [
  User(id: 'p1', name: 'Pedro', role: Role.profissional),
  User(id: 'p2', name: 'Marina', role: Role.profissional),
];

List<Override> _overrides({required FakeOrdens ordens}) => [
  ...painelOverrides(user: painelUser()),
  ordensRepositoryProvider.overrideWithValue(ordens),
  clientesRepositoryProvider.overrideWithValue(FakeClientes()),
  servicosRepositoryProvider.overrideWithValue(
    FakeServicos(ativos: const [_servico]),
  ),
  usuariosRepositoryProvider.overrideWithValue(
    FakeUsuarios(profissionais: _profs),
  ),
  ordensLookupsProvider.overrideWith(
    (ref) async => const OrdensLookups(
      servicos: [_servico],
      profissionais: _profs,
    ),
  ),
];

Future<void> _pumpInline(WidgetTester tester) async {
  await pumpPainel(
    tester,
    const SingleChildScrollView(child: OsInlineSection(enabled: true)),
    overrides: _overrides(
      ordens: FakeOrdens(seed: [fakeOS()]),
    ),
  );
  await tester.pumpAndSettle();
}

OrdemServico fakeOS() => OrdemServico(
  id: 'os1',
  nomeCurto: 'Carlos S.',
  bairro: 'Centro',
  tipoServicoNome: 'Higienização',
  dataHora: '2026-07-10 13:00:00Z',
  status: OSStatus.agendada,
  valorServico: 200,
);

void main() {
  testWidgets('Gerar OS não mostra Nome do serviço (snapshot)', (tester) async {
    await _pumpInline(tester);
    expect(find.text('Nome do serviço (snapshot)'), findsNothing);
  });

  testWidgets('Gerar OS: Dupla revela o 2º profissional', (tester) async {
    await _pumpInline(tester);

    expect(find.text('Forma de prestação'), findsOneWidget);
    expect(find.byKey(const ValueKey('os-inline-execucao-modo')), findsOneWidget);
    expect(find.byKey(const ValueKey('os-inline-profissional2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('os-inline-execucao-modo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dupla (2 profissionais)').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('os-inline-profissional2')), findsOneWidget);
    expect(find.text('2º profissional'), findsOneWidget);
  });

  testWidgets('Gerar OS grava os dois profissionais da dupla', (tester) async {
    final ordens = FakeOrdens(one: fakeOS());
    await pumpPainel(
      tester,
      const ClienteForm(),
      overrides: _overrides(ordens: ordens),
    );
    await tester.pumpAndSettle();

    final campos = find.descendant(
      of: find.byType(ClienteForm),
      matching: find.byType(TextField),
    );
    await tester.enterText(campos.at(0), 'Carlos Silva');
    await tester.enterText(campos.at(1), '85999998888');
    await tester.enterText(campos.at(6), 'Centro');

    final gerarOs = find.ancestor(
      of: find.text('Gerar OS'),
      matching: find.byType(Row),
    ).first;
    await tester.ensureVisible(gerarOs);
    await tester.tap(find.descendant(of: gerarOs, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('os-inline-execucao-modo')));
    await tester.tap(find.byKey(const ValueKey('os-inline-execucao-modo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dupla (2 profissionais)').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('os-inline-profissional')));
    await tester.tap(find.byKey(const ValueKey('os-inline-profissional')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('os-inline-profissional2')));
    await tester.tap(find.byKey(const ValueKey('os-inline-profissional2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marina').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('os-inline-servico'),
      ),
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('os-inline-servico'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Higienização Sofá').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.calendar_month_outlined));
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(ordens.createCount, 1);
    expect(ordens.lastCreate?['profissional'], 'p1');
    expect(ordens.lastCreate?['profissional2'], 'p2');
    expect(ordens.lastCreate?['execucao_modo'], ExecucaoModo.dupla.wire);
  });
}
